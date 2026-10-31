import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/vault_service.dart';
import '../widgets.dart';
import 'entry_form_screen.dart';

class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({super.key, required this.entryId});
  final String entryId;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  bool _reveal = false;

  Future<void> _copy(String value) async {
    await vault.copySecret(value);
    if (mounted) {
      snack(context,
          'Copiado. Se borrará del portapapeles en ${vault.settings.clipboardSeconds} s.');
    }
  }

  Widget _tile(String label, String value, {bool secret = false}) {
    if (value.isEmpty) return const SizedBox.shrink();
    final hidden = secret && !_reveal;
    return ListTile(
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      subtitle: Text(
        hidden ? '••••••••••••' : value,
        style: TextStyle(
          fontSize: 16,
          fontFamily: secret && _reveal ? 'monospace' : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (secret)
            IconButton(
              tooltip: _reveal ? 'Ocultar' : 'Mostrar',
              icon: Icon(_reveal ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _reveal = !_reveal),
            ),
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(value),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Entry e) async {
    final ok = await confirm(
      context,
      title: 'Eliminar “${e.title}”',
      message: 'Esta acción no se puede deshacer.',
      confirmText: 'Eliminar',
      danger: true,
    );
    if (!ok) return;
    await vault.remove(e.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vault,
      builder: (context, _) {
        final matches = vault.entries.where((x) => x.id == widget.entryId);
        if (matches.isEmpty) return const Scaffold(body: SizedBox.shrink());
        final e = matches.first;
        final s = e.password.isEmpty ? null : e;
        return Scaffold(
          appBar: AppBar(
            title: Text(e.title),
            actions: [
              IconButton(
                tooltip: 'Favorita',
                icon: Icon(e.favorite ? Icons.star : Icons.star_border,
                    color: e.favorite ? Colors.amber : null),
                onPressed: () => vault.toggleFavorite(e),
              ),
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EntryFormScreen(entry: e)),
                ),
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(e),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                leading: Icon(categoryIcon(e.category)),
                title: Text(e.category),
              ),
              const Divider(height: 1),
              _tile('Usuario / correo', e.username),
              _tile('Contraseña', e.password, secret: true),
              if (s != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StrengthBar(e.password),
                ),
              _tile('Sitio / sistema', e.url),
              if (e.notes.isNotEmpty)
                ListTile(
                  title: Text('Notas',
                      style: Theme.of(context).textTheme.labelMedium),
                  subtitle: SelectableText(e.notes,
                      style: const TextStyle(fontSize: 16)),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Creada: ${fmtDate(e.createdAt)}   ·   Modificada: ${fmtDate(e.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
