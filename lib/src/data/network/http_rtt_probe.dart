import 'dart:async';
import 'dart:io';

import '../../application/captured_sample.dart';
import '../../application/collector.dart';
import '../../domain/enums.dart';
import '../../domain/telemetry_sample.dart';

/// Shared RTT probe, matching the reference LatencySampler as closely as Dart allows:
/// - HTTPS GET of https://www.gstatic.com/generate_204;
/// - a **new connection per probe**, so DNS + TCP + TLS + request are all included (as with
///   HttpURLConnection plus disconnect);
/// - a 4 s connect timeout and a 4 s response timeout;
/// - any HTTP response counts as a measurement.
///
/// Timed with a monotonic stopwatch. A timeout reports TIMEOUT; any other error reports FAILED.
class HttpRttProbe implements RttProbe {
  HttpRttProbe({
    Uri? url,
    this.connectTimeout = const Duration(seconds: 4),
    this.readTimeout = const Duration(seconds: 4),
  }) : url = url ?? Uri.parse('https://www.gstatic.com/generate_204');

  final Uri url;
  final Duration connectTimeout;
  final Duration readTimeout;

  @override
  String get method => SampleProvenance.rttMethodDartGenerate204;

  @override
  Future<RttResult> measure() async {
    final client = HttpClient()
      ..connectionTimeout = connectTimeout
      ..idleTimeout = Duration.zero; // never reuse a connection between probes
    final watch = Stopwatch()..start();
    try {
      final request = await client.getUrl(url);
      request.followRedirects = false;
      final response = await request.close().timeout(readTimeout);
      await response.drain<void>().timeout(readTimeout);
      return RttResult(FieldStatus.ok, watch.elapsedMilliseconds);
    } on TimeoutException {
      return const RttResult(FieldStatus.timeout);
    } on SocketException catch (e) {
      // connectionTimeout surfaces as a SocketException whose message mentions the timeout.
      final timedOut = e.message.toLowerCase().contains('timed out');
      return RttResult(timedOut ? FieldStatus.timeout : FieldStatus.failed);
    } on Object {
      return const RttResult(FieldStatus.failed);
    } finally {
      client.close(force: true);
    }
  }
}
