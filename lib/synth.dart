import 'dart:math' as math;
import 'dart:typed_data';
import 'model.dart';

class RenderedAudio {
  final Uint8List wav;
  final List<double> peaks;
  final double seconds, peak;
  final int sampleRate;
  const RenderedAudio(
    this.wav,
    this.peaks,
    this.seconds,
    this.peak,
    this.sampleRate,
  );
}

/// Offline rendering is run in an isolate. Samples and noise are deterministic.
RenderedAudio renderAudio(NoonProject project, {int sampleRate = 44100}) {
  // Validate programmatically-created documents as strictly as imported scripts.
  parseNoon(project.encode());
  if (sampleRate != 22050 && sampleRate != 44100) {
    throw ArgumentError('Sample rate inválido.');
  }
  final length = ((project.seconds + 4) * sampleRate).ceil();
  final left = Float32List(length), right = Float32List(length);
  final beat = 60 / project.bpm;
  for (var index = 0; index < project.layers.length; index++) {
    final layer = project.layers[index];
    if (layer.muted || layer.gain == 0) continue;
    final mono = Float32List(length);
    var bar = 0;
    for (final section in project.sections) {
      for (var local = 0; local < section.bars; local++, bar++) {
        final start = bar * 4 * beat;
        final chord = chordMidi(
          project.chords[bar % project.chords.length],
          layer.octave,
        );
        void note(
          int midi,
          double offset,
          double duration, [
          double velocity = 1,
        ]) {
          _voice(
            mono,
            layer,
            midiHz(midi),
            start + offset * beat,
            duration * beat,
            section.energy * velocity,
            sampleRate,
            index * 7919 + bar * 97 + midi,
          );
        }

        switch (layer.mode) {
          case 'pad':
            for (final midi in chord) {
              note(midi, 0, 3.6, .48);
            }
          case 'baixo':
            note(chord.first, 0, 1.3);
            note(chord.first, 2, 1.2, .8);
          case 'arp':
            for (var step = 0; step < 8; step++) {
              note(chord[step % chord.length], step / 2, .38, .8);
            }
          case 'pulso':
            for (var step = 0; step < 4; step++) {
              note(chord.first, step.toDouble(), .16, step.isEven ? 1 : .55);
            }
          case 'fx':
            note(chord.first, 0, 3.1, .7);
          case 'melodia':
            var offset = 0.0;
            final steps = parseNotes(layer.notes);
            var step = 0;
            while (offset < 4) {
              final event = steps[step++ % steps.length];
              final duration = math.min(event.beats, 4 - offset);
              if (event.midi != null) {
                note(event.midi!, offset, duration * .86, .85);
              }
              offset += duration;
            }
        }
      }
    }
    // One-pole low pass -> soft saturation -> delay -> diffuse multi-tap room.
    final alpha =
        1 -
        math.exp(
          -2 * math.pi * math.min(layer.cutoff, sampleRate * .44) / sampleRate,
        );
    double filtered = 0;
    final drive = 1 + layer.drive * 9;
    final norm = math.atan(drive);
    for (var i = 0; i < length; i++) {
      filtered += alpha * (mono[i] - filtered);
      mono[i] = layer.drive == 0
          ? filtered
          : math.atan(filtered * drive) / norm;
    }
    if (layer.echo > 0) {
      final delay = (beat * .75 * sampleRate).round();
      for (var i = delay; i < length; i++) {
        mono[i] += mono[i - delay] * layer.echo * .55;
      }
    }
    if (layer.reverb > 0) {
      // Parallel taps read an unchanged signal, avoiding unstable feedback.
      final dry = Float32List.fromList(mono);
      for (var tap = 0; tap < 6; tap++) {
        final delay = ((.031 + tap * .0473) * sampleRate).round();
        final wet = layer.reverb * .3 * math.pow(.72, tap);
        for (var i = delay; i < length; i++) {
          mono[i] += dry[i - delay] * wet;
        }
      }
    }
    final l = math.sqrt((1 - layer.pan) / 2) * layer.gain;
    final r = math.sqrt((1 + layer.pan) / 2) * layer.gain;
    for (var i = 0; i < length; i++) {
      left[i] += mono[i] * l;
      right[i] += mono[i] * r;
    }
  }
  var maxPeak = 0.0;
  for (var i = 0; i < length; i++) {
    maxPeak = math.max(maxPeak, math.max(left[i].abs(), right[i].abs()));
  }
  // Attenuate only when necessary; master volume always has an audible effect.
  final scale = project.volume * (maxPeak > .95 ? .95 / maxPeak : 1.0);
  final bytes = Uint8List(44 + length * 4);
  final data = ByteData.sublistView(bytes);
  void ascii(int offset, String value) {
    bytes.setRange(offset, offset + value.length, value.codeUnits);
  }

  ascii(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 2, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 4, Endian.little);
  data.setUint16(32, 4, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, length * 4, Endian.little);
  final peaks = List<double>.filled(240, 0);
  for (var i = 0; i < length; i++) {
    final fade = math.min(1.0, (length - 1 - i) / (sampleRate * .03));
    final l = (left[i] * scale * fade).clamp(-1.0, 1.0);
    final r = (right[i] * scale * fade).clamp(-1.0, 1.0);
    data.setInt16(44 + i * 4, (l * 32767).round(), Endian.little);
    data.setInt16(46 + i * 4, (r * 32767).round(), Endian.little);
    final bucket = math.min(239, i * 240 ~/ length);
    peaks[bucket] = math.max(peaks[bucket], math.max(l.abs(), r.abs()));
  }
  return RenderedAudio(
    bytes,
    peaks,
    length / sampleRate,
    maxPeak * scale,
    sampleRate,
  );
}

void _voice(
  Float32List target,
  Layer layer,
  double hz,
  double start,
  double duration,
  double velocity,
  int rate,
  int seed,
) {
  final first = (start * rate).round();
  final count = ((duration + layer.release) * rate).ceil();
  final random = math.Random(seed);
  var phase = 0.0;
  for (var i = 0; i < count && first + i < target.length; i++) {
    final time = i / rate;
    var frequency = hz;
    if (layer.mode == 'pulso') frequency = 42 + hz * math.exp(-time * 35);
    if (layer.mode == 'fx') {
      frequency *= math.pow(2, 2 * time / math.max(.1, duration));
    }
    phase += frequency / rate;
    final p = phase % 1;
    final s = math.sin(2 * math.pi * p);
    double value;
    switch (layer.wave) {
      case 'triangulo':
        value = 1 - 4 * (p - .5).abs();
      // Finite harmonic sums limit aliasing for bright waveforms.
      case 'serra':
        value = 0;
        for (var h = 1; h <= 10 && frequency * h < rate * .45; h++) {
          value += math.sin(2 * math.pi * phase * h) / h;
        }
        value *= .58;
      case 'quadrada':
        value = 0;
        for (var h = 1; h <= 11 && frequency * h < rate * .45; h += 2) {
          value += math.sin(2 * math.pi * phase * h) / h;
        }
        value *= .8;
      case 'piano':
        value =
            (s +
                .3 * math.sin(4 * math.pi * p) +
                .12 * math.sin(6 * math.pi * p)) *
            math.exp(-time * 2.2) *
            .7;
      case 'sino':
        value =
            (s +
                .4 *
                    math.sin(2 * math.pi * phase * 2.76) *
                    math.exp(-time * 3)) *
            math.exp(-time * 2) *
            .7;
      case 'ruido':
        value = random.nextDouble() * 2 - 1;
      default:
        value = s;
    }
    var envelope = math.min(1.0, time / layer.attack);
    if (time > duration) {
      envelope *= math.max(0, 1 - (time - duration) / layer.release);
    }
    if (layer.mode == 'pulso') envelope *= math.exp(-time * 19);
    target[first + i] += value * envelope * velocity;
  }
}
