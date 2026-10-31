import 'package:flutter/material.dart';

import 'utils/password_tools.dart';

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Campo de contraseña con ojo para mostrar/ocultar y sin aprendizaje del teclado.
class SecretField extends StatefulWidget {
  const SecretField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.action,
    this.trailing,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final TextInputAction? action;
  final Widget? trailing;
  final bool autofocus;

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: !_show,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.action,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.trailing != null) widget.trailing!,
            IconButton(
              tooltip: _show ? 'Ocultar' : 'Mostrar',
              icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _show = !_show),
            ),
          ],
        ),
      ),
    );
  }
}

class StrengthBar extends StatelessWidget {
  const StrengthBar(this.password, {super.key});
  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final s = PasswordTools.evaluate(password);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (s.score + 1) / 5,
            minHeight: 6,
            color: s.color,
            backgroundColor: s.color.withOpacity(0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text('${s.label}  ·  ${s.bits.round()} bits',
            style: TextStyle(color: s.color, fontSize: 12)),
      ],
    );
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Aceptar',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> askPassword(
  BuildContext context, {
  required String title,
  String? message,
  String label = 'Contraseña maestra',
  String confirmText = 'Aceptar',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PasswordDialog(
        title: title, message: message, label: label, confirmText: confirmText),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({
    required this.title,
    required this.message,
    required this.label,
    required this.confirmText,
  });
  final String title;
  final String? message;
  final String label;
  final String confirmText;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 12),
          ],
          SecretField(
            controller: _c,
            label: widget.label,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _c.text),
            child: Text(widget.confirmText)),
      ],
    );
  }
}
