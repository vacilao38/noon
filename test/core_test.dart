import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:noon/model.dart';
import 'package:noon/synth.dart';
import 'package:noon/controller.dart';
import 'fakes.dart';

NoonProject tone({Layer? layer, double volume = .8}) => NoonProject(
  name: 'Teste',
  bpm: 180,
  volume: volume,
  chords: ['C'],
  sections: const [Section('Teste', 1, 1)],
  layers: [layer ?? const Layer(mode: 'melodia', notes: 'A4:1 R:3', reverb: 0)],
);
double rms(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  var sum = 0.0;
  for (var i = 44; i < wav.length; i += 4) {
    final v = data.getInt16(i, Endian.little) / 32768;
    sum += v * v;
  }
  return sum / ((wav.length - 44) / 4);
}

void main() {
  test('Script round-trip preserves parameter precision and tiny energies', () {
    final p = tone(
      layer: const Layer(gain: .123456789, attack: .004567891),
    ).copyWith(sections: [const Section('Baixa', 1, 1e-8)]);
    final reopened = parseNoon(p.encode());
    expect(reopened.layers.first.gain, p.layers.first.gain);
    expect(reopened.layers.first.attack, p.layers.first.attack);
    expect(reopened.sections.first.energy, 1e-8);
    expect(
      renderAudio(reopened, sampleRate: 22050).wav,
      renderAudio(p, sampleRate: 22050).wav,
    );
  });
  test('Draft byte limit accounts for multibyte UTF-8 characters', () async {
    final c = NoonController(storage: MemoryStorage(), audio: SilentAudio());
    await c.initialize();
    final before = c.draft;
    c.editDraft('🎶' * 20000);
    expect(c.draft, before);
    expect(c.error, contains('UTF-8'));
    c.dispose();
  });
  test('Stop during native note preparation prevents late playback', () async {
    final audio = DelayedAudio();
    final c = NoonController(storage: MemoryStorage(), audio: audio);
    await c.initialize();
    final pending = c.audition('C4');
    await audio.started.future;
    await c.stop();
    audio.release.complete();
    await pending;
    expect(audio.audible, false);
    c.dispose();
  });
  test('Noon Script round-trip preserves all musical values and Unicode', () {
    final p = NoonProject.demo().copyWith(name: 'Música "âmbar" 🎶');
    expect(parseNoon(p.encode()).encode(), p.encode());
    expect(
      parseNoon('\uFEFF// projeto UTF-8\n${p.encode()}').encode(),
      p.encode(),
    );
  });
  test('Unknown versions, commands and duplicate properties are rejected', () {
    final s = tone().encode();
    for (final invalid in [
      s.replaceFirst('noon 1', 'noon 2'),
      '${s}import arquivo',
      s.replaceFirst('  ganho', '  ganho 0.5\n  ganho'),
      s.replaceFirst('fim', ''),
    ]) {
      expect(() => parseNoon(invalid), throwsA(isA<ScriptError>()));
    }
  });
  test('Parser reports source line without changing another document', () {
    final p = tone();
    try {
      parseNoon(p.encode().replaceFirst('tempo 180', 'tempo NaN'));
      fail('Accepted NaN');
    } on ScriptError catch (e) {
      expect(e.line, 3);
    }
    expect(p.bpm, 180);
  });
  test('Limits bound duration, layers, notes and source size', () {
    expect(
      () => parseNoon(
        tone()
            .copyWith(bpm: 60, sections: [const Section('Longo', 16, 1)])
            .encode(),
      ),
      throwsA(isA<ScriptError>()),
    );
    expect(
      () => parseNoon(
        tone().copyWith(layers: List.filled(9, const Layer())).encode(),
      ),
      throwsA(isA<ScriptError>()),
    );
    expect(
      () => parseNoon('noon 1\n${' ' * 65536}'),
      throwsA(isA<ScriptError>()),
    );
    for (final notes in [
      'C4:0',
      'C4:NaN',
      'C4:Infinity',
      'C4:0.01',
      'H4:1',
      'C4',
      'R:2 ' * 65,
    ]) {
      expect(() => parseNotes(notes), throwsFormatException);
    }
  });
  test('Harmony resolves sharps, flats and seventh intervals', () {
    expect(noteMidi('A4'), 69);
    expect(chordMidi('Am', 4), [69, 72, 76]);
    expect(chordMidi('Bbmaj7', 3), [58, 62, 65, 69]);
    expect(chordMidi('Dm7', 4), [62, 65, 69, 72]);
    expect(chordMidi('F#7', 3), [54, 58, 61, 64]);
  });
  test(
    'Renderer produces deterministic stereo PCM WAV with correct header',
    () {
      final a = renderAudio(tone(), sampleRate: 22050);
      final b = renderAudio(tone(), sampleRate: 22050);
      final data = ByteData.sublistView(a.wav);
      expect(ascii.decode(a.wav.sublist(0, 4)), 'RIFF');
      expect(data.getUint32(4, Endian.little), a.wav.length - 8);
      expect(data.getUint16(22, Endian.little), 2);
      expect(data.getUint32(24, Endian.little), 22050);
      expect(data.getUint16(34, Endian.little), 16);
      expect(a.wav, b.wav);
      expect(rms(a.wav), greaterThan(.0001));
      expect(data.getInt16(a.wav.length - 2, Endian.little), 0);
    },
  );
  test('A4 has 440 Hz, pan directs channels, and master affects amplitude', () {
    final p = tone(
      layer: const Layer(
        mode: 'melodia',
        notes: 'A4:1 R:3',
        pan: -1,
        attack: .002,
        reverb: 0,
        release: .02,
        cutoff: 16000,
      ),
    );
    final a = renderAudio(p, sampleRate: 22050);
    final data = ByteData.sublistView(a.wav);
    var crossings = 0;
    for (var i = 2205; i < 4410; i++) {
      if (data.getInt16(44 + i * 4, Endian.little) >= 0 &&
          data.getInt16(44 + (i - 1) * 4, Endian.little) < 0) {
        crossings++;
      }
      expect(data.getInt16(46 + i * 4, Endian.little), 0);
    }
    expect(crossings, closeTo(44, 1));
    expect(
      rms(renderAudio(p.copyWith(volume: .4), sampleRate: 22050).wav) /
          rms(a.wav),
      closeTo(.25, .005),
    );
  });
  test('Mute is silent and heavy summation stays below full scale', () {
    final silent = renderAudio(
      tone(layer: const Layer(muted: true)),
      sampleRate: 22050,
    );
    expect(rms(silent.wav), 0);
    final loud = renderAudio(
      tone().copyWith(
        layers: List.filled(
          8,
          const Layer(wave: 'quadrada', gain: 1, drive: 1, reverb: 1, echo: 1),
        ),
      ),
      sampleRate: 22050,
    );
    expect(loud.peak, lessThanOrEqualTo(.951));
  });
  test('All instruments and performance modes create finite nonzero audio', () {
    for (final wave in waveNames.keys) {
      final a = renderAudio(tone(layer: Layer(wave: wave)), sampleRate: 22050);
      expect(a.peak.isFinite, true);
      expect(rms(a.wav), greaterThan(0));
    }
    for (final mode in modeNames.keys) {
      expect(
        rms(renderAudio(tone(layer: Layer(mode: mode)), sampleRate: 22050).wav),
        greaterThan(0),
      );
    }
  });
  test('Effects and filter alter real PCM samples', () {
    final dry = tone(
      layer: const Layer(
        mode: 'melodia',
        wave: 'serra',
        notes: 'C4:1 R:3',
        reverb: 0,
      ),
    );
    final reference = renderAudio(dry, sampleRate: 22050).wav;
    for (final layer in [
      dry.layers.first.copyWith(cutoff: 200),
      dry.layers.first.copyWith(drive: .8),
      dry.layers.first.copyWith(echo: .7),
      dry.layers.first.copyWith(reverb: .9),
    ]) {
      expect(
        renderAudio(dry.copyWith(layers: [layer]), sampleRate: 22050).wav,
        isNot(reference),
      );
    }
  });
  test(
    'Invalid draft survives save/reopen; apply is transactional and undo works',
    () async {
      final store = MemoryStorage();
      final c = NoonController(storage: store, audio: SilentAudio());
      await c.initialize();
      final original = c.project.encode();
      c.editDraft('noon 1\ncomando_invalido');
      expect(c.applyDraft(), false);
      expect(c.project.encode(), original);
      expect(c.canEdit, false);
      await c.flush();
      final c2 = NoonController(storage: store, audio: SilentAudio());
      await c2.initialize();
      expect(c2.draft, 'noon 1\ncomando_invalido');
      expect(c2.dirty, true);
      c2.revertDraft();
      c2.updateLayer(c2.layer.copyWith(drive: .8));
      expect(c2.layer.drive, .8);
      c2.undo();
      expect(c2.project.encode(), original);
      c2.redo();
      expect(c2.layer.drive, .8);
      c.dispose();
      c2.dispose();
    },
  );
  test('Corrupt workspace is preserved and save errors are visible', () async {
    final store = MemoryStorage()..content = '{bad';
    final c = NoonController(storage: store, audio: SilentAudio());
    await c.initialize();
    c.updateLayer(c.layer.copyWith(drive: .2));
    await c.flush();
    expect(store.content, '{bad');
    expect(store.saves, 0);
    c.dispose();
    final broken = MemoryStorage()..failSave = true;
    final c2 = NoonController(storage: broken, audio: SilentAudio());
    await c2.initialize();
    await c2.flush();
    expect(c2.error, contains('Não foi possível salvar'));
    c2.dispose();
  });
  test(
    'Invalid import does not replace project and exported script reopens',
    () async {
      final store = MemoryStorage()..incoming = 'noon 99';
      final c = NoonController(storage: store, audio: SilentAudio());
      await c.initialize();
      final before = c.project.encode();
      await c.importProject();
      expect(c.project.encode(), before);
      expect(c.error, isNotNull);
      await c.exportProject();
      expect(parseNoon(utf8.decode(store.exported!)).encode(), before);
      c.dispose();
    },
  );
}

class DelayedAudio extends SilentAudio {
  final started = Completer<void>(), release = Completer<void>();
  bool audible = false;
  @override
  Future<void> play(Uint8List bytes) async {
    started.complete();
    await release.future;
    audible = true;
  }

  @override
  Future<void> stop() async {
    audible = false;
  }
}
