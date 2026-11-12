import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models.dart';

/// Tout est chiffré (Keystore Android / Trousseau iOS), y compris les mots de
/// passe des comptes et des box.
class Storage {
  static const _key = 'deltahome.data.v1';

  static const _storage = FlutterSecureStorage(
    // Lisible après le premier déverrouillage : nécessaire pour que les
    // widgets fonctionnent quand l'app est fermée.
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<AppData> load() async {
    try {
      return AppData.decode(await _storage.read(key: _key));
    } on Exception {
      return AppData();
    }
  }

  static Future<void> save(AppData data) => _storage.write(key: _key, value: data.encode());
}
