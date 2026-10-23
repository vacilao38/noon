import 'dart:convert';
import 'dart:io';
import 'package:noon/model.dart';
import 'package:noon/synth.dart';

void main() {
  final directory = Directory('artifacts')..createSync(recursive: true);
  final project = NoonProject.demo();
  final timer = Stopwatch()..start();
  final audio = renderAudio(project);
  timer.stop();
  File(
    '${directory.path}/Entre-o-sol-e-o-silencio.noon',
  ).writeAsStringSync(project.encode(), encoding: utf8);
  File(
    '${directory.path}/Entre-o-sol-e-o-silencio.wav',
  ).writeAsBytesSync(audio.wav);
  final effect = NoonProject(
    name: 'Sinal de outro lugar',
    bpm: 120,
    chords: ['Dm'],
    sections: const [Section('Sinal', 1, .8)],
    layers: const [
      Layer(
        name: 'Subida',
        mode: 'fx',
        wave: 'serra',
        gain: .23,
        attack: .3,
        release: .6,
        drive: .35,
        reverb: .5,
        octave: 3,
      ),
      Layer(
        name: 'Ar',
        mode: 'fx',
        wave: 'ruido',
        gain: .13,
        attack: .7,
        release: .8,
        cutoff: 2500,
        pan: .25,
        reverb: .3,
      ),
    ],
  );
  File(
    '${directory.path}/Sinal.noon',
  ).writeAsStringSync(effect.encode(), encoding: utf8);
  File('${directory.path}/Sinal.wav').writeAsBytesSync(renderAudio(effect).wav);
  File('${directory.path}/render-metrics.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'sampleRate': audio.sampleRate,
      'channels': 2,
      'bits': 16,
      'arrangementSeconds': project.seconds,
      'wavSeconds': audio.seconds,
      'bytes': audio.wav.length,
      'peak': audio.peak,
      'renderMillisecondsDartJit': timer.elapsedMilliseconds,
      'note':
          'Medição local de render offline. Não mede latência, FPS, memória nem desempenho Android.',
    }),
    encoding: utf8,
  );
  stdout.writeln(
    'Exemplos .noon e WAV gerados. Render do demo: ${timer.elapsedMilliseconds} ms.',
  );
}
