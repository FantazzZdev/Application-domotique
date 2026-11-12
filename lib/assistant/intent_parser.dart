import '../models.dart';

/// Ce que l'assistant a compris d'une phrase.
enum IntentKind { command, greeting, thanks, status, identity, cancel, clarify, unknown }

class AssistantIntent {
  AssistantIntent(this.kind, {this.devices = const [], this.action, this.position, this.category, this.choices = const []});

  final IntentKind kind;
  final List<Device> devices;
  final DeviceAction? action;

  /// Position demandée (0-100) pour « volets à moitié », « à 30 % »…
  final int? position;
  final DeviceKind? category;

  /// Comptes possibles quand la phrase est ambiguë (« chez qui ? »).
  final List<Account> choices;
}

/// Minuscules, sans accents ni ponctuation.
String normalize(String input) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b
      .toString()
      .replaceAll(RegExp(r"[^a-z0-9%]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Set<String> _words(String s) => normalize(s).split(' ').where((w) => w.isNotEmpty).toSet();

const _stop = {
  'le', 'la', 'les', 'de', 'du', 'des', 'un', 'une', 'et', 'a', 'au', 'aux', 'en', 'sur', 'dans', 'chez',
  'mon', 'ma', 'mes', 'ton', 'ta', 'tes', 'son', 'sa', 'ses', 'nos', 'notre', 'vos', 'votre', 'leur', 'leurs',
  'l', 'd', 'il', 'te', 'plait', 'stp', 'svp', 'peux', 'tu', 'pourrais', 'orion', 'nova', 'moi', 'nous', 'est', 'ce',
  'volet', 'volets', 'store', 'stores', 'portail', 'garage', 'porte', 'lumiere', 'lumieres', 'lampe', 'lampes',
  'roulant', 'roulants', 'tout', 'tous', 'toutes', 'toute', 'piece', 'maison',
};

const _close = {
  'ferme', 'fermer', 'fermes', 'fermez', 'fermons', 'baisse', 'baisser', 'baisses', 'baissez', 'descend',
  'descends', 'descendre', 'descendez', 'eteins', 'eteindre', 'eteignez', 'coupe', 'couper', 'boucle',
};
const _open = {
  'ouvre', 'ouvrir', 'ouvres', 'ouvrez', 'ouvrons', 'monte', 'monter', 'montes', 'montez', 'leve', 'lever',
  'levez', 'remonte', 'remonter', 'allume', 'allumer', 'allumez', 'remontez',
};
const _stopWords = {'stop', 'arrete', 'arreter', 'arretez', 'stoppe', 'stopper', 'pause', 'bloque', 'immobilise'};
const _toggle = {'actionne', 'actionner', 'active', 'activer', 'declenche', 'declencher', 'bascule', 'appuie'};

const _numbers = {
  'zero': 0, 'dix': 10, 'quinze': 15, 'vingt': 20, 'trente': 30, 'quarante': 40, 'cinquante': 50,
  'soixante': 60, 'septante': 70, 'quatre vingt': 80, 'huitante': 80, 'nonante': 90, 'cent': 100,
};

class IntentParser {
  IntentParser(this.data);
  final AppData data;

  AssistantIntent parse(String utterance, {AssistantIntent? pending}) {
    var text = normalize(utterance);
    text = text.replaceFirst(RegExp(r'^(ok |hey |dis |eh )?(orion|nova)\b'), '').trim();
    final words = text.split(' ').where((w) => w.isNotEmpty).toSet();

    // Réponse à une question « chez qui ? ».
    if (pending != null && pending.kind == IntentKind.clarify) {
      final acc = _matchAccounts(text, pending.choices);
      if (acc.isNotEmpty) {
        final devices = pending.devices.where((d) => acc.any((a) => a.id == d.accountId)).toList();
        return AssistantIntent(IntentKind.command,
            devices: devices, action: pending.action, position: pending.position, category: pending.category);
      }
      if (words.contains('partout') || words.contains('deux') || words.contains('tous')) {
        return AssistantIntent(IntentKind.command,
            devices: pending.devices, action: pending.action, position: pending.position, category: pending.category);
      }
    }

    if (text.isEmpty) return AssistantIntent(IntentKind.unknown);
    if (words.intersection({'annule', 'annuler', 'laisse', 'rien', 'oublie'}).isNotEmpty) {
      return AssistantIntent(IntentKind.cancel);
    }

    final position = _position(text);
    DeviceAction? action;
    if (words.intersection(_stopWords).isNotEmpty) {
      action = DeviceAction.stop;
    } else if (words.intersection(_close).isNotEmpty) {
      action = DeviceAction.close;
    } else if (words.intersection(_open).isNotEmpty) {
      action = DeviceAction.open;
    } else if (words.intersection(_toggle).isNotEmpty) {
      action = DeviceAction.toggle;
    }

    final category = _category(text);

    if (action == null && position == null) {
      if (words.intersection({'merci', 'thanks', 'parfait', 'super', 'top', 'genial'}).isNotEmpty) {
        return AssistantIntent(IntentKind.thanks);
      }
      if (words.intersection({'bonjour', 'salut', 'hello', 'bonsoir', 'coucou', 'yo', 'hey'}).isNotEmpty) {
        return AssistantIntent(IntentKind.greeting);
      }
      if (words.intersection({'etat', 'statut', 'rapport', 'bilan', 'situation', 'diagnostic'}).isNotEmpty ||
          text.contains('ou en sont') || text.contains('est ce que') && category != null) {
        return AssistantIntent(IntentKind.status, category: category);
      }
      if (text.contains('qui es tu') || text.contains('t es qui') || text.contains('qui etes vous') ||
          text.contains('presente toi')) {
        return AssistantIntent(IntentKind.identity);
      }
      return AssistantIntent(IntentKind.unknown);
    }

    // Équipements candidats.
    final accounts = _matchAccounts(text, data.accounts);
    final scope = accounts.isEmpty ? data.devices : data.devices.where((d) => accounts.any((a) => a.id == d.accountId)).toList();
    var devices = _matchByName(text, scope);
    if (category != null) devices = devices.where((d) => _inCategory(d, category)).toList();
    if (devices.isEmpty) {
      final cat = category ?? (position != null ? DeviceKind.shutter : null);
      if (cat == null) return AssistantIntent(IntentKind.unknown);
      devices = scope.where((d) => _inCategory(d, cat)).toList();
      if (devices.isEmpty) return AssistantIntent(IntentKind.command, category: cat, action: action);
      // Plusieurs maisons concernées et aucune précisée : on demande.
      final owners = {for (final d in devices) d.accountId};
      if (accounts.isEmpty && owners.length > 1 && !_saysEverywhere(words)) {
        return AssistantIntent(
          IntentKind.clarify,
          devices: devices,
          action: action ?? DeviceAction.open,
          position: position,
          category: cat,
          choices: data.accounts.where((a) => owners.contains(a.id)).toList(),
        );
      }
    }
    return AssistantIntent(IntentKind.command,
        devices: devices, action: action ?? DeviceAction.open, position: position, category: category ?? devices.first.kind);
  }

  bool _saysEverywhere(Set<String> w) => w.contains('partout') || (w.contains('deux') && w.contains('maisons'));

  DeviceKind? _category(String t) {
    if (RegExp(r'\b(volets?|stores?|roulants?|fenetres?)\b').hasMatch(t)) return DeviceKind.shutter;
    if (RegExp(r'\bgarage\b').hasMatch(t)) return DeviceKind.garage;
    if (RegExp(r'\b(portails?|portillon|barriere)\b').hasMatch(t)) return DeviceKind.gate;
    if (RegExp(r'\b(lumieres?|lampes?|eclairages?|lustre|spots?)\b').hasMatch(t)) return DeviceKind.light;
    return null;
  }

  bool _inCategory(Device d, DeviceKind k) => d.kind == k;

  int? _position(String t) {
    if (RegExp(r'\b(moitie|mi hauteur|demi)\b').hasMatch(t)) return 50;
    if (t.contains('trois quart')) return 75;
    if (RegExp(r'\b(un quart|quart)\b').hasMatch(t)) return 25;
    final m = RegExp(r'\b(\d{1,3})\s*(%|pour ?cent|pourcent)?').firstMatch(t);
    if (m != null && (m.group(2) != null || RegExp(r'\ba\s+\d').hasMatch(t))) {
      return int.parse(m.group(1)!).clamp(0, 100);
    }
    for (final e in _numbers.entries) {
      if (RegExp('\\b${e.key}\\s*(pour ?cent|%)').hasMatch(t)) return e.value;
    }
    return null;
  }

  List<Account> _matchAccounts(String text, List<Account> candidates) {
    final w = text.split(' ').toSet();
    final result = <Account>[];
    for (final a in candidates) {
      final label = _words(a.label).where((x) => x.length > 2 && !{'les', 'des', 'chez'}.contains(x)).toSet();
      if (label.isEmpty) continue;
      final hits = label.intersection(w).length;
      if (hits == label.length || (label.length > 1 && hits >= 1 && hits >= label.length - 1)) {
        result.add(a);
      } else if (label.contains('maison') && RegExp(r'\b(chez moi|a la maison|chez nous)\b').hasMatch(text)) {
        result.add(a);
      }
    }
    return result;
  }

  List<Device> _matchByName(String text, List<Device> devices) {
    final w = text.split(' ').toSet();
    var best = 0;
    final out = <Device>[];
    for (final d in devices) {
      final name = _words(d.name).difference(_stop).where((x) => x.length > 1).toSet();
      if (name.isEmpty) continue;
      final hits = name.intersection(w).length;
      if (hits == 0) continue;
      if (hits > best) {
        best = hits;
        out
          ..clear()
          ..add(d);
      } else if (hits == best) {
        out.add(d);
      }
    }
    return out;
  }
}

/// Phrases de l'assistant.
class AssistantLines {
  AssistantLines(this.title, [this.persona = Persona.orion]);
  final String title;
  final Persona persona;

  String _t([String sep = ', ']) => title.trim().isEmpty ? '' : '$sep${title.trim()}';

  String ack(AssistantIntent i, AppData data) {
    final n = i.devices.length;
    final kind = i.category ?? (n > 0 ? i.devices.first.kind : DeviceKind.shutter);
    final where = _where(i, data);
    final what = n == 1 ? _nameOf(i.devices.first) : _plural(kind);
    if (i.position != null) {
      return 'Bien${_t()}. Je règle $what à ${i.position} %$where.';
    }
    switch (i.action!) {
      case DeviceAction.open:
        if (kind == DeviceKind.light) return 'Tout de suite${_t()}. J\'allume $what$where.';
        return 'D\'accord${_t()}. J\'ouvre $what$where.';
      case DeviceAction.close:
        if (kind == DeviceKind.light) return 'Entendu${_t()}. J\'éteins $what$where.';
        return 'D\'accord${_t()}. Je ferme $what$where.';
      case DeviceAction.stop:
        return 'J\'arrête $what$where.';
      case DeviceAction.toggle:
        return 'Activation $what$where.';
    }
  }

  String _where(AssistantIntent i, AppData data) {
    final owners = {for (final d in i.devices) d.accountId};
    if (data.accounts.length < 2 || owners.length != 1) return '';
    final a = data.account(owners.first);
    return a == null ? '' : ' chez ${a.label}';
  }

  String _nameOf(Device d) {
    final n = d.name.trim();
    final lower = n.toLowerCase();
    if (lower.startsWith('le ') || lower.startsWith('la ') || lower.startsWith('les ') || lower.startsWith('l\'')) {
      return lower;
    }
    switch (d.kind) {
      case DeviceKind.shutter:
        return lower.startsWith('volet') ? 'le $lower' : 'le volet $n';
      case DeviceKind.gate:
        return lower.startsWith('portail') ? 'le $lower' : 'le portail $n';
      case DeviceKind.garage:
        return 'la porte de garage';
      case DeviceKind.light:
        return lower.startsWith('lumi') ? 'la $lower' : 'la lumière $n';
      case DeviceKind.other:
        return n;
    }
  }

  String _plural(DeviceKind k) => switch (k) {
        DeviceKind.shutter => 'les volets',
        DeviceKind.gate => 'le portail',
        DeviceKind.garage => 'la porte de garage',
        DeviceKind.light => 'les lumières',
        DeviceKind.other => 'les équipements',
      };

  String clarify(AssistantIntent i) {
    final names = i.choices.map((a) => a.label).toList();
    final list = names.length <= 1
        ? names.join()
        : '${names.sublist(0, names.length - 1).join(', ')} ou ${names.last}';
    return 'Chez $list${_t()} ?';
  }

  String noDevice(AssistantIntent i) => 'Je ne trouve aucun équipement de ce type${_t()}.';
  String unknown() => 'Je n\'ai pas compris${_t()}. Pouvez-vous reformuler ?';
  String greeting() {
    final h = DateTime.now().hour;
    final hello = h >= 18 || h < 5 ? 'Bonsoir' : 'Bonjour';
    return '$hello${_t(' ')}. Tous les systèmes sont opérationnels.';
  }

  String thanks() => 'À votre service${_t()}.';
  String cancel() => 'Très bien, j\'annule.';
  String identity() =>
      'Je suis ${persona.displayName}, votre ${persona.male ? 'assistant' : 'assistante'} domotique. '
      'Je pilote vos volets, portails et lumières, dans toutes vos maisons.';
  String error(String detail) => 'Désolé${persona.male ? '' : 'e'}${_t()}, il y a un problème. $detail';
  String done() => 'C\'est fait.';

  String status(AppData data, DeviceKind? only) {
    final parts = <String>[];
    for (final a in data.accounts) {
      final covers = data.devices.where((d) => d.accountId == a.id && d.isCover && d.value != null).toList();
      if (covers.isEmpty || (only != null && only != DeviceKind.shutter)) continue;
      final open = covers.where((d) => d.value! > 0).length;
      final where = data.accounts.length > 1 ? 'Chez ${a.label}, ' : '';
      if (open == 0) {
        parts.add('${where}tous les volets sont fermés.');
      } else if (open == covers.length) {
        parts.add('${where}tous les volets sont ouverts.');
      } else {
        parts.add('$where$open volet${open > 1 ? 's' : ''} sur ${covers.length} ouvert${open > 1 ? 's' : ''}.');
      }
    }
    if (parts.isEmpty) return 'Tous les systèmes sont opérationnels${_t()}.';
    return parts.join(' ');
  }
}
