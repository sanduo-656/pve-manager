sealed class PveException implements Exception {
  const PveException(
    this.message, {
    this.statusCode,
    this.code,
    this.operationMayHaveSucceeded = false,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final bool operationMayHaveSucceeded;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

final class PveApiException extends PveException {
  const PveApiException(
    super.message, {
    super.statusCode,
    super.code,
    super.operationMayHaveSucceeded,
    super.cause,
  });
}

final class PveProtocolException extends PveException {
  const PveProtocolException(super.message, {super.cause});
}

final class PveAuthenticationException extends PveException {
  const PveAuthenticationException(
    super.message, {
    super.statusCode,
    super.code,
    super.cause,
  });
}

final class PvePermissionException extends PveException {
  const PvePermissionException(
    super.message, {
    super.statusCode,
    super.code,
    super.cause,
  });
}

final class PveNetworkException extends PveException {
  const PveNetworkException(
    super.message, {
    super.operationMayHaveSucceeded,
    super.cause,
  });
}

final class PveTimeoutException extends PveException {
  const PveTimeoutException(
    super.message, {
    super.operationMayHaveSucceeded,
    super.cause,
  });
}

final class PveStorageException extends PveException {
  const PveStorageException(super.message, {super.cause});
}

final class PveTotpRequiredException extends PveException {
  const PveTotpRequiredException({
    required this.connectionId,
    required this.username,
    required this.challenge,
    required this.availableMethods,
  }) : super('A TOTP code is required.');

  final String connectionId;
  final String username;
  final String challenge;
  final Set<String> availableMethods;
}

final class PveUnsupportedSecondFactorException extends PveException {
  const PveUnsupportedSecondFactorException({required this.availableMethods})
    : super('The available second-factor methods are not supported.');

  final Set<String> availableMethods;
}

sealed class PveCertificateException extends PveException {
  const PveCertificateException(
    super.message, {
    required this.host,
    required this.port,
    required this.actualFingerprint,
    super.cause,
  });

  final String host;
  final int port;
  final String actualFingerprint;
}

final class PveUntrustedCertificateException extends PveCertificateException {
  const PveUntrustedCertificateException({
    required super.host,
    required super.port,
    required super.actualFingerprint,
    super.cause,
  }) : super('The server certificate is not trusted by the system.');
}

final class PveCertificateMismatchException extends PveCertificateException {
  const PveCertificateMismatchException({
    required super.host,
    required super.port,
    required this.expectedFingerprint,
    required super.actualFingerprint,
    super.cause,
  }) : super('The server certificate does not match the stored fingerprint.');

  final String expectedFingerprint;
}
