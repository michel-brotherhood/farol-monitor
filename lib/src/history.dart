import 'dart:convert';
import 'dart:io';

import 'models.dart';

class HistoryStore {
  HistoryStore(this.file);
  final File file;

  Future<void> append(ProbeRun run) async {
    await file.parent.create(recursive: true);
    await file.writeAsString('${run.toJsonLine()}\n', mode: FileMode.append, flush: true);
  }

  Future<List<Map<String, dynamic>>> readRuns({int limit = 20}) async {
    if (!await file.exists()) return const [];
    final lines = await file.readAsLines();
    final runs = <Map<String, dynamic>>[];
    for (final line in lines.reversed) {
      if (line.trim().isEmpty) continue;
      try {
        final value = jsonDecode(line);
        if (value is Map<String, dynamic>) runs.add(value);
      } on FormatException {
        // Uma linha incompleta por interrupção não invalida o restante do histórico.
      }
      if (runs.length >= limit) break;
    }
    return runs;
  }
}
