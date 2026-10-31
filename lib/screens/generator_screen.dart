import 'package:flutter/material.dart';

import '../data/vault_service.dart';
import '../utils/password_tools.dart';
import '../widgets.dart';

class GeneratorScreen extends StatelessWidget {
  const GeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generador')),
      body: const SingleChildScrollView(child: GeneratorPanel()),
    );
  }
}

/// Panel reutilizable: se usa en pantalla completa y en el formulario.
class GeneratorPanel extends StatefulWidget {
  const GeneratorPanel({super.key, this.onUse});
  final ValueChanged<String>? onUse;

  @override
  State<GeneratorPanel> createState() => _GeneratorPanelState();
}

class _GeneratorPanelState extends State<GeneratorPanel> {
  int _length = 20;
  bool _lower = true;
  bool _upper = true;
  bool _digits = true;
  bool _symbols = true;
  bool _clear = false;
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = _gen();
  }

  String _gen() => PasswordTools.generate(
        length: _length,
        lower: _lower,
        upper: _upper,
        digits: _digits,
        symbols: _symbols,
        avoidAmbiguous: _clear,
      );

  void _regen() => setState(() => _value = _gen());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _value,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 20, letterSpacing: 0.5),
            ),
          ),
          StrengthBar(_value),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Regenerar',
                icon: const Icon(Icons.refresh),
                onPressed: _regen,
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await vault.copySecret(_value);
                  if (context.mounted) snack(context, 'Copiada');
                },
              ),
              const Spacer(),
              if (widget.onUse != null)
                FilledButton(
                  onPressed: () => widget.onUse!(_value),
                  child: const Text('Usar esta'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Longitud: $_length'),
          Slider(
            value: _length.toDouble(),
            min: 8,
            max: 64,
            divisions: 56,
            label: '$_length',
            onChanged: (v) {
              _length = v.round();
              _regen();
            },
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Minúsculas (a-z)'),
            value: _lower,
            onChanged: (v) {
              _lower = v;
              _regen();
            },
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Mayúsculas (A-Z)'),
            value: _upper,
            onChanged: (v) {
              _upper = v;
              _regen();
            },
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Números (0-9)'),
            value: _digits,
            onChanged: (v) {
              _digits = v;
              _regen();
            },
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Símbolos (!@#…)'),
            value: _symbols,
            onChanged: (v) {
              _symbols = v;
              _regen();
            },
          ),
          SwitchListTile(
            dense: true,
            title: const Text('Evitar caracteres ambiguos (Il1O0o)'),
            value: _clear,
            onChanged: (v) {
              _clear = v;
              _regen();
            },
          ),
        ],
      ),
    );
  }
}
