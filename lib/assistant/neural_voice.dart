import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Un modèle Piper (voix neuronale) à télécharger une fois.
class VoiceModel {
  const VoiceModel(this.id, this.archive, this.onnx, this.sizeMb, this.license);
  final String id;
  final String archive; // nom de l'archive / du dossier
  final String onnx;
  final int sizeMb;
  final String license;

  String get url => 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$archive.tar.bz2';
}

const upmcModel = VoiceModel('upmc', 'vits-piper-fr_FR-upmc-medium', 'fr_FR-upmc-medium.onnx', 80, 'CC BY-SA 4.0');
const siwisModel = VoiceModel('siwis', 'vits-piper-fr_FR-siwis-medium', 'fr_FR-siwis-medium.onnx', 67, 'CC BY 4.0');

/// Une voix proposée dans l'app.
class NeuralVoiceOption {
  const NeuralVoiceOption(this.id, this.label, this.male, this.model, this.speaker, this.description);
  final String id;
  final String label;
  final bool male;
  final VoiceModel model;
  final int speaker;
  final String description;
}

const neuralVoices = [
  NeuralVoiceOption('pierre', 'Pierre', true, upmcModel, 1, 'Voix masculine posée'),
  NeuralVoiceOption('siwis', 'Siwis', false, siwisModel, 0, 'Voix féminine claire'),
  NeuralVoiceOption('jessica', 'Jessica', false, upmcModel, 0, 'Voix féminine douce'),
];

NeuralVoiceOption? neuralVoiceById(String id) {
  for (final v in neuralVoices) {
    if (v.id == id) return v;
  }
  return null;
}

/// Téléchargement, synthèse (dans un isolate dédié) et lecture des voix IA.
class NeuralVoiceEngine {
  AudioPlayer? _p;
  AudioPlayer get _player => _p ??= AudioPlayer();
  SendPort? _worker;
  Future<SendPort>? _starting;
  final Map<String, double> downloads = {}; // id modèle -> progression 0..1

  Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/voices');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String> _modelDir(VoiceModel m) async => '${(await _root()).path}/${m.archive}';

  Future<bool> isInstalled(VoiceModel m) async {
    final String dir;
    try {
      dir = await _modelDir(m);
    } on Exception {
      return false;
    }
    return File('$dir/${m.onnx}').existsSync() &&
        File('$dir/tokens.txt').existsSync() &&
        Directory('$dir/espeak-ng-data').existsSync();
  }

  /// Télécharge et décompresse un modèle. [onProgress] reçoit 0..1.
  Future<void> install(VoiceModel m, void Function(double) onProgress) async {
    final root = await _root();
    final tmp = File('${root.path}/${m.archive}.tar.bz2.part');
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(m.url)));
      if (res.statusCode != 200) throw Exception('Téléchargement impossible (${res.statusCode}).');
      final total = res.contentLength ?? m.sizeMb * 1024 * 1024;
      var received = 0;
      final sink = tmp.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress((received / total).clamp(0.0, 0.97));
      }
      await sink.close();
      final archivePath = tmp.path;
      final outPath = root.path;
      // Décompression hors du fil principal : l'interface reste fluide.
      await Isolate.run(() => extractFileToDisk(archivePath, outPath));
      onProgress(1);
    } finally {
      client.close();
      if (tmp.existsSync()) tmp.deleteSync();
    }
    if (!await isInstalled(m)) throw Exception('Voix incomplète après installation.');
  }

  Future<void> uninstall(VoiceModel m) async {
    final dir = Directory(await _modelDir(m));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  Future<SendPort> _ensureWorker() {
    if (_worker != null) return Future.value(_worker!);
    return _starting ??= () async {
      final ready = ReceivePort();
      await Isolate.spawn(_ttsWorker, ready.sendPort);
      _worker = await ready.first as SendPort;
      return _worker!;
    }();
  }

  /// Fabrique le fichier WAV de la phrase (voix + effet IA).
  Future<File> synthesize(NeuralVoiceOption v, String text, {double speed = 1.0, double effect = 0.5}) async {
    final worker = await _ensureWorker();
    final reply = ReceivePort();
    worker.send({
      'dir': await _modelDir(v.model),
      'onnx': v.model.onnx,
      'sid': v.speaker,
      'text': text,
      'speed': speed,
      'effect': effect,
      'reply': reply.sendPort,
    });
    final result = await reply.first;
    if (result is String) throw Exception(result);
    final bytes = (result as TransferableTypedData).materialize().asUint8List();
    final tmp = await getTemporaryDirectory();
    final f = File('${tmp.path}/voice_${DateTime.now().microsecondsSinceEpoch}.wav');
    await f.writeAsBytes(bytes);
    return f;
  }

  /// Lit un fichier et attend la fin de la lecture.
  Future<void> play(File f, {bool deleteAfter = true}) async {
    final done = _player.onPlayerComplete.first;
    await _player.play(DeviceFileSource(f.path));
    try {
      await done.timeout(const Duration(seconds: 40));
    } on TimeoutException {
      // sécurité
    }
    if (!deleteAfter) return;
    try {
      f.deleteSync();
    } on FileSystemException {
      // ignore
    }
  }

  Future<void> stop() async {
    await _p?.stop();
  }
}

// --------------------------------------------------------------- isolate

void _ttsWorker(SendPort ready) {
  final port = ReceivePort();
  ready.send(port.sendPort);
  final cache = <String, sherpa.OfflineTts>{};
  var initialized = false;
  port.listen((dynamic msg) {
    final m = msg as Map;
    final reply = m['reply'] as SendPort;
    try {
      if (!initialized) {
        sherpa.initBindings();
        initialized = true;
      }
      final dir = m['dir'] as String;
      final tts = cache.putIfAbsent(
        dir,
        () => sherpa.OfflineTts(sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(
              model: '$dir/${m['onnx']}',
              tokens: '$dir/tokens.txt',
              dataDir: '$dir/espeak-ng-data',
            ),
            numThreads: 2,
            debug: false,
          ),
          maxNumSenetences: 2,
        )),
      );
      final audio = tts.generate(
        text: m['text'] as String,
        sid: m['sid'] as int,
        speed: (m['speed'] as double).clamp(0.6, 1.6),
      );
      if (audio.samples.isEmpty) throw Exception('Aucun son généré.');
      final samples = applyAiEffect(audio.samples, audio.sampleRate, m['effect'] as double);
      reply.send(TransferableTypedData.fromList([encodeWav(samples, audio.sampleRate)]));
    } catch (e) {
      reply.send('Synthèse vocale impossible : $e');
    }
  });
}

/// Effet « IA » : léger doublage métallique, modulation et espace.
/// [amount] de 0 (voix naturelle) à 1 (très synthétique).
Float32List applyAiEffect(Float32List x, int sr, double amount) {
  if (amount <= 0 || x.isEmpty) return x;
  final a = amount.clamp(0.0, 1.0);
  final n = x.length;
  final y = Float32List.fromList(x);
  final d = (sr * 0.011).round();
  for (var i = d; i < n; i++) {
    y[i] += 0.45 * a * x[i - d];
  }
  final w = 2 * math.pi * 55 / sr;
  for (var i = 0; i < n; i++) {
    y[i] = y[i] * (1 - 0.18 * a) + 0.18 * a * y[i] * math.sin(w * i);
  }
  final out = Float32List(n + (sr * 0.35).round());
  for (var i = 0; i < n; i++) {
    out[i] = y[i];
  }
  for (final (delay, g) in const [(0.047, 0.22), (0.071, 0.16), (0.113, 0.10)]) {
    final k = (sr * delay).round();
    for (var i = 0; i < n; i++) {
      out[i + k] += a * g * y[i];
    }
  }
  var peak = 1e-6;
  for (final v in out) {
    if (v.abs() > peak) peak = v.abs();
  }
  final gain = 0.9 / peak;
  for (var i = 0; i < out.length; i++) {
    out[i] *= gain;
  }
  return out;
}

/// WAV PCM 16 bits mono.
Uint8List encodeWav(Float32List samples, int sampleRate) {
  final data = ByteData(44 + samples.length * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}
