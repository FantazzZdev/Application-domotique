import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'jarvis/jarvis.dart';
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
  final jarvis = Jarvis(state);
  state.onJarvisRequested = () => jarvis.listen();
  state.initQuickActions();
  runApp(DeltaHomeApp(state: state, jarvis: jarvis));
}

class DeltaHomeApp extends StatefulWidget {
  const DeltaHomeApp({super.key, required this.state, required this.jarvis});
  final AppState state;
  final Jarvis jarvis;

  @override
  State<DeltaHomeApp> createState() => _DeltaHomeAppState();
}

class _DeltaHomeAppState extends State<DeltaHomeApp> with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.jarvis.startWakeWord();
    // Ouverture depuis le widget « Jarvis » : on lance directement l'écoute.
    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_onWidgetUri);
      _widgetClicks = HomeWidget.widgetClicked.listen(_onWidgetUri);
    } on Exception {
      // plugin indisponible (tests)
    }
  }

  void _onWidgetUri(Uri? uri) {
    if (uri?.host == 'jarvis') {
      Future<void>.delayed(const Duration(milliseconds: 400), widget.jarvis.listen);
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
      widget.jarvis.stopWakeWord();
    }
    if (s == AppLifecycleState.resumed) {
      widget.state.refreshStates();
      widget.jarvis.startWakeWord();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarvis',
      debugShowCheckedModeBanner: false,
      theme: Hud.theme(),
      darkTheme: Hud.theme(),
      themeMode: ThemeMode.dark,
      home: HudHome(state: widget.state, jarvis: widget.jarvis),
    );
  }
}
