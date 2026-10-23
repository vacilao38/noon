import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noon/controller.dart';
import 'package:noon/workspace.dart';
import 'fakes.dart';

void main() {
  testWidgets('Editing dialogs remain usable in landscape with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(740, 360);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = NoonController(storage: MemoryStorage(), audio: SilentAudio());
    await c.initialize();
    await tester.pumpWidget(NoonApp(controller: c));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('96 BPM'));
    await tester.tap(find.text('96 BPM'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compor').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Editar seção 1'));
    await tester.tap(find.byTooltip('Editar seção 1'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pumpAndSettle();
  });
  for (final size in [
    const Size(390, 844),
    const Size(740, 360),
    const Size(800, 1280),
    const Size(1280, 800),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('All panels fit ${size.width}×${size.height} text $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final c = NoonController(
          storage: MemoryStorage(),
          audio: SilentAudio(),
        );
        await c.initialize();
        await tester.pumpWidget(NoonApp(controller: c));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final page in ['Timbre', 'Compor', 'Script', 'Estúdio']) {
          final target = size.width >= 1000
              ? find.byTooltip(page)
              : find.text(page).last;
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$page at $size, text $scale',
          );
        }
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await tester.pumpAndSettle();
      });
    }
  }
  testWidgets(
    'Typing invalid script preserves draft and applying valid script updates studio',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final c = NoonController(storage: MemoryStorage(), audio: SilentAudio());
      await c.initialize();
      final original = c.project.encode();
      await tester.pumpWidget(NoonApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Script').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('script-editor')),
        'noon 1\nerrado',
      );
      await tester.tap(find.text('Aplicar script'));
      await tester.pumpAndSettle();
      expect(c.error, contains('Linha 2'));
      expect(c.project.encode(), original);
      await tester.enterText(
        find.byKey(const ValueKey('script-editor')),
        original.replaceFirst('tempo 96', 'tempo 110'),
      );
      await tester.tap(find.text('Aplicar script'));
      await tester.pumpAndSettle();
      expect(c.project.bpm, 110);
      expect(c.dirty, false);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pumpAndSettle();
    },
  );
  if (Platform.environment['NOON_CAPTURE'] == '1') {
    testWidgets('Capture actual Flutter layouts', (tester) async {
      await tester.runAsync(() async {
        for (final entry in [
          ('Lato', 'assets/fonts/Lato-Regular.ttf'),
          ('Bitcount', 'assets/fonts/BitcountGridSingleInk.ttf'),
          (
            'MaterialIcons',
            '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ),
        ]) {
          await (FontLoader(entry.$1)..addFont(
                File(
                  entry.$2,
                ).readAsBytes().then((b) => ByteData.sublistView(b)),
              ))
              .load();
        }
      });
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = NoonController(storage: MemoryStorage(), audio: SilentAudio());
      await c.initialize();
      final key = GlobalKey();
      for (final entry in [
        ('desktop', const Size(1440, 900)),
        ('phone', const Size(390, 844)),
        ('tablet', const Size(800, 1280)),
      ]) {
        tester.view.physicalSize = entry.$2;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: NoonApp(controller: c),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('artifacts/noon-${entry.$1}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.pumpAndSettle();
    });
  }
}
