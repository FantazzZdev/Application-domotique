import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'services/widget_bridge.dart';
import 'ui/common.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  try {
    await WidgetBridge.init();
    await WidgetBridge.publish(state.data);
  } on Exception {
    // Les widgets sont un bonus : l'app doit démarrer quoi qu'il arrive.
  }
  state.initQuickActions();
  runApp(DeltaHomeApp(state: state));
}

class DeltaHomeApp extends StatefulWidget {
  const DeltaHomeApp({super.key, required this.state});
  final AppState state;

  @override
  State<DeltaHomeApp> createState() => _DeltaHomeAppState();
}

class _DeltaHomeAppState extends State<DeltaHomeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // On libère les connexions en arrière-plan, on rafraîchit au retour.
    if (s == AppLifecycleState.paused) widget.state.disconnect();
    if (s == AppLifecycleState.resumed) widget.state.refreshStates();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeltaHome',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomePage(state: widget.state),
    );
  }
}
