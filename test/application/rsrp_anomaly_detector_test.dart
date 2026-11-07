import 'package:flutter_test/flutter_test.dart';
import 'package:qoesense/src/application/rsrp_anomaly_detector.dart';

void main() {
  List<int> repeat(int v, int n) => List.filled(n, v);

  test('too few readings -> nothing', () {
    expect(RsrpAnomalyDetector.detect(repeat(-90, 12)), isNull);
  });

  test('a >=10 dB drop of the recent 3 vs the baseline 10 is a drop', () {
    expect(RsrpAnomalyDetector.detect([...repeat(-85, 10), ...repeat(-100, 3)]), AnomalyReason.signalDrop);
  });

  test('a >=10 dB rise is a spike', () {
    expect(RsrpAnomalyDetector.detect([...repeat(-110, 10), ...repeat(-95, 3)]), AnomalyReason.signalSpike);
  });

  test('a 9 dB swing is not drastic', () {
    // 13 readings is below the stability window, so only drop/spike is considered.
    expect(RsrpAnomalyDetector.detect([...repeat(-85, 10), ...repeat(-94, 3)]), isNull);
  });

  test('15 readings within 2 dB std dev is prolonged stability', () {
    expect(
      RsrpAnomalyDetector.detect([for (var i = 0; i < 15; i++) i.isEven ? -90 : -92]),
      AnomalyReason.prolongedStability,
    );
  });

  test('a noisy signal is not stable', () {
    expect(RsrpAnomalyDetector.detect([for (var i = 0; i < 15; i++) i.isEven ? -85 : -95]), isNull);
  });

  test('drop/spike takes precedence over stability', () {
    expect(RsrpAnomalyDetector.detect([...repeat(-80, 12), ...repeat(-100, 3)]), AnomalyReason.signalDrop);
  });
}
