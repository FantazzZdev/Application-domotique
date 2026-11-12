import '../models.dart';
import 'client.dart';

/// Pilote toutes les box de tous les comptes en même temps : une connexion
/// par box, ouverte à la demande.
class TydomController {
  final Map<String, TydomClient> _clients = {};

  TydomClient clientFor(Gateway gw) {
    final existing = _clients[gw.mac];
    if (existing != null && existing.password == gw.password) return existing;
    existing?.close();
    return _clients[gw.mac] = TydomClient(mac: gw.mac, password: gw.password);
  }

  Gateway? _gateway(AppData data, String accountId, String mac) {
    final acc = data.account(accountId);
    if (acc == null) return null;
    for (final g in acc.gateways) {
      if (g.mac == mac) return g;
    }
    return null;
  }

  /// Interroge chaque box du compte pour lister ses équipements.
  Future<List<Device>> discover(Account account) async {
    final result = <Device>[];
    for (final gw in account.gateways) {
      final client = clientFor(gw);
      final config = await client.getJson('/configs/file');
      final data = await client.getJson('/devices/data');
      result.addAll(parseDevices(account.id, gw.mac, config, data));
    }
    return result;
  }

  /// Met à jour les positions / niveaux connus.
  Future<void> refreshStates(AppData appData) async {
    final byMac = <String, List<Device>>{};
    for (final d in appData.devices) {
      byMac.putIfAbsent(d.mac, () => []).add(d);
    }
    await Future.wait(byMac.entries.map((e) async {
      final gw = _gateway(appData, e.value.first.accountId, e.key);
      if (gw == null) return;
      try {
        final data = await clientFor(gw).getJson('/devices/data');
        applyStates(e.value, data);
      } on Exception {
        // Une box injoignable ne doit pas bloquer les autres.
      }
    }));
  }

  Future<void> command(AppData data, Device device, DeviceAction action) async {
    final gw = _gateway(data, device.accountId, device.mac);
    if (gw == null) throw TydomException('Compte introuvable pour ${device.name}.');
    final (name, value) = commandFor(device, action);
    await clientFor(gw).putDeviceData(device.deviceId, device.endpointId, name, value);
    if (device.family == CommandFamily.position) {
      if (action == DeviceAction.open) device.value = 100;
      if (action == DeviceAction.close) device.value = 0;
    }
  }

  /// Exécute un raccourci (un équipement, ou tous les volets d'un compte).
  Future<void> runShortcut(AppData data, Shortcut s) async {
    final targets = targetsOf(data, s);
    if (targets.isEmpty) throw TydomException('Aucun équipement pour « ${s.label} ».');
    final errors = <String>[];
    // Les commandes partent en parallèle : tous les volets bougent ensemble.
    await Future.wait(targets.map((d) async {
      try {
        await command(data, d, s.action);
      } on Exception catch (e) {
        errors.add('${d.name} : $e');
      }
    }));
    if (errors.length == targets.length) throw TydomException(errors.first);
  }

  static List<Device> targetsOf(AppData data, Shortcut s) {
    if (s.target == allShuttersTarget) {
      return data.devices.where((d) => d.accountId == s.accountId && d.isCover).toList();
    }
    final d = data.device(s.target);
    return d == null ? [] : [d];
  }

  Future<void> closeAll() async {
    for (final c in _clients.values) {
      await c.close();
    }
    _clients.clear();
  }
}

/// Traduit une action en commande Tydom.
(String, Object) commandFor(Device d, DeviceAction action) {
  if (d.family == CommandFamily.position) {
    switch (action) {
      case DeviceAction.open:
        return ('positionCmd', 'UP');
      case DeviceAction.close:
        return ('positionCmd', 'DOWN');
      case DeviceAction.stop:
        return ('positionCmd', 'STOP');
      case DeviceAction.toggle:
        return ('positionCmd', (d.value ?? 0) > 50 ? 'DOWN' : 'UP');
    }
  }
  switch (action) {
    case DeviceAction.open:
      return ('levelCmd', 'ON');
    case DeviceAction.close:
      return ('levelCmd', 'OFF');
    case DeviceAction.stop:
      return ('levelCmd', 'STOP');
    case DeviceAction.toggle:
      return ('levelCmd', 'TOGGLE');
  }
}

DeviceKind kindFromUsage(String usage) {
  final u = usage.toLowerCase();
  if (u.contains('garage')) return DeviceKind.garage;
  if (u.contains('gate') || u.contains('portail')) return DeviceKind.gate;
  if (u.contains('light') || u.contains('lumi')) return DeviceKind.light;
  if (u.contains('shutter') ||
      u.contains('awning') ||
      u.contains('window') ||
      u.contains('blind') ||
      u.contains('store')) {
    return DeviceKind.shutter;
  }
  return DeviceKind.other;
}

Map<String, Map<String, dynamic>> _indexData(dynamic devicesData) {
  final out = <String, Map<String, dynamic>>{};
  if (devicesData is! List) return out;
  for (final dev in devicesData) {
    if (dev is! Map) continue;
    for (final ep in (dev['endpoints'] as List? ?? const [])) {
      if (ep is! Map) continue;
      final values = <String, dynamic>{};
      for (final item in (ep['data'] as List? ?? const [])) {
        if (item is Map && item['name'] != null) values[item['name'] as String] = item['value'];
      }
      out['${dev['id']}/${ep['id']}'] = values;
    }
  }
  return out;
}

/// Construit la liste d'équipements pilotables à partir de /configs/file et
/// /devices/data.
List<Device> parseDevices(String accountId, String mac, dynamic config, dynamic devicesData) {
  final states = _indexData(devicesData);
  final endpoints = config is Map ? (config['endpoints'] as List? ?? const []) : const [];
  final result = <Device>[];
  for (final ep in endpoints) {
    if (ep is! Map) continue;
    final deviceId = (ep['id_device'] as num?)?.toInt();
    final endpointId = (ep['id_endpoint'] as num?)?.toInt();
    if (deviceId == null || endpointId == null) continue;
    final usage = (ep['last_usage'] ?? ep['first_usage'] ?? '').toString();
    var kind = kindFromUsage(usage);
    final values = states['$deviceId/$endpointId'] ?? const {};
    CommandFamily? family;
    if (values.containsKey('position') || values.containsKey('positionCmd')) {
      family = CommandFamily.position;
    } else if (values.containsKey('level') || values.containsKey('levelCmd')) {
      family = CommandFamily.level;
    } else if (kind == DeviceKind.gate || kind == DeviceKind.garage) {
      family = CommandFamily.level;
    } else if (kind == DeviceKind.shutter) {
      family = CommandFamily.position;
    }
    if (family == null) continue; // capteurs, thermostats… non gérés ici
    if (kind == DeviceKind.other) {
      kind = family == CommandFamily.position ? DeviceKind.shutter : DeviceKind.light;
    }
    final raw = values['position'] ?? values['level'];
    result.add(Device(
      accountId: accountId,
      mac: mac,
      deviceId: deviceId,
      endpointId: endpointId,
      name: (ep['name'] as String?)?.trim().isNotEmpty == true
          ? (ep['name'] as String).trim()
          : 'Équipement $deviceId',
      kind: kind,
      family: family,
      value: raw is num ? raw.toDouble() : null,
    ));
  }
  result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
}

void applyStates(List<Device> devices, dynamic devicesData) {
  final states = _indexData(devicesData);
  for (final d in devices) {
    final v = states['${d.deviceId}/${d.endpointId}'];
    if (v == null) continue;
    final raw = v['position'] ?? v['level'];
    if (raw is num) d.value = raw.toDouble();
  }
}
