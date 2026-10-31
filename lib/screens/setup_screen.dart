import 'package:flutter/material.dart';

import '../data/vault_service.dart';
import '../widgets.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _ack = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_pw.text.length < 10) {
      setState(() => _error = 'Usa al menos 10 caracteres.');
      return;
    }
    if (_pw.text != _pw2.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    if (!_ack) {
      setState(() => _error = 'Confirma que entiendes que no hay recuperación.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await vault.createVault(_pw.text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.shield_outlined, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text('Crea tu bóveda',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Elige una contraseña maestra larga que solo tú conozcas. '
                'Todo se cifra en este teléfono y nada sale a internet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SecretField(
                controller: _pw,
                label: 'Contraseña maestra',
                onChanged: (_) => setState(() {}),
                action: TextInputAction.next,
              ),
              StrengthBar(_pw.text),
              const SizedBox(height: 16),
              SecretField(
                controller: _pw2,
                label: 'Repite la contraseña maestra',
                onSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _ack,
                onChanged: (v) => setState(() => _ack = v ?? false),
                title: const Text(
                  'Entiendo que si olvido esta contraseña NO hay forma de '
                  'recuperar mis datos.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _create,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Crear bóveda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
