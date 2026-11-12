import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app_state.dart';
import '../models.dart';
import 'intent_parser.dart';

enum AssistantPhase { idle, listening, thinking, speaking }

class AssistantLog {
  AssistantLog(this.fromUser, this.text) : time = DateTime.now();
  final bool fromUser;
  final String text;
  final DateTime time;
}

/// L'assistant vocal (Orion ou Nova) : écoute, comprend, agit et répond.
class Assistant extends ChangeNotifier {
  Assistant(this.app);

  final AppState app;
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  AssistantPhase phase = AssistantPhase.idle;
  String transcript = '';
  String reply = '';
  double level = 0; // 0..1, niveau sonore pendant l'écoute
  bool wakeActive = false;
  String? wakeError;
  final List<AssistantLog> log = [];

  bool _sttReady = false;
  bool _ttsReady = false;
  AssistantIntent? _pending;
  bool _handled = false;

  AssistantSettings get settings => app.data.assistant;
  AssistantLines get lines => AssistantLines(settings.title, settings.persona);

  void _set(AssistantPhase p) {
    phase = p;
    notifyListeners();
  }

  String? _appliedVoice;
  double _pitchFactor = 1.0;

  Future<void> _initTts() async {
    try {
      if (!_ttsReady) {
        await _tts.setLanguage('fr-FR');
        await _tts.awaitSpeakCompletion(true);
        _ttsReady = true;
      }
      await _applyVoice();
    } on Exception {
      // Synthèse vocale indisponible : les réponses restent affichées.
    }
  }

  /// Voix françaises installées sur le téléphone.
  Future<List<Map<String, String>>> frenchVoices() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((v) => v.map((k, val) => MapEntry('$k', '$val')))
          .where((v) => (v['locale'] ?? '').toLowerCase().replaceAll('_', '-').startsWith('fr'))
          .toList();
    } on Exception {
      return [];
    }
  }

  /// Choisit une voix d'homme (Orion) ou de femme (Nova), ou celle réglée.
  Future<void> _applyVoice() async {
    final wanted = '${settings.persona.name}/${settings.voiceName}';
    if (_appliedVoice == wanted) return;
    final voices = await frenchVoices();
    Map<String, String>? pick;
    if (settings.voiceName.isNotEmpty) {
      pick = voices.where((v) => v['name'] == settings.voiceName).firstOrNull;
    }
    final byGender = bestVoice(voices, male: settings.persona.male);
    // Pas de voix identifiable : on garde la voix par défaut en ajustant la hauteur.
    _pitchFactor = pick == null && byGender == null ? (settings.persona.male ? 0.82 : 1.18) : 1.0;
    pick ??= byGender;
    if (pick != null) {
      await _tts.setVoice({'name': pick['name']!, 'locale': pick['locale']!});
    }
    _appliedVoice = wanted;
  }

  /// Notre meilleure estimation d'une voix masculine / féminine.
  static Map<String, String>? bestVoice(List<Map<String, String>> voices, {required bool male}) {
    if (voices.isEmpty) return null;
    const maleHints = ['male', 'homme', 'thomas', 'nicolas', 'daniel', 'paul', 'jacques'];
    const femaleHints = ['female', 'femme', 'amelie', 'amélie', 'audrey', 'aurelie', 'aurélie', 'marie', 'julie', 'virginie'];
    int score(Map<String, String> v) {
      final n = '${v['name']} ${v['gender'] ?? ''}'.toLowerCase();
      final isFemale = femaleHints.any(n.contains);
      final isMale = !n.contains('female') && maleHints.any(n.contains);
      var s = 0;
      if (male ? isMale : isFemale) s += 10;
      if (male ? isFemale : isMale) s -= 10;
      if ((v['locale'] ?? '').toLowerCase().replaceAll('_', '-') == 'fr-fr') s += 2;
      if (n.contains('local') || n.contains('enhanced') || n.contains('premium')) s += 1;
      if (n.contains('network')) s -= 1;
      return s;
    }

    final sorted = [...voices]..sort((a, b) => score(b).compareTo(score(a)));
    return score(sorted.first) > 0 ? sorted.first : null;
  }

  Future<bool> _initStt() async {
    if (_sttReady) return true;
    try {
      _sttReady = await _stt.initialize(
        onStatus: _onSttStatus,
        onError: (e) {
          if (_wakeListening) {
            _onWakeError(e.errorMsg);
          } else if (phase == AssistantPhase.listening) {
            _endListening();
          }
        },
      );
    } on Exception {
      _sttReady = false;
    }
    return _sttReady;
  }

  // ------------------------------------------- mains libres (prénom)

  static const _audio = MethodChannel('domus/audio');
  bool _wakeLoopOn = false;
  bool _wakeListening = false;
  int _wakeErrors = 0;
  Timer? _wakeTimer;
  bool _wakeHandled = false;

  /// Variantes de transcription du prénom par la reconnaissance vocale.
  List<String> get _aliases => settings.persona == Persona.orion
      ? const ['orion', 'o rion', 'aurion', 'horion', 'orian', 'oreon']
      : const ['nova', 'novah', 'nouva', 'novak', 'no va'];

  /// Démarre l'écoute en continu du prénom (« Orion » / « Nova ») si le mode
  /// mains libres est activé. Ne fonctionne que lorsque l'app est ouverte.
  Future<void> startWakeWord() async {
    await stopWakeWord();
    wakeError = null;
    if (!settings.handsFree) {
      notifyListeners();
      return;
    }
    if (!await _initStt()) {
      wakeError = 'Micro ou reconnaissance vocale indisponible.';
      notifyListeners();
      return;
    }
    _wakeLoopOn = true;
    _wakeErrors = 0;
    wakeActive = true;
    notifyListeners();
    await _startWakeListen();
  }

  Future<void> stopWakeWord() async {
    _wakeLoopOn = false;
    wakeActive = false;
    _wakeTimer?.cancel();
    if (_wakeListening) {
      _wakeListening = false;
      try {
        await _stt.cancel();
      } on Exception {
        // ignore
      }
    }
    await _muteBeeps(false);
  }

  Future<void> _muteBeeps(bool mute) async {
    if (mute && !settings.muteBeeps) return;
    try {
      await _audio.invokeMethod<void>('muteBeeps', {'mute': mute});
    } on Exception {
      // iOS / tests : pas de bips à couper.
    } on Error {
      // MissingPluginException
    }
  }

  /// Remet les sons du téléphone (au démarrage, au cas où l'app aurait été
  /// fermée pendant l'écoute).
  Future<void> restoreAudio() => _muteBeeps(false);

  Future<void> _startWakeListen() async {
    if (!_wakeLoopOn || _wakeListening || phase != AssistantPhase.idle) return;
    _wakeListening = true;
    _wakeHandled = false;
    await _muteBeeps(true);
    try {
      await _stt.listen(
        onResult: _onWakeResult,
        listenOptions: SpeechListenOptions(
          localeId: 'fr_FR',
          partialResults: true,
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 30),
          listenFor: const Duration(seconds: 60),
          cancelOnError: true,
        ),
      );
    } on Exception {
      _wakeListening = false;
      _scheduleWake(const Duration(seconds: 2));
    }
  }

  void _scheduleWake(Duration d) {
    _wakeTimer?.cancel();
    _wakeTimer = Timer(d, _startWakeListen);
  }

  void _onWakeError(String msg) {
    _wakeListening = false;
    if (msg.contains('permission')) {
      wakeError = 'Autorisez le micro pour le mode mains libres.';
      stopWakeWord();
      notifyListeners();
      return;
    }
    // Silence, rien reconnu, service occupé : on relance avec un léger délai.
    _wakeErrors = (_wakeErrors + 1).clamp(0, 10);
    _scheduleWake(Duration(milliseconds: 300 + 300 * _wakeErrors));
  }

  /// Cherche le prénom ; renvoie ce qui a été dit après, ou null.
  String? _afterName(String words) {
    final text = normalize(words);
    for (final alias in _aliases) {
      final m = RegExp('\\b$alias\\b').firstMatch(text);
      if (m != null) return text.substring(m.end).trim();
    }
    return null;
  }

  void _onWakeResult(SpeechRecognitionResult r) {
    if (!_wakeListening || _wakeHandled) return;
    final rest = _afterName(r.recognizedWords);
    if (rest == null) return;
    _wakeErrors = 0;
    // « Orion, ferme les volets » d'une traite : on exécute directement.
    if (r.finalResult && rest.split(' ').where((w) => w.isNotEmpty).length >= 2) {
      _wakeHandled = true;
      _wakeTimer?.cancel();
      _leaveWake().then((_) {
        HapticFeedback.mediumImpact();
        transcript = rest;
        handle(rest);
      });
      return;
    }
    if (r.finalResult) {
      _wakeHandled = true;
      _wakeTimer?.cancel();
      _leaveWake().then((_) => listen());
      return;
    }
    // Prénom entendu, phrase en cours : on laisse une chance à la suite.
    _wakeTimer?.cancel();
    _wakeTimer = Timer(const Duration(milliseconds: 1800), () {
      if (_wakeHandled || !_wakeListening) return;
      _wakeHandled = true;
      _leaveWake().then((_) => listen());
    });
  }

  Future<void> _leaveWake() async {
    _wakeListening = false;
    try {
      await _stt.cancel();
    } on Exception {
      // ignore
    }
    await _muteBeeps(false);
  }

  Future<void> _pauseWake() async {
    _wakeTimer?.cancel();
    if (_wakeListening) await _leaveWake();
  }

  Future<void> _resumeWake() async {
    if (_wakeLoopOn && phase == AssistantPhase.idle) _scheduleWake(const Duration(milliseconds: 500));
  }

  // ---------------------------------------------------------------- écoute

  Future<void> listen() async {
    if (phase == AssistantPhase.listening) {
      await _stt.stop();
      return;
    }
    await _tts.stop();
    await _pauseWake();
    if (!await _initStt()) {
      await _say('Je n\'ai pas accès au micro. Autorisez-le dans les réglages du téléphone.');
      await _resumeWake();
      return;
    }
    HapticFeedback.mediumImpact();
    transcript = '';
    level = 0;
    _handled = false;
    _set(AssistantPhase.listening);
    await _stt.listen(
      onResult: _onResult,
      onSoundLevelChange: (db) {
        // Android : environ -2..10 dB ; iOS : -50..0.
        final v = db < -2 ? (db + 50) / 50 : (db + 2) / 12;
        level = v.clamp(0.0, 1.0);
        notifyListeners();
      },
      listenOptions: SpeechListenOptions(
        localeId: 'fr_FR',
        partialResults: true,
        listenMode: ListenMode.confirmation,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 12),
        cancelOnError: true,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    transcript = r.recognizedWords;
    notifyListeners();
    if (r.finalResult && !_handled) {
      _handled = true;
      handle(transcript);
    }
  }

  void _onSttStatus(String status) {
    if ((status == 'done' || status == 'notListening') && _wakeListening) {
      // Fin d'une session d'écoute du prénom : on enchaîne.
      _wakeListening = false;
      _scheduleWake(const Duration(milliseconds: 250));
      return;
    }
    if ((status == 'done' || status == 'notListening') && phase == AssistantPhase.listening) {
      // Laisse le temps au résultat final d'arriver.
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (phase == AssistantPhase.listening && !_handled) _endListening();
      });
    }
  }

  void _endListening() {
    level = 0;
    if (!_handled && transcript.trim().isNotEmpty) {
      _handled = true;
      handle(transcript);
      return;
    }
    _set(AssistantPhase.idle);
    _resumeWake();
  }

  // ----------------------------------------------------------- compréhension

  /// Traite une phrase (vocale ou tapée).
  Future<void> handle(String text) async {
    if (text.trim().isEmpty) {
      _set(AssistantPhase.idle);
      await _resumeWake();
      return;
    }
    level = 0;
    log.add(AssistantLog(true, text));
    _set(AssistantPhase.thinking);
    final intent = IntentParser(app.data).parse(text, pending: _pending);
    _pending = null;
    final l = lines;
    switch (intent.kind) {
      case IntentKind.command:
        if (intent.devices.isEmpty) {
          await _say(l.noDevice(intent));
          break;
        }
        final ack = l.ack(intent, app.data);
        // On parle et on agit en même temps.
        final speaking = _say(ack);
        final errors = await app.runOn(intent.devices, intent.action!, position: intent.position);
        await speaking;
        if (errors.length == intent.devices.length) {
          await _say(l.error(_short(errors.first)));
        } else if (errors.isNotEmpty) {
          await _say('${errors.length} équipement${errors.length > 1 ? 's n\'ont' : ' n\'a'} pas répondu.');
        }
        break;
      case IntentKind.clarify:
        _pending = intent;
        await _say(l.clarify(intent));
        // On réécoute directement la réponse.
        await listen();
        return;
      case IntentKind.greeting:
        await _say(l.greeting());
        break;
      case IntentKind.thanks:
        await _say(l.thanks());
        break;
      case IntentKind.status:
        await _say(l.status(app.data, intent.category));
        break;
      case IntentKind.identity:
        await _say(l.identity());
        break;
      case IntentKind.cancel:
        await _say(l.cancel());
        break;
      case IntentKind.unknown:
        await _say(l.unknown());
        break;
    }
    _set(AssistantPhase.idle);
    await _resumeWake();
  }

  String _short(String e) {
    final i = e.indexOf(' : ');
    return i > 0 ? e.substring(i + 3) : e;
  }

  /// Fait parler l'assistant (test de la voix dans les réglages).
  Future<void> say(String text) async {
    _appliedVoice = null;
    await _say(text);
    _set(AssistantPhase.idle);
    await _resumeWake();
  }

  Future<void> _say(String text) async {
    // Le son peut être coupé pendant l'écoute du prénom : on le rétablit.
    await _pauseWake();
    reply = text;
    log.add(AssistantLog(false, text));
    if (log.length > 30) log.removeRange(0, log.length - 30);
    _set(AssistantPhase.speaking);
    if (!settings.voice) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return;
    }
    await _initTts();
    try {
      await _tts.setSpeechRate(settings.speechRate);
      await _tts.setPitch((settings.pitch * _pitchFactor).clamp(0.5, 2.0));
      await _tts.speak(text);
    } on Exception {
      // pas de voix disponible
    }
  }

  /// Message d'accueil au lancement.
  Future<void> greet() => _say(lines.greeting()).then((_) => _set(AssistantPhase.idle));

  @override
  void dispose() {
    stopWakeWord();
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }
}
