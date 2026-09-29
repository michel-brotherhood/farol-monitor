import 'dart:convert';
import 'dart:io';

enum HealthStatus { healthy, degraded, down }

class ProbeTarget {
  const ProbeTarget({
    required this.name,
    required this.uri,
    required this.method,
    required this.expectedStatuses,
    required this.timeoutMs,
    required this.maxBodyBytes,
    this.maxLatencyMs,
    this.contains,
  });

  final String name;
  final Uri uri;
  final String method;
  final Set<int> expectedStatuses;
  final int timeoutMs;
  final int maxBodyBytes;
  final int? maxLatencyMs;
  final String? contains;

  String get host => uri.host;
}

class ProbeResult {
  const ProbeResult({
    required this.targetName,
    required this.host,
    required this.checkedAt,
    required this.latencyMs,
    required this.statusCode,
    required this.expectedStatus,
    required this.contentMatched,
    required this.maxLatencyMs,
    this.error,
  });

  final String targetName;
  final String host;
  final DateTime checkedAt;
  final int latencyMs;
  final int? statusCode;
  final bool expectedStatus;
  final bool? contentMatched;
  final int? maxLatencyMs;
  final String? error;

  HealthStatus get status {
    if (error != null || !expectedStatus || contentMatched == false) {
      return HealthStatus.down;
    }
    if (maxLatencyMs != null && latencyMs > maxLatencyMs!) {
      return HealthStatus.degraded;
    }
    return HealthStatus.healthy;
  }

  Map<String, Object?> toJson() => {
        'name': targetName,
        'host': host,
        'checkedAt': checkedAt.toUtc().toIso8601String(),
        'status': status.name,
        'latencyMs': latencyMs,
        'statusCode': statusCode,
        'expectedStatus': expectedStatus,
        'contentMatched': contentMatched,
        'maxLatencyMs': maxLatencyMs,
        'error': error,
      };

  factory ProbeResult.fromJson(Map<String, dynamic> json) {
    return ProbeResult(
      targetName: json['name'] as String,
      host: json['host'] as String,
      checkedAt: DateTime.parse(json['checkedAt'] as String),
      latencyMs: json['latencyMs'] as int,
      statusCode: json['statusCode'] as int?,
      expectedStatus: json['expectedStatus'] as bool? ?? false,
      contentMatched: json['contentMatched'] as bool?,
      maxLatencyMs: json['maxLatencyMs'] as int?,
      error: json['error'] as String?,
    );
  }
}

class ProbeRun {
  const ProbeRun({required this.startedAt, required this.results});

  final DateTime startedAt;
  final List<ProbeResult> results;

  bool get isHealthy => results.every((result) => result.status == HealthStatus.healthy);

  Map<String, Object?> toJson() => {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'summary': {
          'total': results.length,
          'healthy': results.where((r) => r.status == HealthStatus.healthy).length,
          'degraded': results.where((r) => r.status == HealthStatus.degraded).length,
          'down': results.where((r) => r.status == HealthStatus.down).length,
        },
        'results': results.map((result) => result.toJson()).toList(),
      };

  String toJsonLine() => jsonEncode(toJson());
}

String statusLabel(HealthStatus status) => switch (status) {
      HealthStatus.healthy => 'OK',
      HealthStatus.degraded => 'LENTO',
      HealthStatus.down => 'INDISPONÍVEL',
    };

String statusIcon(HealthStatus status) => switch (status) {
      HealthStatus.healthy => '✓',
      HealthStatus.degraded => '!',
      HealthStatus.down => '×',
    };

String errorLabel(Object error) => switch (error) {
      SocketException() => 'Falha de conexão',
      HandshakeException() => 'Falha na negociação TLS',
      HttpException() => 'Falha na resposta HTTP',
      FormatException() => 'Resposta inválida',
      _ => 'Falha ${error.runtimeType}',
    };
