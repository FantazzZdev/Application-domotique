import 'package:deltahome/app_state.dart';
import 'package:deltahome/models.dart';
import 'package:deltahome/ui/common.dart';
import 'package:deltahome/ui/home_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('accueil avec deux comptes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    final state = AppState.withData(AppData());
    state.data.accounts.addAll([
      Account(id: 'a', label: 'Maison', email: 'a@a.fr', password: 'x'),
      Account(id: 'b', label: 'Beaux-parents', email: 'b@b.fr', password: 'x', colorIndex: 1),
    ]);
    state.data.devices.addAll([
      Device(accountId: 'a', mac: 'A', deviceId: 1, endpointId: 1, name: 'Volet salon',
          kind: DeviceKind.shutter, family: CommandFamily.position, value: 100),
      Device(accountId: 'a', mac: 'A', deviceId: 2, endpointId: 2, name: 'Volet chambre parentale très long',
          kind: DeviceKind.shutter, family: CommandFamily.position, value: 40),
      Device(accountId: 'b', mac: 'B', deviceId: 3, endpointId: 3, name: 'Portail',
          kind: DeviceKind.gate, family: CommandFamily.level),
    ]);
    state.data.shortcuts.addAll([
      Shortcut(id: '1', label: 'Fermer volets', icon: 'down', accountId: 'a', target: allShuttersTarget, action: DeviceAction.close),
      Shortcut(id: '2', label: 'Ouvrir portail', icon: 'gate', accountId: 'b', target: 'B/3/3', action: DeviceAction.toggle),
    ]);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: HomePage(state: state)));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir portail'), findsOneWidget);
    expect(find.text('Beaux-parents'), findsWidgets);
    expect(find.text('Ouvert à 40 %'), findsOneWidget);
  });
}
