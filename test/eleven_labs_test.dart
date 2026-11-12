import 'dart:convert';
import 'dart:io';

import 'package:deltahome/assistant/eleven_labs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory cache;
  setUp(() => cache = Directory.systemTemp.createTempSync('eleven'));
  tearDown(() => cache.deleteSync(recursive: true));

  test('liste des voix', () async {
    final client = MockClient((req) async {
      expect(req.headers['xi-api-key'], 'KEY');
      return http.Response(
          jsonEncode({
            'voices': [
              {'voice_id': 'b', 'name': 'Orion', 'labels': {'gender': 'male', 'accent': 'french'}},
              {'voice_id': 'a', 'name': 'Alice', 'labels': {'gender': 'female'}},
            ],
          }),
          200);
    });
    final voices = await ElevenLabs(client: client).voices(' KEY ');
    expect(voices.map((v) => v.name), ['Alice', 'Orion']);
    expect(voices.last.gender, 'male');
    expect(voices.last.description, 'french');
  });

  test('synthèse mise en cache', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      expect(req.url.path, '/v1/text-to-speech/VOICE');
      final body = jsonDecode(req.body) as Map;
      expect(body['model_id'], ElevenLabs.flashModel);
      expect(body['language_code'], 'fr');
      return http.Response.bytes([1, 2, 3], 200, headers: {'content-type': 'audio/mpeg'});
    });
    final api = ElevenLabs(client: client);
    final f1 = await api.speech('KEY', 'VOICE', 'Bonjour', cacheDir: cache);
    final f2 = await api.speech('KEY', 'VOICE', 'Bonjour', cacheDir: cache);
    expect(f1.path, f2.path);
    expect(f1.readAsBytesSync(), [1, 2, 3]);
    expect(calls, 1);
  });

  test('clé refusée : message clair', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({'detail': {'message': 'invalid'}}), 401));
    await expectLater(
      ElevenLabs(client: client).speech('BAD', 'V', 'x', cacheDir: cache),
      throwsA(predicate((e) => e.toString().contains('Clé ElevenLabs refusée'))),
    );
  });
}
