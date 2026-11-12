import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'assistant/assistant.dart';
import 'services/widget_bridge.dart';
import 'ui/hud/hud_home.dart';
import 'ui/hud/hud_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  try {
    await WidgetBridge.init();
    await WidgetBridge.publish(state.data);
  } on Exception {
    // Les widgets sont un bonus : l'app doit démarrer quoi qu'il arrive.
  }
  final assistant = Assistant(state);
  state.onAssistantRequested = () => assistant.listen();
  state.initQuickActions();
  runApp(DeltaHomeApp(state: state, assistant: assistant));
}

class DeltaHomeApp extends StatefulWidget {
  const DeltaHomeApp({super.key, required this.state, required this.assistant});
  final AppState state;
  final Assistant assistant;

  @override
  State<DeltaHomeApp> createState() => _DeltaHomeAppState();
}

class _DeltaHomeAppState extends State<DeltaHomeApp> with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.assistant.restoreAudio().then((_) => widget.assistant.startWakeWord());
    // Ouverture depuis le widget de l'assistant : on lance directement l'écoute.
    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetUri);
      _widgetClicks = HomeWidget.widgetClicked.listen(_onWidgetUri);
    } on Exception {
      // plugin indisponible (tests)
    }
  }

  void _onWidgetUri(Uri? uri) {
    if (uri?.host == 'assistant') {
      Future<void>.delayed(const Duration(milliseconds: 400), widget.assistant.listen);
    }
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Micro et connexions libérés en arrière-plan, repris au retour.
    if (s == AppLifecycleState.paused) {
      widget.state.disconnect();
      widget.assistant.stopWakeWord();
    }
    if (s == AppLifecycleState.resumed) {
      widget.state.refreshStates();
      widget.assistant.restoreAudio().then((_) => widget.assistant.startWakeWord());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Domus',
      debugShowCheckedModeBanner: false,
      theme: Hud.theme(),
      darkTheme: Hud.theme(),
      themeMode: ThemeMode.dark,
      home: HudHome(state: widget.state, assistant: widget.assistant),
    );
  }
}
