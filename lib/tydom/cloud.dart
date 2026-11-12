import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'client.dart';

/// Accès au cloud Delta Dore : connexion avec l'e-mail / mot de passe de
/// l'application Tydom, puis récupération des box (adresse MAC + mot de passe
/// de la box) rattachées au compte.
class DeltaDoreCloud {
  DeltaDoreCloud({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  static const _openIdConfig =
      'https://deltadoreadb2ciot.b2clogin.com/deltadoreadb2ciot.onmicrosoft.com/v2.0/'
      '.well-known/openid-configuration?p=B2C_1_AccountProviderROPC_SignIn';
  static const _clientId = '8782839f-3264-472a-ab87-4d4e23524da4';
  static const _scope = 'openid profile offline_access '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/video_config '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/video_allowed '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/sites_management_allowed '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/sites_management_gateway_credentials '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/sites_management_camera_credentials '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/comptage_europe_collect_reader '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/comptage_europe_site_config_contributor '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/pilotage_allowed '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/consent_mgt_contributor '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/b2caccountprovider_manage_account '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/b2caccountprovider_allow_view_account '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/tydom_backend_allowed '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/websocket_remote_access '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/orkestro_device '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/orkestro_view '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/orkestro_space '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/orkestro_actor '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/orkestro_actor_owner '
      'https://deltadoreadb2ciot.onmicrosoft.com/iotapi/orkestro_profile';
  static const _sitesUrl = 'https://prod.iotdeltadore.com/sitesmanagement/api/v1/sites';

  Future<String> _login(String email, String password) async {
    final conf = await _http.get(Uri.parse(_openIdConfig));
    if (conf.statusCode != 200) {
      throw TydomException('Service Delta Dore indisponible (${conf.statusCode}).');
    }
    final tokenEndpoint = (jsonDecode(conf.body) as Map)['token_endpoint'] as String;
    final res = await _http.post(
      Uri.parse(tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': email,
        'password': password,
        'grant_type': 'password',
        'client_id': _clientId,
        'scope': _scope,
      },
    );
    final body = jsonDecode(res.body) as Map;
    final token = body['access_token'] as String?;
    if (res.statusCode != 200 || token == null) {
      throw TydomException('Identifiants Delta Dore incorrects.');
    }
    return token;
  }

  /// Normalise une adresse MAC saisie ("00:1a:25…" → "001A25…").
  static String normalizeMac(String mac) => mac.replaceAll(RegExp('[^0-9A-Fa-f]'), '').toUpperCase();

  /// Récupère le mot de passe de chaque box demandée. Le service Delta Dore
  /// exige l'adresse MAC de la box : il ne sait pas lister toutes les box.
  Future<List<Gateway>> fetchGateways(String email, String password, {required List<String> macs}) async {
    final wanted = macs.map(normalizeMac).where((m) => m.isNotEmpty).toSet();
    if (wanted.isEmpty) throw TydomException('Indiquez l\'adresse MAC de la box Tydom.');
    final token = await _login(email, password);
    final gateways = <Gateway>[];
    for (final mac in wanted) {
      final res = await _http.get(
        Uri.parse(_sitesUrl).replace(queryParameters: {'gateway_mac': mac}),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode >= 400 && res.statusCode < 500) {
        throw TydomException('La box $mac est introuvable sur ce compte '
            '(${res.statusCode}). Vérifiez l\'adresse MAC.');
      }
      if (res.statusCode != 200) {
        throw TydomException('Service Delta Dore indisponible (${res.statusCode}).');
      }
      final json = jsonDecode(res.body);
      final sites = json is Map ? (json['sites'] as List? ?? const []) : (json is List ? json : const []);
      Gateway? found;
      for (final site in sites) {
        if (site is! Map) continue;
        final gw = site['gateway'];
        if (gw is! Map || gw['mac'] == null || gw['password'] == null) continue;
        if ((gw['mac'] as String).toUpperCase() != mac) continue;
        found = Gateway(mac: mac, password: gw['password'] as String, name: (site['name'] as String?) ?? '');
      }
      if (found == null) {
        throw TydomException('La box $mac n\'est pas rattachée à ce compte. Vérifiez l\'adresse MAC.');
      }
      gateways.add(found);
    }
    return gateways;
  }
}
