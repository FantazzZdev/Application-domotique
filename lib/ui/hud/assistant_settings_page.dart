import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../assistant/assistant.dart';
import '../../models.dart';
import 'hud_theme.dart';
import 'hud_widgets.dart';

class AssistantSettingsPage extends StatefulWidget {
  const AssistantSettingsPage({super.key, required this.state, required this.assistant});
  final AppState state;
  final Assistant assistant;

  @override
  State<AssistantSettingsPage> createState() => _AssistantSettingsPageState();
}

class _AssistantSettingsPageState extends State<AssistantSettingsPage> {
  late final settings = widget.state.data.assistant;
  late final _title = TextEditingController(text: settings.title);
  List<Map<String, String>> _voices = [];

  @override
  void initState() {
    super.initState();
    widget.assistant.frenchVoices().then((v) {
      if (mounted) setState(() => _voices = v);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save({bool restartWake = false}) async {
    settings.title = _title.text.trim();
    await widget.state.saveSettings();
    if (restartWake) await widget.assistant.startWakeWord();
    if (mounted) setState(() {});
  }

  Future<void> _choosePersona(Persona p) async {
    if (settings.persona == p) return;
    settings
      ..persona = p
      ..voiceName = '';
    await _save(restartWake: true);
    await widget.assistant.say(widget.assistant.lines.identity());
  }

  @override
  Widget build(BuildContext context) {
    final name = settings.persona.displayName;
    return Scaffold(
      appBar: AppBar(title: const Text('ASSISTANT')),
      body: ListenableBuilder(
        listenable: widget.assistant,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              for (final p in Persona.values) ...[
                Expanded(child: _personaCard(p)),
                if (p != Persona.values.last) const SizedBox(width: 12),
              ],
            ]),
            const SizedBox(height: 16),
            HudPanel(
              title: 'Personnalité',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _title,
                  style: Hud.bodyText(),
                  decoration: InputDecoration(
                    labelText: 'Comment $name s\'adresse à vous',
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
                if (_voices.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _voices.any((v) => v['name'] == settings.voiceName) ? settings.voiceName : '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Voix'),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text('Automatique (${settings.persona.male ? 'voix d\'homme' : 'voix de femme'})'),
                      ),
                      for (final v in _voices)
                        DropdownMenuItem(
                          value: v['name'],
                          child: Text('${v['name']}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) async {
                      settings.voiceName = v ?? '';
                      await _save();
                      await widget.assistant.say('Voici ma voix.');
                    },
                  ),
                _slider('Débit', settings.speechRate, 0.2, 0.9, (v) => settings.speechRate = v),
                _slider('Hauteur', settings.pitch, 0.5, 1.5, (v) => settings.pitch = v),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => widget.assistant.say(widget.assistant.lines.greeting()),
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Tester la voix'),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            HudPanel(
              title: 'Mains libres',
              accent: Hud.amber,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  'Quand l\'app est ouverte, dites « $name » puis votre demande, sans toucher l\'écran. '
                  'Vous pouvez aussi tout dire d\'une traite : « $name, ferme les volets ».\n'
                  'Aucun compte nécessaire : c\'est la reconnaissance vocale du téléphone qui écoute. '
                  'Le micro reste actif tant que l\'app est à l\'écran, ce qui consomme plus de batterie.',
                  style: Hud.bodyText(size: 14, color: Hud.text.withValues(alpha: 0.85)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.handsFree,
                  title: Text('Écouter « $name »', style: Hud.bodyText()),
                  subtitle: Text(
                    widget.assistant.wakeError ??
                        (widget.assistant.wakeActive ? 'Actif — dites « $name »' : 'Inactif'),
                    style: Hud.bodyText(size: 13, color: widget.assistant.wakeError != null ? Hud.red : Hud.dim),
                  ),
                  onChanged: (v) {
                    settings.handsFree = v;
                    _save(restartWake: true);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.muteBeeps,
                  title: Text('Couper les bips d\'écoute', style: Hud.bodyText()),
                  subtitle: Text(
                    'Certains téléphones bipent à chaque relance de l\'écoute. Le son du téléphone est '
                    'coupé pendant l\'écoute du prénom et rétabli dès que $name parle.',
                    style: Hud.bodyText(size: 13, color: Hud.dim),
                  ),
                  onChanged: (v) {
                    settings.muteBeeps = v;
                    _save(restartWake: true);
                  },
                ),
                Text(
                  'Application fermée : utilisez le widget « Assistant vocal » ou l\'appui long sur l\'icône de l\'app.',
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

  Widget _personaCard(Persona p) {
    final selected = settings.persona == p;
    final accent = p.male ? Hud.cyan : Hud.violet;
    return GestureDetector(
      onTap: () => _choosePersona(p),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: selected ? 1 : 0.55,
        child: HudPanel(
          accent: selected ? accent : Hud.dim,
          child: Column(children: [
            SizedBox(
              height: 96,
              child: ArcReactor(mode: selected ? ReactorMode.speaking : ReactorMode.idle, size: 96, color: accent),
            ),
            const SizedBox(height: 8),
            Text(p.displayName.toUpperCase(),
                style: Hud.label(size: 16, color: selected ? accent : Hud.dim, spacing: 4)
                    .copyWith(shadows: selected ? Hud.glow(accent, 10) : null)),
            const SizedBox(height: 2),
            Text(p.male ? 'VOIX MASCULINE' : 'VOIX FÉMININE', style: Hud.label(size: 8, color: Hud.dim, spacing: 1.5)),
          ]),
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, void Function(double) set) {
    return Row(children: [
      SizedBox(width: 100, child: Text(label, style: Hud.bodyText(size: 14, color: Hud.dim))),
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
