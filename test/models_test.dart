import 'package:farol_cli/farol.dart';
import 'package:test/test.dart';

void main() {
  test('classifica uma resposta funcional acima do limite como lenta', () {
    final result = ProbeResult(
      targetName: 'API',
      host: 'api.example.test',
      checkedAt: DateTime.utc(2026, 9, 29),
      latencyMs: 1510,
      statusCode: 200,
      expectedStatus: true,
      contentMatched: null,
      maxLatencyMs: 1500,
    );

    expect(result.status, HealthStatus.degraded);
  });

  test('não classifica como saudável uma resposta com status inesperado', () {
    final result = ProbeResult(
      targetName: 'API',
      host: 'api.example.test',
      checkedAt: DateTime.utc(2026, 9, 29),
      latencyMs: 20,
      statusCode: 503,
      expectedStatus: false,
      contentMatched: null,
      maxLatencyMs: 1500,
    );

    expect(result.status, HealthStatus.down);
  });
}
