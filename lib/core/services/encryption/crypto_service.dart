import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

/// Custom wrapper to bridge Dart's secure random OS generator with PointyCastle's SecureRandom interface.
class DartSecureRandom implements SecureRandom {
  final Random _random;

  DartSecureRandom(this._random);

  @override
  String get algorithmName => 'DartSecureRandom';

  @override
  void seed(CipherParameters params) {
    // OS-level secure random is already seeded.
  }

  @override
  int nextUint8() => _random.nextInt(256);

  @override
  int nextUint16() => _random.nextInt(65536);

  @override
  int nextUint32() => _random.nextInt(4294967296);

  @override
  BigInt nextBigInteger(int bitLength) {
    final numBytes = (bitLength + 7) ~/ 8;
    final bytes = nextBytes(numBytes);
    final excessBits = (numBytes * 8) - bitLength;
    if (excessBits > 0) {
      bytes[0] &= (0xFF >> excessBits);
    }
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  @override
  Uint8List nextBytes(int count) {
    final bytes = Uint8List(count);
    for (var i = 0; i < count; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}

/// Cryptography service offering End-to-End Encryption features using PointyCastle.
class CryptoService {
  static final ECDomainParameters _domain = ECCurve_secp256r1();

  /// Generates a new EC (secp256r1) private/public key pair.
  static AsymmetricKeyPair<ECPublicKey, ECPrivateKey> generateKeyPair() {
    final secureRandom = DartSecureRandom(Random.secure());
    final keyGen = ECKeyGenerator();
    final ecParams = ECKeyGeneratorParameters(_domain);
    keyGen.init(ParametersWithRandom(ecParams, secureRandom));
    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<ECPublicKey, ECPrivateKey>(
      pair.publicKey as ECPublicKey,
      pair.privateKey as ECPrivateKey,
    );
  }

  /// Encodes an EC public key to base64.
  static String encodePublicKey(ECPublicKey key) {
    final bytes = key.Q!.getEncoded(false); // Uncompressed format
    return base64Encode(bytes);
  }

  /// Decodes an EC public key from base64.
  static ECPublicKey decodePublicKey(String base64Key) {
    final bytes = base64Decode(base64Key);
    final point = _domain.curve.decodePoint(bytes);
    return ECPublicKey(point, _domain);
  }

  /// Encodes an EC private key to base64.
  static String encodePrivateKey(ECPrivateKey key) {
    final bytes = _bigIntToBytes(key.d!, 32);
    return base64Encode(bytes);
  }

  /// Decodes an EC private key from base64.
  static ECPrivateKey decodePrivateKey(String base64Key) {
    final bytes = base64Decode(base64Key);
    final d = _bytesToBigInt(bytes);
    return ECPrivateKey(d, _domain);
  }

  /// Derives an ECDH shared secret key from own private key and peer's public key.
  static Uint8List deriveSharedSecret(ECPrivateKey privateKey, ECPublicKey publicKey) {
    final agreement = ECDHBasicAgreement();
    agreement.init(privateKey);
    final secretBigInt = agreement.calculateAgreement(publicKey);
    
    // Hash the shared secret with SHA-256 to produce a uniform 256-bit key
    final digest = SHA256Digest();
    final secretBytes = _bigIntToBytes(secretBigInt, 32);
    return digest.process(secretBytes);
  }

  /// Encrypts plaintext using AES-256-GCM.
  static Uint8List encryptAesGcm(Uint8List plaintext, Uint8List key, Uint8List iv) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));
    cipher.init(true, params);
    return cipher.process(plaintext);
  }

  /// Decrypts ciphertext using AES-256-GCM.
  static Uint8List decryptAesGcm(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));
    cipher.init(false, params);
    return cipher.process(ciphertext);
  }

  /// Signs a message using SHA-256/ECDSA.
  static Uint8List sign(Uint8List message, ECPrivateKey privateKey) {
    final signer = Signer('SHA-256/ECDSA');
    final secureRandom = DartSecureRandom(Random.secure());
    signer.init(true, ParametersWithRandom(PrivateKeyParameter(privateKey), secureRandom));
    final sig = signer.generateSignature(message) as ECSignature;
    
    final rBytes = _bigIntToBytes(sig.r, 32);
    final sBytes = _bigIntToBytes(sig.s, 32);
    final out = Uint8List(64);
    out.setRange(0, 32, rBytes);
    out.setRange(32, 64, sBytes);
    return out;
  }

  /// Verifies a signature using SHA-256/ECDSA.
  static bool verify(Uint8List message, Uint8List signature, ECPublicKey publicKey) {
    if (signature.length != 64) return false;
    final r = _bytesToBigInt(signature.sublist(0, 32));
    final s = _bytesToBigInt(signature.sublist(32, 64));
    final sig = ECSignature(r, s);

    final signer = Signer('SHA-256/ECDSA');
    signer.init(false, PublicKeyParameter(publicKey));
    try {
      return signer.verifySignature(message, sig);
    } catch (_) {
      return false;
    }
  }

  // --- Helper Methods ---

  static Uint8List _bigIntToBytes(BigInt number, int outLength) {
    var hex = number.toRadixString(16);
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    if (bytes.length == outLength) {
      return bytes;
    }
    final result = Uint8List(outLength);
    if (bytes.length < outLength) {
      result.setRange(outLength - bytes.length, outLength, bytes);
    } else {
      result.setRange(0, outLength, bytes.sublist(bytes.length - outLength));
    }
    return result;
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }
}
