import 'package:farol_cli/farol.dart';
import 'package:test/test.dart';

void main() {
  group('MonitorConfig', () {
    test('aplica padrões e interpreta uma configuração válida', () {
      final config = MonitorConfig.fromJson({
        'version': 1,
        'targets': [
          {
            'name': 'API pública',
            'url': 'https://example.com/health',
            'expectedStatus': [200, 204],
          },
        ],
      });

      expect(config.targets, hasLength(1));
      expect(config.targets.single.timeoutMs, 5000);
      expect(config.targets.single.expectedStatuses, {200, 204});
      expect(config.concurrency, 8);
    });

    test('rejeita esquema inseguro ou inválido', () {
      expect(
        () => MonitorConfig.fromJson({
          'version': 1,
          'targets': [
            {'name': 'Local', 'url': 'file:///etc/passwd'},
          ],
        }),
        throwsA(isA<ConfigException>()),
      );
    });

    test('rejeita nomes repetidos para evitar resultados ambíguos', () {
      expect(
        () => MonitorConfig.fromJson({
          'version': 1,
          'targets': [
            {'name': 'API', 'url': 'https://one.example'},
            {'name': 'api', 'url': 'https://two.example'},
          ],
        }),
        throwsA(isA<ConfigException>()),
      );
    });

    test('rejeita credenciais embutidas na URL', () {
      expect(
        () => MonitorConfig.fromJson({
          'version': 1,
          'targets': [
            {'name': 'Privado', 'url': 'https://user:secret@example.com'},
          ],
        }),
        throwsA(isA<ConfigException>()),
      );
    });

    test('rejeita expectativa de corpo com método HEAD', () {
      expect(
        () => MonitorConfig.fromJson({
          'version': 1,
          'targets': [
            {
              'name': 'HEAD',
              'url': 'https://example.com',
              'method': 'HEAD',
              'contains': 'ready',
            },
          ],
        }),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
