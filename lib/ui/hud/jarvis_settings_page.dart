import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../jarvis/jarvis.dart';
import 'hud_theme.dart';
import 'hud_widgets.dart';

class JarvisSettingsPage extends StatefulWidget {
  const JarvisSettingsPage({super.key, required this.state, required this.jarvis});
  final AppState state;
  final Jarvis jarvis;

  @override
  State<JarvisSettingsPage> createState() => _JarvisSettingsPageState();
}

class _JarvisSettingsPageState extends State<JarvisSettingsPage> {
  late final settings = widget.state.data.jarvis;
  late final _title = TextEditingController(text: settings.title);
  late final _key = TextEditingController(text: settings.picovoiceKey);
  bool _obscure = true;

  @override
  void dispose() {
    _title.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save({bool restartWake = false}) async {
    settings
      ..title = _title.text.trim()
      ..picovoiceKey = _key.text.trim();
    await widget.state.saveSettings();
    if (restartWake) await widget.jarvis.startWakeWord();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JARVIS')),
      body: ListenableBuilder(
        listenable: widget.jarvis,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            HudPanel(
              title: 'Personnalité',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _title,
                  style: Hud.bodyText(),
                  decoration: const InputDecoration(
                    labelText: 'Comment Jarvis s\'adresse à vous',
                    hintText: 'monsieur, madame, un prénom… (vide = rien)',
                  ),
                  onChanged: (_) => _save(),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.voice,
                  title: Text('Réponses parlées', style: Hud.bodyText()),
                  onChanged: (v) {
                    settings.voice = v;
                    _save();
                  },
                ),
                _slider('Débit de la voix', settings.speechRate, 0.2, 0.9, (v) => settings.speechRate = v),
                _slider('Grave ↔ aigu', settings.pitch, 0.5, 1.5, (v) => settings.pitch = v),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => widget.jarvis.handle('bonjour'),
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Tester la voix'),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            HudPanel(
              title: 'Mot d\'activation « Jarvis »',
              accent: Hud.amber,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  'Quand l\'app est ouverte, dites simplement « Jarvis » pour lancer l\'écoute, sans toucher l\'écran. '
                  'La détection se fait sur le téléphone grâce à Picovoice (gratuit pour un usage personnel) : '
                  'créez un compte sur console.picovoice.ai, copiez votre « AccessKey » et collez-la ici.',
                  style: Hud.bodyText(size: 14, color: Hud.text.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: _obscure,
                  style: Hud.bodyText(),
                  decoration: InputDecoration(
                    labelText: 'AccessKey Picovoice',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  onSubmitted: (_) => _save(restartWake: true),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.wakeWord,
                  title: Text('Écouter « Jarvis »', style: Hud.bodyText()),
                  subtitle: Text(
                    widget.jarvis.wakeError ??
                        (widget.jarvis.wakeActive ? 'Actif — dites « Jarvis »' : 'Inactif'),
                    style: Hud.bodyText(
                        size: 13, color: widget.jarvis.wakeError != null ? Hud.red : Hud.dim),
                  ),
                  onChanged: (v) {
                    settings.wakeWord = v;
                    _save(restartWake: true);
                  },
                ),
                Text(
                  'Sans clé : touchez le réacteur, utilisez le widget « Jarvis » ou l\'appui long sur l\'icône de l\'app.',
                  style: Hud.bodyText(size: 13, color: Hud.dim),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            HudPanel(
              title: 'Exemples de commandes',
              child: Text(
                '« Ferme les volets »\n'
                '« Ouvre le portail chez les beaux-parents »\n'
                '« Descends le volet du salon »\n'
                '« Mets les volets de la maison à moitié »\n'
                '« Volets de la chambre à 30 % »\n'
                '« Stop les volets partout »\n'
                '« Allume la lumière de la cuisine »\n'
                '« Fais-moi un rapport »',
                style: Hud.bodyText(size: 15, color: Hud.cyanSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, void Function(double) set) {
    return Row(children: [
      SizedBox(width: 120, child: Text(label, style: Hud.bodyText(size: 14, color: Hud.dim))),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) => setState(() => set(v)),
          onChangeEnd: (_) => _save(),
        ),
      ),
    ]);
  }
}
