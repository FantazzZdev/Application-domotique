import 'dart:convert';

import 'package:deltahome/tydom/client.dart';
import 'package:deltahome/tydom/cloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final requests = <http.Request>[];
  final mock = MockClient((req) async {
    requests.add(req);
    if (req.url.path.contains('openid-configuration')) {
      return http.Response(jsonEncode({'token_endpoint': 'https://login.test/token'}), 200);
    }
    if (req.url.host == 'login.test') return http.Response(jsonEncode({'access_token': 'T'}), 200);
    final mac = req.url.queryParameters['gateway_mac'];
    if (mac == null || mac.isEmpty) return http.Response('', 400);
    if (mac != '001A25ABCDEF') return http.Response(jsonEncode({'sites': []}), 200);
    return http.Response(
        jsonEncode({
          'sites': [
            {
              'name': 'Maison',
              'gateway': {'mac': '001A25ABCDEF', 'password': 'secret'},
            },
          ],
        }),
        200);
  });

  test('récupère la box à partir de la MAC saisie (avec séparateurs)', () async {
    final gws = await DeltaDoreCloud(client: mock).fetchGateways('a@b.fr', 'p', macs: ['00:1a:25:ab:cd:ef']);
    expect(gws.single.mac, '001A25ABCDEF');
    expect(gws.single.password, 'secret');
    expect(requests.last.url.queryParameters['gateway_mac'], '001A25ABCDEF');
    expect(requests.last.headers['Authorization'], 'Bearer T');
  });

  test('MAC absente ou inconnue : message clair', () async {
    final cloud = DeltaDoreCloud(client: mock);
    expect(() => cloud.fetchGateways('a@b.fr', 'p', macs: ['']), throwsA(isA<TydomException>()));
    await expectLater(
      cloud.fetchGateways('a@b.fr', 'p', macs: ['001A25000000']),
      throwsA(predicate((e) => e.toString().contains("n'est pas rattachée"))),
    );
  });
}
