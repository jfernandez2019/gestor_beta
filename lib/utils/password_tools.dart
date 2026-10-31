import 'dart:math';

import 'package:flutter/material.dart';

class Strength {
  const Strength(this.score, this.label, this.color, this.bits);
  final int score; // 0..4
  final String label;
  final Color color;
  final double bits;
}

class PasswordTools {
  static const _lower = 'abcdefghijklmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digits = '0123456789';
  static const _symbols = '!@#%^&*()-_=+[]{}:;,.?';
  static const _ambiguous = 'Il1O0o';

  static const _common = [
    'password', 'contraseña', 'contrasena', '123456', 'qwerty', 'admin',
    'abcdef', '111111', 'letmein', 'welcome', 'banco', 'netflix', 'asdf',
  ];

  /// Generador con aleatoriedad criptográfica (Random.secure).
  static String generate({
    int length = 20,
    bool lower = true,
    bool upper = true,
    bool digits = true,
    bool symbols = true,
    bool avoidAmbiguous = false,
  }) {
    final rnd = Random.secure();
    String clean(String s) => avoidAmbiguous
        ? s.split('').where((c) => !_ambiguous.contains(c)).join()
        : s;

    final sets = <String>[
      if (lower) clean(_lower),
      if (upper) clean(_upper),
      if (digits) clean(_digits),
      if (symbols) _symbols,
    ];
    if (sets.isEmpty) sets.add(clean(_lower));

    final all = sets.join();
    final chars = <String>[];
    // Garantiza al menos un carácter de cada grupo elegido.
    for (final s in sets) {
      chars.add(s[rnd.nextInt(s.length)]);
    }
    while (chars.length < length) {
      chars.add(all[rnd.nextInt(all.length)]);
    }
    chars.shuffle(rnd);
    return chars.take(length).join();
  }

  static double entropyBits(String p) {
    if (p.isEmpty) return 0;
    var pool = 0;
    if (RegExp(r'[a-z]').hasMatch(p)) pool += 26;
    if (RegExp(r'[A-Z]').hasMatch(p)) pool += 26;
    if (RegExp(r'[0-9]').hasMatch(p)) pool += 10;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(p)) pool += 33;
    var bits = p.length * (log(pool) / ln2);
    final unique = p.split('').toSet().length;
    if (unique < p.length / 2) bits *= 0.6;
    final low = p.toLowerCase();
    if (_common.any((c) => low.contains(c))) bits *= 0.5;
    return bits;
  }

  static Strength evaluate(String p) {
    final b = entropyBits(p);
    if (b < 28) return Strength(0, 'Muy débil', Colors.red, b);
    if (b < 36) return Strength(1, 'Débil', Colors.deepOrange, b);
    if (b < 60) return Strength(2, 'Aceptable', Colors.amber.shade800, b);
    if (b < 80) return Strength(3, 'Fuerte', Colors.lightGreen.shade700, b);
    return Strength(4, 'Muy fuerte', Colors.green, b);
  }
}
