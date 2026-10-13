import 'dart:io';

import 'package:crypto/crypto.dart';

abstract final class CertificateFingerprint {
  static String fromCertificate(X509Certificate certificate) {
    return fromDer(certificate.der);
  }

  static String fromDer(List<int> derBytes) {
    final bytes = sha256.convert(derBytes).bytes;
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  static String normalize(String fingerprint) {
    if (RegExp(r'[^0-9a-fA-F:\s-]').hasMatch(fingerprint)) {
      throw const FormatException(
        'A SHA-256 certificate fingerprint is required.',
      );
    }
    final compact = fingerprint.replaceAll(RegExp(r'[:\s-]'), '');
    if (compact.length != 64 ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(compact)) {
      throw FormatException('A SHA-256 certificate fingerprint is required.');
    }
    final upper = compact.toUpperCase();
    return List<String>.generate(
      32,
      (index) => upper.substring(index * 2, index * 2 + 2),
    ).join(':');
  }

  static bool matches(String expected, String actual) {
    try {
      return normalize(expected) == normalize(actual);
    } on FormatException {
      return false;
    }
  }
}
