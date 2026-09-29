import 'dart:convert';
import 'dart:io';

import 'package:farol_cli/farol.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('farol-test-');
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('grava histórico local sem URL completa, cabeçalhos ou corpo', () async {
    final store = HistoryStore(File('${temporaryDirectory.path}/history.jsonl'));
    final run = ProbeRun(
      startedAt: DateTime.utc(2026, 9, 29),
      results: [
        ProbeResult(
          targetName: 'API de teste',
          host: 'api.example.test',
          checkedAt: DateTime.utc(2026, 9, 29),
          latencyMs: 42,
          statusCode: HttpStatus.ok,
          expectedStatus: true,
          contentMatched: true,
          maxLatencyMs: 1000,
        ),
      ],
    );

    await store.append(run);
    final contents = await store.file.readAsString();
    final decoded = jsonDecode(contents) as Map<String, dynamic>;
    final result = (decoded['results'] as List<dynamic>).single as Map<String, dynamic>;

    expect(contents, isNot(contains('token=')));
    expect(contents, isNot(contains('response body')));
    expect(result.keys, containsAll(['name', 'host', 'status', 'latencyMs']));
    expect(result.keys, isNot(contains('url')));
    expect(result.keys, isNot(contains('headers')));
    expect(result.keys, isNot(contains('body')));
  });

  test('ignora uma última linha JSON incompleta sem perder execuções válidas', () async {
    final file = File('${temporaryDirectory.path}/history.jsonl');
    final store = HistoryStore(file);
    final run = ProbeRun(startedAt: DateTime.utc(2026, 9, 29), results: const []);
    await store.append(run);
    await file.writeAsString('{incomplete', mode: FileMode.append);

    final records = await store.readRuns();

    expect(records, hasLength(1));
    expect(records.single['startedAt'], '2026-09-29T00:00:00.000Z');
  });
}
