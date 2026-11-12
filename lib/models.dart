import 'dart:convert';
import 'dart:math';

String newId() {
  final r = Random.secure();
  return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
}

/// Une box Tydom rattachée à un compte Delta Dore.
class Gateway {
  Gateway({required this.mac, required this.password, this.name = ''});

  final String mac;
  final String password;
  final String name;

  Map<String, dynamic> toJson() => {'mac': mac, 'password': password, 'name': name};

  factory Gateway.fromJson(Map<String, dynamic> j) => Gateway(
        mac: j['mac'] as String,
        password: j['password'] as String,
        name: (j['name'] as String?) ?? '',
      );
}

/// Un compte Delta Dore (Tydom). On peut en avoir plusieurs à la fois.
class Account {
  Account({
    required this.id,
    required this.label,
    required this.email,
    required this.password,
    this.colorIndex = 0,
    List<Gateway>? gateways,
  }) : gateways = gateways ?? [];

  final String id;
  String label;
  String email;
  String password;
  int colorIndex;
  List<Gateway> gateways;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'email': email,
        'password': password,
        'colorIndex': colorIndex,
        'gateways': gateways.map((g) => g.toJson()).toList(),
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        label: j['label'] as String,
        email: j['email'] as String,
        password: j['password'] as String,
        colorIndex: (j['colorIndex'] as int?) ?? 0,
        gateways: ((j['gateways'] as List?) ?? [])
            .map((g) => Gateway.fromJson(Map<String, dynamic>.from(g as Map)))
            .toList(),
      );
}

enum DeviceKind { shutter, gate, garage, light, other }

/// Famille de commandes acceptée par un équipement Tydom.
enum CommandFamily { position, level }

enum DeviceAction { open, close, stop, toggle }

extension DeviceActionLabel on DeviceAction {
  String labelFor(DeviceKind kind) {
    switch (this) {
      case DeviceAction.open:
        return kind == DeviceKind.light ? 'Allumer' : 'Ouvrir';
      case DeviceAction.close:
        return kind == DeviceKind.light ? 'Éteindre' : 'Fermer';
      case DeviceAction.stop:
        return 'Stop';
      case DeviceAction.toggle:
        return 'Actionner';
    }
  }
}

/// Un équipement pilotable (volet, portail, garage, lumière…).
class Device {
  Device({
    required this.accountId,
    required this.mac,
    required this.deviceId,
    required this.endpointId,
    required this.name,
    required this.kind,
    required this.family,
    this.value,
  });

  final String accountId;
  final String mac;
  final int deviceId;
  final int endpointId;
  final String name;
  final DeviceKind kind;
  final CommandFamily family;

  /// Position (volets, 0 = fermé, 100 = ouvert) ou niveau (lumières).
  double? value;

  String get key => '$mac/$deviceId/$endpointId';

  bool get isCover => kind == DeviceKind.shutter;

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'mac': mac,
        'deviceId': deviceId,
        'endpointId': endpointId,
        'name': name,
        'kind': kind.name,
        'family': family.name,
        'value': value,
      };

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        accountId: j['accountId'] as String,
        mac: j['mac'] as String,
        deviceId: (j['deviceId'] as num).toInt(),
        endpointId: (j['endpointId'] as num).toInt(),
        name: j['name'] as String,
        kind: DeviceKind.values.byName(j['kind'] as String),
        family: CommandFamily.values.byName(j['family'] as String),
        value: (j['value'] as num?)?.toDouble(),
      );
}

/// Cible spéciale : tous les volets d'un compte.
const String allShuttersTarget = '*shutters';

/// Un raccourci "un tap" : utilisé dans l'app, les widgets et les raccourcis
/// de l'icône.
class Shortcut {
  Shortcut({
    required this.id,
    required this.label,
    required this.icon,
    required this.accountId,
    required this.target,
    required this.action,
  });

  final String id;
  String label;
  String icon; // clé d'icône partagée avec les widgets natifs
  String accountId;

  /// [Device.key] ou [allShuttersTarget].
  String target;
  DeviceAction action;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'icon': icon,
        'accountId': accountId,
        'target': target,
        'action': action.name,
      };

  factory Shortcut.fromJson(Map<String, dynamic> j) => Shortcut(
        id: j['id'] as String,
        label: j['label'] as String,
        icon: j['icon'] as String,
        accountId: j['accountId'] as String,
        target: j['target'] as String,
        action: DeviceAction.values.byName(j['action'] as String),
      );
}

/// Les deux personnalités de l'assistant.
enum Persona {
  orion('Orion', 'O.R.I.O.N', true),
  nova('Nova', 'N.O.V.A', false);

  const Persona(this.displayName, this.spaced, this.male);
  final String displayName;
  final String spaced;
  final bool male;
}

/// Réglages de l'assistant vocal.
class AssistantSettings {
  AssistantSettings({
    this.persona = Persona.orion,
    this.title = '',
    this.wakeWord = false,
    this.picovoiceKey = '',
    this.keywordPath = '',
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.voiceName = '',
    this.voice = true,
  });

  Persona persona;

  /// Comment l'assistant s'adresse à vous (« monsieur », un prénom…). Vide = rien.
  String title;

  /// Écoute du mot d'activation quand l'app est ouverte (clé Picovoice requise).
  bool wakeWord;
  String picovoiceKey;

  /// Fichier .ppn du mot « Orion » / « Nova » créé sur la console Picovoice.
  String keywordPath;
  double speechRate;
  double pitch;

  /// Voix de synthèse choisie (vide = choix automatique homme / femme).
  String voiceName;

  /// Réponses parlées (sinon affichées seulement).
  bool voice;

  Map<String, dynamic> toJson() => {
        'persona': persona.name,
        'title': title,
        'wakeWord': wakeWord,
        'picovoiceKey': picovoiceKey,
        'keywordPath': keywordPath,
        'speechRate': speechRate,
        'pitch': pitch,
        'voiceName': voiceName,
        'voice': voice,
      };

  factory AssistantSettings.fromJson(Map<String, dynamic>? j) => j == null
      ? AssistantSettings()
      : AssistantSettings(
          persona: Persona.values.asNameMap()[j['persona']] ?? Persona.orion,
          title: (j['title'] as String?) ?? '',
          wakeWord: (j['wakeWord'] as bool?) ?? false,
          picovoiceKey: (j['picovoiceKey'] as String?) ?? '',
          keywordPath: (j['keywordPath'] as String?) ?? '',
          speechRate: (j['speechRate'] as num?)?.toDouble() ?? 0.5,
          pitch: (j['pitch'] as num?)?.toDouble() ?? 1.0,
          voiceName: (j['voiceName'] as String?) ?? '',
          voice: (j['voice'] as bool?) ?? true,
        );
}

/// Tout ce qui est persisté.
class AppData {
  AppData({List<Account>? accounts, List<Device>? devices, List<Shortcut>? shortcuts, AssistantSettings? assistant})
      : accounts = accounts ?? [],
        devices = devices ?? [],
        shortcuts = shortcuts ?? [],
        assistant = assistant ?? AssistantSettings();

  final List<Account> accounts;
  final List<Device> devices;
  final List<Shortcut> shortcuts;
  final AssistantSettings assistant;

  String encode() => jsonEncode({
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'devices': devices.map((d) => d.toJson()).toList(),
        'shortcuts': shortcuts.map((s) => s.toJson()).toList(),
        'assistant': assistant.toJson(),
      });

  factory AppData.decode(String? raw) {
    if (raw == null || raw.isEmpty) return AppData();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    List<Map<String, dynamic>> list(String k) =>
        ((j[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return AppData(
      accounts: list('accounts').map(Account.fromJson).toList(),
      devices: list('devices').map(Device.fromJson).toList(),
      shortcuts: list('shortcuts').map(Shortcut.fromJson).toList(),
      assistant: AssistantSettings.fromJson(
          j['assistant'] == null ? null : Map<String, dynamic>.from(j['assistant'] as Map)),
    );
  }

  Account? account(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Device? device(String key) {
    for (final d in devices) {
      if (d.key == key) return d;
    }
    return null;
  }
}
