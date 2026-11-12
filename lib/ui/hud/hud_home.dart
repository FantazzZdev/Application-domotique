import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../assistant/assistant.dart';
import '../../models.dart';
import '../accounts_page.dart';
import '../common.dart';
import '../shortcut_editor.dart';
import 'hud_theme.dart';
import 'hud_widgets.dart';
import 'assistant_settings_page.dart';

class HudHome extends StatefulWidget {
  const HudHome({super.key, required this.state, required this.assistant});
  final AppState state;
  final Assistant assistant;

  @override
  State<HudHome> createState() => _HudHomeState();
}

class _HudHomeState extends State<HudHome> {
  AppState get s => widget.state;
  Assistant get j => widget.assistant;
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    s.onMessage = (msg, {error = false}) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg, style: Hud.bodyText(color: error ? Hud.red : Hud.text)),
          duration: Duration(seconds: error ? 5 : 2),
        ));
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => s.refreshStates());
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Color get _persona => j.settings.persona.male ? Hud.cyan : Hud.violet;

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _typeCommand() {
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(c).bottom),
        child: TextField(
          controller: ctrl,
          autofocus: true,
          style: Hud.bodyText(size: 18),
          decoration: InputDecoration(
            labelText: 'Commande pour ${j.settings.persona.displayName}',
            hintText: 'Ferme les volets de la maison…',
            prefixIcon: const Icon(Icons.keyboard_command_key),
          ),
          onSubmitted: (v) {
            Navigator.pop(c);
            j.handle(v);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Hud.bg,
        body: HudBackground(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([s, j]),
              builder: (context, _) => RefreshIndicator(
                color: Hud.cyan,
                backgroundColor: Hud.bg2,
                onRefresh: s.refreshStates,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _topBar(),
                    const SizedBox(height: 8),
                    _reactor(),
                    const SizedBox(height: 18),
                    if (s.accounts.isEmpty) _onboarding() else ..._content(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    String two(int v) => v.toString().padLeft(2, '0');
    final online = s.accounts.isNotEmpty;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(j.settings.persona.spaced,
              style: Hud.label(size: 20, color: _persona, spacing: 5, weight: FontWeight.w900)
                  .copyWith(shadows: Hud.glow(_persona, 16))),
          const SizedBox(height: 2),
          Row(children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? const Color(0xFF3DFF9A) : Hud.amber,
                boxShadow: [BoxShadow(color: online ? const Color(0xFF3DFF9A) : Hud.amber, blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              online
                  ? '${s.accounts.length} SECTEUR${s.accounts.length > 1 ? 'S' : ''} EN LIGNE'
                  : 'AUCUN SECTEUR',
              style: Hud.label(size: 9, color: Hud.dim, spacing: 2),
            ),
          ]),
        ]),
      ),
      Text('${two(_now.hour)}:${two(_now.minute)}:${two(_now.second)}',
          style: Hud.label(size: 13, color: Hud.cyanSoft, spacing: 2, weight: FontWeight.w500)),
      const SizedBox(width: 4),
      PopupMenuButton<String>(
        icon: const Icon(Icons.blur_on, color: Hud.cyan),
        color: Hud.bg2,
        onSelected: (v) {
          switch (v) {
            case 'assistant':
              _push(AssistantSettingsPage(state: s, assistant: j));
            case 'accounts':
              _push(AccountsPage(state: s));
            case 'protocol':
              showShortcutEditor(context, s);
            case 'type':
              _typeCommand();
          }
        },
        itemBuilder: (_) => [
          _menu('assistant', Icons.record_voice_over, 'Assistant : ${j.settings.persona.displayName}'),
          _menu('accounts', Icons.hub_outlined, 'Secteurs (comptes Delta Dore)'),
          _menu('protocol', Icons.add_box_outlined, 'Nouveau protocole'),
          _menu('type', Icons.keyboard_outlined, 'Taper une commande'),
        ],
      ),
    ]);
  }

  PopupMenuItem<String> _menu(String v, IconData i, String t) => PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(i, color: Hud.cyan, size: 20),
          const SizedBox(width: 12),
          Text(t, style: Hud.bodyText()),
        ]),
      );

  Widget _reactor() {
    final mode = switch (j.phase) {
      AssistantPhase.idle => ReactorMode.idle,
      AssistantPhase.listening => ReactorMode.listening,
      AssistantPhase.thinking => ReactorMode.thinking,
      AssistantPhase.speaking => ReactorMode.speaking,
    };
    final (String status, String line) = switch (j.phase) {
      AssistantPhase.idle => (
          j.wakeActive ? 'EN VEILLE // DITES ${j.settings.persona.displayName.toUpperCase()}' : 'EN VEILLE // TOUCHEZ LE RÉACTEUR',
          j.reply.isEmpty ? 'Tous les systèmes sont opérationnels.' : j.reply,
        ),
      AssistantPhase.listening => ('À L\'ÉCOUTE', j.transcript.isEmpty ? '…' : '« ${j.transcript} »'),
      AssistantPhase.thinking => ('ANALYSE', '« ${j.transcript} »'),
      AssistantPhase.speaking => (j.settings.persona.displayName.toUpperCase(), j.reply),
    };
    final color = j.phase == AssistantPhase.thinking ? Hud.amber : _persona;
    return Column(children: [
      GestureDetector(
        onTap: j.listen,
        onLongPress: _typeCommand,
        child: ArcReactor(mode: mode, level: j.level, size: 236, color: _persona),
      ),
      const SizedBox(height: 10),
      Text(status, style: Hud.label(size: 10, color: color).copyWith(shadows: Hud.glow(color, 8))),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Padding(
          key: ValueKey(line),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            line,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Hud.bodyText(size: 18, color: Hud.text.withValues(alpha: 0.92)),
          ),
        ),
      ),
    ]);
  }

  Widget _onboarding() => HudPanel(
        title: 'Initialisation',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'Connectez vos comptes Delta Dore — le vôtre, celui de la famille — '
            'et je piloterai volets et portails de toutes vos maisons.',
            style: Hud.bodyText(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => _push(AccountsPage(state: s)), child: const Text('AJOUTER UN SECTEUR')),
        ]),
      );

  List<Widget> _content() => [
        _sectionTitle('PROTOCOLES', trailing: 'APPUI LONG : MODIFIER'),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              for (final sc in s.shortcuts) ...[
                ProtocolTile(
                  label: sc.label,
                  sub: s.data.account(sc.accountId)?.label ?? '',
                  icon: iconFor(sc.icon),
                  accent: _accent(s.data.account(sc.accountId)),
                  busy: s.busy.contains(sc.id),
                  onTap: () => s.runShortcut(sc),
                  onLongPress: () => showShortcutEditor(context, s, sc),
                ),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                onTap: () => showShortcutEditor(context, s),
                child: SizedBox(
                  width: 70,
                  child: HudPanel(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(height: 74, child: Icon(Icons.add, color: Hud.cyan.withValues(alpha: 0.7))),
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final a in s.accounts) ...[const SizedBox(height: 18), _sector(a)],
      ];

  Widget _sectionTitle(String t, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Row(children: [
          Text(t, style: Hud.label(size: 11).copyWith(shadows: Hud.glow(Hud.cyan, 8))),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: Hud.line)),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(trailing, style: Hud.label(size: 7, color: Hud.dim, spacing: 1.5)),
          ],
        ]),
      );

  Color _accent(Account? a) {
    if (a == null) return Hud.cyan;
    // Le premier compte reste cyan ; les autres prennent leur couleur.
    return a.colorIndex == 0 ? Hud.cyan : Color.lerp(accountColor(a), Colors.white, 0.15)!;
  }

  Widget _sector(Account a) {
    final devices = s.devicesOf(a.id);
    final covers = devices.where((d) => d.isCover).toList();
    final gates = devices.where((d) => d.kind == DeviceKind.gate || d.kind == DeviceKind.garage).toList();
    final lights = devices.where((d) => d.kind == DeviceKind.light).toList();
    final accent = _accent(a);
    double? avg() {
      final known = covers.where((d) => d.value != null).toList();
      if (known.isEmpty) return null;
      return known.map((d) => d.value!).reduce((x, y) => x + y) / known.length;
    }

    return HudPanel(
      title: a.label,
      accent: accent,
      trailing: Text('SECTEUR / ${devices.length} UNITÉS', style: Hud.label(size: 8, color: Hud.dim, spacing: 1.5)),
      child: devices.isEmpty
          ? Text('Aucun équipement détecté.', style: Hud.bodyText(color: Hud.dim))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (covers.isNotEmpty) ...[
                Text('VOLETS', style: Hud.label(size: 8, color: Hud.dim)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (covers.length > 1) ...[
                      ShutterSlider(
                        value: avg(),
                        label: 'Tous',
                        accent: Hud.amber,
                        busy: covers.any((d) => s.busy.contains(d.key)),
                        onChanged: (v) => s.runOn(covers, DeviceAction.open, position: v),
                      ),
                      Container(width: 1, height: 200, color: Hud.line, margin: const EdgeInsets.symmetric(horizontal: 6)),
                    ],
                    for (final d in covers)
                      ShutterSlider(
                        value: d.value,
                        label: d.name,
                        accent: accent,
                        busy: s.busy.contains(d.key),
                        onChanged: (v) => s.setPosition(d, v),
                      ),
                  ]),
                ),
              ],
              if (gates.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('ACCÈS', style: Hud.label(size: 8, color: Hud.dim)),
                const SizedBox(height: 10),
                Wrap(spacing: 18, runSpacing: 16, children: [
                  for (final d in gates)
                    HoldActivator(
                      label: d.name,
                      icon: d.kind == DeviceKind.garage ? Icons.garage : Icons.fence,
                      accent: accent,
                      busy: s.busy.contains(d.key),
                      onActivate: () => s.command(d, DeviceAction.toggle),
                    ),
                ]),
              ],
              if (lights.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('ÉCLAIRAGE', style: Hud.label(size: 8, color: Hud.dim)),
                const SizedBox(height: 10),
                Wrap(spacing: 10, runSpacing: 14, children: [
                  for (final d in lights)
                    HudSwitch(
                      on: (d.value ?? 0) > 0,
                      label: d.name,
                      busy: s.busy.contains(d.key),
                      onChanged: (on) async {
                        await s.command(d, on ? DeviceAction.open : DeviceAction.close);
                        d.value = on ? 100 : 0;
                      },
                    ),
                ]),
              ],
            ]),
    );
  }
}
