import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

class HttpProbe {
  const HttpProbe({this.userAgent = 'Farol/0.1.0'});

  final String userAgent;

  Future<ProbeResult> run(ProbeTarget target) async {
    final checkedAt = DateTime.now().toUtc();
    final stopwatch = Stopwatch()..start();
    HttpClient? client;
    try {
      final timeout = Duration(milliseconds: target.timeoutMs);
      Duration remaining() {
        final milliseconds = target.timeoutMs - stopwatch.elapsedMilliseconds;
        if (milliseconds <= 0)
          throw TimeoutException('Request deadline exceeded.');
        return Duration(milliseconds: milliseconds);
      }

      client = HttpClient()..connectionTimeout = timeout;
      final request = await client
          .openUrl(target.method, target.uri)
          .timeout(remaining());
      request
        ..followRedirects = true
        ..maxRedirects = 5
        ..headers.set(HttpHeaders.userAgentHeader, userAgent)
        ..headers.set(HttpHeaders.acceptHeader, '*/*');
      final response = await request.close().timeout(remaining());
      final body = target.contains == null
          ? null
          : await _readBody(response, target.maxBodyBytes).timeout(remaining());
      stopwatch.stop();
      final statusExpected = target.expectedStatuses.contains(
        response.statusCode,
      );
      final contentMatched = target.contains == null
          ? null
          : body!.contains(target.contains!);
      return ProbeResult(
        targetName: target.name,
        host: target.host,
        checkedAt: checkedAt,
        latencyMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        expectedStatus: statusExpected,
        contentMatched: contentMatched,
        maxLatencyMs: target.maxLatencyMs,
      );
    } on TimeoutException {
      stopwatch.stop();
      return _failure(
        target,
        checkedAt,
        stopwatch.elapsedMilliseconds,
        'Tempo limite excedido (${target.timeoutMs} ms).',
      );
    } on Exception catch (error) {
      stopwatch.stop();
      return _failure(
        target,
        checkedAt,
        stopwatch.elapsedMilliseconds,
        errorLabel(error),
      );
    } finally {
      client?.close(force: true);
    }
  }

  Future<String> _readBody(HttpClientResponse response, int maxBytes) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      final remaining = maxBytes - bytes.length;
      if (chunk.length > remaining) {
        bytes.addAll(chunk.take(remaining));
        break;
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  ProbeResult _failure(
    ProbeTarget target,
    DateTime checkedAt,
    int latencyMs,
    String message,
  ) => ProbeResult(
    targetName: target.name,
    host: target.host,
    checkedAt: checkedAt,
    latencyMs: latencyMs,
    statusCode: null,
    expectedStatus: false,
    contentMatched: target.contains == null ? null : false,
    maxLatencyMs: target.maxLatencyMs,
    error: message,
  );
}
