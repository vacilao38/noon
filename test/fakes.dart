import 'dart:async';
import 'dart:typed_data';
import 'package:noon/platform_services.dart';

class MemoryStorage implements ProjectStorage {
  String? content, incoming;
  bool failSave = false;
  int saves = 0;
  Uint8List? exported;
  String? exportedName;
  @override
  Future<String?> load() async => content;
  @override
  Future<void> save(String value) async {
    if (failSave) throw StateError('Disco indisponível');
    content = value;
    saves++;
  }

  @override
  Future<String?> open() async => incoming;
  @override
  Future<bool> export(Uint8List bytes, String name, String mime) async {
    exported = bytes;
    exportedName = name;
    return true;
  }
}

class SilentAudio implements AudioOutput {
  final events = StreamController<void>.broadcast();
  int played = 0, stopped = 0;
  @override
  Stream<void> get completed => events.stream;
  @override
  Future<void> play(Uint8List bytes) async {
    played++;
  }

  @override
  Future<void> stop() async {
    stopped++;
  }

  @override
  Future<void> dispose() async {
    await events.close();
  }
}
