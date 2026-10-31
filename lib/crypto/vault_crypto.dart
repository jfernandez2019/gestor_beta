import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Cifrado de la bóveda: PBKDF2-HMAC-SHA256 para derivar la clave
/// y AES-256-GCM (cifrado autenticado) para los datos.
class VaultCrypto {
  static const int kdfIterations = 310000;
  static const int saltLength = 16;
  static final AesGcm _aes = AesGcm.with256bits();

  static Uint8List randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  static Future<SecretKey> deriveKey(
      String password, List<int> salt, int iterations) {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return kdf.deriveKeyFromPassword(password: password, nonce: salt);
  }

  /// Devuelve nonce(12) + datos cifrados + mac(16).
  static Future<Uint8List> encrypt(String plain, SecretKey key) async {
    final box = await _aes.encrypt(utf8.encode(plain), secretKey: key);
    return Uint8List.fromList(box.concatenation());
  }

  /// Lanza excepción si la clave es incorrecta o el archivo fue alterado.
  static Future<String> decrypt(List<int> data, SecretKey key) async {
    final box =
        SecretBox.fromConcatenation(data, nonceLength: 12, macLength: 16);
    final clear = await _aes.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  }
}
