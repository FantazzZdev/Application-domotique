import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

import 'models.dart';
import 'services/storage.dart';
import 'services/widget_bridge.dart';
import 'tydom/cloud.dart';
import 'tydom/controller.dart';

class AppState extends ChangeNotifier {
  AppState._(this.data);

  static Future<AppState> load() async => AppState._(await Storage.load());

  @visibleForTesting
  factory AppState.withData(AppData data) => AppState._(data);

  final AppData data;
  final TydomController controller = TydomController();
  final DeltaDoreCloud cloud = DeltaDoreCloud();
  final QuickActions _quickActions = const QuickActions();

  /// Clés des équipements / raccourcis en cours d'exécution.
  final Set<String> busy = {};
  bool refreshing = false;

  /// Demande d'ouverture de l'assistant vocal (raccourci de l'icône, widget).
  VoidCallback? onAssistantRequested;

  /// Affiche un message à l'utilisateur (branché par l'UI).
  void Function(String message, {bool error})? onMessage;

  List<Account> get accounts => data.accounts;
  List<Shortcut> get shortcuts => data.shortcuts;

  List<Device> devicesOf(String accountId) =>
      data.devices.where((d) => d.accountId == accountId).toList();

  Future<void> _persist() async {
    await Storage.save(data);
    try {
      await WidgetBridge.publish(data);
    } on Exception {
      // Widgets indisponibles : sans conséquence pour l'app.
    }
    await _publishQuickActions();
    notifyListeners();
  }

  // ---------------------------------------------------------------- comptes

  /// Connecte un compte Delta Dore, récupère ses box et ses équipements.
  Future<Account> addOrUpdateAccount({
    Account? existing,
    required String label,
    required String email,
    required String password,
    String? mac,
    required int colorIndex,
  }) async {
    final gateways = await cloud.fetchGateways(email, password, macs: (mac ?? '').split(RegExp('[,;/]')));
    final account = existing ??
        Account(id: newId(), label: label, email: email, password: password);
    account
      ..label = label
      ..email = email
      ..password = password
      ..colorIndex = colorIndex
      ..gateways = gateways;
    final devices = await controller.discover(account);
    if (existing == null) data.accounts.add(account);
    data.devices
      ..removeWhere((d) => d.accountId == account.id)
      ..addAll(devices);
    if (existing == null) _suggestShortcuts(account, devices);
    await _persist();
    return account;
  }

  Future<void> rediscover(Account account) async {
    final devices = await controller.discover(account);
    data.devices
      ..removeWhere((d) => d.accountId == account.id)
      ..addAll(devices);
    await _persist();
  }

  Future<void> removeAccount(Account account) async {
    data.accounts.remove(account);
    data.devices.removeWhere((d) => d.accountId == account.id);
    data.shortcuts.removeWhere((s) => s.accountId == account.id);
    await _persist();
  }

  /// Crée des raccourcis évidents à l'ajout d'un compte.
  void _suggestShortcuts(Account account, List<Device> devices) {
    final covers = devices.where((d) => d.isCover).toList();
    if (covers.length > 1) {
      data.shortcuts.addAll([
        Shortcut(
          id: newId(),
          label: 'Ouvrir volets',
          icon: 'up',
          accountId: account.id,
          target: allShuttersTarget,
          action: DeviceAction.open,
        ),
        Shortcut(
          id: newId(),
          label: 'Fermer volets',
          icon: 'down',
          accountId: account.id,
          target: allShuttersTarget,
          action: DeviceAction.close,
        ),
      ]);
    }
    for (final d in devices.where((d) => d.kind == DeviceKind.gate || d.kind == DeviceKind.garage)) {
      data.shortcuts.add(Shortcut(
        id: newId(),
        label: d.name,
        icon: d.kind == DeviceKind.gate ? 'gate' : 'garage',
        accountId: account.id,
        target: d.key,
        action: DeviceAction.toggle,
      ));
    }
  }

  // ------------------------------------------------------------- raccourcis

  Future<void> saveShortcut(Shortcut s) async {
    final i = data.shortcuts.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      data.shortcuts[i] = s;
    } else {
      data.shortcuts.add(s);
    }
    await _persist();
  }

  Future<void> deleteShortcut(Shortcut s) async {
    data.shortcuts.removeWhere((x) => x.id == s.id);
    await _persist();
  }

  Future<void> reorderShortcuts(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final s = data.shortcuts.removeAt(oldIndex);
    data.shortcuts.insert(newIndex, s);
    await _persist();
  }

  // -------------------------------------------------------------- commandes

  Future<void> runShortcut(Shortcut s) async {
    if (busy.contains(s.id)) return;
    busy.add(s.id);
    notifyListeners();
    try {
      await controller.runShortcut(data, s);
      onMessage?.call('${s.label} ✓');
    } on Exception catch (e) {
      onMessage?.call(e.toString(), error: true);
    } finally {
      busy.remove(s.id);
      notifyListeners();
    }
  }

  Future<void> command(Device d, DeviceAction action) async {
    busy.add(d.key);
    notifyListeners();
    try {
      await controller.command(data, d, action);
    } on Exception catch (e) {
      onMessage?.call(e.toString(), error: true);
    } finally {
      busy.remove(d.key);
      notifyListeners();
    }
  }

  Future<void> setPosition(Device d, int position) async {
    busy.add(d.key);
    notifyListeners();
    try {
      await controller.setPosition(data, d, position);
    } on Exception catch (e) {
      onMessage?.call(e.toString(), error: true);
    } finally {
      busy.remove(d.key);
      notifyListeners();
    }
  }

  /// Exécute une commande sur plusieurs équipements en parallèle (assistant vocal).
  /// Renvoie les erreurs éventuelles.
  Future<List<String>> runOn(List<Device> devices, DeviceAction action, {int? position}) async {
    final errors = <String>[];
    busy.addAll(devices.map((d) => d.key));
    notifyListeners();
    await Future.wait(devices.map((d) async {
      try {
        if (position != null) {
          await controller.setPosition(data, d, position);
        } else {
          await controller.command(data, d, action);
        }
      } on Exception catch (e) {
        errors.add('${d.name} : $e');
      }
    }));
    busy.removeAll(devices.map((d) => d.key));
    notifyListeners();
    return errors;
  }

  Future<void> setTheme(String id) async {
    data.theme = id;
    await Storage.save(data);
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await Storage.save(data);
    await _publishQuickActions();
    notifyListeners();
  }

  Future<void> refreshStates() async {
    if (data.devices.isEmpty || refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      await controller.refreshStates(data);
      await Storage.save(data);
    } on Exception {
      // Rafraîchissement silencieux : on garde le dernier état connu.
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() => controller.closeAll();

  // ---------------------------------------- raccourcis de l'icône de l'app

  void initQuickActions() {
    _quickActions.initialize((type) {
      if (type == 'assistant') {
        onAssistantRequested?.call();
        return;
      }
      for (final s in data.shortcuts) {
        if (s.id == type) runShortcut(s);
      }
    });
    _publishQuickActions();
  }

  Future<void> _publishQuickActions() async {
    try {
      await _quickActions.setShortcutItems([
        ShortcutItem(type: 'assistant', localizedTitle: 'Parler à ${data.assistant.persona.displayName}'),
        ...data.shortcuts.take(3).map((s) => ShortcutItem(type: s.id, localizedTitle: s.label)),
      ]);
    } on Exception {
      // Non disponible (tests, plateforme non supportée).
    }
  }
}
