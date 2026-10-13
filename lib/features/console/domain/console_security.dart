import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const String qemuConsoleType = 'qemu';
const String lxcConsoleType = 'lxc';

/// Parses an origin used by both the REST client and the embedded console.
///
/// Console cookies must never be written for clear-text, credential-bearing,
/// or path-scoped URLs.
Uri parseConsoleOrigin(String value) {
  final Uri? parsed = Uri.tryParse(value.trim());
  if (parsed == null ||
      parsed.scheme.toLowerCase() != 'https' ||
      parsed.host.isEmpty ||
      (parsed.hasPort && (parsed.port < 1 || parsed.port > 65535)) ||
      parsed.userInfo.isNotEmpty ||
      parsed.hasQuery ||
      parsed.hasFragment ||
      (parsed.path.isNotEmpty && parsed.path != '/')) {
    throw const FormatException('PVE origin must be an HTTPS origin.');
  }

  return Uri(
    scheme: 'https',
    host: parsed.host,
    port: parsed.hasPort ? parsed.port : null,
  );
}

Uri buildConsoleUri({
  required String origin,
  required String consoleType,
  required String node,
  required int vmid,
}) {
  final Uri base = parseConsoleOrigin(origin);
  final String normalizedType = consoleType.trim().toLowerCase();

  if (node.trim().isEmpty) {
    throw const FormatException('PVE node is required.');
  }
  if (vmid <= 0) {
    throw const FormatException('VMID must be a positive integer.');
  }

  final Map<String, String> query = <String, String>{
    'console': switch (normalizedType) {
      qemuConsoleType => 'kvm',
      lxcConsoleType => 'lxc',
      _ => throw const FormatException('Unsupported PVE console type.'),
    },
    if (normalizedType == qemuConsoleType) 'novnc': '1',
    if (normalizedType == qemuConsoleType) 'resize': 'scale',
    if (normalizedType == lxcConsoleType) 'xtermjs': '1',
    'node': node.trim(),
    'vmid': vmid.toString(),
  };

  return base.replace(path: '/', queryParameters: query);
}

bool hasSameHttpsOrigin(Uri candidate, Uri allowedOrigin) {
  return candidate.scheme.toLowerCase() == 'https' &&
      candidate.userInfo.isEmpty &&
      candidate.host.toLowerCase() == allowedOrigin.host.toLowerCase() &&
      candidate.port == allowedOrigin.port;
}

String? normalizeSha256Pin(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  final String normalized = value
      .replaceAll(RegExp(r'[\s:]'), '')
      .toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw const FormatException(
      'Certificate pin must be a 64-character SHA-256 hex fingerprint.',
    );
  }
  return normalized;
}

String derSha256Fingerprint(Uint8List certificateDer) {
  return sha256.convert(certificateDer).toString();
}

bool certificateMatchesPin(Uint8List? certificateDer, String? pinnedSha256) {
  final String? expected = normalizeSha256Pin(pinnedSha256);
  if (certificateDer == null || certificateDer.isEmpty || expected == null) {
    return false;
  }

  final String actual = derSha256Fingerprint(certificateDer);
  int difference = 0;
  for (int index = 0; index < actual.length; index += 1) {
    difference |= actual.codeUnitAt(index) ^ expected.codeUnitAt(index);
  }
  return difference == 0;
}

class ConsoleCertificatePinException implements Exception {
  const ConsoleCertificatePinException({
    required this.expectedFingerprint,
    this.actualFingerprint,
    this.cause,
  });

  final String expectedFingerprint;
  final String? actualFingerprint;
  final Object? cause;

  @override
  String toString() => 'The PVE console certificate pin did not match.';
}

/// Performs a credential-free TLS handshake before a pinned WebView is used.
///
/// Android only invokes WebView's SSL callback for certificate errors. A
/// different, system-trusted certificate would otherwise bypass an existing
/// pin, so pinned console sessions also verify the leaf certificate here.
Future<void> verifyPinnedConsoleCertificate({
  required Uri origin,
  required String? pinnedSha256,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final expected = normalizeSha256Pin(pinnedSha256);
  if (expected == null) return;

  String? actual;
  final context = SecurityContext(withTrustedRoots: false);
  final client = HttpClient(context: context)
    ..connectionTimeout = timeout
    ..badCertificateCallback = (certificate, host, port) {
      actual = derSha256Fingerprint(Uint8List.fromList(certificate.der));
      return host.toLowerCase() == origin.host.toLowerCase() &&
          port == origin.port &&
          certificateMatchesPin(Uint8List.fromList(certificate.der), expected);
    };

  try {
    final request = await client
        .getUrl(origin.replace(path: '/api2/json/version'))
        .timeout(timeout);
    request.followRedirects = false;
    final response = await request.close().timeout(timeout);
    await response.drain<void>().timeout(timeout);
  } on Object catch (error) {
    throw ConsoleCertificatePinException(
      expectedFingerprint: expected,
      actualFingerprint: actual,
      cause: error,
    );
  } finally {
    client.close(force: true);
  }
}
