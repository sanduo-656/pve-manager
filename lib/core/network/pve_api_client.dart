import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../features/connections/domain/connection_profile.dart';
import '../../features/connections/domain/pve_session.dart';
import '../../features/nodes/domain/pve_node.dart';
import '../../features/nodes/domain/pve_node_metrics.dart';
import '../../features/resources/domain/pve_permissions.dart';
import '../../features/resources/domain/pve_resource.dart';
import '../../features/resources/domain/pve_task.dart';
import '../errors/pve_exception.dart';
import 'certificate_fingerprint.dart';

class PveApiClient {
  PveApiClient({
    required this.profile,
    String? pinnedCertificateFingerprint,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 20),
    this.taskPollInterval = const Duration(seconds: 1),
    this.taskPollTimeout = const Duration(minutes: 2),
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : pinnedCertificateFingerprint = pinnedCertificateFingerprint == null
           ? null
           : CertificateFingerprint.normalize(pinnedCertificateFingerprint),
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed,
       _ownsClient = client == null {
    _client = client ?? _createIoClient();
  }

  final ConnectionProfile profile;
  final String? pinnedCertificateFingerprint;
  final Duration requestTimeout;
  final Duration taskPollInterval;
  final Duration taskPollTimeout;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;
  final bool _ownsClient;

  late final http.Client _client;
  String? _lastRejectedFingerprint;

  Future<PveSession> login({required String password}) async {
    final data = await postData(
      '/access/ticket',
      form: <String, String>{
        'username': profile.userId,
        'password': password,
        'new-format': '1',
      },
    );
    return _sessionFromTicketData(data, allowChallenge: true);
  }

  Future<PveSession> completeTotp({
    required String challenge,
    required String code,
  }) async {
    if (!RegExp(r'^\d{2,16}$').hasMatch(code)) {
      throw const PveAuthenticationException(
        'The TOTP code must contain 2 to 16 digits.',
      );
    }
    final data = await postData(
      '/access/ticket',
      form: <String, String>{
        'username': profile.userId,
        'password': 'totp:$code',
        'tfa-challenge': challenge,
        'new-format': '1',
      },
    );
    return _sessionFromTicketData(data, allowChallenge: false);
  }

  Future<PveSession> renewSession(PveSession session) async {
    _requireSessionConnection(session);
    final data = await postData(
      '/access/ticket',
      form: <String, String>{
        'username': session.username,
        'password': session.ticket,
        'new-format': '1',
      },
    );
    return _sessionFromTicketData(data, allowChallenge: false);
  }

  Future<Map<String, Object?>> fetchVersion(PveSession session) async {
    final data = await getData('/version', session: session);
    return _objectMap(data, endpoint: '/version');
  }

  Future<List<PveResource>> fetchResources(PveSession session) async {
    final data = await getData(
      '/cluster/resources',
      session: session,
      queryParameters: const <String, String>{'type': 'vm'},
    );
    return _objectList(data, endpoint: '/cluster/resources')
        .where((item) => item['type'] == 'qemu' || item['type'] == 'lxc')
        .map(
          (item) =>
              PveResource.fromClusterJson(connectionId: profile.id, json: item),
        )
        .toList(growable: false);
  }

  Future<List<PveNode>> fetchNodes(PveSession session) async {
    final data = await getData(
      '/cluster/resources',
      session: session,
      queryParameters: const <String, String>{'type': 'node'},
    );
    return _objectList(data, endpoint: '/cluster/resources')
        .where((item) => item['type'] == null || item['type'] == 'node')
        .map(
          (item) =>
              PveNode.fromClusterJson(connectionId: profile.id, json: item),
        )
        .toList(growable: false);
  }

  Future<PvePermissions> fetchPermissions(PveSession session) async {
    final data = await getData('/access/permissions', session: session);
    return PvePermissions.fromApiJson(
      connectionId: profile.id,
      json: _objectMap(data, endpoint: '/access/permissions'),
    );
  }

  Future<PveNodeMetricsSnapshot> fetchNodeMetrics(
    PveSession session, {
    required String node,
  }) async {
    _requireSessionConnection(session);
    final data = await _getSegments(<String>[
      'nodes',
      node,
      'status',
    ], session: session);
    return PveNodeMetricsSnapshot.fromJson(
      _objectMap(data, endpoint: '/nodes/{node}/status'),
    );
  }

  Future<List<PveNodeRrdPoint>> fetchNodeHistory(
    PveSession session, {
    required String node,
    required PveNodeTimeframe timeframe,
  }) async {
    _requireSessionConnection(session);
    final data = await _getSegments(
      <String>['nodes', node, 'rrddata'],
      session: session,
      queryParameters: <String, String>{
        'timeframe': timeframe.name,
        'cf': 'AVERAGE',
      },
    );
    final samples = _objectList(data, endpoint: '/nodes/{node}/rrddata');
    try {
      final points = samples.map(PveNodeRrdPoint.fromJson).toList();
      points.sort((first, second) => first.time.compareTo(second.time));
      return List<PveNodeRrdPoint>.unmodifiable(points);
    } on FormatException catch (error) {
      throw PveProtocolException(
        '/nodes/{node}/rrddata returned an invalid sample.',
        cause: error,
      );
    }
  }

  Future<List<PveStorageStatus>> fetchNodeStorages(
    PveSession session, {
    required String node,
  }) async {
    _requireSessionConnection(session);
    final data = await _getSegments(<String>[
      'nodes',
      node,
      'storage',
    ], session: session);
    final storages = _objectList(data, endpoint: '/nodes/{node}/storage');
    try {
      return List<PveStorageStatus>.unmodifiable(
        storages.map(PveStorageStatus.fromJson),
      );
    } on FormatException catch (error) {
      throw PveProtocolException(
        '/nodes/{node}/storage returned an invalid storage.',
        cause: error,
      );
    }
  }

  Future<PveTask> powerResource(
    PveSession session,
    PveResource resource,
    PveResourceAction action,
  ) async {
    _requireSessionConnection(session);
    if (resource.connectionId != profile.id) {
      throw const PveProtocolException(
        'The resource belongs to a different connection.',
      );
    }

    final data = await _postSegments(
      <String>[
        'nodes',
        resource.node,
        resource.type.name,
        resource.vmId.toString(),
        'status',
        action.name,
      ],
      session: session,
      operationMayHaveSucceeded: true,
    );
    if (data is! String || data.isEmpty) {
      throw const PveProtocolException(
        'The power operation did not return a task identifier.',
      );
    }
    return PveTask.pending(
      connectionId: profile.id,
      node: resource.node,
      upid: data,
    );
  }

  Future<PveTask> getTaskStatus(PveSession session, PveTask task) async {
    _requireSessionConnection(session);
    if (task.connectionId != profile.id) {
      throw const PveProtocolException(
        'The task belongs to a different connection.',
      );
    }
    final data = await _getSegments(<String>[
      'nodes',
      task.node,
      'tasks',
      task.upid,
      'status',
    ], session: session);
    return task.withStatusJson(
      _objectMap(data, endpoint: '/nodes/{node}/tasks/{upid}/status'),
    );
  }

  Future<PveTask> waitForTask(
    PveSession session,
    PveTask task, {
    Duration? timeout,
  }) async {
    final deadline = _now().add(timeout ?? taskPollTimeout);
    var current = task;
    while (!_now().isAfter(deadline)) {
      current = await getTaskStatus(session, current);
      if (current.isComplete) {
        if (!current.succeeded) {
          throw PveApiException(
            'The PVE task failed with ${current.exitStatus ?? 'unknown status'}.',
            code: current.exitStatus,
            operationMayHaveSucceeded: true,
          );
        }
        return current;
      }
      await _delay(taskPollInterval);
    }
    throw const PveTimeoutException(
      'Timed out while waiting for the PVE task to finish.',
      operationMayHaveSucceeded: true,
    );
  }

  Future<void> powerNode(
    PveSession session,
    PveNode node,
    PveNodeAction action,
  ) async {
    _requireSessionConnection(session);
    if (node.connectionId != profile.id) {
      throw const PveProtocolException(
        'The node belongs to a different connection.',
      );
    }
    await _postSegments(
      <String>['nodes', node.name, 'status'],
      session: session,
      form: <String, String>{'command': action.name},
      operationMayHaveSucceeded: true,
    );
  }

  Future<void> waitForNodePowerTransition(
    PveSession session,
    PveNode node,
    PveNodeAction action, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final deadline = _now().add(timeout);
    var observedExplicitOffline = false;

    while (!_now().isAfter(deadline)) {
      try {
        final nodes = await fetchNodes(session);
        final match = nodes.where((item) => item.name == node.name).firstOrNull;
        if (match?.status == PveNodeStatus.offline) {
          observedExplicitOffline = true;
          if (action == PveNodeAction.shutdown) {
            return;
          }
        } else if (action == PveNodeAction.reboot && match?.isOnline == true) {
          final uptimeReset =
              node.uptimeSeconds > 0 &&
              match!.uptimeSeconds + 10 < node.uptimeSeconds;
          if (observedExplicitOffline || uptimeReset) {
            return;
          }
        }
      } on PveNetworkException {
        // Transport loss alone cannot prove that the target node powered off.
      } on PveTimeoutException {
        // A transient timeout must not turn the command into a false success.
      }
      await _delay(taskPollInterval);
    }

    throw const PveTimeoutException(
      'Timed out while observing the node power transition.',
      operationMayHaveSucceeded: true,
    );
  }

  Future<Object?> getData(
    String path, {
    PveSession? session,
    Map<String, String>? queryParameters,
  }) {
    if (session != null) {
      _requireSessionConnection(session);
    }
    return _request(
      'GET',
      _uriFromPath(path, queryParameters: queryParameters),
      session: session,
    );
  }

  Future<Object?> postData(
    String path, {
    PveSession? session,
    Map<String, String> form = const <String, String>{},
    bool operationMayHaveSucceeded = false,
  }) {
    if (session != null) {
      _requireSessionConnection(session);
    }
    return _request(
      'POST',
      _uriFromPath(path),
      session: session,
      form: form,
      operationMayHaveSucceeded: operationMayHaveSucceeded,
    );
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  http.Client _createIoClient() {
    final pin = pinnedCertificateFingerprint;
    final context = pin == null
        ? SecurityContext.defaultContext
        : SecurityContext(withTrustedRoots: false);
    final ioClient = HttpClient(context: context)
      ..connectionTimeout = requestTimeout
      ..idleTimeout = const Duration(seconds: 15);

    ioClient.badCertificateCallback = (certificate, host, port) {
      final fingerprint = CertificateFingerprint.fromCertificate(certificate);
      if (host.toLowerCase() != profile.host.toLowerCase() ||
          port != profile.port ||
          pin == null) {
        _lastRejectedFingerprint = fingerprint;
        return false;
      }
      final matches = CertificateFingerprint.matches(pin, fingerprint);
      if (!matches) {
        _lastRejectedFingerprint = fingerprint;
      }
      return matches;
    };
    return IOClient(ioClient);
  }

  Future<Object?> _getSegments(
    List<String> segments, {
    required PveSession session,
    Map<String, String>? queryParameters,
  }) {
    return _request(
      'GET',
      _uriFromSegments(segments, queryParameters: queryParameters),
      session: session,
    );
  }

  Future<Object?> _postSegments(
    List<String> segments, {
    required PveSession session,
    Map<String, String> form = const <String, String>{},
    bool operationMayHaveSucceeded = false,
  }) {
    return _request(
      'POST',
      _uriFromSegments(segments),
      session: session,
      form: form,
      operationMayHaveSucceeded: operationMayHaveSucceeded,
    );
  }

  Future<Object?> _request(
    String method,
    Uri uri, {
    PveSession? session,
    Map<String, String>? form,
    bool operationMayHaveSucceeded = false,
  }) async {
    _lastRejectedFingerprint = null;
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (session != null) {
      request.headers['Cookie'] = 'PVEAuthCookie=${session.ticket}';
      if (method != 'GET' && method != 'HEAD') {
        request.headers['CSRFPreventionToken'] = session.csrfPreventionToken;
      }
    }
    if (form != null) {
      request.headers['Content-Type'] =
          'application/x-www-form-urlencoded; charset=utf-8';
      request.bodyFields = form;
    }

    try {
      final streamed = await _client.send(request).timeout(requestTimeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(requestTimeout);
      return _decodeResponse(response);
    } on PveException {
      rethrow;
    } on TimeoutException catch (error) {
      throw PveTimeoutException(
        'The request to PVE timed out.',
        operationMayHaveSucceeded: operationMayHaveSucceeded,
        cause: error,
      );
    } catch (error) {
      final fingerprint = _lastRejectedFingerprint;
      if (fingerprint != null) {
        final pin = pinnedCertificateFingerprint;
        if (pin == null) {
          throw PveUntrustedCertificateException(
            host: profile.host,
            port: profile.port,
            actualFingerprint: fingerprint,
            cause: error,
          );
        }
        throw PveCertificateMismatchException(
          host: profile.host,
          port: profile.port,
          expectedFingerprint: pin,
          actualFingerprint: fingerprint,
          cause: error,
        );
      }
      if (error is HandshakeException) {
        throw PveNetworkException(
          'The TLS handshake with PVE failed.',
          operationMayHaveSucceeded: operationMayHaveSucceeded,
          cause: error,
        );
      }
      if (error is SocketException || error is http.ClientException) {
        throw PveNetworkException(
          'PVE is unreachable.',
          operationMayHaveSucceeded: operationMayHaveSucceeded,
          cause: error,
        );
      }
      rethrow;
    }
  }

  Object? _decodeResponse(http.Response response) {
    Object? decoded;
    try {
      decoded = response.bodyBytes.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } catch (error) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw PveProtocolException(
          'PVE returned an invalid JSON response.',
          cause: error,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessage(decoded, response);
      if (response.statusCode == HttpStatus.unauthorized) {
        throw PveAuthenticationException(
          message,
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode == HttpStatus.forbidden) {
        throw PvePermissionException(message, statusCode: response.statusCode);
      }
      throw PveApiException(message, statusCode: response.statusCode);
    }

    if (decoded is! Map || !decoded.containsKey('data')) {
      throw const PveProtocolException(
        'PVE response does not contain a data field.',
      );
    }
    return decoded['data'];
  }

  PveSession _sessionFromTicketData(
    Object? data, {
    required bool allowChallenge,
  }) {
    final map = _objectMap(data, endpoint: '/access/ticket');
    final ticket = map['ticket']?.toString() ?? '';
    if (ticket.isEmpty) {
      throw const PveProtocolException(
        'The login response does not contain a ticket.',
      );
    }

    final challenge = _parseTfaChallenge(ticket);
    if (challenge != null) {
      final methods = _availableTfaMethods(challenge);
      if (allowChallenge && methods.contains('totp')) {
        throw PveTotpRequiredException(
          connectionId: profile.id,
          username: map['username']?.toString() ?? profile.userId,
          challenge: ticket,
          availableMethods: methods,
        );
      }
      throw PveUnsupportedSecondFactorException(
        availableMethods: methods.isEmpty ? const <String>{'unknown'} : methods,
      );
    }
    if (map['NeedTFA'] == 1 || map['NeedTFA'] == true) {
      throw const PveUnsupportedSecondFactorException(
        availableMethods: <String>{'legacy'},
      );
    }

    final csrf = map['CSRFPreventionToken']?.toString() ?? '';
    if (csrf.isEmpty) {
      throw const PveProtocolException(
        'The login response does not contain a CSRF token.',
      );
    }
    final issuedAt = _ticketIssuedAt(ticket) ?? _now();
    return PveSession(
      connectionId: profile.id,
      username: map['username']?.toString() ?? profile.userId,
      ticket: ticket,
      csrfPreventionToken: csrf,
      issuedAt: issuedAt,
      expiresAt: issuedAt.add(const Duration(hours: 2)),
    );
  }

  Map<String, Object?>? _parseTfaChallenge(String ticket) {
    final match = RegExp(r'^[^\s:]+:!tfa!([^:]+):').firstMatch(ticket);
    if (match == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(Uri.decodeComponent(match.group(1)!));
      return _objectMap(decoded, endpoint: 'TFA challenge');
    } catch (error) {
      if (error is PveProtocolException) {
        rethrow;
      }
      throw PveProtocolException('The TFA challenge is invalid.', cause: error);
    }
  }

  Set<String> _availableTfaMethods(Map<String, Object?> challenge) {
    final methods = <String>{};
    if (_truthy(challenge['totp'])) {
      methods.add('totp');
    }
    if (_truthy(challenge['yubico'])) {
      methods.add('yubico');
    }
    final recovery = challenge['recovery'];
    if ((recovery is Iterable && recovery.isNotEmpty) ||
        (recovery is String && recovery.isNotEmpty)) {
      methods.add('recovery');
    }
    if (challenge['u2f'] != null) {
      methods.add('u2f');
    }
    if (challenge['webauthn'] != null) {
      methods.add('webauthn');
    }
    return Set<String>.unmodifiable(methods);
  }

  DateTime? _ticketIssuedAt(String ticket) {
    final match = RegExp(r'^[^:]+:[^:]+:([0-9a-fA-F]+)::').firstMatch(ticket);
    final encoded = match?.group(1);
    if (encoded == null) {
      return null;
    }
    final seconds = int.tryParse(encoded, radix: 16);
    if (seconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  void _requireSessionConnection(PveSession session) {
    if (session.connectionId != profile.id) {
      throw const PveProtocolException(
        'The session belongs to a different connection.',
      );
    }
  }

  Uri _uriFromPath(String path, {Map<String, String>? queryParameters}) {
    if (path.contains('..')) {
      throw ArgumentError.value(
        path,
        'path',
        'Parent path segments are invalid.',
      );
    }
    final segments = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return _uriFromSegments(segments, queryParameters: queryParameters);
  }

  Uri _uriFromSegments(
    List<String> segments, {
    Map<String, String>? queryParameters,
  }) {
    return profile.origin.replace(
      pathSegments: <String>['api2', 'json', ...segments],
      queryParameters: queryParameters?.isEmpty ?? true
          ? null
          : queryParameters,
    );
  }

  static Map<String, Object?> _objectMap(
    Object? value, {
    required String endpoint,
  }) {
    if (value is! Map) {
      throw PveProtocolException('$endpoint did not return an object.');
    }
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static List<Map<String, Object?>> _objectList(
    Object? value, {
    required String endpoint,
  }) {
    if (value is! List) {
      throw PveProtocolException('$endpoint did not return a list.');
    }
    return value
        .map((item) => _objectMap(item, endpoint: endpoint))
        .toList(growable: false);
  }

  static bool _truthy(Object? value) {
    return value == true || value == 1 || value == '1';
  }

  static String _errorMessage(Object? decoded, http.Response response) {
    if (decoded is Map) {
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      final errors = decoded['errors'];
      if (errors is Map && errors.isNotEmpty) {
        return errors.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('; ');
      }
    }
    final reason = response.reasonPhrase;
    return reason == null || reason.isEmpty
        ? 'PVE request failed with HTTP ${response.statusCode}.'
        : reason;
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
