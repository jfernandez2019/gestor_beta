import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/vault_service.dart';
import '../widgets.dart';
import 'audit_screen.dart';
import 'entry_detail_screen.dart';
import 'entry_form_screen.dart';
import 'generator_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  bool _searching = false;
  String _filter = 'Todas';

  @override
  void initState() {
    super.initState();
    if (vault.justCreated) {
      vault.justCreated = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerBiometrics());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _offerBiometrics() async {
    if (!mounted || !vault.biometricsAvailable) return;
    final yes = await confirm(
      context,
      title: '¿Activar desbloqueo biométrico?',
      message:
          'Podrás abrir la bóveda con tu huella o rostro. La contraseña maestra '
          'seguirá siendo necesaria como respaldo.',
      confirmText: 'Activar',
    );
    if (yes) await vault.enableBiometrics();
  }

  List<Entry> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final list = vault.entries.where((e) {
      if (_filter == 'Favoritas' && !e.favorite) return false;
      if (_filter != 'Todas' && _filter != 'Favoritas' && e.category != _filter) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          e.username.toLowerCase().contains(q) ||
          e.url.toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }

  void _menu(String v) {
    Widget? page;
    switch (v) {
      case 'gen':
        page = const GeneratorScreen();
        break;
      case 'audit':
        page = const AuditScreen();
        break;
      case 'settings':
        page = const SettingsScreen();
        break;
    }
    if (page != null) {
      final p = page;
      Navigator.push(context, MaterialPageRoute(builder: (_) => p));
    }
  }

  Widget _chips() {
    final filters = ['Todas', 'Favoritas', ...kCategories];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          return ChoiceChip(
            label: Text(f),
            selected: _filter == f,
            onSelected: (_) => setState(() => _filter = f),
          );
        },
      ),
    );
  }

  Widget _empty() {
    final none = vault.entries.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(none ? Icons.key_off_outlined : Icons.search_off,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              none
                  ? 'Aún no tienes contraseñas guardadas.\nToca “Nueva” para agregar la primera.'
                  : 'No se encontraron resultados.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vault,
      builder: (context, _) {
        final items = _filtered;
        return Scaffold(
          appBar: AppBar(
            title: _searching
                ? TextField(
                    controller: _search,
                    autofocus: true,
                    decoration: const InputDecoration(
                        hintText: 'Buscar…', border: InputBorder.none),
                    onChanged: (_) => setState(() {}),
                  )
                : const Text('Bóveda'),
            actions: [
              IconButton(
                icon: Icon(_searching ? Icons.close : Icons.search),
                tooltip: 'Buscar',
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _search.clear();
                }),
              ),
              IconButton(
                icon: const Icon(Icons.lock_outline),
                tooltip: 'Bloquear ahora',
                onPressed: vault.lock,
              ),
              PopupMenuButton<String>(
                onSelected: _menu,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'gen', child: Text('Generador')),
                  PopupMenuItem(
                      value: 'audit', child: Text('Auditoría de seguridad')),
                  PopupMenuItem(value: 'settings', child: Text('Ajustes')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              _chips(),
              Expanded(
                child: items.isEmpty
                    ? _empty()
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (_, i) {
                          final e = items[i];
                          return ListTile(
                            leading: CircleAvatar(
                                child: Icon(categoryIcon(e.category))),
                            title: Text(e.title),
                            subtitle: Text(
                                e.username.isEmpty ? e.category : e.username),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (e.favorite)
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 18),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Copiar contraseña',
                                  onPressed: () async {
                                    await vault.copySecret(e.password);
                                    if (context.mounted) {
                                      snack(context,
                                          'Contraseña copiada. Se borrará en ${vault.settings.clipboardSeconds} s.');
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      EntryDetailScreen(entryId: e.id)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Nueva'),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EntryFormScreen())),
          ),
        );
      },
    );
  }
}
