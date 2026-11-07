import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/data/local/telemetry_buffer.dart';

import '../support/fixtures.dart';

void main() {
  test('oldest() is ordered by timestamp, then insertion', () async {
    final b = InMemoryTelemetryBuffer();
    await b.append(sampleAt(300));
    await b.append(sampleAt(100));
    await b.append(sampleAt(100));
    final rows = await b.oldest(10);
    expect(rows.map((r) => r.sample.timestampMs), [100, 100, 300]);
    expect(rows[0].id, lessThan(rows[1].id));
  });

  test('watchCount emits the current count, then every change', () async {
    final b = InMemoryTelemetryBuffer();
    await b.append(sampleAt(1));
    final counts = <int>[];
    final sub = b.watchCount().listen(counts.add);
    await pumpEventQueue();
    final id = await b.append(sampleAt(2));
    await b.deleteByIds([id]);
    await pumpEventQueue();
    await sub.cancel();
    expect(counts, [1, 2, 1]);
  });
}
