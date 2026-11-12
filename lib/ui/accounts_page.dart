import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/widget_bridge.dart';
import '../tydom/cloud.dart';
import 'common.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key, required this.state});
  final AppState state;

  void _edit(BuildContext context, [Account? a]) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => AccountFormPage(state: state, account: a)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final t = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Comptes Delta Dore')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Text(
                'Chaque compte reste connecté en permanence : plus besoin de se déconnecter '
                'pour passer de chez vous à chez la famille.',
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              for (final a in state.accounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      leading: CircleAvatar(
                        backgroundColor: accountColor(a),
                        child: Text(
                          a.label.isEmpty ? '?' : a.label.characters.first.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${a.email}\n'
                          '${a.gateways.length} box · ${state.devicesOf(a.id).length} équipements'),
                      isThreeLine: true,
                      onTap: () => _edit(context, a),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AccountFormPage extends StatefulWidget {
  const AccountFormPage({super.key, required this.state, this.account});
  final AppState state;
  final Account? account;

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.account?.label ?? '');
  late final _email = TextEditingController(text: widget.account?.email ?? '');
  late final _password = TextEditingController(text: widget.account?.password ?? '');
  late final _mac = TextEditingController(
      text: widget.account?.gateways.map((g) => g.mac).join(', ') ?? '');
  late int _color = widget.account?.colorIndex ?? widget.state.accounts.length % accountColors.length;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.account != null;

  @override
  void dispose() {
    for (final c in [_label, _email, _password, _mac]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.state.addOrUpdateAccount(
        existing: widget.account,
        label: _label.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        mac: _mac.text.trim(),
        colorIndex: _color,
      );
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: const Text('Ses équipements et raccourcis seront retirés de l\'app. '
            'Le compte Delta Dore lui-même n\'est pas modifié.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await widget.state.removeAccount(widget.account!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifier le compte' : 'Nouveau compte'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Supprimer',
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _label,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom affiché',
                hintText: 'Maison, Beaux-parents…',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Donnez un nom à ce compte' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-mail du compte Tydom',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (v) => (v ?? '').contains('@') ? null : 'E-mail invalide',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? 'Mot de passe requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mac,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Adresse MAC de la box Tydom',
                hintText: '001A25XXXXXX',
                helperText: 'Étiquette sous la box (12 caractères, commence souvent par 001A25). '
                    'Plusieurs box : séparez par une virgule.',
                helperMaxLines: 3,
                prefixIcon: Icon(Icons.router_outlined),
              ),
              validator: (v) {
                final macs = (v ?? '')
                    .split(RegExp('[,;/]'))
                    .map(DeltaDoreCloud.normalizeMac)
                    .where((m) => m.isNotEmpty)
                    .toList();
                if (macs.isEmpty) return 'Adresse MAC requise';
                if (macs.any((m) => m.length != 12)) return 'Une adresse MAC fait 12 caractères (0-9, A-F)';
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text('Couleur', style: t.textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: [
                for (var i = 0; i < accountColors.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _color = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(accountColors[i]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == i ? t.colorScheme.onSurface : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: _color == i ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline_rounded, color: t.colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_error!, style: TextStyle(color: t.colorScheme.onErrorContainer)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link_rounded),
              label: Text(_busy ? 'Connexion et recherche des équipements…' : 'Connecter le compte'),
            ),
            const SizedBox(height: 12),
            Text(
              'Les identifiants sont chiffrés sur ce téléphone et ne servent qu\'à dialoguer '
              'avec les serveurs Delta Dore.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
