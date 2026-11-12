import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import 'common.dart';

Future<void> showShortcutEditor(BuildContext context, AppState state, [Shortcut? existing]) {
  if (state.accounts.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ShortcutEditor(state: state, existing: existing),
  );
}

class _ShortcutEditor extends StatefulWidget {
  const _ShortcutEditor({required this.state, this.existing});
  final AppState state;
  final Shortcut? existing;

  @override
  State<_ShortcutEditor> createState() => _ShortcutEditorState();
}

class _ShortcutEditorState extends State<_ShortcutEditor> {
  late String _accountId = widget.existing?.accountId ?? widget.state.accounts.first.id;
  late String? _target = widget.existing?.target;
  late DeviceAction _action = widget.existing?.action ?? DeviceAction.open;
  late String _icon = widget.existing?.icon ?? 'up';
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
  bool _labelTouched = false;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _labelTouched = widget.existing != null;
    _ensureTarget();
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  List<Device> get _devices => s.devicesOf(_accountId);

  bool get _hasCovers => _devices.any((d) => d.isCover);

  DeviceKind get _kind {
    if (_target == allShuttersTarget) return DeviceKind.shutter;
    return s.data.device(_target ?? '')?.kind ?? DeviceKind.other;
  }

  List<DeviceAction> get _actions {
    final d = _target == null || _target == allShuttersTarget ? null : s.data.device(_target!);
    if (d == null || d.family == CommandFamily.position) {
      return [DeviceAction.open, DeviceAction.stop, DeviceAction.close];
    }
    if (d.kind == DeviceKind.light) return [DeviceAction.open, DeviceAction.close, DeviceAction.toggle];
    return [DeviceAction.toggle, DeviceAction.open, DeviceAction.close];
  }

  void _ensureTarget() {
    final valid = _target == allShuttersTarget ? _hasCovers : _devices.any((d) => d.key == _target);
    if (!valid) {
      _target = _hasCovers ? allShuttersTarget : (_devices.isEmpty ? null : _devices.first.key);
    }
    if (!_actions.contains(_action)) _action = _actions.first;
    _autoFill();
  }

  void _autoFill() {
    final kind = _kind;
    _icon = switch ((kind, _action)) {
      (DeviceKind.gate, _) => 'gate',
      (DeviceKind.garage, _) => 'garage',
      (DeviceKind.light, _) => 'light',
      (_, DeviceAction.open) => 'up',
      (_, DeviceAction.close) => 'down',
      (_, DeviceAction.stop) => 'stop',
      _ => 'shutter',
    };
    if (_labelTouched) return;
    final what = _target == allShuttersTarget
        ? 'volets'
        : (s.data.device(_target ?? '')?.name ?? '');
    _label.text = '${_action.labelFor(kind)} $what'.trim();
  }

  Future<void> _save() async {
    if (_target == null || _label.text.trim().isEmpty) return;
    final sc = Shortcut(
      id: widget.existing?.id ?? newId(),
      label: _label.text.trim(),
      icon: _icon,
      accountId: _accountId,
      target: _target!,
      action: _action,
    );
    await s.saveShortcut(sc);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.existing == null ? 'Nouveau raccourci' : 'Modifier le raccourci',
                style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            if (s.accounts.length > 1) ...[
              SegmentedButton<String>(
                segments: [
                  for (final a in s.accounts) ButtonSegment(value: a.id, label: Text(a.label)),
                ],
                selected: {_accountId},
                onSelectionChanged: (v) => setState(() {
                  _accountId = v.first;
                  _ensureTarget();
                }),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: _target,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Équipement'),
              items: [
                if (_hasCovers)
                  const DropdownMenuItem(value: allShuttersTarget, child: Text('Tous les volets')),
                for (final d in _devices)
                  DropdownMenuItem(
                    value: d.key,
                    child: Row(children: [
                      Icon(deviceIcon(d.kind), size: 20),
                      const SizedBox(width: 10),
                      Flexible(child: Text(d.name, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
              ],
              onChanged: (v) => setState(() {
                _target = v;
                _ensureTarget();
              }),
            ),
            const SizedBox(height: 16),
            SegmentedButton<DeviceAction>(
              segments: [
                for (final a in _actions) ButtonSegment(value: a, label: Text(a.labelFor(_kind))),
              ],
              selected: {_action},
              onSelectionChanged: (v) => setState(() {
                _action = v.first;
                _autoFill();
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _label,
              onChanged: (_) => _labelTouched = true,
              decoration: const InputDecoration(labelText: 'Nom du bouton'),
            ),
            const SizedBox(height: 16),
            Text('Icône', style: t.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in shortcutIcons.entries)
                  IconButton.filled(
                    isSelected: _icon == e.key,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          _icon == e.key ? accountColor(s.data.account(_accountId)) : t.colorScheme.surfaceContainerHighest,
                      foregroundColor: _icon == e.key ? Colors.white : t.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _icon = e.key),
                    icon: Icon(e.value),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _target == null ? null : _save, child: const Text('Enregistrer')),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await s.deleteShortcut(widget.existing!);
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Supprimer'),
                style: TextButton.styleFrom(foregroundColor: t.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
