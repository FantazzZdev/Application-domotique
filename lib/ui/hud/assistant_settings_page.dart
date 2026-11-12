import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

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
  late final _key = TextEditingController(text: settings.picovoiceKey);
  bool _obscure = true;
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
    _key.dispose();
    super.dispose();
  }

  Future<void> _save({bool restartWake = false}) async {
    settings
      ..title = _title.text.trim()
      ..picovoiceKey = _key.text.trim();
    await widget.state.saveSettings();
    if (restartWake) await widget.assistant.startWakeWord();
    if (mounted) setState(() {});
  }

  Future<void> _choosePersona(Persona p) async {
    if (settings.persona == p) return;
    settings
      ..persona = p
      ..voiceName = ''
      // Le mot d'activation dépend du prénom : il faut le fichier du nouveau nom.
      ..keywordPath = ''
      ..wakeWord = false;
    await _save(restartWake: true);
    await widget.assistant.say(widget.assistant.lines.identity());
  }

  Future<void> _importKeyword() async {
    final file = await FilePicker.pickFile(type: FileType.any, dialogTitle: 'Fichier .ppn');
    if (file == null) return;
    if (!file.name.toLowerCase().endsWith('.ppn')) {
      _snack('Choisissez le fichier .ppn téléchargé depuis la console Picovoice.');
      return;
    }
    final dir = await getApplicationSupportDirectory();
    final dest = File('${dir.path}/wake_${settings.persona.name}.ppn');
    await dest.writeAsBytes(await file.readAsBytes());
    settings
      ..keywordPath = dest.path
      ..wakeWord = true;
    await _save(restartWake: true);
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
              title: 'Mot d\'activation : $name',
              accent: Hud.amber,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  'Pour lancer l\'écoute en disant simplement « $name » (app ouverte), sans toucher l\'écran. '
                  'La détection se fait sur le téléphone grâce à Picovoice, gratuit pour un usage personnel :\n'
                  '1. Créez un compte sur console.picovoice.ai et copiez votre « AccessKey ».\n'
                  '2. Dans « Porcupine », créez le mot « $name » et téléchargez le fichier '
                  '${Platform.isIOS ? 'iOS' : 'Android'} (.ppn).\n'
                  '3. Collez la clé et importez le fichier ci-dessous.',
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
                  onChanged: (_) => _save(),
                  onSubmitted: (_) => _save(restartWake: true),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _importKeyword,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(settings.keywordPath.isEmpty ? 'Importer le fichier « $name » (.ppn)' : 'Fichier importé ✓ — remplacer'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.wakeWord,
                  title: Text('Écouter « $name »', style: Hud.bodyText()),
                  subtitle: Text(
                    widget.assistant.wakeError ??
                        (widget.assistant.wakeActive
                            ? 'Actif — dites « $name »'
                            : (settings.picovoiceKey.isEmpty || settings.keywordPath.isEmpty)
                                ? 'Clé et fichier requis'
                                : 'Inactif'),
                    style: Hud.bodyText(size: 13, color: widget.assistant.wakeError != null ? Hud.red : Hud.dim),
                  ),
                  onChanged: (v) {
                    settings.wakeWord = v;
                    _save(restartWake: true);
                  },
                ),
                Text(
                  'Sans mot d\'activation : touchez le réacteur, utilisez le widget « $name » '
                  'ou l\'appui long sur l\'icône de l\'app.',
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
