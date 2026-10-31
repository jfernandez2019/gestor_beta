import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/vault_service.dart';
import '../widgets.dart';
import '../data/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _changeMaster() async {
    final r = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _ChangeMasterDialog(),
    );
    if (r == null) return;
    final ok = await vault.changeMaster(r[0], r[1]);
    if (!mounted) return;
    snack(
        context,
        ok
            ? 'Contraseña maestra actualizada.'
            : 'La contraseña actual es incorrecta.');
  }

  Future<void> _export() async {
    final go = await confirm(
      context,
      title: 'Exportar copia cifrada',
      message:
          'Se genera un archivo .bvd cifrado con tu contraseña maestra actual. '
          'Guárdalo en un lugar seguro (otro dispositivo, USB). Sin esa '
          'contraseña nadie puede abrirlo.',
      confirmText: 'Exportar',
    );
    if (!go) return;
    vault.externalBusy = true;
    try {
      final f = await vault.exportBackup();
      await Share.shareXFiles([XFile(f.path)],
          subject: 'Copia de seguridad Bóveda');
    } catch (_) {
      if (mounted) snack(context, 'No se pudo exportar.');
    } finally {
      vault.externalBusy = false;
    }
  }

  Future<void> _import() async {
    vault.externalBusy = true;
    FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(type: FileType.any);
    } finally {
      vault.externalBusy = false;
    }
    final path = res?.files.single.path;
    if (path == null || !mounted) return;
    final pw = await askPassword(
      context,
      title: 'Importar copia',
      message: 'Ingresa la contraseña maestra con la que se creó esa copia.',
    );
    if (pw == null || !mounted) return;
    final n = await vault.importBackup(path, pw);
    if (!mounted) return;
    snack(
        context,
        n == null
            ? 'No se pudo abrir la copia (contraseña o archivo inválido).'
            : 'Importación lista: $n entradas agregadas/actualizadas.');
  }

  Future<void> _wipe() async {
    final ok = await confirm(
      context,
      title: 'Borrar toda la bóveda',
      message:
          'Se eliminarán todas tus contraseñas de este teléfono de forma permanente.',
      confirmText: 'Continuar',
      danger: true,
    );
    if (!ok || !mounted) return;
    final pw = await askPassword(context,
        title: 'Confirma con tu contraseña maestra',
        confirmText: 'Borrar todo');
    if (pw == null) return;
    final done = await vault.wipe(pw);
    if (!mounted) return;
    if (done) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      snack(context, 'Contraseña incorrecta.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([vault, themeController]),
      builder: (context, _) {
        final s = vault.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Ajustes')),
          body: ListView(
            children: [
              const _Header('Apariencia'),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('Sistema')),
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Claro')),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Oscuro')),
                  ],
                  selected: {themeController.mode},
                  onSelectionChanged: (s) => themeController.set(s.first),
                ),
              ),
              const _Header('Seguridad'),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Desbloqueo biométrico'),
                subtitle: Text(vault.biometricsAvailable
                    ? 'Huella o rostro, con la contraseña maestra de respaldo'
                    : 'No disponible en este dispositivo'),
                value: vault.biometricsEnabled,
                onChanged: vault.biometricsAvailable
                    ? (v) async {
                        if (v) {
                          final ok = await vault.enableBiometrics();
                          if (!ok && context.mounted) {
                            snack(context, 'No se pudo activar.');
                          }
                        } else {
                          await vault.disableBiometrics();
                        }
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Bloqueo automático'),
                subtitle: const Text('Al salir de la app'),
                trailing: DropdownButton<int>(
                  value: s.autoLockSeconds,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Inmediato')),
                    DropdownMenuItem(value: 15, child: Text('15 s')),
                    DropdownMenuItem(value: 60, child: Text('1 min')),
                    DropdownMenuItem(value: 300, child: Text('5 min')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    s.autoLockSeconds = v;
                    await vault.saveSettings();
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.content_paste_off_outlined),
                title: const Text('Borrar portapapeles tras'),
                trailing: DropdownButton<int>(
                  value: s.clipboardSeconds,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 s')),
                    DropdownMenuItem(value: 30, child: Text('30 s')),
                    DropdownMenuItem(value: 60, child: Text('60 s')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    s.clipboardSeconds = v;
                    await vault.saveSettings();
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Cambiar contraseña maestra'),
                onTap: _changeMaster,
              ),
              const _Header('Copias de seguridad'),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Exportar copia cifrada'),
                subtitle: const Text(
                    'Archivo .bvd protegido con tu contraseña maestra'),
                onTap: _export,
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Importar copia'),
                subtitle: const Text('Combina con las contraseñas actuales'),
                onTap: _import,
              ),
              const _Header('Zona de peligro'),
              ListTile(
                leading: Icon(Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Borrar toda la bóveda',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: _wipe,
              ),
              const _Header('Acerca de'),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Text(
                  'Sin conexión: la app no usa internet ni servidores.\n'
                  'Cifrado AES-256-GCM · clave derivada con PBKDF2-HMAC-SHA256 '
                  '(310.000 iteraciones).\n'
                  'Pantalla protegida contra capturas y grabación.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _ChangeMasterDialog extends StatefulWidget {
  const _ChangeMasterDialog();

  @override
  State<_ChangeMasterDialog> createState() => _ChangeMasterDialogState();
}

class _ChangeMasterDialogState extends State<_ChangeMasterDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _new2 = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _new2.dispose();
    super.dispose();
  }

  void _submit() {
    if (_new.text.length < 10) {
      setState(() => _error = 'La nueva debe tener al menos 10 caracteres.');
      return;
    }
    if (_new.text != _new2.text) {
      setState(() => _error = 'Las contraseñas nuevas no coinciden.');
      return;
    }
    Navigator.pop(context, [_old.text, _new.text]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña maestra'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SecretField(
                controller: _old, label: 'Contraseña actual', autofocus: true),
            const SizedBox(height: 12),
            SecretField(
                controller: _new,
                label: 'Nueva contraseña',
                onChanged: (_) => setState(() {})),
            StrengthBar(_new.text),
            const SizedBox(height: 12),
            SecretField(controller: _new2, label: 'Repite la nueva'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Cambiar')),
      ],
    );
  }
}
