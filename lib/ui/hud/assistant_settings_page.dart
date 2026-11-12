import 'package:material_ui/material_ui.dart';

import '../../assistant/neural_voice.dart';

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

  final Map<String, bool> _installed = {};
  int _lastDownloads = 0;

  @override
  void initState() {
    super.initState();
    widget.assistant.frenchVoices().then((v) {
      if (mounted) setState(() => _voices = v);
    });
    _refreshInstalled();
    widget.assistant.addListener(_onAssistant);
  }

  void _onAssistant() {
    final n = widget.assistant.neural.downloads.length;
    if (n < _lastDownloads) _refreshInstalled();
    _lastDownloads = n;
  }

  Future<void> _refreshInstalled() async {
    for (final m in [upmcModel, siwisModel]) {
      _installed[m.id] = await widget.assistant.neural.isInstalled(m);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.assistant.removeListener(_onAssistant);
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
      ..voiceName = ''
      ..neuralVoice = neuralVoices
              .where((v) => v.male == p.male && (_installed[v.model.id] ?? false))
              .firstOrNull
              ?.id ??
          '';
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
              ]),
            ),
            const SizedBox(height: 16),
            _voicePanel(),
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

  Widget _voicePanel() {
    final a = widget.assistant;
    final options = neuralVoices.where((v) => v.male == settings.persona.male).toList();
    final usingNeural = options.any((v) => v.id == settings.neuralVoice && (_installed[v.model.id] ?? false));
    return HudPanel(
      title: 'Voix de ${settings.persona.displayName}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          'Voix IA : générées directement sur le téléphone, sans Internet ni compte. '
          'Téléchargement unique au premier choix.',
          style: Hud.bodyText(size: 14, color: Hud.text.withValues(alpha: 0.85)),
        ),
        const SizedBox(height: 8),
        for (final v in options) _neuralTile(v),
        _choice(
          selected: !usingNeural,
          title: 'Voix du téléphone',
          subtitle: 'Synthèse vocale standard d\'Android / iOS',
          onTap: () {
            settings.neuralVoice = '';
            _save();
          },
        ),
        if (!usingNeural && _voices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String>(
              initialValue: _voices.any((v) => v['name'] == settings.voiceName) ? settings.voiceName : '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Voix du téléphone'),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text('Automatique (${settings.persona.male ? 'voix d\'homme' : 'voix de femme'})'),
                ),
                for (final v in _voices)
                  DropdownMenuItem(value: v['name'], child: Text('${v['name']}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) async {
                settings.voiceName = v ?? '';
                await _save();
                await a.say('Voici ma voix.');
              },
            ),
          ),
        if (a.voiceError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(a.voiceError!, style: Hud.bodyText(size: 13, color: Hud.red)),
          ),
        const SizedBox(height: 8),
        _slider('Débit', settings.speechRate, 0.2, 0.9, (v) => settings.speechRate = v),
        if (usingNeural)
          _slider('Effet IA', settings.aiEffect, 0, 1, (v) => settings.aiEffect = v)
        else
          _slider('Hauteur', settings.pitch, 0.5, 1.5, (v) => settings.pitch = v),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => a.say(a.lines.greeting()),
          icon: const Icon(Icons.volume_up_outlined),
          label: const Text('Tester la voix'),
        ),
      ]),
    );
  }

  Widget _neuralTile(NeuralVoiceOption v) {
    final a = widget.assistant;
    final installed = _installed[v.model.id] ?? false;
    final progress = a.neural.downloads[v.model.id];
    final selected = installed && settings.neuralVoice == v.id;
    if (progress != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            progress < 0.97
                ? 'Téléchargement de ${v.label}… ${(progress * 100).round()} %'
                : 'Installation de ${v.label}…',
            style: Hud.bodyText(size: 15),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress < 0.97 ? progress : null, color: Hud.cyan),
        ]),
      );
    }
    return _choice(
      selected: selected,
      title: '${v.label} (voix IA)',
      subtitle: installed ? v.description : '${v.description} — ${v.model.sizeMb} Mo à télécharger',
      trailing: installed
          ? null
          : TextButton(onPressed: () => a.installVoice(v), child: const Text('Télécharger')),
      onTap: () async {
        if (!installed) {
          await a.installVoice(v);
          return;
        }
        settings.neuralVoice = v.id;
        await _save();
        await a.say('Voici ma voix.');
      },
    );
  }

  Widget _choice({
    required bool selected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? Hud.cyan : Hud.dim),
      title: Text(title, style: Hud.bodyText(weight: FontWeight.w700)),
      subtitle: Text(subtitle, style: Hud.bodyText(size: 13, color: Hud.dim)),
      trailing: trailing,
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
