import 'dart:async';
import 'dart:io';

import 'config.dart';
import 'history.dart';
import 'models.dart';
import 'report.dart';
import 'runner.dart';

class FarolCli {
  const FarolCli();

  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
      stdout.write(_usage);
      return 0;
    }
    final command = args.first;
    if (!const {'check', 'watch', 'history'}.contains(command)) {
      stderr.writeln('Comando desconhecido: $command\n');
      stderr.write(_usage);
      return 2;
    }

    try {
      final options = _parseOptions(args.skip(1).toList());
      return switch (command) {
        'check' => await _check(options),
        'watch' => await _watch(options),
        'history' => await _history(options),
        _ => 2,
      };
    } on FormatException catch (error) {
      stderr.writeln('Erro: ${error.message}\n');
      stderr.write(_usage);
      return 2;
    } on ConfigException catch (error) {
      stderr.writeln('Configuração inválida: $error');
      return 2;
    } on FileSystemException catch (error) {
      stderr.writeln('Erro de arquivo: ${error.message}');
      return 2;
    }
  }

  Future<int> _check(Map<String, String?> options) async {
    _ensureAllowed(options, const {'config', 'format', 'no-history'});
    final format = options['format'] ?? 'text';
    if (!const {'text', 'json', 'markdown'}.contains(format)) {
      throw const FormatException('--format deve ser text, json ou markdown.');
    }
    final config = _loadConfig(options['config']);
    final run = await const ProbeRunner().run(config);
    stdout.writeln(renderRun(run, format));
    if (!_isEnabled(options, 'no-history')) await _historyStore().append(run);
    return run.isHealthy ? 0 : 1;
  }

  Future<int> _watch(Map<String, String?> options) async {
    _ensureAllowed(options, const {'config', 'interval', 'no-history'});
    final config = _loadConfig(options['config']);
    final intervalSeconds = _parseBounded(
      options['interval'] ?? '30',
      '--interval',
      1,
      86400,
    );
    final previousStates = <String, HealthStatus>{};
    final stop = Completer<void>();
    final signal = ProcessSignal.sigint.watch().listen((_) {
      if (!stop.isCompleted) stop.complete();
    });
    var runNumber = 0;
    stdout.writeln(
      'Farol em monitoramento. Ctrl+C encerra. Intervalo: ${intervalSeconds}s.',
    );
    try {
      while (!stop.isCompleted) {
        runNumber++;
        final run = await const ProbeRunner().run(config);
        if (!_isEnabled(options, 'no-history'))
          await _historyStore().append(run);
        final currentNames = <String>{};
        for (final result in run.results) {
          currentNames.add(result.targetName);
          if (previousStates[result.targetName] != result.status ||
              runNumber == 1) {
            stdout.writeln(
              '${statusIcon(result.status)} ${result.targetName} · ${statusLabel(result.status)} · ${result.latencyMs} ms${result.error == null ? '' : ' · ${result.error}'}',
            );
          }
          previousStates[result.targetName] = result.status;
        }
        previousStates.removeWhere((name, _) => !currentNames.contains(name));
        final down = run.results
            .where((result) => result.status == HealthStatus.down)
            .length;
        final degraded = run.results
            .where((result) => result.status == HealthStatus.degraded)
            .length;
        stdout.writeln(
          'Ciclo $runNumber · ${run.startedAt.toLocal().toIso8601String()} · $down indisponíveis · $degraded lentos',
        );
        if (!stop.isCompleted) {
          await Future.any<void>([
            Future<void>.delayed(Duration(seconds: intervalSeconds)),
            stop.future,
          ]);
        }
      }
    } finally {
      await signal.cancel();
    }
    stdout.writeln('\nMonitoramento encerrado. Histórico local preservado.');
    return 0;
  }

  Future<int> _history(Map<String, String?> options) async {
    _ensureAllowed(options, const {'path', 'limit'});
    final limit = _parseBounded(options['limit'] ?? '20', '--limit', 1, 1000);
    final path = options['path'] ?? '.farol/history.jsonl';
    final runs = await HistoryStore(File(path)).readRuns(limit: limit);
    stdout.writeln(renderHistory(runs));
    return 0;
  }

  MonitorConfig _loadConfig(String? path) {
    final configPath = path ?? 'farol.json';
    return MonitorConfig.fromFile(File(configPath));
  }

  HistoryStore _historyStore() => HistoryStore(File('.farol/history.jsonl'));

  int _parseBounded(String value, String option, int minimum, int maximum) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < minimum || parsed > maximum) {
      throw FormatException(
        '$option deve ser um inteiro entre $minimum e $maximum.',
      );
    }
    return parsed;
  }

  bool _isEnabled(Map<String, String?> options, String option) =>
      options.containsKey(option);

  void _ensureAllowed(Map<String, String?> options, Set<String> allowed) {
    final unknown = options.keys
        .where((key) => !allowed.contains(key))
        .toList();
    if (unknown.isNotEmpty)
      throw FormatException(
        'Opção(ões) não reconhecida(s): ${unknown.map((v) => '--$v').join(', ')}.',
      );
  }

  Map<String, String?> _parseOptions(List<String> args) {
    const aliases = {
      '-c': 'config',
      '-f': 'format',
      '-i': 'interval',
      '-p': 'path',
      '-n': 'limit',
    };
    const valueOptions = {'config', 'format', 'interval', 'path', 'limit'};
    final options = <String, String?>{};
    for (var index = 0; index < args.length; index++) {
      final token = args[index];
      if (token == '--no-history') {
        options['no-history'] = null;
        continue;
      }
      final optionName =
          aliases[token] ??
          (token.startsWith('--') ? token.substring(2) : null);
      if (optionName == null || optionName.isEmpty) {
        throw FormatException('Argumento inesperado: $token.');
      }
      if (!valueOptions.contains(optionName)) {
        throw FormatException('Opção não reconhecida: $token.');
      }
      if (index + 1 >= args.length || args[index + 1].startsWith('-')) {
        throw FormatException('Falta o valor de $token.');
      }
      if (options.containsKey(optionName))
        throw FormatException('$token foi informado mais de uma vez.');
      options[optionName] = args[++index];
    }
    return options;
  }
}

const _usage = '''Farol — monitor local de disponibilidade e latência

Uso:
  farol check   [-c|--config <arquivo>] [-f|--format text|json|markdown] [--no-history]
  farol watch   [-c|--config <arquivo>] [-i|--interval <segundos>] [--no-history]
  farol history [-p|--path <arquivo>] [-n|--limit <quantidade>]

Comandos:
  check    Verifica endpoints uma vez. Código de saída 0 = todos OK, 1 = alerta, 2 = erro.
  watch    Repete as verificações e destaca mudanças de estado. Encerre com Ctrl+C.
  history  Mostra execuções gravadas localmente em .farol/history.jsonl.

Opções:
  -c, --config       Arquivo de configuração JSON (padrão: farol.json)
  -f, --format       Formato de saída do check: text, json ou markdown
  -i, --interval     Intervalo do watch em segundos (padrão: 30)
  -p, --path         Caminho do arquivo de histórico
  -n, --limit        Quantidade de execuções no histórico (padrão: 20)
      --no-history   Não grava a execução no histórico local
  -h, --help         Exibe esta ajuda

Privacidade: Farol não envia telemetria. O histórico local não armazena corpo,
cabeçalhos nem query strings das URLs monitoradas.
''';
