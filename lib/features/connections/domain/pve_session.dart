class PveSession {
  const PveSession({
    required this.connectionId,
    required this.username,
    required this.ticket,
    required this.csrfPreventionToken,
    required this.issuedAt,
    required this.expiresAt,
  });

  final String connectionId;
  final String username;
  final String ticket;
  final String csrfPreventionToken;
  final DateTime issuedAt;
  final DateTime expiresAt;

  bool isExpired([DateTime? at]) => !(at ?? DateTime.now()).isBefore(expiresAt);

  bool shouldRenew([
    DateTime? at,
    Duration renewAfter = const Duration(minutes: 90),
  ]) {
    return !(at ?? DateTime.now()).isBefore(issuedAt.add(renewAfter));
  }

  PveSession copyWith({
    String? connectionId,
    String? username,
    String? ticket,
    String? csrfPreventionToken,
    DateTime? issuedAt,
    DateTime? expiresAt,
  }) {
    return PveSession(
      connectionId: connectionId ?? this.connectionId,
      username: username ?? this.username,
      ticket: ticket ?? this.ticket,
      csrfPreventionToken: csrfPreventionToken ?? this.csrfPreventionToken,
      issuedAt: issuedAt ?? this.issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
