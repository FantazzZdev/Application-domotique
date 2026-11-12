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
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                  children: [
                    Appear(child: _topBar()),
                    const SizedBox(height: 4),
                    Appear(index: 1, child: _reactor()),
                    const SizedBox(height: 22),
                    if (s.accounts.isEmpty)
                      Appear(index: 2, child: _onboarding())
                    else
                      for (final (i, w) in _content().indexed) Appear(index: 2 + i, child: w),
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
    final greeting = _now.hour >= 18 || _now.hour < 5 ? 'Bonsoir' : 'Bonjour';
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greeting, style: Hud.bodyText(size: 15, color: Hud.dim)),
          Text(j.settings.persona.displayName,
              style: Hud.label(size: 24, color: Hud.text, spacing: 3, weight: FontWeight.w700)
                  .copyWith(shadows: Hud.glow(_persona, 14))),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${two(_now.hour)}:${two(_now.minute)}',
            style: Hud.label(size: 18, color: Hud.cyanSoft, spacing: 1.5, weight: FontWeight.w500)),
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
            online ? '${s.accounts.length} maison${s.accounts.length > 1 ? 's' : ''} en ligne' : 'Hors ligne',
            style: Hud.bodyText(size: 12, color: Hud.dim),
          ),
        ]),
      ]),
      const SizedBox(width: 4),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: Hud.cyan),
        color: Hud.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          _menu('assistant', Icons.record_voice_over_outlined, 'Assistant et voix'),
          _menu('accounts', Icons.home_work_outlined, 'Maisons (comptes Delta Dore)'),
          _menu('protocol', Icons.add_circle_outline, 'Nouveau raccourci'),
          _menu('type', Icons.keyboard_outlined, 'Écrire une commande'),
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
    final name = j.settings.persona.displayName;
    final (String status, String line) = switch (j.phase) {
      AssistantPhase.idle => (
          j.wakeActive ? 'En veille · dites « $name »' : 'Touchez pour parler',
          j.reply.isEmpty ? 'Tous les systèmes sont opérationnels.' : j.reply,
        ),
      AssistantPhase.listening => ('Je vous écoute…', j.transcript.isEmpty ? '' : '« ${j.transcript} »'),
      AssistantPhase.thinking => ('Analyse…', '« ${j.transcript} »'),
      AssistantPhase.speaking => (name, j.reply),
    };
    final color = j.phase == AssistantPhase.thinking ? Hud.amber : _persona;
    return Column(children: [
      GestureDetector(
        onTap: j.listen,
        onLongPress: _typeCommand,
        child: AnimatedScale(
          scale: j.phase == AssistantPhase.listening ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          child: ArcReactor(mode: mode, level: j.level, size: 190, color: _persona),
        ),
      ),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(status,
            key: ValueKey(status),
            style: Hud.bodyText(size: 14, color: color, weight: FontWeight.w700).copyWith(letterSpacing: 0.6)),
      ),
      const SizedBox(height: 6),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a), child: c),
        ),
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
      const SizedBox(height: 10),
      _handsFreeChip(),
    ]);
  }

  /// Interrupteur mains libres + ce que le téléphone entend (diagnostic).
  Widget _handsFreeChip() {
    final on = j.settings.handsFree;
    final name = j.settings.persona.displayName;
    return Column(children: [
      GestureDetector(
        onTap: () async {
          j.settings.handsFree = !on;
          await s.saveSettings();
          await j.startWakeWord();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: (on ? _persona : Hud.dim).withValues(alpha: on ? 0.14 : 0.08),
            border: Border.all(color: (on ? _persona : Hud.dim).withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(on ? Icons.hearing_rounded : Icons.hearing_disabled_rounded, size: 16, color: on ? _persona : Hud.dim),
            const SizedBox(width: 8),
            Text(on ? 'Mains libres : « $name »' : 'Mains libres désactivé',
                style: Hud.bodyText(size: 13, color: on ? Hud.text : Hud.dim, weight: FontWeight.w600)),
          ]),
        ),
      ),
      if (j.wakeError != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(j.wakeError!, textAlign: TextAlign.center, style: Hud.bodyText(size: 12, color: Hud.red)),
        )
      else if (on && j.wakeHeard.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Entendu : « ${j.wakeHeard} »',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Hud.bodyText(size: 12, color: Hud.dim)),
        ),
    ]);
  }

  Widget _onboarding() => HudPanel(
        title: 'Bienvenue',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'Connectez vos comptes Delta Dore — le vôtre, celui de la famille — '
            'et je piloterai volets et portails de toutes vos maisons.',
            style: Hud.bodyText(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => _push(AccountsPage(state: s)), child: const Text('Ajouter une maison')),
        ]),
      );

  List<Widget> _content() => [
        _sectionTitle('Raccourcis', trailing: 'appui long pour modifier'),
        SizedBox(
          height: 122,
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
                const SizedBox(width: 12),
              ],
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => showShortcutEditor(context, s),
                child: Container(
                  width: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Hud.line),
                  ),
                  child: Icon(Icons.add_rounded, color: Hud.cyan.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
        ),
        for (final a in s.accounts) ...[const SizedBox(height: 18), _sector(a)],
      ];

  Widget _sectionTitle(String t, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Row(children: [
          Text(t, style: Hud.bodyText(size: 18, weight: FontWeight.w700)),
          const Spacer(),
          if (trailing != null) Text(trailing, style: Hud.bodyText(size: 12, color: Hud.dim)),
        ]),
      );

  Color _accent(Account? a) {
    if (a == null) return Hud.cyan;
    // Le premier compte reste cyan ; les autres prennent leur couleur.
    return a.colorIndex == 0 ? Hud.cyan : Color.lerp(accountColor(a), Colors.white, 0.15)!;
  }

  Widget _subTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(t, style: Hud.bodyText(size: 13, color: Hud.dim, weight: FontWeight.w600).copyWith(letterSpacing: 0.8)),
      );

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
      trailing: Text('${devices.length} équipement${devices.length > 1 ? 's' : ''}',
          style: Hud.bodyText(size: 12, color: Hud.dim)),
      child: devices.isEmpty
          ? Text('Aucun équipement détecté.', style: Hud.bodyText(color: Hud.dim))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (covers.isNotEmpty) ...[
                _subTitle('VOLETS'),
                if (covers.length > 1) ...[
                  ShutterRow(
                    value: avg(),
                    label: 'Tous les volets',
                    icon: Icons.select_all_rounded,
                    accent: Hud.amber,
                    busy: covers.any((d) => s.busy.contains(d.key)),
                    onChanged: (v) => s.runOn(covers, DeviceAction.open, position: v),
                    onStep: (open) => s.runOn(covers, open ? DeviceAction.open : DeviceAction.close),
                  ),
                  Divider(color: Hud.line, height: 14),
                ],
                for (final d in covers)
                  ShutterRow(
                    value: d.value,
                    label: d.name,
                    accent: accent,
                    busy: s.busy.contains(d.key),
                    onChanged: (v) => s.setPosition(d, v),
                    onStep: (open) => s.command(d, open ? DeviceAction.open : DeviceAction.close),
                  ),
              ],
              if (gates.isNotEmpty) ...[
                const SizedBox(height: 14),
                _subTitle('ACCÈS'),
                const SizedBox(height: 6),
                Wrap(spacing: 18, runSpacing: 16, children: [
                  for (final d in gates)
                    HoldActivator(
                      label: d.name,
                      icon: d.kind == DeviceKind.garage ? Icons.garage : Icons.fence,
                      accent: accent,
                      busy: s.busy.contains(d.key),
                      size: 104,
                      onActivate: () => s.command(d, DeviceAction.toggle),
                    ),
                ]),
              ],
              if (lights.isNotEmpty) ...[
                const SizedBox(height: 14),
                _subTitle('ÉCLAIRAGE'),
                const SizedBox(height: 6),
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
