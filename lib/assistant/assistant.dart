import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
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
  PorcupineManager? _wake;

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
  AssistantLines get lines => AssistantLines(settings.title);

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
          if (phase == AssistantPhase.listening) _endListening();
        },
      );
    } on Exception {
      _sttReady = false;
    }
    return _sttReady;
  }

  // ------------------------------------------------- mot d'activation

  /// Démarre l'écoute du mot d'activation (« Orion » / « Nova ») si elle est
  /// configurée : clé Picovoice + fichier du mot créé sur leur console.
  Future<void> startWakeWord() async {
    await stopWakeWord();
    wakeError = null;
    if (!settings.wakeWord || settings.picovoiceKey.trim().isEmpty || settings.keywordPath.isEmpty) {
      notifyListeners();
      return;
    }
    try {
      _wake = await PorcupineManager.fromKeywordPaths(
        settings.picovoiceKey.trim(),
        [settings.keywordPath],
        (_) => listen(fromWakeWord: true),
        sensitivities: [0.6],
        errorCallback: (PorcupineException e) {
          wakeError = e.message;
          notifyListeners();
        },
      );
      await _wake!.start();
      wakeActive = true;
    } on PorcupineException catch (e) {
      wakeError = e.message ?? 'Clé ou fichier Picovoice refusé.';
      wakeActive = false;
    }
    notifyListeners();
  }

  Future<void> stopWakeWord() async {
    final w = _wake;
    _wake = null;
    wakeActive = false;
    if (w != null) {
      try {
        await w.stop();
        await w.delete();
      } on Exception {
        // déjà libéré
      }
    }
  }

  Future<void> _pauseWake() async {
    try {
      await _wake?.stop();
    } on Exception {
      // ignore
    }
  }

  Future<void> _resumeWake() async {
    if (_wake == null) return;
    try {
      await _wake!.start();
    } on Exception {
      // ignore
    }
  }

  // ---------------------------------------------------------------- écoute

  Future<void> listen({bool fromWakeWord = false}) async {
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
  }

  Future<void> _say(String text) async {
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
