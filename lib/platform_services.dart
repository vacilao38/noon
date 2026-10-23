import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

abstract class ProjectStorage {
  Future<String?> load();
  Future<void> save(String value);
  Future<String?> open();
  Future<bool> export(Uint8List bytes, String name, String mime);
}

class NativeStorage implements ProjectStorage {
  static const channel = MethodChannel('dev.clustter.noon/files');
  Future<File> get _file async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/noon-workspace-v1.json');
  }

  @override
  Future<String?> load() async {
    if (Platform.isAndroid) return channel.invokeMethod<String>('load');
    final file = await _file;
    final backup = File('${file.path}.bak');
    if (await backup.exists()) {
      if (await file.exists()) await file.delete();
      await backup.rename(file.path);
    }
    if (!await file.exists()) return null;
    if (await file.length() > 200000) {
      throw const FormatException('Arquivo local excede o limite.');
    }
    return file.readAsString(encoding: utf8);
  }

  @override
  Future<void> save(String value) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('save', value);
      return;
    }
    final file = await _file;
    final temp = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    await temp.writeAsString(value, encoding: utf8, flush: true);
    if (await file.exists()) await file.rename(backup.path);
    try {
      await temp.rename(file.path);
    } catch (_) {
      if (await backup.exists()) await backup.rename(file.path);
      rethrow;
    }
    if (await backup.exists()) await backup.delete();
  }

  @override
  Future<String?> open() async {
    if (Platform.isAndroid) return channel.invokeMethod<String>('import');
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Projeto Noon', extensions: ['noon', 'txt']),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 65536) {
      throw const FormatException('O projeto excede 64 KB.');
    }
    return file.readAsString();
  }

  @override
  Future<bool> export(Uint8List bytes, String name, String mime) async {
    if (Platform.isAndroid) {
      return await channel.invokeMethod<bool>('export', {
            'bytes': bytes,
            'name': name,
            'mime': mime,
          }) ??
          false;
    }
    final destination = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        XTypeGroup(
          label: mime == 'audio/wav' ? 'Áudio WAV' : 'Projeto Noon',
          extensions: [mime == 'audio/wav' ? 'wav' : 'noon'],
        ),
      ],
    );
    if (destination == null) return false;
    await XFile.fromData(
      bytes,
      mimeType: mime,
      name: name,
    ).saveTo(destination.path);
    return true;
  }
}

abstract class AudioOutput {
  Stream<void> get completed;
  Future<void> play(Uint8List bytes);
  Future<void> stop();
  Future<void> dispose();
}

class NativeAudio implements AudioOutput {
  AudioPlayer? _player;
  final _done = StreamController<void>.broadcast();
  StreamSubscription<void>? _subscription;
  String? _path;
  @override
  Stream<void> get completed => _done.stream;
  Future<Duration?> get duration async => await _player?.getDuration();
  Future<AudioPlayer> _getPlayer() async {
    if (_player != null) return _player!;
    final player = AudioPlayer();
    _player = player;
    _subscription = player.onPlayerComplete.listen((_) => _done.add(null));
    // Release the decoded media before replacing its file. On Windows, stop
    // mode retains the URL cache and an open handle to the old WAV.
    await player.setReleaseMode(ReleaseMode.release);
    return player;
  }

  @override
  Future<void> play(Uint8List bytes) async {
    final player = await _getPlayer();
    await player.stop();
    _path ??=
        '${(await getTemporaryDirectory()).path}/noon-preview-${DateTime.now().microsecondsSinceEpoch}.wav';
    await File(_path!).writeAsBytes(bytes, flush: true);
    await player.play(DeviceFileSource(_path!, mimeType: 'audio/wav'));
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _player?.dispose();
    await _done.close();
    if (_path != null && await File(_path!).exists()) {
      await File(_path!).delete();
    }
  }
}
