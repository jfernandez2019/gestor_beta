import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

import '../crypto/vault_crypto.dart';
import 'models.dart';

enum UnlockResult { ok, wrong, lockedOut, error }

/// Instancia única de la bóveda (estado de toda la app).
final VaultService vault = VaultService();

class VaultService extends ChangeNotifier {
  static const _fileName = 'vault.bvd';
  static const _kFails = 'fails';
  static const _kLockUntil = 'lock_until';
  static const _kBioKey = 'bio_key';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final LocalAuthentication _auth = LocalAuthentication();

  File? _file;
  SecretKey? _key;
  Uint8List? _salt;
  int _iterations = VaultCrypto.kdfIterations;
  int _fails = 0;
  Timer? _clipTimer;
  String? _clipValue;

  bool hasVault = false;
  bool unlocked = false;
  bool justCreated = false;
  bool biometricsEnabled = false;
  bool biometricsAvailable = false;

  /// true mientras hay un selector de archivos / compartir abierto
  /// (evita que el bloqueo automático cierre la bóveda a mitad de la acción).
  bool externalBusy = false;

  DateTime? lockUntil;
  List<Entry> entries = [];
  VaultSettings settings = VaultSettings();

  // ───────────────────────── utilidades internas ─────────────────────────

  Future<String?> _read(String k) async {
    try {
      return await _secure.read(key: k);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String k, String v) async {
    try {
      await _secure.write(key: k, value: v);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _readDoc() async =>
      jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;

  String _plainJson() => jsonEncode({
        'entries': entries.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      });

  void _loadPlain(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    entries = (m['entries'] as List)
        .map((e) => Entry.fromJson(e as Map<String, dynamic>))
        .toList();
    settings = VaultSettings.fromJson(
        ((m['settings'] as Map?) ?? {}).cast<String, dynamic>());
  }

  void _apply(Map<String, dynamic> doc, SecretKey key, String plain) {
    _salt = Uint8List.fromList(base64Decode(doc['salt'] as String));
    _iterations = doc['iter'] as int;
    _key = key;
    _loadPlain(plain);
    unlocked = true;
  }

  /// Guarda de forma atómica (archivo temporal + rename).
  Future<void> _save() async {
    final data = await VaultCrypto.encrypt(_plainJson(), _key!);
    final doc = jsonEncode({
      'v': 1,
      'kdf': 'pbkdf2-sha256',
      'iter': _iterations,
      'salt': base64Encode(_salt!),
      'data': base64Encode(data),
    });
    final tmp = File('${_file!.path}.tmp');
    await tmp.writeAsString(doc, flush: true);
    await tmp.rename(_file!.path);
  }

  Future<bool> _verifyMaster(String pw) async {
    try {
      final doc = await _readDoc();
      final k = await VaultCrypto.deriveKey(
          pw, base64Decode(doc['salt'] as String), doc['iter'] as int);
      await VaultCrypto.decrypt(base64Decode(doc['data'] as String), k);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ───────────────────────── arranque y bloqueo ─────────────────────────

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/$_fileName');
    hasVault = await _file!.exists();
    _fails = int.tryParse(await _read(_kFails) ?? '') ?? 0;
    final until = int.tryParse(await _read(_kLockUntil) ?? '');
    if (until != null) lockUntil = DateTime.fromMillisecondsSinceEpoch(until);
    biometricsEnabled = (await _read(_kBioKey)) != null;
    try {
      biometricsAvailable =
          await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      biometricsAvailable = false;
    }
  }

  Duration get lockRemaining {
    final u = lockUntil;
    if (u == null) return Duration.zero;
    final d = u.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  bool get isLockedOut => lockRemaining > Duration.zero;

  Future<void> _registerFail() async {
    _fails++;
    await _write(_kFails, '$_fails');
    if (_fails >= 3) {
      final exp = min(_fails - 3, 6);
      final secs = min(300, 5 * (1 << exp));
      lockUntil = DateTime.now().add(Duration(seconds: secs));
      await _write(_kLockUntil, '${lockUntil!.millisecondsSinceEpoch}');
    }
  }

  Future<void> _resetFails() async {
    _fails = 0;
    lockUntil = null;
    await _write(_kFails, '0');
    try {
      await _secure.delete(key: _kLockUntil);
    } catch (_) {}
  }

  Future<void> createVault(String master) async {
    _salt = VaultCrypto.randomBytes(VaultCrypto.saltLength);
    _iterations = VaultCrypto.kdfIterations;
    _key = await VaultCrypto.deriveKey(master, _salt!, _iterations);
    entries = [];
    settings = VaultSettings();
    await _save();
    hasVault = true;
    unlocked = true;
    justCreated = true;
    notifyListeners();
  }

  Future<UnlockResult> unlock(String master) async {
    if (isLockedOut) return UnlockResult.lockedOut;
    Map<String, dynamic> doc;
    try {
      doc = await _readDoc();
    } catch (_) {
      return UnlockResult.error;
    }
    SecretKey? key;
    String? plain;
    try {
      key = await VaultCrypto.deriveKey(
          master, base64Decode(doc['salt'] as String), doc['iter'] as int);
      plain =
          await VaultCrypto.decrypt(base64Decode(doc['data'] as String), key);
    } catch (_) {
      await _registerFail();
      notifyListeners();
      return UnlockResult.wrong;
    }
    _apply(doc, key, plain);
    await _resetFails();
    notifyListeners();
    return UnlockResult.ok;
  }

  Future<UnlockResult> unlockWithBiometrics() async {
    if (!biometricsEnabled) return UnlockResult.error;
    if (isLockedOut) return UnlockResult.lockedOut;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Desbloquea tu bóveda de contraseñas',
        options: const AuthenticationOptions(
            biometricOnly: true, stickyAuth: true),
      );
      if (!ok) return UnlockResult.error;
      final b64 = await _read(_kBioKey);
      if (b64 == null) return UnlockResult.error;
      final key = SecretKey(base64Decode(b64));
      final doc = await _readDoc();
      final plain =
          await VaultCrypto.decrypt(base64Decode(doc['data'] as String), key);
      _apply(doc, key, plain);
      await _resetFails();
      notifyListeners();
      return UnlockResult.ok;
    } catch (_) {
      return UnlockResult.error;
    }
  }

  Future<bool> enableBiometrics() async {
    if (!unlocked || !biometricsAvailable) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Confirma para activar el desbloqueo biométrico',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!ok) return false;
      final bytes = await _key!.extractBytes();
      await _secure.write(key: _kBioKey, value: base64Encode(bytes));
      biometricsEnabled = true;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disableBiometrics() async {
    try {
      await _secure.delete(key: _kBioKey);
    } catch (_) {}
    biometricsEnabled = false;
    notifyListeners();
  }

  void lock() {
    if (!unlocked) return;
    _key = null;
    entries = [];
    unlocked = false;
    _clearClipboardNow();
    notifyListeners();
  }

  // ───────────────────────── entradas ─────────────────────────

  Future<void> upsert(Entry e) async {
    e.updatedAt = DateTime.now();
    final i = entries.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      entries[i] = e;
    } else {
      entries.add(e);
    }
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    entries.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> toggleFavorite(Entry e) async {
    e.favorite = !e.favorite;
    await _save();
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await _save();
    notifyListeners();
  }

  // ───────────────────────── portapapeles ─────────────────────────

  Future<void> copySecret(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _clipValue = text;
    _clipTimer?.cancel();
    _clipTimer = Timer(
        Duration(seconds: settings.clipboardSeconds), _clearClipboardNow);
  }

  Future<void> _clearClipboardNow() async {
    _clipTimer?.cancel();
    final mine = _clipValue;
    _clipValue = null;
    if (mine == null) return;
    final cur = await Clipboard.getData(Clipboard.kTextPlain);
    if (cur == null || cur.text == mine) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  // ───────────────────────── contraseña maestra ─────────────────────────

  Future<bool> changeMaster(String oldPw, String newPw) async {
    if (!await _verifyMaster(oldPw)) return false;
    _salt = VaultCrypto.randomBytes(VaultCrypto.saltLength);
    _iterations = VaultCrypto.kdfIterations;
    _key = await VaultCrypto.deriveKey(newPw, _salt!, _iterations);
    await _save();
    if (biometricsEnabled) {
      final bytes = await _key!.extractBytes();
      await _write(_kBioKey, base64Encode(bytes));
    }
    notifyListeners();
    return true;
  }

  // ───────────────────────── copias de seguridad ─────────────────────────

  String _two(int n) => n.toString().padLeft(2, '0');

  /// Copia el archivo ya cifrado a una carpeta temporal para compartirlo.
  Future<File> exportBackup() async {
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    final name = 'boveda_${d.year}${_two(d.month)}${_two(d.day)}.bvd';
    return _file!.copy('${dir.path}/$name');
  }

  /// Devuelve cuántas entradas se agregaron/actualizaron, o null si la
  /// contraseña es incorrecta o el archivo no es válido.
  Future<int?> importBackup(String path, String backupPassword) async {
    try {
      final doc =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final key = await VaultCrypto.deriveKey(backupPassword,
          base64Decode(doc['salt'] as String), doc['iter'] as int);
      final plain =
          await VaultCrypto.decrypt(base64Decode(doc['data'] as String), key);
      final m = jsonDecode(plain) as Map<String, dynamic>;
      final incoming = (m['entries'] as List)
          .map((e) => Entry.fromJson(e as Map<String, dynamic>))
          .toList();
      var changed = 0;
      for (final e in incoming) {
        final i = entries.indexWhere((x) => x.id == e.id);
        if (i < 0) {
          entries.add(e);
          changed++;
        } else if (e.updatedAt.isAfter(entries[i].updatedAt)) {
          entries[i] = e;
          changed++;
        }
      }
      if (changed > 0) await _save();
      notifyListeners();
      return changed;
    } catch (_) {
      return null;
    }
  }

  /// Borra todo: bóveda, clave biométrica y contadores.
  Future<bool> wipe(String master) async {
    if (!await _verifyMaster(master)) return false;
    try {
      await _file!.delete();
    } catch (_) {}
    try {
      await _secure.deleteAll();
    } catch (_) {}
    _key = null;
    entries = [];
    unlocked = false;
    hasVault = false;
    biometricsEnabled = false;
    _fails = 0;
    lockUntil = null;
    notifyListeners();
    return true;
  }
}
