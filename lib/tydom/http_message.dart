import 'dart:convert';
import 'dart:typed_data';

/// Les box Tydom parlent "HTTP dans un WebSocket" : chaque trame contient une
/// requête ou une réponse HTTP/1.1 complète. Via le serveur de médiation
/// (accès à distance), chaque message est préfixé par l'octet 0x02.
const int remotePrefix = 0x02;

class TydomMessage {
  TydomMessage({
    required this.startLine,
    required this.headers,
    required this.body,
  });

  /// "HTTP/1.1 200 OK" ou "PUT /devices/data HTTP/1.1".
  final String startLine;
  final Map<String, String> headers; // clés en minuscules
  final Uint8List body;

  bool get isResponse => startLine.startsWith('HTTP/');

  int? get status {
    if (!isResponse) return null;
    final parts = startLine.split(' ');
    return parts.length > 1 ? int.tryParse(parts[1]) : null;
  }

  /// Chemin de la ressource : celui de la requête, ou "uri-origin" pour une
  /// réponse.
  String? get uri {
    if (!isResponse) {
      final parts = startLine.split(' ');
      return parts.length > 1 ? parts[1] : null;
    }
    return headers['uri-origin'];
  }

  String? get transactionId => headers['transac-id'];

  String get text => utf8.decode(body, allowMalformed: true);

  dynamic get json {
    final t = text.trim();
    if (t.isEmpty) return null;
    try {
      return jsonDecode(t);
    } on FormatException {
      return null;
    }
  }

  static int _indexOf(List<int> data, List<int> pattern, [int start = 0]) {
    outer:
    for (var i = start; i <= data.length - pattern.length; i++) {
      for (var j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  static final List<int> _crlf = const [13, 10];
  static final List<int> _crlfcrlf = const [13, 10, 13, 10];

  /// Décode une trame reçue de la box. Renvoie null si ce n'est pas du HTTP.
  static TydomMessage? parse(List<int> raw) {
    var start = 0;
    while (start < raw.length && (raw[start] == remotePrefix || raw[start] == 10 || raw[start] == 13)) {
      start++;
    }
    final data = raw.sublist(start);
    final headerEnd = _indexOf(data, _crlfcrlf);
    final headPart = utf8.decode(
      headerEnd < 0 ? data : data.sublist(0, headerEnd),
      allowMalformed: true,
    );
    final lines = headPart.split('\r\n');
    if (lines.isEmpty || !(lines.first.startsWith('HTTP/') || lines.first.contains(' HTTP/'))) {
      return null;
    }
    final headers = <String, String>{};
    for (final line in lines.skip(1)) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      headers[line.substring(0, idx).trim().toLowerCase()] = line.substring(idx + 1).trim();
    }
    var body = headerEnd < 0 ? <int>[] : data.sublist(headerEnd + 4);
    if ((headers['transfer-encoding'] ?? '').toLowerCase().contains('chunked')) {
      body = _dechunk(body);
    } else if (headers['content-length'] != null) {
      final len = int.tryParse(headers['content-length']!);
      if (len != null && len <= body.length) body = body.sublist(0, len);
    }
    return TydomMessage(
      startLine: lines.first.trim(),
      headers: headers,
      body: Uint8List.fromList(body),
    );
  }

  static List<int> _dechunk(List<int> data) {
    final out = <int>[];
    var pos = 0;
    while (pos < data.length) {
      final lineEnd = _indexOf(data, _crlf, pos);
      if (lineEnd < 0) break;
      final sizeStr = ascii.decode(data.sublist(pos, lineEnd), allowInvalid: true).split(';').first.trim();
      final size = int.tryParse(sizeStr, radix: 16);
      if (size == null) {
        // Ligne vide ou parasite : on passe.
        pos = lineEnd + 2;
        continue;
      }
      if (size == 0) break;
      final chunkStart = lineEnd + 2;
      final chunkEnd = (chunkStart + size).clamp(0, data.length);
      out.addAll(data.sublist(chunkStart, chunkEnd));
      pos = chunkEnd + 2;
    }
    return out;
  }
}

/// Construit une requête HTTP à envoyer à la box.
Uint8List buildRequest(
  String method,
  String path, {
  String? body,
  required String transactionId,
  bool remote = true,
}) {
  final bodyBytes = body == null ? const <int>[] : utf8.encode(body);
  final head = StringBuffer()
    ..write('$method $path HTTP/1.1\r\n')
    ..write('Content-Length: ${bodyBytes.length}\r\n')
    ..write('Content-Type: application/json; charset=UTF-8\r\n')
    ..write('Transac-Id: $transactionId\r\n')
    ..write('\r\n');
  return Uint8List.fromList([
    if (remote) remotePrefix,
    ...utf8.encode(head.toString()),
    ...bodyBytes,
    if (body != null) ...utf8.encode('\r\n\r\n'),
  ]);
}
