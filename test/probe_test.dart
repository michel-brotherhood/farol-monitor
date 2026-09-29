import 'dart:io';

import 'package:farol_cli/farol.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _activeServer = server;
    server.listen((request) {
      switch (request.uri.path) {
        case '/ready':
          request.response
            ..statusCode = HttpStatus.ok
            ..write('service ready');
          break;
        case '/missing':
          request.response
            ..statusCode = HttpStatus.serviceUnavailable
            ..write('maintenance');
          break;
        default:
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('not found');
          break;
      }
      request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    _activeServer = null;
  });

  test('retorna saudável quando status e conteúdo correspondem', () async {
    final target = _target('/ready', contains: 'ready');
    final result = await const HttpProbe().run(target);

    expect(result.status, HealthStatus.healthy);
    expect(result.statusCode, HttpStatus.ok);
    expect(result.contentMatched, isTrue);
    expect(result.latencyMs, greaterThanOrEqualTo(0));
  });

  test('marca indisponível quando o status esperado não corresponde', () async {
    final result = await const HttpProbe().run(_target('/missing'));

    expect(result.status, HealthStatus.down);
    expect(result.statusCode, HttpStatus.serviceUnavailable);
    expect(result.expectedStatus, isFalse);
  });

  test('marca indisponível quando o conteúdo esperado não aparece', () async {
    final result = await const HttpProbe().run(_target('/ready', contains: 'database connected'));

    expect(result.status, HealthStatus.down);
    expect(result.contentMatched, isFalse);
  });
}

ProbeTarget _target(String path, {String? contains}) => ProbeTarget(
      name: path,
      uri: Uri(scheme: 'http', host: '127.0.0.1', port: serverPort, path: path),
      method: 'GET',
      expectedStatuses: const {HttpStatus.ok},
      timeoutMs: 2000,
      maxBodyBytes: 4096,
      contains: contains,
    );

int get serverPort => _activeServer!.port;
HttpServer? _activeServer;
