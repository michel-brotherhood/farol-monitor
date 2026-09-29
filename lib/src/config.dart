import 'dart:convert';
import 'dart:io';

import 'models.dart';

class ConfigException implements Exception {
  const ConfigException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MonitorConfig {
  const MonitorConfig({required this.targets, this.concurrency = 8});

  final List<ProbeTarget> targets;
  final int concurrency;

  factory MonitorConfig.fromFile(File file) {
    if (!file.existsSync()) {
      throw ConfigException(
        'Arquivo de configuração não encontrado: ${file.path}',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (error) {
      throw ConfigException('JSON inválido: ${error.message}');
    } on FileSystemException catch (error) {
      throw ConfigException('Não foi possível ler o arquivo: ${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ConfigException('A raiz do arquivo deve ser um objeto JSON.');
    }
    return MonitorConfig.fromJson(decoded);
  }

  factory MonitorConfig.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const ConfigException('Campo "version" deve ser igual a 1.');
    }

    final settings = _asMap(
      json['settings'] ?? const <String, dynamic>{},
      'settings',
    );
    final timeoutMs = _boundedInt(
      settings['timeoutMs'] ?? 5000,
      'settings.timeoutMs',
      100,
      120000,
    );
    final maxBodyBytes = _boundedInt(
      settings['maxBodyBytes'] ?? 65536,
      'settings.maxBodyBytes',
      1,
      1048576,
    );
    final concurrency = _boundedInt(
      settings['concurrency'] ?? 8,
      'settings.concurrency',
      1,
      32,
    );
    final rawTargets = json['targets'];
    if (rawTargets is! List || rawTargets.isEmpty) {
      throw const ConfigException(
        '"targets" precisa ser uma lista com pelo menos um endpoint.',
      );
    }
    if (rawTargets.length > 100) {
      throw const ConfigException('O limite é de 100 endpoints por arquivo.');
    }

    final names = <String>{};
    final targets = <ProbeTarget>[];
    for (var index = 0; index < rawTargets.length; index++) {
      final path = 'targets[$index]';
      final target = _asMap(rawTargets[index], path);
      final name = _asString(target['name'], '$path.name').trim();
      if (name.isEmpty)
        throw ConfigException('$path.name não pode ficar vazio.');
      if (!names.add(name.toLowerCase())) {
        throw ConfigException('Nome de endpoint duplicado: "$name".');
      }

      final rawUrl = _asString(target['url'], '$path.url').trim();
      final Uri uri;
      try {
        uri = Uri.parse(rawUrl);
      } on FormatException {
        throw ConfigException('$path.url não é uma URL válida.');
      }
      if (!uri.hasAuthority ||
          uri.host.isEmpty ||
          !const {'http', 'https'}.contains(uri.scheme)) {
        throw ConfigException(
          '$path.url deve usar http:// ou https:// e conter um host.',
        );
      }
      if (uri.userInfo.isNotEmpty) {
        throw ConfigException(
          '$path.url não deve conter credenciais embutidas.',
        );
      }

      final method = _asString(
        target['method'] ?? 'GET',
        '$path.method',
      ).toUpperCase();
      if (!const {'GET', 'HEAD'}.contains(method)) {
        throw ConfigException(
          '$path.method aceita apenas GET ou HEAD nesta versão.',
        );
      }
      final rawStatuses = target['expectedStatus'] ?? 200;
      final List<dynamic> statusValues = rawStatuses is List
          ? rawStatuses
          : [rawStatuses];
      if (statusValues.isEmpty)
        throw ConfigException(
          '$path.expectedStatus não pode ser uma lista vazia.',
        );
      final statuses = <int>{};
      for (final value in statusValues) {
        final code = _boundedInt(value, '$path.expectedStatus', 100, 599);
        statuses.add(code);
      }
      final latency = target['maxLatencyMs'] == null
          ? null
          : _boundedInt(
              target['maxLatencyMs'],
              '$path.maxLatencyMs',
              1,
              120000,
            );
      final contains = target['contains'] == null
          ? null
          : _asString(target['contains'], '$path.contains');
      if (method == 'HEAD' && contains != null) {
        throw ConfigException(
          '$path.contains não pode ser usado com o método HEAD.',
        );
      }

      targets.add(
        ProbeTarget(
          name: name,
          uri: uri,
          method: method,
          expectedStatuses: statuses,
          timeoutMs: _boundedInt(
            target['timeoutMs'] ?? timeoutMs,
            '$path.timeoutMs',
            100,
            120000,
          ),
          maxBodyBytes: maxBodyBytes,
          maxLatencyMs: latency,
          contains: contains,
        ),
      );
    }
    return MonitorConfig(targets: targets, concurrency: concurrency);
  }
}

Map<String, dynamic> _asMap(Object? value, String path) {
  if (value is Map<String, dynamic>) return value;
  throw ConfigException('$path deve ser um objeto JSON.');
}

String _asString(Object? value, String path) {
  if (value is String) return value;
  throw ConfigException('$path deve ser um texto.');
}

int _boundedInt(Object? value, String path, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw ConfigException(
      '$path deve ser um número inteiro entre $min e $max.',
    );
  }
  return value;
}
