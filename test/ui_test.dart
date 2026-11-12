import 'dart:io';

import 'package:deltahome/app_state.dart';
import 'package:deltahome/assistant/assistant.dart';
import 'package:deltahome/models.dart';
import 'package:deltahome/ui/hud/hud_home.dart';
import 'package:deltahome/ui/hud/hud_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Les vraies polices (sinon la police de test, très large, fausse la mise en page).
Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await l.load();
  }

  await load('Orbitron', ['assets/fonts/Orbitron_500Medium.ttf', 'assets/fonts/Orbitron_700Bold.ttf', 'assets/fonts/Orbitron_900Black.ttf']);
  await load('Rajdhani', ['assets/fonts/Rajdhani_500Medium.ttf', 'assets/fonts/Rajdhani_600SemiBold.ttf', 'assets/fonts/Rajdhani_700Bold.ttf']);
}

AppState demoState() {
  final state = AppState.withData(AppData());
  state.data.accounts.addAll([
    Account(id: 'a', label: 'Maison', email: 'a@a.fr', password: 'x'),
    Account(id: 'b', label: 'Beaux-parents', email: 'b@b.fr', password: 'x', colorIndex: 1),
  ]);
  Device d(String acc, int id, String name, DeviceKind k, double? v) => Device(
      accountId: acc,
      mac: acc.toUpperCase(),
      deviceId: id,
      endpointId: id,
      name: name,
      kind: k,
      family: k == DeviceKind.shutter ? CommandFamily.position : CommandFamily.level,
      value: v);
  state.data.devices.addAll([
    d('a', 1, 'Salon', DeviceKind.shutter, 100),
    d('a', 2, 'Chambre parentale', DeviceKind.shutter, 40),
    d('a', 3, 'Cuisine', DeviceKind.shutter, 0),
    d('a', 5, 'Terrasse', DeviceKind.light, 100),
    d('b', 4, 'Portail', DeviceKind.gate, null),
    d('b', 6, 'Garage', DeviceKind.garage, null),
  ]);
  state.data.shortcuts.addAll([
    Shortcut(id: '1', label: 'Fermer volets', icon: 'down', accountId: 'a', target: allShuttersTarget, action: DeviceAction.close),
    Shortcut(id: '2', label: 'Ouvrir portail', icon: 'gate', accountId: 'b', target: 'B/4/4', action: DeviceAction.toggle),
  ]);
  return state;
}

void main() {
  setUpAll(loadFonts);

  testWidgets('interface HUD avec deux secteurs', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    final state = demoState();
    final assistant = Assistant(state);
    await tester.pumpWidget(MaterialApp(theme: Hud.theme(), home: HudHome(state: state, assistant: assistant)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Orion'), findsOneWidget);
    expect(find.text('Maison'), findsWidgets);
    expect(find.text('40 %'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
