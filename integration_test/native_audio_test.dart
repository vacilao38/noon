import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:noon/model.dart';
import 'package:noon/platform_services.dart';
import 'package:noon/synth.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native player decodes generated stereo WAV and emits completion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Noon · verificação do áudio nativo')),
        ),
      ),
    );
    final project = NoonProject(
      name: 'Integração',
      bpm: 180,
      volume: .18,
      chords: ['C'],
      sections: const [Section('Teste', 1, 1)],
      layers: const [Layer(mode: 'melodia', notes: 'A4:1 R:3', reverb: 0)],
    );
    final rendered = renderAudio(project);
    final directory = await getTemporaryDirectory();
    expect(await Directory(directory.path).exists(), true);
    final audio = NativeAudio();
    try {
      final complete = audio.completed.first.timeout(
        const Duration(seconds: 15),
      );
      await audio.play(rendered.wav);
      await complete;
      await audio.stop();
      final second = renderAudio(
        project.copyWith(sections: [const Section('Outro som', 2, 1)]),
      );
      await audio.play(second.wav);
      final secondComplete = audio.completed.first.timeout(
        const Duration(seconds: 15),
      );
      final duration = await audio.duration;
      await secondComplete;
      expect(duration, isNotNull);
      expect(
        duration!.inMilliseconds,
        closeTo((second.seconds * 1000).round(), 60),
        reason:
            'Replacing WAV content must reload its duration, even at the same file path.',
      );
      await audio.stop();
    } finally {
      await audio.dispose();
    }
  });
}
