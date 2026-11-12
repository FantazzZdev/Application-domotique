import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import 'accounts_page.dart';
import 'common.dart';
import 'shortcut_editor.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.state});
  final AppState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _filter; // id de compte, null = tous

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    s.onMessage = (msg, {error = false}) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: error ? scheme.error : null,
          duration: Duration(seconds: error ? 5 : 2),
        ));
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => s.refreshStates());
  }

  void _openAccounts() =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountsPage(state: s)));

  void _editShortcut([Shortcut? sc]) => showShortcutEditor(context, s, sc);

  void _showWidgetHelp() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _WidgetHelp(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final accounts = s.accounts;
        return Scaffold(
          body: RefreshIndicator(
            onRefresh: s.refreshStates,
            edgeOffset: 120,
            child: CustomScrollView(
              slivers: [
                SliverAppBar.large(
                  title: const Text('DeltaHome'),
                  actions: [
                    IconButton(
                      tooltip: 'Widgets',
                      icon: const Icon(Icons.widgets_outlined),
                      onPressed: _showWidgetHelp,
                    ),
                    IconButton(
                      tooltip: 'Comptes',
                      icon: const Icon(Icons.manage_accounts_outlined),
                      onPressed: _openAccounts,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                if (accounts.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: _Welcome(onAdd: _openAccounts))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.list(children: [
                      SectionTitle(
                        'Raccourcis',
                        trailing: TextButton.icon(
                          onPressed: _editShortcut,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Ajouter'),
                        ),
                      ),
                      _ShortcutGrid(state: s, onEdit: _editShortcut),
                      if (accounts.length > 1) ...[
                        const SizedBox(height: 20),
                        _AccountFilter(
                          accounts: accounts,
                          selected: _filter,
                          onChanged: (v) => setState(() => _filter = v),
                        ),
                      ],
                      for (final a in accounts)
                        if (_filter == null || _filter == a.id) ..._accountSection(a),
                    ]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _accountSection(Account a) {
    final devices = s.devicesOf(a.id);
    return [
      SectionTitle(a.label, color: accountColor(a)),
      if (devices.isEmpty)
        Card(
          child: ListTile(
            leading: const Icon(Icons.search_off_rounded),
            title: const Text('Aucun équipement trouvé'),
            subtitle: const Text('Relancez la recherche depuis la page Comptes.'),
            onTap: _openAccounts,
          ),
        )
      else
        for (final d in devices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DeviceCard(device: d, state: s, color: accountColor(a)),
          ),
    ];
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: t.colorScheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.home_rounded, size: 56, color: t.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 28),
          Text('Bienvenue', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            'Ajoutez vos comptes Delta Dore (le vôtre, celui de la famille…) '
            'et pilotez volets et portail depuis une seule app, sans jamais vous déconnecter.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter un compte'),
          ),
        ],
      ),
    );
  }
}

class _AccountFilter extends StatelessWidget {
  const _AccountFilter({required this.accounts, required this.selected, required this.onChanged});
  final List<Account> accounts;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(label: const Text('Tout'), selected: selected == null, onSelected: (_) => onChanged(null)),
          for (final a in accounts) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: CircleAvatar(backgroundColor: accountColor(a), radius: 6),
              label: Text(a.label),
              selected: selected == a.id,
              onSelected: (_) => onChanged(a.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({required this.state, required this.onEdit});
  final AppState state;
  final void Function([Shortcut?]) onEdit;

  @override
  Widget build(BuildContext context) {
    final items = state.shortcuts;
    if (items.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.bolt_rounded),
          title: const Text('Créez votre premier raccourci'),
          subtitle: const Text('Ex. « Ouvrir le portail » : un seul tap, ici ou sur l\'écran d\'accueil.'),
          onTap: onEdit,
        ),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 600 ? 4 : 2;
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final sc in items)
            SizedBox(
              width: w,
              child: ShortcutTile(
                shortcut: sc,
                account: state.data.account(sc.accountId),
                busy: state.busy.contains(sc.id),
                onTap: () => state.runShortcut(sc),
                onLongPress: () => onEdit(sc),
              ),
            ),
        ],
      );
    });
  }
}

class ShortcutTile extends StatelessWidget {
  const ShortcutTile({
    super.key,
    required this.shortcut,
    required this.account,
    required this.busy,
    required this.onTap,
    required this.onLongPress,
  });

  final Shortcut shortcut;
  final Account? account;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = accountColor(account);
    final dark = t.brightness == Brightness.dark;
    return Material(
      color: Color.alphaBlend(color.withValues(alpha: dark ? 0.22 : 0.14), t.colorScheme.surface),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: busy ? null : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Icon(iconFor(shortcut.icon), color: Colors.white),
                  ),
                  const Spacer(),
                  Icon(Icons.touch_app_outlined, size: 18, color: t.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                shortcut.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                account?.label ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.device, required this.state, required this.color});
  final Device device;
  final AppState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final busy = state.busy.contains(device.key);
    final d = device;
    String? subtitle;
    if (d.value != null) {
      if (d.isCover) {
        subtitle = d.value! <= 0
            ? 'Fermé'
            : d.value! >= 100
                ? 'Ouvert'
                : 'Ouvert à ${d.value!.round()} %';
      } else if (d.kind == DeviceKind.light) {
        subtitle = d.value! > 0 ? 'Allumé' : 'Éteint';
      }
    }
    Widget action(IconData icon, String tip, DeviceAction a) => IconButton.filledTonal(
          tooltip: tip,
          onPressed: busy ? null : () => state.command(d, a),
          icon: Icon(icon),
        );

    final List<Widget> actions;
    if (d.family == CommandFamily.position) {
      actions = [
        action(Icons.arrow_upward_rounded, 'Ouvrir', DeviceAction.open),
        action(Icons.stop_rounded, 'Stop', DeviceAction.stop),
        action(Icons.arrow_downward_rounded, 'Fermer', DeviceAction.close),
      ];
    } else if (d.kind == DeviceKind.light) {
      actions = [
        action(Icons.lightbulb, 'Allumer', DeviceAction.open),
        action(Icons.lightbulb_outline, 'Éteindre', DeviceAction.close),
      ];
    } else {
      actions = [
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: busy ? null : () => state.command(d, DeviceAction.toggle),
          icon: const Icon(Icons.power_settings_new_rounded, size: 20),
          label: const Text('Actionner'),
        ),
        PopupMenuButton<DeviceAction>(
          enabled: !busy,
          padding: EdgeInsets.zero,
          iconSize: 20,
          onSelected: (a) => state.command(d, a),
          itemBuilder: (_) => [
            for (final a in [DeviceAction.open, DeviceAction.close, DeviceAction.stop])
              PopupMenuItem(value: a, child: Text(a.labelFor(d.kind))),
          ],
        ),
      ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
                    )
                  : Icon(deviceIcon(d.kind), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            for (final w in actions) ...[const SizedBox(width: 4), w],
          ],
        ),
      ),
    );
  }
}

class _WidgetHelp extends StatelessWidget {
  const _WidgetHelp();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget step(IconData i, String title, String body) => ListTile(
          leading: CircleAvatar(
            backgroundColor: t.colorScheme.primaryContainer,
            child: Icon(i, color: t.colorScheme.onPrimaryContainer),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(body),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Boutons sur l\'écran d\'accueil',
                  style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
            step(Icons.bolt_rounded, '1. Créez vos raccourcis',
                'Ici, dans l\'app : « Ouvrir portail », « Fermer volets »…'),
            step(Icons.touch_app_rounded, '2. Appui long sur l\'écran d\'accueil',
                'Puis « Widgets » (Android) ou « + » (iPhone), et cherchez DeltaHome.'),
            step(Icons.widgets_rounded, '3. Choisissez le widget',
                '« Bouton » : un seul raccourci, au choix. « Raccourcis » : vos 4 premiers.'),
            step(Icons.apps_rounded, 'Astuce',
                'Un appui long sur l\'icône de l\'app propose aussi vos 4 premiers raccourcis.'),
          ],
        ),
      ),
    );
  }
}
