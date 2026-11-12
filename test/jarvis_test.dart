import 'package:deltahome/jarvis/intent_parser.dart';
import 'package:deltahome/models.dart';
import 'package:flutter_test/flutter_test.dart';

Device dev(String acc, int id, String name, DeviceKind k) => Device(
      accountId: acc,
      mac: acc.toUpperCase(),
      deviceId: id,
      endpointId: id,
      name: name,
      kind: k,
      family: k == DeviceKind.shutter ? CommandFamily.position : CommandFamily.level,
      value: 100,
    );

void main() {
  final data = AppData(
    accounts: [
      Account(id: 'm', label: 'Maison', email: '', password: ''),
      Account(id: 'b', label: 'Beaux-parents', email: '', password: ''),
    ],
    devices: [
      dev('m', 1, 'Volet salon', DeviceKind.shutter),
      dev('m', 2, 'Volet chambre', DeviceKind.shutter),
      dev('b', 3, 'Volet cuisine', DeviceKind.shutter),
      dev('b', 4, 'Portail', DeviceKind.gate),
    ],
  );
  final p = IntentParser(data);
  final lines = JarvisLines('');

  test('ferme les volets de la maison', () {
    final i = p.parse('Jarvis, ferme les volets de la maison');
    expect(i.kind, IntentKind.command);
    expect(i.action, DeviceAction.close);
    expect(i.devices.map((d) => d.deviceId), unorderedEquals([1, 2]));
    expect(lines.ack(i, data), "D'accord. Je ferme les volets chez Maison.");
  });

  test('volet nommé', () {
    final i = p.parse('Descends le volet du salon');
    expect(i.devices.single.deviceId, 1);
    expect(i.action, DeviceAction.close);
  });

  test('portail chez les beaux-parents (un seul portail)', () {
    final i = p.parse('ouvre le portail');
    expect(i.kind, IntentKind.command);
    expect(i.devices.single.deviceId, 4);
    expect(i.action, DeviceAction.open);
  });

  test('ambiguïté puis précision', () {
    final q = p.parse('ferme les volets');
    expect(q.kind, IntentKind.clarify);
    expect(lines.clarify(q), 'Chez Maison ou Beaux-parents ?');
    final a = p.parse('chez les beaux-parents', pending: q);
    expect(a.kind, IntentKind.command);
    expect(a.devices.single.deviceId, 3);
    expect(a.action, DeviceAction.close);
  });

  test('position', () {
    expect(p.parse('mets les volets de la maison à moitié').position, 50);
    expect(p.parse('volets du salon à 30 %').position, 30);
    expect(p.parse('baisse le volet du salon à 20').position, 20);
  });

  test('stop, partout, small talk', () {
    expect(p.parse('stop les volets partout').devices.length, 3);
    expect(p.parse('stop les volets partout').action, DeviceAction.stop);
    expect(p.parse('bonjour jarvis').kind, IntentKind.greeting);
    expect(p.parse('merci').kind, IntentKind.thanks);
    expect(p.parse('fais-moi un rapport').kind, IntentKind.status);
    expect(p.parse('raconte une blague').kind, IntentKind.unknown);
  });
}
