import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'http_message.dart';

class TydomException implements Exception {
  TydomException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Construit l'en-tête HTTP Digest (RFC 2617, qop=auth) attendu par Tydom.
String buildDigestHeader({
  required String username,
  required String password,
  required String realm,
  required String nonce,
  required String method,
  required String uri,
  String? cnonce,
  String nc = '00000001',
}) {
  String md5hex(String s) => md5.convert(utf8.encode(s)).toString();
  cnonce ??= _randomHex(16);
  final ha1 = md5hex('$username:$realm:$password');
  final ha2 = md5hex('$method:$uri');
  final response = md5hex('$ha1:$nonce:$nc:$cnonce:auth:$ha2');
  return 'Digest username="$username", realm="$realm", nonce="$nonce", '
      'uri="$uri", response="$response", qop="auth", nc=$nc, cnonce="$cnonce"';
}

String _randomHex(int bytes) {
  final r = Random.secure();
  return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

String _wsKey() {
  final r = Random.secure();
  return base64.encode(List.generate(16, (_) => r.nextInt(256)));
}

/// Connexion WebSocket à une box Tydom via le serveur de médiation Delta Dore
/// (fonctionne partout, pas besoin d'être sur le Wi-Fi de la maison).
class TydomClient {
  TydomClient({required this.mac, required this.password, this.host = 'mediation.tydom.com'});

  final String mac;
  final String password;
  final String host;

  WebSocket? _ws;
  Future<void>? _connecting;
  int _tx = DateTime.now().millisecondsSinceEpoch;
  final Map<String, Completer<TydomMessage>> _pending = {};
  final List<String> _fifo = [];
  final _pushes = StreamController<TydomMessage>.broadcast();

  /// Messages envoyés spontanément par la box (changement de position…).
  Stream<TydomMessage> get updates => _pushes.stream;

  bool get isConnected => _ws != null && _ws!.readyState == WebSocket.open;

  String get _path => '/mediation/client?mac=${mac.toUpperCase()}&appli=1';

  Future<void> connect() {
    if (isConnected) return Future.value();
    return _connecting ??= _doConnect().whenComplete(() => _connecting = null);
  }

  /// Realm qui a fonctionné pour chaque box (évite de retester à chaque fois).
  static final Map<String, String> _workingRealm = {};

  Future<void> _doConnect() async {
    // Le realm attendu diffère selon les versions du service de médiation :
    // on prend celui annoncé par le serveur, puis les valeurs connues.
    final first = await _fetchChallenge();
    final realms = <String>{
      ?_workingRealm[mac],
      ?first.realm,
      'ServiceMedia',
      'protected area',
    }.toList();
    var challenge = first;
    for (var i = 0; i < realms.length; i++) {
      if (i > 0) challenge = await _fetchChallenge();
      try {
        final ws = await WebSocket.connect(
          'wss://$host:443$_path',
          headers: {'Authorization': _authorization(challenge, realms[i])},
        ).timeout(const Duration(seconds: 15));
        _workingRealm[mac] = realms[i];
        ws.pingInterval = const Duration(seconds: 20);
        _ws = ws;
        ws.listen(
          _onData,
          onDone: _onClosed,
          onError: (_) => _onClosed(),
          cancelOnError: true,
        );
        return;
      } on WebSocketException {
        continue; // realm suivant
      } on TimeoutException {
        throw TydomException('La box ne répond pas (délai dépassé).');
      } on SocketException catch (e) {
        throw TydomException('Pas de connexion réseau (${e.message}).');
      }
    }
    // Échec : on refait la requête "à la main" pour connaître la réponse exacte.
    final c = await _fetchChallenge();
    final status = await _probe(_authorization(c, realms.first));
    throw TydomException('La box a refusé la connexion ($status, '
        'realm annoncé : ${first.realm ?? 'aucun'}). '
        'Vérifiez l\'adresse MAC de la box.');
  }

  String _authorization(_Challenge c, String realm) {
    var header = buildDigestHeader(
      username: mac.toUpperCase(),
      password: password,
      realm: realm,
      nonce: c.nonce,
      method: 'GET',
      uri: _path,
    );
    if (c.opaque != null) header += ', opaque="${c.opaque}"';
    return header;
  }

  /// Envoie une requête d'upgrade WebSocket brute et renvoie l'en-tête HTTP
  /// reçu (ligne de statut + en-têtes).
  Future<String> _rawUpgrade({String? authorization}) async {
    SecureSocket? socket;
    try {
      socket = await SecureSocket.connect(host, 443, timeout: const Duration(seconds: 15));
      socket.write('GET $_path HTTP/1.1\r\n'
          'Host: $host:443\r\n'
          'Accept: */*\r\n'
          'Connection: Upgrade\r\n'
          'Upgrade: websocket\r\n'
          'Sec-WebSocket-Key: ${_wsKey()}\r\n'
          'Sec-WebSocket-Version: 13\r\n'
          '${authorization == null ? '' : 'Authorization: $authorization\r\n'}'
          '\r\n');
      await socket.flush();
      final buffer = <int>[];
      await for (final chunk in socket.timeout(const Duration(seconds: 15))) {
        buffer.addAll(chunk);
        if (latin1.decode(buffer).contains('\r\n\r\n')) break;
      }
      final head = latin1.decode(buffer);
      final end = head.indexOf('\r\n\r\n');
      return end < 0 ? head : head.substring(0, end);
    } on SocketException catch (e) {
      throw TydomException('Impossible de joindre $host (${e.message}).');
    } on TimeoutException {
      throw TydomException('Le serveur Tydom ne répond pas.');
    } finally {
      socket?.destroy();
    }
  }

  /// Première requête sans authentification : le serveur répond 401 avec le
  /// défi Digest (nonce, realm…).
  Future<_Challenge> _fetchChallenge() async {
    final head = await _rawUpgrade();
    String? param(String name) =>
        RegExp('$name="([^"]*)"', caseSensitive: false).firstMatch(head)?.group(1);
    final nonce = param('nonce');
    if (nonce == null) {
      throw TydomException('Réponse inattendue du serveur Tydom : ${head.split('\r\n').first}');
    }
    return _Challenge(nonce: nonce, realm: param('realm'), opaque: param('opaque'));
  }

  Future<String> _probe(String authorization) async {
    try {
      return (await _rawUpgrade(authorization: authorization)).split('\r\n').first;
    } on TydomException catch (e) {
      return e.message;
    }
  }

  void _onData(dynamic data) {
    final bytes = data is String ? utf8.encode(data) : data as List<int>;
    final msg = TydomMessage.parse(bytes);
    if (msg == null) return;
    if (msg.isResponse) {
      final id = msg.transactionId;
      Completer<TydomMessage>? c;
      if (id != null && _pending.containsKey(id)) {
        c = _pending.remove(id);
        _fifo.remove(id);
      } else if (_fifo.isNotEmpty && (id == null || id.isEmpty)) {
        final first = _fifo.removeAt(0);
        c = _pending.remove(first);
      }
      if (c != null && !c.isCompleted) {
        c.complete(msg);
        return;
      }
    }
    _pushes.add(msg);
  }

  void _onClosed() {
    _ws = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(TydomException('Connexion à la box interrompue.'));
    }
    _pending.clear();
    _fifo.clear();
  }

  Future<TydomMessage> request(
    String method,
    String path, {
    Object? body,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await connect();
    final id = (++_tx).toString();
    final completer = Completer<TydomMessage>();
    _pending[id] = completer;
    _fifo.add(id);
    _ws!.add(buildRequest(
      method,
      path,
      body: body == null ? null : jsonEncode(body),
      transactionId: id,
    ));
    try {
      final res = await completer.future.timeout(timeout);
      final status = res.status ?? 200;
      if (status >= 400) {
        throw TydomException('La box a refusé la commande (HTTP $status).');
      }
      return res;
    } on TimeoutException {
      _pending.remove(id);
      _fifo.remove(id);
      throw TydomException('La box n\'a pas répondu à temps.');
    }
  }

  Future<dynamic> getJson(String path) async => (await request('GET', path)).json;

  /// Envoie une commande à un équipement, ex. name="positionCmd", value="UP".
  Future<void> putDeviceData(int deviceId, int endpointId, String name, Object value) async {
    await request(
      'PUT',
      '/devices/$deviceId/endpoints/$endpointId/data',
      body: [
        {'name': name, 'value': value},
      ],
    );
  }

  Future<void> close() async {
    final ws = _ws;
    _ws = null;
    await ws?.close();
  }
}

class _Challenge {
  _Challenge({required this.nonce, this.realm, this.opaque});
  final String nonce;
  final String? realm;
  final String? opaque;
}
