import 'dart:convert';

import 'models.dart';

String renderRun(ProbeRun run, String format) => switch (format) {
  'json' => const JsonEncoder.withIndent('  ').convert(run.toJson()),
  'markdown' => renderMarkdown(run),
  _ => renderText(run),
};

String renderText(ProbeRun run) {
  final lines = <String>[
    'Farol · ${run.startedAt.toLocal().toIso8601String()}',
    '',
  ];
  for (final result in run.results) {
    final code = result.statusCode?.toString() ?? '—';
    final details =
        result.error ??
        (result.contentMatched == false ? 'Texto esperado não encontrado' : '');
    final suffix = details.isEmpty ? '' : ' · $details';
    lines.add(
      '${statusIcon(result.status)}  ${statusLabel(result.status).padRight(13)} ${result.targetName} · ${result.host} · HTTP $code · ${result.latencyMs} ms$suffix',
    );
  }
  final healthy = run.results
      .where((r) => r.status == HealthStatus.healthy)
      .length;
  final degraded = run.results
      .where((r) => r.status == HealthStatus.degraded)
      .length;
  final down = run.results.where((r) => r.status == HealthStatus.down).length;
  lines.add('');
  lines.add('Resumo: $healthy OK · $degraded lentos · $down indisponíveis');
  return lines.join('\n');
}

String renderMarkdown(ProbeRun run) {
  final lines = <String>[
    '# Relatório Farol',
    '',
    'Verificação: ${run.startedAt.toUtc().toIso8601String()}',
    '',
    '| Endpoint | Host | Estado | HTTP | Latência |',
    '|---|---|---:|---:|---:|',
  ];
  for (final result in run.results) {
    final code = result.statusCode?.toString() ?? '—';
    lines.add(
      '| ${_escapeCell(result.targetName)} | ${_escapeCell(result.host)} | ${statusLabel(result.status)} | $code | ${result.latencyMs} ms |',
    );
  }
  final down = run.results
      .where((r) => r.status != HealthStatus.healthy)
      .length;
  lines.add('');
  lines.add('Endpoints com alerta: $down de ${run.results.length}.');
  lines.add('');
  lines.add(
    'Privacidade: o relatório não inclui corpo, cabeçalhos ou query string das URLs.',
  );
  return lines.join('\n');
}

String renderHistory(List<Map<String, dynamic>> runs) {
  if (runs.isEmpty)
    return 'Histórico vazio. Execute `farol check` para registrar a primeira verificação.';
  final lines = <String>[
    'Histórico local · ${runs.length} execuções recentes',
    '',
  ];
  for (final run in runs) {
    final startedAt = run['startedAt'] as String? ?? 'data desconhecida';
    final summary = run['summary'] as Map<String, dynamic>? ?? const {};
    lines.add(
      '$startedAt · ${summary['healthy'] ?? 0} OK · ${summary['degraded'] ?? 0} lentos · ${summary['down'] ?? 0} indisponíveis',
    );
  }
  return lines.join('\n');
}

String _escapeCell(String value) =>
    value.replaceAll('|', r'\|').replaceAll('\n', ' ');
