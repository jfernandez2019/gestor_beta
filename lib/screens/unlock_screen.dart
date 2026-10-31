import 'dart:async';

import 'package:flutter/material.dart';

import '../data/vault_service.dart';
import '../widgets.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _pw = TextEditingController();
  bool _busy = false;
  String? _error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && vault.lockUntil != null) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vault.biometricsEnabled) _bio();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _bio() async {
    if (_busy) return;
    await vault.unlockWithBiometrics();
  }

  Future<void> _submit() async {
    if (_busy || _pw.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await vault.unlock(_pw.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r) {
        case UnlockResult.ok:
          _pw.clear();
          break;
        case UnlockResult.wrong:
          _error = 'Contraseña incorrecta.';
          _pw.clear();
          break;
        case UnlockResult.lockedOut:
          _error = 'Demasiados intentos fallidos.';
          break;
        case UnlockResult.error:
          _error = 'No se pudo abrir la bóveda.';
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = vault.lockRemaining;
    final locked = remaining > Duration.zero;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/psyduck.png', height: 120),
                const SizedBox(height: 16),
                Text('Bóveda bloqueada',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),
                SecretField(
                  controller: _pw,
                  label: 'Contraseña maestra',
                  onSubmitted: (_) => _submit(),
                ),
                if (locked)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Espera ${remaining.inSeconds + 1} s antes de reintentar.',
                      style: TextStyle(color: cs.error),
                    ),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: cs.error)),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: (_busy || locked) ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Desbloquear'),
                ),
                if (vault.biometricsEnabled) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: locked ? null : _bio,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Usar huella / rostro'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
