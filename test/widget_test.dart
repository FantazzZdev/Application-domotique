import 'dart:convert';

import 'package:deltahome/models.dart';
import 'package:deltahome/tydom/client.dart';
import 'package:deltahome/tydom/controller.dart';
import 'package:deltahome/tydom/http_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('digest RFC 2617 (exemple officiel)', () {
    final h = buildDigestHeader(
      username: 'Mufasa',
      password: 'Circle Of Life',
      realm: 'testrealm@host.com',
      nonce: 'dcd98b7102dd2f0e8b11d0f600bfb0c093',
      method: 'GET',
      uri: '/dir/index.html',
      cnonce: '0a4f113b',
    );
    expect(h, contains('response="6629fae49393a05397450978507c4ef1"'));
  });

  test('requête préfixée et réponse chunked', () {
    final req = buildRequest('PUT', '/devices/1/endpoints/1/data', body: '[]', transactionId: '42');
    expect(req.first, remotePrefix);
    expect(utf8.decode(req.sublist(1)), startsWith('PUT /devices/1/endpoints/1/data HTTP/1.1\r\n'));

    const body = '[{"id":1,"name":"Séjour"}]';
    final bytes = utf8.encode(body);
    final raw = [
      remotePrefix,
      ...utf8.encode('HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTransac-Id: 42\r\n'
          'Uri-Origin: /configs/file\r\n\r\n'),
      ...utf8.encode('${bytes.length.toRadixString(16)}\r\n'),
      ...bytes,
      ...utf8.encode('\r\n0\r\n\r\n'),
    ];
    final msg = TydomMessage.parse(raw)!;
    expect(msg.status, 200);
    expect(msg.transactionId, '42');
    expect(msg.uri, '/configs/file');
    expect((msg.json as List).first['name'], 'Séjour');
  });

  test('détection des équipements et commandes', () {
    final config = {
      'endpoints': [
        {'id_device': 10, 'id_endpoint': 10, 'name': 'Salon', 'first_usage': 'shutter'},
        {'id_device': 20, 'id_endpoint': 20, 'name': 'Portail', 'first_usage': 'gate'},
        {'id_device': 30, 'id_endpoint': 30, 'name': 'Sonde', 'first_usage': 'sensor'},
      ],
    };
    final data = [
      {
        'id': 10,
        'endpoints': [
          {
            'id': 10,
            'data': [
              {'name': 'position', 'value': 100},
            ],
          },
        ],
      },
    ];
    final devices = parseDevices('a', 'MAC', config, data);
    expect(devices.map((d) => d.name), ['Portail', 'Salon']);
    final salon = devices.firstWhere((d) => d.name == 'Salon');
    final portail = devices.firstWhere((d) => d.name == 'Portail');
    expect(salon.kind, DeviceKind.shutter);
    expect(salon.value, 100);
    expect(commandFor(salon, DeviceAction.close), ('positionCmd', 'DOWN'));
    expect(portail.kind, DeviceKind.gate);
    expect(commandFor(portail, DeviceAction.toggle), ('levelCmd', 'TOGGLE'));
  });

  test('sérialisation des données', () {
    final d = AppData(accounts: [
      Account(id: 'a', label: 'Maison', email: 'x@y.fr', password: 'p', gateways: [Gateway(mac: 'M', password: 'g')]),
    ], shortcuts: [
      Shortcut(id: 's', label: 'Fermer', icon: 'down', accountId: 'a', target: allShuttersTarget, action: DeviceAction.close),
    ]);
    final back = AppData.decode(d.encode());
    expect(back.accounts.single.gateways.single.mac, 'M');
    expect(back.shortcuts.single.action, DeviceAction.close);
  });
}
