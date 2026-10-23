import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'model.dart';
import 'platform_services.dart';
import 'synth.dart';

RenderedAudio _preview(NoonProject p) => renderAudio(p, sampleRate: 22050);
RenderedAudio _export(NoonProject p) => renderAudio(p);

class NoonController extends ChangeNotifier {
  final ProjectStorage storage;
  final AudioOutput audio;
  late NoonProject project;
  late String draft;
  int selected = 0;
  bool ready = false, busy = false, playing = false, dirty = false;
  String status = 'Abrindo estúdio…';
  String? error;
  RenderedAudio? rendered;
  String? _renderedSource;
  final _undo = <String>[], _redo = <String>[];
  Timer? _saveTimer, _clock;
  DateTime? _started;
  double playSeconds = 0;
  int _operation = 0;
  bool _disposed = false, _canSave = true;
  Future<void> _writes = Future.value();
  late final StreamSubscription<void> _completion;
  NoonController({required this.storage, required this.audio}) {
    project = NoonProject.demo();
    draft = project.encode();
    _completion = audio.completed.listen((_) {
      _finishPlayback();
    });
  }
  bool get canEdit => ready && !busy && !dirty;
  bool get canUndo => canEdit && _undo.isNotEmpty;
  bool get canRedo => canEdit && _redo.isNotEmpty;
  Layer get layer => project.layers[selected];
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final value = await storage.load();
      if (_disposed) return;
      if (value != null) {
        final map = jsonDecode(value) as Map<String, dynamic>;
        if (map['version'] != 1) {
          throw const FormatException('Versão local desconhecida.');
        }
        project = parseNoon(map['source'] as String);
        draft = map['draft'] as String? ?? project.encode();
        if (utf8.encode(draft).length > 65536) {
          throw const FormatException('Rascunho local excede 64 KB.');
        }
        dirty = draft != project.encode();
      }
      status = 'Salvo neste dispositivo';
    } catch (e) {
      _canSave = false;
      error =
          'Não foi possível abrir o arquivo local. Ele foi preservado. Exporte seu trabalho antes de fechar. $e';
      status = 'Salvamento local suspenso';
    }
    ready = true;
    _notify();
  }

  void select(int index) {
    selected = index;
    _notify();
  }

  void editDraft(String value) {
    if (!ready || busy) return;
    if (utf8.encode(value).length > 65536) {
      error =
          'O rascunho excede 64 KB em UTF-8. O texto anterior foi preservado.';
      _notify();
      return;
    }
    draft = value;
    dirty = draft != project.encode();
    error = null;
    _scheduleSave();
    _notify();
  }

  void revertDraft() {
    draft = project.encode();
    dirty = false;
    error = null;
    _scheduleSave();
    _notify();
  }

  bool applyDraft() {
    if (!ready || busy) return false;
    try {
      final next = parseNoon(draft);
      _commit(next);
      error = null;
      return true;
    } catch (e) {
      error = e.toString();
      _notify();
      return false;
    }
  }

  void update(NoonProject next) {
    if (canEdit) _commit(next);
  }

  void updateLayer(Layer next) {
    if (!canEdit) return;
    final layers = [...project.layers];
    layers[selected] = next;
    _commit(project.copyWith(layers: layers));
  }

  void _commit(NoonProject next, {bool record = true}) {
    try {
      parseNoon(next.encode());
    } catch (e) {
      error = e.toString();
      _notify();
      return;
    }
    if (record && next.encode() != project.encode()) {
      _undo.add(project.encode());
      if (_undo.length > 40) _undo.removeAt(0);
      _redo.clear();
    }
    project = next;
    draft = next.encode();
    dirty = false;
    selected = selected.clamp(0, next.layers.length - 1);
    rendered = null;
    _renderedSource = null;
    error = null;
    unawaited(stop());
    _scheduleSave();
    _notify();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(project.encode());
    _commit(parseNoon(_undo.removeLast()), record: false);
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(project.encode());
    _commit(parseNoon(_redo.removeLast()), record: false);
  }

  void addLayer(Layer layer) {
    if (!canEdit) return;
    if (project.layers.length >= 8) {
      error = 'Você já tem 8 camadas. Remova uma para adicionar outra.';
      _notify();
      return;
    }
    _commit(project.copyWith(layers: [...project.layers, layer]));
    selected = project.layers.length - 1;
    _notify();
  }

  void removeLayer() {
    if (!canEdit || project.layers.length == 1) return;
    final layers = [...project.layers]..removeAt(selected);
    _commit(project.copyWith(layers: layers));
  }

  void loadExample(NoonProject next) {
    if (canEdit) _commit(next);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    if (!_canSave || _disposed) return;
    status = 'Salvando…';
    _saveTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(flush());
    });
  }

  Future<void> flush() {
    _saveTimer?.cancel();
    if (!_canSave) return _writes;
    final value = jsonEncode({
      'version': 1,
      'source': project.encode(),
      'draft': draft,
    });
    _writes = _writes.then((_) async {
      try {
        await storage.save(value);
        status = 'Salvo neste dispositivo';
      } catch (e) {
        status = 'Falha ao salvar';
        error = 'Não foi possível salvar: $e';
      }
      _notify();
    });
    return _writes;
  }

  Future<void> play() async {
    if (!canEdit) return;
    busy = true;
    error = null;
    final token = ++_operation;
    final snapshot = project;
    _notify();
    try {
      await audio.stop();
      final source = snapshot.encode();
      final result = _renderedSource == source && rendered != null
          ? rendered!
          : await compute(_preview, snapshot);
      if (_disposed || token != _operation) return;
      rendered = result;
      _renderedSource = source;
      await audio.play(result.wav);
      if (_disposed || token != _operation) {
        await audio.stop();
        return;
      }
      playing = true;
      playSeconds = 0;
      _started = DateTime.now();
      _clock?.cancel();
      _clock = Timer.periodic(const Duration(milliseconds: 70), (_) {
        playSeconds =
            DateTime.now().difference(_started!).inMilliseconds / 1000;
        _notify();
      });
    } catch (e) {
      if (!_disposed) error = 'Não foi possível reproduzir: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _finishPlayback() {
    _clock?.cancel();
    playing = false;
    playSeconds = 0;
    _started = null;
    _notify();
  }

  Future<void> stop() async {
    _operation++;
    _finishPlayback();
    try {
      await audio.stop();
    } catch (e) {
      error = 'Não foi possível parar o áudio: $e';
      _notify();
    }
  }

  Future<void> audition(String note) async {
    if (!canEdit) return;
    busy = true;
    error = null;
    final token = ++_operation;
    _finishPlayback();
    _notify();
    final p = NoonProject(
      name: 'Tecla',
      bpm: 180,
      volume: project.volume,
      chords: ['C'],
      sections: const [Section('Tecla', 1, .9)],
      layers: [
        layer.copyWith(mode: 'melodia', notes: '$note:1 R:3', muted: false),
      ],
    );
    try {
      await audio.stop();
      final result = await compute(_preview, p);
      if (!_disposed && token == _operation) {
        await audio.play(result.wav);
        if (_disposed || token != _operation) await audio.stop();
      }
    } catch (e) {
      error = 'Não foi possível tocar a nota: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> importProject() async {
    if (!canEdit) return;
    busy = true;
    error = null;
    _notify();
    try {
      final source = await storage.open();
      if (!_disposed && source != null) _commit(parseNoon(source));
    } catch (e) {
      error = 'Não foi possível importar: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> exportProject() async {
    if (!canEdit) return;
    busy = true;
    error = null;
    _notify();
    try {
      final saved = await storage.export(
        Uint8List.fromList(utf8.encode(project.encode())),
        'Projeto.noon',
        'text/plain',
      );
      if (saved) status = 'Projeto .noon exportado';
    } catch (e) {
      error = 'Não foi possível exportar: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> exportWav() async {
    if (!canEdit) return;
    busy = true;
    error = null;
    _notify();
    try {
      final result = await compute(_export, project);
      if (!_disposed) {
        final saved = await storage.export(
          result.wav,
          'Noon-trilha.wav',
          'audio/wav',
        );
        if (saved) status = 'WAV exportado · 44,1 kHz';
      }
    } catch (e) {
      error = 'Não foi possível exportar o WAV: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    _saveTimer?.cancel();
    _clock?.cancel();
    unawaited(flush());
    unawaited(_completion.cancel());
    unawaited(audio.dispose());
    super.dispose();
  }
}
