import 'dart:math' as math;

import 'config.dart';
import 'models.dart';
import 'probe.dart';

class ProbeRunner {
  const ProbeRunner({this.probe = const HttpProbe()});

  final HttpProbe probe;

  Future<ProbeRun> run(MonitorConfig config) async {
    final startedAt = DateTime.now().toUtc();
    final results = List<ProbeResult?>.filled(config.targets.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= config.targets.length) return;
        results[index] = await probe.run(config.targets[index]);
      }
    }

    final workerCount = math.min(config.concurrency, config.targets.length);
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return ProbeRun(
      startedAt: startedAt,
      results: results.cast<ProbeResult>(),
    );
  }
}
