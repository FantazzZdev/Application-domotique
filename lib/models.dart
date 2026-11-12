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
    this.handsFree = true,
    this.muteBeeps = true,
    this.speechRate = 0.5,
    this.pitch = 1.0,
    this.voiceNameOrion = '',
    this.voiceNameNova = '',
    this.voice = true,
    this.neuralVoiceOrion = '',
    this.neuralVoiceNova = '',
    this.aiEffect = 0.45,
    this.elevenKey = '',
    this.elevenVoiceOrion = '',
    this.elevenVoiceNova = '',
    this.elevenNameOrion = '',
    this.elevenNameNova = '',
    this.elevenQuality = false,
  });

  Persona persona;

  /// Comment l'assistant s'adresse à vous (« monsieur », un prénom…). Vide = rien.
  String title;

  /// Mains libres : écoute du prénom de l'assistant quand l'app est ouverte.
  bool handsFree;

  /// Coupe les bips de la reconnaissance vocale en mains libres (Android).
  bool muteBeeps;
  double speechRate;
  double pitch;

  /// Voix du téléphone choisie, par assistant (vide = automatique).
  String voiceNameOrion;
  String voiceNameNova;
  String get voiceName => persona.male ? voiceNameOrion : voiceNameNova;
  set voiceName(String v) => persona.male ? voiceNameOrion = v : voiceNameNova = v;

  /// Réponses parlées (sinon affichées seulement).
  bool voice;

  /// Moteur de voix, par assistant : « pierre », « siwis »… (voix IA
  /// intégrée), « eleven » (ElevenLabs) ou vide (voix du téléphone).
  String neuralVoiceOrion;
  String neuralVoiceNova;
  String get neuralVoice => persona.male ? neuralVoiceOrion : neuralVoiceNova;
  set neuralVoice(String v) => persona.male ? neuralVoiceOrion = v : neuralVoiceNova = v;

  /// Intensité de l'effet « IA » sur la voix intégrée (0 à 1).
  double aiEffect;

  /// ElevenLabs (neuralVoice == 'eleven') : clé API et voix choisies.
  String elevenKey;
  String elevenVoiceOrion;
  String elevenVoiceNova;
  String elevenNameOrion;
  String elevenNameNova;

  /// Modèle « qualité maximale » (plus lent, 2× plus de crédits).
  bool elevenQuality;

  String get elevenVoice => persona.male ? elevenVoiceOrion : elevenVoiceNova;
  String get elevenName => persona.male ? elevenNameOrion : elevenNameNova;
  void setElevenVoice(String id, String name) {
    if (persona.male) {
      elevenVoiceOrion = id;
      elevenNameOrion = name;
    } else {
      elevenVoiceNova = id;
      elevenNameNova = name;
    }
  }

  Map<String, dynamic> toJson() => {
        'persona': persona.name,
        'title': title,
        'handsFree': handsFree,
        'muteBeeps': muteBeeps,
        'speechRate': speechRate,
        'pitch': pitch,
        'voiceNameOrion': voiceNameOrion,
        'voiceNameNova': voiceNameNova,
        'voice': voice,
        'neuralVoiceOrion': neuralVoiceOrion,
        'neuralVoiceNova': neuralVoiceNova,
        'aiEffect': aiEffect,
        'elevenKey': elevenKey,
        'elevenVoiceOrion': elevenVoiceOrion,
        'elevenVoiceNova': elevenVoiceNova,
        'elevenNameOrion': elevenNameOrion,
        'elevenNameNova': elevenNameNova,
        'elevenQuality': elevenQuality,
      };

  factory AssistantSettings.fromJson(Map<String, dynamic>? j) => j == null
      ? AssistantSettings()
      : AssistantSettings(
          persona: Persona.values.asNameMap()[j['persona']] ?? Persona.orion,
          title: (j['title'] as String?) ?? '',
          handsFree: (j['handsFree'] as bool?) ?? true,
          muteBeeps: (j['muteBeeps'] as bool?) ?? true,
          speechRate: (j['speechRate'] as num?)?.toDouble() ?? 0.5,
          pitch: (j['pitch'] as num?)?.toDouble() ?? 1.0,
          voiceNameOrion: (j['voiceNameOrion'] as String?) ?? '',
          voiceNameNova: (j['voiceNameNova'] as String?) ?? '',
          voice: (j['voice'] as bool?) ?? true,
          // Anciennes versions : un seul réglage commun aux deux assistants.
          neuralVoiceOrion: (j['neuralVoiceOrion'] as String?) ?? (j['neuralVoice'] as String?) ?? '',
          neuralVoiceNova: (j['neuralVoiceNova'] as String?) ?? (j['neuralVoice'] as String?) ?? '',
          aiEffect: (j['aiEffect'] as num?)?.toDouble() ?? 0.45,
          elevenKey: (j['elevenKey'] as String?) ?? '',
          elevenVoiceOrion: (j['elevenVoiceOrion'] as String?) ?? '',
          elevenVoiceNova: (j['elevenVoiceNova'] as String?) ?? '',
          elevenNameOrion: (j['elevenNameOrion'] as String?) ?? '',
          elevenNameNova: (j['elevenNameNova'] as String?) ?? '',
          elevenQuality: (j['elevenQuality'] as bool?) ?? false,
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
