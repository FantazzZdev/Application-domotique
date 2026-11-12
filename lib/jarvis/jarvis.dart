import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../app_state.dart';
import '../models.dart';
import 'intent_parser.dart';

enum JarvisPhase { idle, listening, thinking, speaking }

class JarvisLog {
  JarvisLog(this.fromUser, this.text) : time = DateTime.now();
  final bool fromUser;
  final String text;
  final DateTime time;
}

/// L'assistant vocal : écoute, comprend, agit et répond.
class Jarvis extends ChangeNotifier {
  Jarvis(this.app);

  final AppState app;
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  PorcupineManager? _wake;

  JarvisPhase phase = JarvisPhase.idle;
  String transcript = '';
  String reply = '';
  double level = 0; // 0..1, niveau sonore pendant l'écoute
  bool wakeActive = false;
  String? wakeError;
  final List<JarvisLog> log = [];

  bool _sttReady = false;
  bool _ttsReady = false;
  JarvisIntent? _pending;
  bool _handled = false;

  JarvisSettings get settings => app.data.jarvis;
  JarvisLines get lines => JarvisLines(settings.title);

  void _set(JarvisPhase p) {
    phase = p;
    notifyListeners();
  }

  Future<void> _initTts() async {
    if (_ttsReady) return;
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.awaitSpeakCompletion(true);
      _ttsReady = true;
    } on Exception {
      // Synthèse vocale indisponible : les réponses restent affichées.
    }
  }

  Future<bool> _initStt() async {
    if (_sttReady) return true;
    try {
      _sttReady = await _stt.initialize(
        onStatus: _onSttStatus,
        onError: (e) {
          if (phase == JarvisPhase.listening) _endListening();
        },
      );
    } on Exception {
      _sttReady = false;
    }
    return _sttReady;
  }

  // ---------------------------------------------------------- mot « Jarvis »

  /// Démarre l'écoute du mot « Jarvis » si elle est activée dans les réglages.
  Future<void> startWakeWord() async {
    await stopWakeWord();
    wakeError = null;
    if (!settings.wakeWord || settings.picovoiceKey.trim().isEmpty) {
      notifyListeners();
      return;
    }
    try {
      _wake = await PorcupineManager.fromBuiltInKeywords(
        settings.picovoiceKey.trim(),
        [BuiltInKeyword.JARVIS],
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
      wakeError = e.message ?? 'Clé Picovoice refusée.';
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
    if (phase == JarvisPhase.listening) {
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
    _set(JarvisPhase.listening);
    await _stt.listen(
      onResult: _onResult,
      onSoundLevelChange: (db) {
        // Android : environ -2..10 dB ; iOS : -50..0.
        final v = db < 0 && db < -2 ? (db + 50) / 50 : (db + 2) / 12;
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
    if ((status == 'done' || status == 'notListening') && phase == JarvisPhase.listening) {
      // Laisse le temps au résultat final d'arriver.
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        if (phase == JarvisPhase.listening && !_handled) _endListening();
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
    _set(JarvisPhase.idle);
    _resumeWake();
  }

  // ----------------------------------------------------------- compréhension

  /// Traite une phrase (vocale ou tapée).
  Future<void> handle(String text) async {
    if (text.trim().isEmpty) {
      _set(JarvisPhase.idle);
      await _resumeWake();
      return;
    }
    level = 0;
    log.add(JarvisLog(true, text));
    _set(JarvisPhase.thinking);
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
        // On parle et on agit en même temps, comme dans le film.
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
    _set(JarvisPhase.idle);
    await _resumeWake();
  }

  String _short(String e) {
    final i = e.indexOf(' : ');
    return i > 0 ? e.substring(i + 3) : e;
  }

  Future<void> _say(String text) async {
    reply = text;
    log.add(JarvisLog(false, text));
    if (log.length > 30) log.removeRange(0, log.length - 30);
    _set(JarvisPhase.speaking);
    if (!settings.voice) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      return;
    }
    await _initTts();
    try {
      await _tts.setSpeechRate(settings.speechRate);
      await _tts.setPitch(settings.pitch);
      await _tts.speak(text);
    } on Exception {
      // pas de voix disponible
    }
  }

  /// Message d'accueil au lancement.
  Future<void> greet() => _say(lines.greeting()).then((_) => _set(JarvisPhase.idle));

  @override
  void dispose() {
    stopWakeWord();
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }
}
