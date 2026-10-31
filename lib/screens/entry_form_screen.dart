import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/vault_service.dart';
import '../widgets.dart';
import 'generator_screen.dart';

class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({super.key, this.entry});
  final Entry? entry;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _url;
  late final TextEditingController _notes;
  late String _category;
  late bool _favorite;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _title = TextEditingController(text: e?.title ?? '');
    _user = TextEditingController(text: e?.username ?? '');
    _pass = TextEditingController(text: e?.password ?? '');
    _url = TextEditingController(text: e?.url ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? 'Otros';
    _favorite = e?.favorite ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _user.dispose();
    _pass.dispose();
    _url.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final old = widget.entry;
    final e = Entry(
      id: old?.id ?? Entry.newId(),
      title: _title.text.trim(),
      username: _user.text.trim(),
      password: _pass.text,
      url: _url.text.trim(),
      notes: _notes.text.trim(),
      category: _category,
      favorite: _favorite,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    await vault.upsert(e);
    if (mounted) Navigator.pop(context);
  }

  void _openGenerator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: GeneratorPanel(
            onUse: (p) {
              _pass.text = p;
              Navigator.pop(ctx);
              setState(() {});
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.entry != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar' : 'Nueva contraseña'),
        actions: [
          IconButton(
            tooltip: 'Favorita',
            icon: Icon(_favorite ? Icons.star : Icons.star_border,
                color: _favorite ? Colors.amber : null),
            onPressed: () => setState(() => _favorite = !_favorite),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Nombre (ej. Banco Itaú, Netflix)',
                  border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                  labelText: 'Categoría', border: OutlineInputBorder()),
              items: kCategories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(children: [
                          Icon(categoryIcon(c), size: 20),
                          const SizedBox(width: 12),
                          Text(c),
                        ]),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? 'Otros'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _user,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Usuario / correo', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SecretField(
              controller: _pass,
              label: 'Contraseña',
              onChanged: (_) => setState(() {}),
              validator: (v) => (v == null || v.isEmpty) ? 'Requerida' : null,
              trailing: IconButton(
                tooltip: 'Generar',
                icon: const Icon(Icons.auto_awesome),
                onPressed: _openGenerator,
              ),
            ),
            StrengthBar(_pass.text),
            const SizedBox(height: 16),
            TextFormField(
              controller: _url,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  labelText: 'Sitio web / sistema (opcional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
