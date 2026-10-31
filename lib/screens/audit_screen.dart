import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/vault_service.dart';
import '../utils/password_tools.dart';
import 'entry_detail_screen.dart';

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = vault.entries;
    final weak =
        entries.where((e) => PasswordTools.evaluate(e.password).score <= 1).toList();

    final byPw = <String, List<Entry>>{};
    for (final e in entries) {
      byPw.putIfAbsent(e.password, () => []).add(e);
    }
    final reused = byPw.values.where((l) => l.length > 1).expand((l) => l).toList();

    final now = DateTime.now();
    final old = entries.where((e) => now.difference(e.updatedAt).inDays > 365).toList();

    final problems = <Entry>{...weak, ...reused, ...old}.length;
    final ok = entries.isEmpty ? 100 : ((entries.length - problems) * 100 ~/ entries.length);

    return Scaffold(
      appBar: AppBar(title: const Text('Auditoría de seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('$ok%',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(entries.isEmpty
                        ? 'Aún no hay contraseñas para revisar.'
                        : '$problems de ${entries.length} contraseñas necesitan atención.'),
                  ),
                ],
              ),
            ),
          ),
          _section(context, 'Contraseñas débiles', weak, Icons.warning_amber),
          _section(context, 'Contraseñas repetidas', reused, Icons.copy_all),
          _section(context, 'Sin cambiar hace más de 1 año', old, Icons.history),
        ],
      ),
    );
  }

  Widget _section(
      BuildContext context, String title, List<Entry> list, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text('$title (${list.length})',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 28),
              child: Text('Todo en orden ✔'),
            )
          else
            ...list.map((e) => ListTile(
                  contentPadding: const EdgeInsets.only(left: 28),
                  title: Text(e.title),
                  subtitle: Text(e.username.isEmpty ? e.category : e.username),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EntryDetailScreen(entryId: e.id)),
                  ),
                )),
        ],
      ),
    );
  }
}
