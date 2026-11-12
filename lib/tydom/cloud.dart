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

  /// Renvoie les box du compte. Si [mac] est fourni, ne garde que celle-ci.
  Future<List<Gateway>> fetchGateways(String email, String password, {String? mac}) async {
    final token = await _login(email, password);
    final wanted = mac?.replaceAll(RegExp('[^0-9A-Fa-f]'), '').toUpperCase();
    final uri = Uri.parse(wanted == null || wanted.isEmpty
        ? '$_sitesUrl?gateway_mac='
        : '$_sitesUrl?gateway_mac=$wanted');
    final res = await _http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) {
      throw TydomException('Impossible de lister les box du compte (${res.statusCode}).');
    }
    final json = jsonDecode(res.body);
    final sites = json is Map ? (json['sites'] as List? ?? const []) : (json is List ? json : const []);
    final gateways = <Gateway>[];
    for (final site in sites) {
      if (site is! Map) continue;
      final gw = site['gateway'];
      if (gw is! Map || gw['mac'] == null || gw['password'] == null) continue;
      final gwMac = (gw['mac'] as String).toUpperCase();
      if (wanted != null && wanted.isNotEmpty && gwMac != wanted) continue;
      gateways.add(Gateway(
        mac: gwMac,
        password: gw['password'] as String,
        name: (site['name'] as String?) ?? '',
      ));
    }
    if (gateways.isEmpty) {
      throw TydomException(wanted == null || wanted.isEmpty
          ? 'Aucune box Tydom trouvée sur ce compte. Essayez d\'indiquer l\'adresse MAC de la box.'
          : 'La box $wanted n\'est pas rattachée à ce compte.');
    }
    return gateways;
  }
}
