import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/core/services/encryption/crypto_service.dart';

void main() {
  group('Cryptography Tests', () {
    test('EC Keypair generation and serialization', () {
      final keys = CryptoService.generateKeyPair();
      expect(keys.publicKey, isNotNull);
      expect(keys.privateKey, isNotNull);

      // Verify serialization and deserialization of public key
      final pubEncoded = CryptoService.encodePublicKey(keys.publicKey);
      final pubDecoded = CryptoService.decodePublicKey(pubEncoded);
      expect(CryptoService.encodePublicKey(pubDecoded), equals(pubEncoded));

      // Verify serialization and deserialization of private key
      final privEncoded = CryptoService.encodePrivateKey(keys.privateKey);
      final privDecoded = CryptoService.decodePrivateKey(privEncoded);
      expect(CryptoService.encodePrivateKey(privDecoded), equals(privEncoded));
    });

    test('ECDH Shared Secret Derivation', () {
      final alice = CryptoService.generateKeyPair();
      final bob = CryptoService.generateKeyPair();

      // Alice derives secret using Bob's public key
      final aliceSecret = CryptoService.deriveSharedSecret(alice.privateKey, bob.publicKey);

      // Bob derives secret using Alice's public key
      final bobSecret = CryptoService.deriveSharedSecret(bob.privateKey, alice.publicKey);

      expect(aliceSecret.length, equals(32)); // 256 bits
      expect(bobSecret.length, equals(32)); // 256 bits
      expect(aliceSecret, equals(bobSecret)); // Secrets must match!
    });

    test('AES-256-GCM Encryption and Decryption', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i)); // 256-bit key
      final iv = Uint8List.fromList(List.generate(12, (i) => i + 10)); // 96-bit IV
      final plaintext = Uint8List.fromList(utf8.encode('Hello, Bluetooth Mesh Network!'));

      final ciphertext = CryptoService.encryptAesGcm(plaintext, key, iv);
      expect(ciphertext, isNot(equals(plaintext)));
      expect(ciphertext.length, equals(plaintext.length + 16)); // ciphertext + 16-byte MAC tag

      final decrypted = CryptoService.decryptAesGcm(ciphertext, key, iv);
      expect(utf8.decode(decrypted), equals('Hello, Bluetooth Mesh Network!'));
    });

    test('ECDSA Signature Generation and Verification', () {
      final keys = CryptoService.generateKeyPair();
      final message = Uint8List.fromList(utf8.encode('Mesh packet payload authenticity check.'));

      final signature = CryptoService.sign(message, keys.privateKey);
      expect(signature.length, equals(64)); // 32 bytes for R, 32 bytes for S

      final isValid = CryptoService.verify(message, signature, keys.publicKey);
      expect(isValid, isTrue);

      // Verify tampering failure
      final tamperedMessage = Uint8List.fromList(utf8.encode('Mesh packet payload authenticity check!'));
      final isTamperedValid = CryptoService.verify(tamperedMessage, signature, keys.publicKey);
      expect(isTamperedValid, isFalse);
    });
  });
}
