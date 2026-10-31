import 'dart:convert';

import 'package:flutter/material.dart';

import '../crypto/vault_crypto.dart';

const List<String> kCategories = [
  'Bancos',
  'Streaming',
  'Sistemas',
  'Correo',
  'Redes sociales',
  'Compras',
  'Otros',
];

IconData categoryIcon(String c) {
  switch (c) {
    case 'Bancos':
      return Icons.account_balance;
    case 'Streaming':
      return Icons.play_circle_outline;
    case 'Sistemas':
      return Icons.dns_outlined;
    case 'Correo':
      return Icons.mail_outline;
    case 'Redes sociales':
      return Icons.people_outline;
    case 'Compras':
      return Icons.shopping_bag_outlined;
    default:
      return Icons.vpn_key_outlined;
  }
}

class Entry {
  Entry({
    required this.id,
    required this.title,
    this.username = '',
    required this.password,
    this.url = '',
    this.notes = '',
    this.category = 'Otros',
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  String title;
  String username;
  String password;
  String url;
  String notes;
  String category;
  bool favorite;
  final DateTime createdAt;
  DateTime updatedAt;

  static String newId() => base64UrlEncode(VaultCrypto.randomBytes(9));

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
        'category': category,
        'favorite': favorite,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        username: (j['username'] as String?) ?? '',
        password: (j['password'] as String?) ?? '',
        url: (j['url'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
        category: (j['category'] as String?) ?? 'Otros',
        favorite: (j['favorite'] as bool?) ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class VaultSettings {
  VaultSettings({this.autoLockSeconds = 60, this.clipboardSeconds = 30});

  /// 0 = bloquear apenas la app pasa a segundo plano.
  int autoLockSeconds;
  int clipboardSeconds;

  Map<String, dynamic> toJson() => {
        'autoLockSeconds': autoLockSeconds,
        'clipboardSeconds': clipboardSeconds,
      };

  factory VaultSettings.fromJson(Map<String, dynamic> j) {
    const locks = [0, 15, 60, 300];
    const clips = [15, 30, 60];
    final a = (j['autoLockSeconds'] as int?) ?? 60;
    final c = (j['clipboardSeconds'] as int?) ?? 30;
    return VaultSettings(
      autoLockSeconds: locks.contains(a) ? a : 60,
      clipboardSeconds: clips.contains(c) ? c : 30,
    );
  }
}
