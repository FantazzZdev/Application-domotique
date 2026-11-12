import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Une voix du compte ElevenLabs (voix prêtes à l'emploi, créées ou ajoutées
/// depuis la bibliothèque).
class ElevenVoice {
  ElevenVoice({required this.id, required this.name, this.gender = '', this.description = ''});
  final String id;
  final String name;
  final String gender;
  final String description;

  factory ElevenVoice.fromJson(Map<String, dynamic> j) {
    final labels = (j['labels'] as Map?)?.cast<String, dynamic>() ?? const {};
    final parts = [labels['accent'], labels['age'], labels['description'] ?? labels['descriptive'], labels['use_case']]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    return ElevenVoice(
      id: j['voice_id'] as String,
      name: (j['name'] as String?) ?? 'Voix',
      gender: (labels['gender'] as String?) ?? '',
      description: parts.join(', '),
    );
  }
}

class ElevenLabsException implements Exception {
  ElevenLabsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client minimal de l'API ElevenLabs.
class ElevenLabs {
  ElevenLabs({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;

  static const _base = 'https://api.elevenlabs.io';

  /// Modèle rapide et économique (½ crédit par caractère).
  static const flashModel = 'eleven_flash_v2_5';

  /// Meilleure qualité, un peu plus lent (1 crédit par caractère).
  static const qualityModel = 'eleven_multilingual_v2';

  Map<String, String> _headers(String key) => {'xi-api-key': key.trim(), 'Accept': 'application/json'};

  ElevenLabsException _error(http.Response r) {
    var detail = '';
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final d = j is Map ? j['detail'] : null;
      detail = d is Map ? '${d['message'] ?? d['status'] ?? ''}' : '${d ?? ''}';
    } on FormatException {
      // corps non JSON
    }
    switch (r.statusCode) {
      case 401:
        return ElevenLabsException('Clé ElevenLabs refusée. Vérifiez-la et ses permissions. $detail'.trim());
      case 402:
      case 429:
        return ElevenLabsException('Quota ElevenLabs atteint pour le moment. $detail'.trim());
      default:
        return ElevenLabsException('ElevenLabs a répondu ${r.statusCode}. $detail'.trim());
    }
  }

  Future<List<ElevenVoice>> voices(String key) async {
    final r = await _http.get(Uri.parse('$_base/v1/voices'), headers: _headers(key));
    if (r.statusCode != 200) throw _error(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final list = ((j['voices'] as List?) ?? const [])
        .whereType<Map>()
        .map((v) => ElevenVoice.fromJson(v.cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Caractères utilisés / disponibles ce mois-ci (null si non autorisé).
  Future<(int, int)?> quota(String key) async {
    try {
      final r = await _http.get(Uri.parse('$_base/v1/user/subscription'), headers: _headers(key));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return ((j['character_count'] as num).toInt(), (j['character_limit'] as num).toInt());
    } on Exception {
      return null;
    }
  }

  /// Corps de la requête de synthèse (exposé pour les tests).
  static Map<String, dynamic> requestBody(String text, {required String model, double speed = 1.0}) => {
        'text': text,
        'model_id': model,
        if (model == flashModel) 'language_code': 'fr',
        'voice_settings': {
          'stability': 0.45,
          'similarity_boost': 0.8,
          'style': 0.15,
          'use_speaker_boost': true,
          'speed': speed.clamp(0.7, 1.2),
        },
      };

  /// Fichier MP3 de la phrase, mis en cache : une phrase déjà prononcée
  /// ne consomme plus de crédits.
  Future<File> speech(
    String key,
    String voiceId,
    String text, {
    String model = flashModel,
    double speed = 1.0,
    Directory? cacheDir,
  }) async {
    final dir = cacheDir ?? Directory('${(await getApplicationCacheDirectory()).path}/eleven');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final id = sha1.convert(utf8.encode('$voiceId|$model|${speed.toStringAsFixed(2)}|$text')).toString();
    final file = File('${dir.path}/$id.mp3');
    if (file.existsSync() && file.lengthSync() > 0) return file;

    final r = await _http
        .post(
          Uri.parse('$_base/v1/text-to-speech/$voiceId?output_format=mp3_44100_128'),
          headers: {..._headers(key), 'Content-Type': 'application/json', 'Accept': 'audio/mpeg'},
          body: jsonEncode(requestBody(text, model: model, speed: speed)),
        )
        .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw _error(r);
    await file.writeAsBytes(r.bodyBytes);
    _trim(dir);
    return file;
  }

  /// Garde le cache sous ~30 Mo.
  void _trim(Directory dir) {
    try {
      final files = dir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      var total = files.fold<int>(0, (s, f) => s + f.lengthSync());
      for (final f in files) {
        if (total < 30 * 1024 * 1024) break;
        total -= f.lengthSync();
        f.deleteSync();
      }
    } on FileSystemException {
      // ignore
    }
  }
}
