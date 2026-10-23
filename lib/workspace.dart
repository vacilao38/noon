import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controller.dart';
import 'design.dart';
import 'model.dart';
import 'platform_services.dart';

class NoonApp extends StatelessWidget {
  final NoonController? controller;
  const NoonApp({super.key, this.controller});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Noon',
    debugShowCheckedModeBanner: false,
    theme: noonTheme(),
    home: Workspace(controller: controller),
  );
}

class Workspace extends StatefulWidget {
  final NoonController? controller;
  const Workspace({super.key, this.controller});
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> with WidgetsBindingObserver {
  late final NoonController c =
      widget.controller ??
      NoonController(storage: NativeStorage(), audio: NativeAudio());
  late final TextEditingController script = TextEditingController(
    text: c.draft,
  );
  final scriptFocus = FocusNode();
  int page = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    if (!c.ready) unawaited(c.initialize());
  }

  void _changed() {
    if (!mounted) return;
    if (script.text != c.draft) {
      script.value = TextEditingValue(
        text: c.draft,
        selection: TextSelection.collapsed(
          offset: math.min(
            script.selection.baseOffset.clamp(0, c.draft.length),
            c.draft.length,
          ),
        ),
      );
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(c.flush());
      unawaited(c.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    script.dispose();
    scriptFocus.dispose();
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final desktop = box.maxWidth >= 1000;
      final inspector = box.maxWidth >= 1320 && page == 0;
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: desktop ? 24 : 16,
          title: Row(
            children: [
              const NoonMark(),
              const SizedBox(width: 10),
              const Text(
                'noon',
                style: TextStyle(
                  fontFamily: 'Bitcount',
                  fontSize: 30,
                  letterSpacing: -1,
                ),
              ),
              if (desktop) ...[
                const SizedBox(width: 18),
                const Text(
                  'CLUSTTER CORES',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: NoonColors.muted,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Desfazer',
              onPressed: c.canUndo ? c.undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            if (box.maxWidth > 480)
              IconButton(
                tooltip: 'Refazer',
                onPressed: c.canRedo ? c.redo : null,
                icon: const Icon(Icons.redo_rounded),
              ),
            if (desktop)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FilledButton.icon(
                  onPressed: c.canEdit ? c.exportWav : null,
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  label: const Text('Exportar WAV'),
                ),
              ),
            PopupMenuButton<String>(
              tooltip: 'Arquivos e ajuda',
              onSelected: _menuAction,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'open',
                  enabled: c.canEdit,
                  child: const Text('Abrir projeto .noon'),
                ),
                PopupMenuItem(
                  value: 'save',
                  enabled: c.canEdit,
                  child: const Text('Exportar projeto .noon'),
                ),
                PopupMenuItem(
                  value: 'wav',
                  enabled: c.canEdit,
                  child: const Text('Exportar WAV'),
                ),
                PopupMenuItem(
                  value: 'demo',
                  enabled: c.canEdit,
                  child: const Text('Carregar exemplo (pode desfazer)'),
                ),
                const PopupMenuItem(
                  value: 'help',
                  child: Text('Como usar o Noon'),
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (c.busy) const LinearProgressIndicator(minHeight: 2),
              if (c.error != null) _message(c.error!, error: true),
              if (c.dirty && page != 3)
                _message(
                  'Há um rascunho no Script. Aplique ou descarte as alterações para continuar.',
                  action: () => setState(() => page = 3),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (desktop) _rail(),
                    if (desktop)
                      SizedBox(width: 230, child: _layers(sidebar: true)),
                    Expanded(child: _content(desktop)),
                    if (inspector)
                      Container(
                        width: 310,
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: NoonColors.line),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _inspector(),
                        ),
                      ),
                  ],
                ),
              ),
              _transport(desktop),
            ],
          ),
        ),
        bottomNavigationBar: desktop
            ? null
            : NavigationBar(
                selectedIndex: page,
                onDestinationSelected: (v) {
                  FocusScope.of(context).unfocus();
                  setState(() => page = v);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.graphic_eq_rounded),
                    label: 'Estúdio',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.tune_rounded),
                    label: 'Timbre',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.queue_music_rounded),
                    label: 'Compor',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.code_rounded),
                    label: 'Script',
                  ),
                ],
              ),
      );
    },
  );
  Widget _message(String message, {bool error = false, VoidCallback? action}) =>
      Container(
        width: double.infinity,
        color: error ? const Color(0xff422a27) : NoonColors.selected,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(error ? Icons.error_outline : Icons.code_rounded, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (action != null)
              TextButton(onPressed: action, child: const Text('Abrir Script')),
          ],
        ),
      );
  Widget _rail() => Container(
    width: 76,
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: NoonColors.line)),
    ),
    child: SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 18),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  IconButton.filledTonal(
                    tooltip: ['Estúdio', 'Timbre', 'Compor', 'Script'][i],
                    style: IconButton.styleFrom(
                      backgroundColor: page == i
                          ? NoonColors.selected
                          : Colors.transparent,
                      foregroundColor: page == i
                          ? NoonColors.amber
                          : NoonColors.muted,
                    ),
                    onPressed: () => setState(() => page = i),
                    icon: Icon(
                      [
                        Icons.graphic_eq_rounded,
                        Icons.tune_rounded,
                        Icons.queue_music_rounded,
                        Icons.code_rounded,
                      ][i],
                    ),
                  ),
                  Text(
                    ['Estúdio', 'Timbre', 'Compor', 'Script'][i],
                    style: TextStyle(
                      fontSize: 10,
                      color: page == i ? NoonColors.amber : NoonColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 48),
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              'FEITO PARA OUVIR',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 2,
                color: NoonColors.muted.withValues(alpha: .6),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );
  Widget _layers({bool sidebar = false}) {
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'CAMADAS  /  ${c.project.layers.length}',
                style: const TextStyle(
                  fontSize: 10,
                  color: NoonColors.muted,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Adicionar camada',
              onPressed: c.canEdit ? _addLayer : null,
              icon: const Icon(Icons.add_rounded, size: 20),
            ),
          ],
        ),
      ),
      for (var i = 0; i < c.project.layers.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Material(
            color: c.selected == i ? NoonColors.raised : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => c.select(i),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 34,
                      decoration: BoxDecoration(
                        color: NoonColors.tracks[i],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.project.layers[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: c.project.layers[i].muted
                                  ? NoonColors.muted
                                  : NoonColors.text,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            modeNames[c.project.layers[i].mode]!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: NoonColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: c.project.layers[i].muted
                          ? 'Ativar ${c.project.layers[i].name}'
                          : 'Silenciar ${c.project.layers[i].name}',
                      onPressed: c.canEdit
                          ? () {
                              final layers = [...c.project.layers];
                              layers[i] = layers[i].copyWith(
                                muted: !layers[i].muted,
                              );
                              c.update(c.project.copyWith(layers: layers));
                            }
                          : null,
                      icon: Icon(
                        c.project.layers[i].muted
                            ? Icons.volume_off_outlined
                            : Icons.volume_up_outlined,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Selecione uma camada e abra Timbre para transformar o som.',
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: NoonColors.muted.withValues(alpha: .85),
          ),
        ),
      ),
    ];
    return Container(
      decoration: sidebar
          ? const BoxDecoration(
              color: NoonColors.surface,
              border: Border(right: BorderSide(color: NoonColors.line)),
            )
          : null,
      child: sidebar ? ListView(children: rows) : Column(children: rows),
    );
  }

  Widget _content(bool desktop) {
    if (page == 3) return _code();
    return SingleChildScrollView(
      key: ValueKey('page-$page'),
      padding: EdgeInsets.all(desktop ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _projectHeading(desktop),
          const SizedBox(height: 24),
          if (page == 0) ...[
            _soundPreview(),
            const SizedBox(height: 22),
            _heading('Arranjo', '${c.project.bars} compassos · 4/4'),
            const SizedBox(height: 14),
            _timeline(),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < c.project.chords.length; i++)
                  Chip(
                    label: Text(c.project.chords[i]),
                    side: const BorderSide(color: NoonColors.line),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Harmonia'),
                  onPressed: () => setState(() => page = 2),
                ),
              ],
            ),
            if (!desktop) _layers(),
            const SizedBox(height: 10),
            _keyboard(),
          ],
          if (page == 1) ...[
            _keyboard(),
            const SizedBox(height: 24),
            _inspector(),
          ],
          if (page == 2) ...[_composition()],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _projectHeading(bool desktop) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        page == 0
            ? 'UM ESPAÇO PARA EXPERIMENTAR'
            : page == 1
            ? 'ESCULPA O SEU SOM'
            : 'ENCONTRE UM CAMINHO',
        style: const TextStyle(
          fontSize: 9,
          letterSpacing: 2.2,
          color: NoonColors.amber,
        ),
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              c.project.name,
              style: TextStyle(
                fontSize: desktop ? 27 : 23,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Renomear projeto',
            onPressed: c.canEdit ? _renameProject : null,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ActionChip(
            label: Text('${c.project.bpm.round()} BPM'),
            avatar: const Icon(Icons.speed_rounded, size: 16),
            onPressed: c.canEdit ? _tempo : null,
          ),
          Text(
            '  ${(c.project.seconds).toStringAsFixed(1)} s  ·  4/4  ·  local',
            style: const TextStyle(color: NoonColors.muted, fontSize: 12),
          ),
        ],
      ),
    ],
  );
  Widget _heading(String title, String detail) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 14,
    runSpacing: 8,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      Text(
        detail,
        style: const TextStyle(color: NoonColors.muted, fontSize: 11),
      ),
    ],
  );
  Widget _soundPreview() => Panel(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.waves_rounded, color: NoonColors.amber, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                c.rendered == null ? c.layer.name : 'Mixagem do projeto',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Text(
              c.rendered == null ? 'TIMBRE' : 'PRÉVIA · 22,05 kHz',
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 1,
                color: NoonColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: c.rendered == null
              ? 'Representação da forma de onda ${waveNames[c.layer.wave]}'
              : 'Forma de onda do áudio renderizado',
          child: SizedBox(
            height: 104,
            width: double.infinity,
            child: CustomPaint(
              painter: WavePainter(
                c.layer.wave,
                c.rendered?.peaks,
                c.playSeconds / (c.rendered?.seconds ?? 1),
              ),
            ),
          ),
        ),
        Text(
          c.rendered == null
              ? 'Toque em Ouvir para renderizar a mixagem.'
              : 'Áudio sintetizado no dispositivo · estéreo',
          style: const TextStyle(fontSize: 11, color: NoonColors.muted),
        ),
      ],
    ),
  );
  Widget _timeline() => LayoutBuilder(
    builder: (context, box) {
      final w = math.max(480.0, box.maxWidth);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: w,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 116),
                  for (var i = 0; i < c.project.bars; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${i + 1}'.padLeft(2, '0'),
                          style: const TextStyle(
                            fontSize: 9,
                            color: NoonColors.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 116),
                  for (var i = 0; i < c.project.sections.length; i++)
                    Expanded(
                      flex: c.project.sections[i].bars,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4, bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: NoonColors.raised,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c.project.sections[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: NoonColors.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              for (var i = 0; i < c.project.layers.length; i++)
                InkWell(
                  onTap: () => c.select(i),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: c.selected == i
                          ? NoonColors.raised
                          : NoonColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 116,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              c.project.layers[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: NoonColors.tracks[i],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: CustomPaint(
                              painter: ArrangementPainter(
                                c.project,
                                i,
                                c.playSeconds,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
  Widget _keyboard() => Panel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text(
              'Experimente as notas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            Text(
              '${c.layer.name} · oitava ${c.layer.octave}',
              style: const TextStyle(color: NoonColors.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final note in [
                'C',
                'C#',
                'D',
                'D#',
                'E',
                'F',
                'F#',
                'G',
                'G#',
                'A',
                'A#',
                'B',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: note.contains('#') ? 38 : 44,
                    height: note.contains('#') ? 60 : 76,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: note.contains('#')
                            ? NoonColors.text
                            : NoonColors.background,
                        backgroundColor: note.contains('#')
                            ? NoonColors.field
                            : const Color(0xffe5e2d6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      onPressed: c.canEdit
                          ? () => c.audition('$note${c.layer.octave}')
                          : null,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            note,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Prévia de uma nota por vez. As teclas não gravam no arranjo.',
          style: TextStyle(fontSize: 10, color: NoonColors.muted),
        ),
      ],
    ),
  );
  Widget _inspector() {
    final l = c.layer;
    void edit(Layer next) => c.updateLayer(next);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Timbre & efeitos', 'CAMADA ${c.selected + 1}'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                l.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Renomear camada',
              onPressed: c.canEdit
                  ? () async {
                      final name = await _textDialog(
                        'Nome da camada',
                        l.name,
                        maxLength: 40,
                      );
                      if (name != null && mounted) edit(l.copyWith(name: name));
                    }
                  : null,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _select(
          'Instrumento',
          l.wave,
          waveNames,
          c.canEdit ? (v) => edit(l.copyWith(wave: v)) : null,
        ),
        const SizedBox(height: 14),
        _select(
          'Como tocar',
          l.mode,
          modeNames,
          c.canEdit ? (v) => edit(l.copyWith(mode: v)) : null,
        ),
        if (l.mode == 'melodia')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: c.canEdit ? _editNotes : null,
              icon: const Icon(Icons.piano_rounded, size: 18),
              label: const Text('Editar sequência de notas'),
            ),
          ),
        Parameter(
          key: ValueKey('gain-${c.selected}'),
          label: 'Volume da camada',
          value: l.gain,
          onChanged: c.canEdit ? (v) => edit(l.copyWith(gain: v)) : null,
        ),
        Parameter(
          key: ValueKey('pan-${c.selected}'),
          label: 'Panorama · esquerda / direita',
          value: l.pan,
          min: -1,
          max: 1,
          onChanged: c.canEdit ? (v) => edit(l.copyWith(pan: v)) : null,
        ),
        Parameter(
          key: ValueKey('octave-${c.selected}'),
          label: 'Oitava',
          value: l.octave.toDouble(),
          min: 1,
          max: 6,
          unit: '',
          divisions: 5,
          onChanged: c.canEdit
              ? (v) => edit(l.copyWith(octave: v.round()))
              : null,
        ),
        const Divider(height: 30),
        const Text(
          'FORMA DO SOM',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            color: NoonColors.muted,
          ),
        ),
        Parameter(
          key: ValueKey('attack-${c.selected}'),
          label: 'Entrada · ataque',
          value: l.attack,
          min: .002,
          max: 2,
          unit: 'ms',
          onChanged: c.canEdit ? (v) => edit(l.copyWith(attack: v)) : null,
        ),
        Parameter(
          key: ValueKey('release-${c.selected}'),
          label: 'Cauda · release',
          value: l.release,
          min: .02,
          max: 3,
          unit: 'ms',
          onChanged: c.canEdit ? (v) => edit(l.copyWith(release: v)) : null,
        ),
        Parameter(
          key: ValueKey('cutoff-${c.selected}'),
          label: 'Brilho · filtro passa-baixas',
          value: l.cutoff,
          min: 100,
          max: 16000,
          unit: 'Hz',
          onChanged: c.canEdit ? (v) => edit(l.copyWith(cutoff: v)) : null,
        ),
        const Divider(height: 30),
        const Text(
          'ESPAÇO & TEXTURA',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            color: NoonColors.muted,
          ),
        ),
        Parameter(
          key: ValueKey('drive-${c.selected}'),
          label: 'Distorção · drive',
          value: l.drive,
          onChanged: c.canEdit ? (v) => edit(l.copyWith(drive: v)) : null,
        ),
        Parameter(
          key: ValueKey('room-${c.selected}'),
          label: 'Ambiente · reverb',
          value: l.reverb,
          onChanged: c.canEdit ? (v) => edit(l.copyWith(reverb: v)) : null,
        ),
        Parameter(
          key: ValueKey('echo-${c.selected}'),
          label: 'Repetições · eco',
          value: l.echo,
          onChanged: c.canEdit ? (v) => edit(l.copyWith(echo: v)) : null,
        ),
        const SizedBox(height: 12),
        const Text(
          'Os efeitos seguem esta ordem: filtro → drive → eco → reverb.',
          style: TextStyle(fontSize: 11, color: NoonColors.muted, height: 1.5),
        ),
        const Divider(height: 30),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: c.canEdit && c.project.layers.length < 8
                  ? () => c.addLayer(
                      l.copyWith(
                        name:
                            '${l.name.substring(0, math.min(l.name.length, 32))} cópia',
                      ),
                    )
                  : null,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Duplicar'),
            ),
            TextButton.icon(
              onPressed: c.canEdit && c.project.layers.length > 1
                  ? c.removeLayer
                  : null,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Remover'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _select(
    String label,
    String value,
    Map<String, String> items,
    ValueChanged<String>? onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label-${c.selected}-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: items.entries
        .map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: Text(
              e.value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        )
        .toList(),
    onChanged: onChanged == null
        ? null
        : (v) {
            if (v != null) onChanged(v);
          },
  );
  Widget _composition() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Um ponto de partida', 'GUIAS DE HARMONIA'),
      const SizedBox(height: 12),
      const Text(
        'Escolha uma progressão. Cada compasso avança um acorde; ao chegar ao fim, a sequência recomeça. Todas as camadas harmônicas acompanham.',
        style: TextStyle(fontSize: 13, color: NoonColors.muted, height: 1.6),
      ),
      const SizedBox(height: 18),
      for (final guide in harmonyGuides.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: c.project.chords.join(' ') == guide.value.join(' ')
                ? NoonColors.selected
                : NoonColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: NoonColors.line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: c.canEdit
                  ? () => c.update(c.project.copyWith(chords: guide.value))
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(guide.key, style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 7),
                          Text(
                            guide.value.join('    →    '),
                            style: const TextStyle(
                              color: NoonColors.amber,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      c.project.chords.join(' ') == guide.value.join(' ')
                          ? Icons.check_circle_outline_rounded
                          : Icons.arrow_forward_rounded,
                      size: 20,
                      color: NoonColors.amber,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      TextButton.icon(
        onPressed: c.canEdit ? _customChords : null,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Usar meus próprios acordes'),
      ),
      const SizedBox(height: 26),
      _heading('Estrutura da trilha', 'SEÇÕES'),
      const SizedBox(height: 14),
      const Text(
        'Adapte uma estrutura que você conhece. A energia de cada seção controla sua intensidade.',
        style: TextStyle(fontSize: 13, color: NoonColors.muted, height: 1.6),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < c.project.sections.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Text(
                  '${i + 1}'.padLeft(2, '0'),
                  style: const TextStyle(
                    fontFamily: 'Bitcount',
                    fontSize: 22,
                    color: NoonColors.amber,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.project.sections[i].name),
                      const SizedBox(height: 4),
                      Text(
                        '${c.project.sections[i].bars} compassos · energia ${(c.project.sections[i].energy * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: NoonColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar seção ${i + 1}',
                  onPressed: c.canEdit ? () => _section(i) : null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  tooltip: 'Remover seção ${i + 1}',
                  onPressed: c.canEdit && c.project.sections.length > 1
                      ? () {
                          final sections = [...c.project.sections]..removeAt(i);
                          c.update(c.project.copyWith(sections: sections));
                        }
                      : null,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: c.canEdit && c.project.sections.length < 8
            ? () => _section(null)
            : null,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Adicionar seção'),
      ),
      const SizedBox(height: 22),
      Parameter(
        label: 'Volume geral',
        value: c.project.volume,
        onChanged: c.canEdit
            ? (v) => c.update(c.project.copyWith(volume: v))
            : null,
      ),
      const SizedBox(height: 12),
      const Text(
        'Para estudar uma música, informe seus acordes e seções manualmente. Esta versão não identifica nem importa a harmonia de uma gravação.',
        style: TextStyle(fontSize: 11, color: NoonColors.muted, height: 1.6),
      ),
    ],
  );
  Widget _code() => LayoutBuilder(
    builder: (context, bounds) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('O som também é código.', 'NOON SCRIPT · v1'),
            const SizedBox(height: 10),
            const Text(
              'Edite aqui ou cole um script feito com uma LLM. Aplique para atualizar o estúdio.',
              style: TextStyle(
                fontSize: 12,
                color: NoonColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: c.ready && !c.busy ? c.applyDraft : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Aplicar script'),
                ),
                OutlinedButton.icon(
                  onPressed: c.ready && !c.busy ? _copyContext : null,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar para LLM'),
                ),
                if (c.dirty)
                  TextButton(
                    onPressed: !c.busy ? c.revertDraft : null,
                    child: const Text('Descartar rascunho'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: math.max(260, bounds.maxHeight - 245),
              child: TextField(
                key: const ValueKey('script-editor'),
                controller: script,
                focusNode: scriptFocus,
                enabled: c.ready && !c.busy,
                expands: true,
                maxLines: null,
                minLines: null,
                maxLength: 65536,
                textAlignVertical: TextAlignVertical.top,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.7,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'noon 1',
                ),
                onChanged: c.editDraft,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              c.dirty
                  ? 'Rascunho salvo separadamente · ainda não aplicado'
                  : 'Visual e script sincronizados · UTF-8',
              style: const TextStyle(fontSize: 10, color: NoonColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _transport(bool desktop) => Container(
    decoration: const BoxDecoration(
      color: NoonColors.surface,
      border: Border(top: BorderSide(color: NoonColors.line)),
    ),
    padding: EdgeInsets.symmetric(horizontal: desktop ? 24 : 14, vertical: 10),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Parar reprodução',
          onPressed: c.ready ? c.stop : null,
          icon: const Icon(Icons.stop_rounded),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: c.playing
              ? c.stop
              : c.canEdit
              ? c.play
              : null,
          icon: Icon(
            c.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
          label: Text(
            c.busy
                ? 'Preparando…'
                : c.playing
                ? 'Parar'
                : 'Ouvir',
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_time(c.playSeconds)} / ${_time(c.rendered?.seconds ?? c.project.seconds)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                c.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: NoonColors.muted),
              ),
            ],
          ),
        ),
        if (desktop)
          const Text(
            'SÍNTESE LOCAL  /  ESTÉREO',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.5,
              color: NoonColors.muted,
            ),
          ),
      ],
    ),
  );
  String _time(double seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).floor().toString().padLeft(2, '0')}';
  void _menuAction(String action) {
    switch (action) {
      case 'open':
        unawaited(c.importProject());
      case 'save':
        unawaited(c.exportProject());
      case 'wav':
        unawaited(c.exportWav());
      case 'demo':
        c.loadExample(NoonProject.demo());
      case 'help':
        _help();
    }
  }

  Future<String?> _textDialog(
    String title,
    String initial, {
    int maxLength = 80,
    String? hint,
  }) async {
    final field = TextEditingController(text: initial);
    String? validation;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: field,
              autofocus: true,
              maxLength: maxLength,
              decoration: InputDecoration(
                hintText: hint,
                errorText: validation,
              ),
              onSubmitted: (_) {
                if (field.text.trim().isNotEmpty) {
                  Navigator.pop(context, field.text.trim());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (field.text.trim().isEmpty) {
                  setLocal(() => validation = 'Preencha o campo.');
                  return;
                }
                Navigator.pop(context, field.text.trim());
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    // The route may still animate out while retaining the text field.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    field.dispose();
    return result;
  }

  Future<void> _renameProject() async {
    final name = await _textDialog('Nome do projeto', c.project.name);
    if (name != null && mounted) c.update(c.project.copyWith(name: name));
  }

  Future<void> _customChords() async {
    final chords = await _textDialog(
      'Acordes por compasso',
      c.project.chords.join(' '),
      maxLength: 120,
      hint: 'Am F C G',
    );
    if (chords != null && mounted) {
      c.update(c.project.copyWith(chords: chords.split(RegExp(r'\s+'))));
    }
  }

  Future<void> _editNotes() async {
    final notes = await _textDialog(
      'Notas · duração em tempos',
      c.layer.notes,
      maxLength: 640,
      hint: 'C4:1 E4:0.5 R:0.5 G4:2',
    );
    if (notes != null && mounted) c.updateLayer(c.layer.copyWith(notes: notes));
  }

  Future<void> _tempo() async {
    var value = c.project.bpm;
    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          scrollable: true,
          title: const Text('Encontre o ritmo'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.round()} BPM',
                  style: const TextStyle(
                    fontFamily: 'Bitcount',
                    fontSize: 36,
                    color: NoonColors.amber,
                  ),
                ),
                Slider(
                  value: value,
                  min: 60,
                  max: 180,
                  divisions: 120,
                  onChanged: (v) => setLocal(() => value = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, value),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) c.update(c.project.copyWith(bpm: result));
  }

  Future<void> _section(int? index) async {
    final old = index == null
        ? const Section('Nova seção', 2, .8)
        : c.project.sections[index];
    final name = TextEditingController(text: old.name);
    var bars = old.bars.toDouble(), energy = old.energy;
    final result = await showDialog<Section>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          scrollable: true,
          title: Text(index == null ? 'Adicionar seção' : 'Editar seção'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  const SizedBox(height: 16),
                  Text('${bars.round()} compassos'),
                  Slider(
                    value: bars,
                    min: 1,
                    max: 16,
                    divisions: 15,
                    onChanged: (v) => setLocal(() => bars = v),
                  ),
                  Text('Energia ${(energy * 100).round()}%'),
                  Slider(
                    value: energy,
                    onChanged: (v) => setLocal(() => energy = v),
                  ),
                  const Text(
                    'Limite total: 16 compassos e 60 segundos.',
                    style: TextStyle(fontSize: 11, color: NoonColors.muted),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isNotEmpty) {
                  Navigator.pop(
                    context,
                    Section(name.text.trim(), bars.round(), energy),
                  );
                }
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    if (result != null && mounted) {
      final sections = [...c.project.sections];
      if (index == null) {
        sections.add(result);
      } else {
        sections[index] = result;
      }
      c.update(c.project.copyWith(sections: sections));
    }
  }

  Future<void> _addLayer() async {
    const presets = [
      Layer(name: 'Acordes macios', wave: 'triangulo', attack: .3, reverb: .4),
      Layer(name: 'Piano de bolso', wave: 'piano', mode: 'melodia'),
      Layer(
        name: 'Arpejo de vidro',
        wave: 'sino',
        mode: 'arp',
        octave: 5,
        echo: .2,
      ),
      Layer(
        name: 'Baixo redondo',
        mode: 'baixo',
        octave: 2,
        cutoff: 1200,
        reverb: .05,
      ),
      Layer(
        name: 'Pulso',
        mode: 'pulso',
        octave: 2,
        attack: .004,
        release: .08,
        reverb: .05,
      ),
      Layer(
        name: 'Vento',
        mode: 'fx',
        wave: 'ruido',
        attack: 1.2,
        release: 1,
        cutoff: 2400,
        reverb: .5,
        gain: .2,
      ),
      Layer(
        name: 'Subida digital',
        mode: 'fx',
        wave: 'serra',
        attack: .6,
        reverb: .3,
        drive: .2,
        gain: .25,
      ),
    ];
    final layer = await showModalBottomSheet<Layer>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              const ListTile(
                title: Text('Comece por um som'),
                subtitle: Text('Tudo pode ser transformado depois.'),
              ),
              for (final l in presets)
                ListTile(
                  leading: Icon(
                    l.mode == 'fx'
                        ? Icons.blur_on_rounded
                        : Icons.piano_rounded,
                    color: NoonColors.amber,
                  ),
                  title: Text(l.name),
                  subtitle: Text(modeNames[l.mode]!),
                  trailing: const Icon(Icons.add_rounded),
                  onTap: () => Navigator.pop(context, l),
                ),
            ],
          ),
        ),
      ),
    );
    if (layer != null && mounted) c.addLayer(layer);
  }

  Future<void> _copyContext() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '''Crie ou altere este projeto Noon Script v1. Responda apenas com um script válido, sem Markdown.
Sintaxe: noon 1; projeto "Nome"; tempo 60..180; volume 0..1; harmonia Am F C G.
Cada comando fica em uma linha. Seções: secao "Nome" compassos energia. Total até 16 compassos e 60 s; no máximo 8 seções.
Até 8 blocos: camada "Nome" modo, propriedades em linhas, fechar com fim.
Modos: pad, baixo, arp, pulso, melodia, fx. Ondas: seno, triangulo, serra, quadrada, piano, sino, ruido.
Propriedades: onda; ganho 0..1; pan -1..1; oitava 1..6; ataque .002..2; release .02..3; filtro 100..16000; drive/reverb/eco 0..1; mudo sim/nao; notas C4:1 E4:0.5 R:0.5.
Acordes A..G, #/b opcionais, sufixos m, 7, m7, maj7. Um acorde por compasso; sequências de notas repetem a cada compasso. Energia da seção 0..1. Sem loops, imports, expressões ou outros comandos.
Projeto atual:
${c.draft}''',
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Instruções da linguagem e projeto copiados. Cole na sua LLM.',
          ),
        ),
      );
    }
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Um pequeno estúdio de possibilidades'),
      content: const SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Text(
            '1. Toque em Ouvir para escutar o projeto de exemplo.\n\n2. Selecione uma camada. Em Timbre, escolha o instrumento e experimente volume, brilho e efeitos.\n\n3. Em Compor, escolha os acordes e ajuste as seções da trilha.\n\n4. Tudo vira Noon Script. Use Copiar para LLM, edite fora e cole o resultado aqui. Aplicar script valida e atualiza o estúdio.\n\n5. Exporte WAV para ouvir em outros aplicativos ou .noon para continuar editando.\n\nO projeto e o rascunho são salvos localmente. Exporte .noon para manter um backup.\n\nVersão inicial: síntese offline, 8 camadas e até 60 s. Piano e sino são timbres sintetizados. Sem plugins VST, samples importados, reconhecimento de músicas ou LLM conectada.',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vamos experimentar'),
        ),
      ],
    ),
  );
}

class WavePainter extends CustomPainter {
  final String wave;
  final List<double>? peaks;
  final double progress;
  WavePainter(this.wave, this.peaks, this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = NoonColors.line.withValues(alpha: .65)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    final pen = Paint()
      ..color = NoonColors.amber
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (peaks != null) {
      for (var i = 0; i < peaks!.length; i++) {
        final x = i * size.width / peaks!.length;
        final h = peaks![i] * size.height * .48;
        canvas.drawLine(
          Offset(x, size.height / 2 - h),
          Offset(x, size.height / 2 + h),
          pen,
        );
      }
    } else {
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 1) {
        final p = (x / size.width * 6) % 1;
        final v = switch (wave) {
          'triangulo' => 1 - 4 * (p - .5).abs(),
          'serra' => 2 * p - 1,
          'quadrada' => p < .5 ? 1.0 : -1.0,
          'sino' =>
            (math.sin(p * math.pi * 2) + .35 * math.sin(p * math.pi * 5.52)) *
                .7,
          'piano' =>
            (math.sin(p * math.pi * 2) + .3 * math.sin(p * math.pi * 4)) * .8,
          'ruido' => math.sin(x * 3.71) * math.cos(x * 5.13),
          _ => math.sin(p * math.pi * 2),
        };
        final y = size.height / 2 + v * size.height * .3;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, pen);
    }
    if (progress > 0 && progress <= 1) {
      canvas.drawLine(
        Offset(size.width * progress, 0),
        Offset(size.width * progress, size.height),
        Paint()
          ..color = NoonColors.text
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(WavePainter old) =>
      old.wave != wave || old.peaks != peaks || old.progress != progress;
}

class ArrangementPainter extends CustomPainter {
  final NoonProject project;
  final int index;
  final double seconds;
  ArrangementPainter(this.project, this.index, this.seconds);
  @override
  void paint(Canvas canvas, Size size) {
    final layer = project.layers[index];
    final width = size.width / project.bars;
    for (var bar = 0; bar < project.bars; bar++) {
      final color = NoonColors.tracks[index].withValues(
        alpha: layer.muted ? .12 : .22,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bar * width + 1, 1, width - 3, size.height - 2),
          const Radius.circular(5),
        ),
        Paint()..color = color,
      );
      final ink = Paint()
        ..color = NoonColors.tracks[index].withValues(
          alpha: layer.muted ? .25 : .8,
        )
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final steps = layer.mode == 'arp'
          ? 8
          : layer.mode == 'pulso'
          ? 4
          : layer.mode == 'baixo'
          ? 2
          : 1;
      if (layer.mode == 'melodia') {
        final notes = parseNotes(layer.notes);
        var time = 0.0;
        var step = 0;
        while (time < 4) {
          final note = notes[step++ % notes.length];
          final duration = math.min(note.beats, 4 - time);
          if (note.midi != null) {
            final y = 8 + (1 - (note.midi! % 12) / 12) * 24;
            canvas.drawLine(
              Offset(bar * width + width * time / 4 + 3, y),
              Offset(bar * width + width * (time + duration) / 4 - 3, y),
              ink,
            );
          }
          time += duration;
        }
      } else {
        for (var step = 0; step < steps; step++) {
          final x = bar * width + step * width / steps + 4;
          final y = layer.mode == 'arp' ? 30.0 - step % 3 * 8 : 20.0;
          canvas.drawLine(
            Offset(x, y),
            Offset(math.max(x, x + width / steps - 9), y),
            ink,
          );
          if (layer.mode == 'pad') {
            canvas.drawLine(Offset(x, 11), Offset(x + width - 9, 11), ink);
            canvas.drawLine(Offset(x, 29), Offset(x + width - 9, 29), ink);
          }
        }
      }
    }
    if (seconds > 0 && seconds < project.seconds) {
      final x = seconds / project.seconds * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = NoonColors.text
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(ArrangementPainter old) =>
      old.project != project || old.index != index || old.seconds != seconds;
}
