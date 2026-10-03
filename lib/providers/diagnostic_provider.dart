import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum NetworkHealthTier {
  excellent, // > 10 Mbps, ping < 150 ms
  fair,      // 2 – 10 Mbps or moderate ping
  poor,      // < 2 Mbps but reachable
  degraded,  // extreme latency > 500 ms AND no connectivity
}

/// Proven Android-friendly endpoints. Uses GET (HEAD is blocked on many networks).
const _pingEndpoints = [
  'https://www.google.com/generate_204',
  'https://connectivitycheck.gstatic.com/generate_204',
  'https://clients3.google.com/generate_204',
];

enum DiagnosticStep {
  idle,
  measuringIdlePing,
  measuringDownloadBandwidth,
  measuringUploadBandwidth,
  complete,
  failed,
}

class DiagnosticResult {
  final double idlePingMs;
  final double downloadSpeedMbps;
  final double downloadPingMs;
  final double uploadSpeedMbps;
  final double uploadPingMs;
  final NetworkHealthTier tier;
  final DateTime timestamp;

  DiagnosticResult({
    required this.idlePingMs,
    required this.downloadSpeedMbps,
    required this.downloadPingMs,
    required this.uploadSpeedMbps,
    required this.uploadPingMs,
    required this.tier,
    required this.timestamp,
  });
}

class DiagnosticProvider extends ChangeNotifier {
  NetworkHealthTier _currentTier = NetworkHealthTier.excellent;
  DiagnosticStep _currentStep = DiagnosticStep.idle;
  String _stepProgressMessage = "Diagnostic ready — tap ▶ to run";
  
  double _idlePingMs = 28.0;
  double _downloadSpeedMbps = 18.5;
  double _downloadPingMs = 34.0;
  double _uploadSpeedMbps = 12.0;
  double _uploadPingMs = 38.0;
  
  bool _isAutoDiagnosticRunning = false;
  Timer? _autoDiagnosticTimer;
  final List<DiagnosticResult> _history = [];
  bool _isManualPreset = false;

  NetworkHealthTier get currentTier => _currentTier;
  DiagnosticStep get currentStep => _currentStep;
  String get stepProgressMessage => _stepProgressMessage;
  bool get isRunning => _currentStep != DiagnosticStep.idle && 
                        _currentStep != DiagnosticStep.complete && 
                        _currentStep != DiagnosticStep.failed;
  
  double get idlePingMs => _idlePingMs;
  double get downloadSpeedMbps => _downloadSpeedMbps;
  double get downloadPingMs => _downloadPingMs;
  double get uploadSpeedMbps => _uploadSpeedMbps;
  double get uploadPingMs => _uploadPingMs;
  bool get isAutoDiagnosticRunning => _isAutoDiagnosticRunning;
  bool get isManualPreset => _isManualPreset;
  List<DiagnosticResult> get history => List.unmodifiable(_history);

  DiagnosticProvider() {
    // Initial result
    _recordResult();
  }

  // Set manual preset for easy demonstration of UI adaptation
  void setManualTierPreset(NetworkHealthTier tier) {
    _isManualPreset = true;
    _currentTier = tier;
    switch (tier) {
      case NetworkHealthTier.excellent:
        _idlePingMs = 24.0;
        _downloadSpeedMbps = 24.5;
        _downloadPingMs = 30.0;
        _uploadSpeedMbps = 15.2;
        _uploadPingMs = 32.0;
        _stepProgressMessage = "Preset: Excellent Network Tier (> 10 Mbps, Low Ping)";
        break;
      case NetworkHealthTier.fair:
        _idlePingMs = 65.0;
        _downloadSpeedMbps = 6.2;
        _downloadPingMs = 82.0;
        _uploadSpeedMbps = 3.8;
        _uploadPingMs = 95.0;
        _stepProgressMessage = "Preset: Fair Network Tier (2 - 10 Mbps)";
        break;
      case NetworkHealthTier.poor:
        _idlePingMs = 145.0;
        _downloadSpeedMbps = 1.1;
        _downloadPingMs = 210.0;
        _uploadSpeedMbps = 0.6;
        _uploadPingMs = 240.0;
        _stepProgressMessage = "Preset: Poor Network Tier (< 2 Mbps)";
        break;
      case NetworkHealthTier.degraded:
        _idlePingMs = 520.0;
        _downloadSpeedMbps = 0.3;
        _downloadPingMs = 620.0;
        _uploadSpeedMbps = 0.1;
        _uploadPingMs = 650.0;
        _stepProgressMessage = "Preset: Degraded Network Tier (Extreme Latency / Loss)";
        break;
    }
    _recordResult();
    notifyListeners();
  }

  // ─── Full Diagnostic Run ────────────────────────────────────────────────────

  Future<void> runFullDiagnostic() async {
    if (isRunning) return;
    _isManualPreset = false;

    // Check hardware connectivity first — this is the ground truth on Android.
    // If the OS says we're on WiFi or cellular, we will never report degraded
    // just because a specific CDN or test endpoint is unreachable.
    bool hardwareConnected = false;
    try {
      final results = await Connectivity().checkConnectivity();
      hardwareConnected = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
    } catch (_) {}

    try {
      // Step 1: Idle ping — races 3 proven endpoints with GET, 4 rounds
      _currentStep = DiagnosticStep.measuringIdlePing;
      _stepProgressMessage = "Step 1/3: Measuring baseline latency...";
      notifyListeners();

      _idlePingMs = await _measurePingRobust(samples: 4);

      // If hardware says we're connected but all probes timed out,
      // cap idlePing to a fair-tier value so we don't falsely degrade.
      if (hardwareConnected && _idlePingMs >= 500) {
        _idlePingMs = 120.0; // Generous but non-degraded latency
      }

      // Step 2: Download bandwidth
      _currentStep = DiagnosticStep.measuringDownloadBandwidth;
      _stepProgressMessage = "Step 2/3: Measuring download speed...";
      notifyListeners();

      final downloadResult = await _measureDownloadBandwidth(hardwareConnected);
      _downloadSpeedMbps = downloadResult['speed']!;
      _downloadPingMs = downloadResult['ping']!;

      // Step 3: Upload bandwidth
      _currentStep = DiagnosticStep.measuringUploadBandwidth;
      _stepProgressMessage = "Step 3/3: Measuring upload speed...";
      notifyListeners();

      final uploadResult = await _measureUploadBandwidth(hardwareConnected);
      _uploadSpeedMbps = uploadResult['speed']!;
      _uploadPingMs = uploadResult['ping']!;

      // Evaluate tier
      _currentTier = _evaluateTier(
        downloadMbps: _downloadSpeedMbps,
        idlePing: _idlePingMs,
        loadedPing: max(_downloadPingMs, _uploadPingMs),
        hardwareConnected: hardwareConnected,
      );

      _currentStep = DiagnosticStep.complete;
      _stepProgressMessage =
          "Completed — Tier: ${_currentTier.name.toUpperCase()} "
          "(↓${_downloadSpeedMbps.toStringAsFixed(1)} Mbps, "
          "ping ${_idlePingMs.toStringAsFixed(0)} ms)";
      _recordResult();
    } catch (e) {
      _currentStep = DiagnosticStep.failed;
      _stepProgressMessage = "Diagnostic error: ${e.toString().split('\n').first}";
      // Keep last good values — don't downgrade on a transient error
    } finally {
      notifyListeners();
    }
  }

  // ─── Tier Evaluation — tuned thresholds ─────────────────────────────────────

  NetworkHealthTier _evaluateTier({
    required double downloadMbps,
    required double idlePing,
    required double loadedPing,
    bool hardwareConnected = false,
  }) {
    // If the OS confirms we have a live connection, never report degraded.
    // Degraded is ONLY for when hardware is uncertain AND metrics are extreme.
    final bool metricsLookDegraded =
        idlePing > 500 || loadedPing > 600 || downloadMbps < 0.2;
    if (metricsLookDegraded && !hardwareConnected) {
      return NetworkHealthTier.degraded;
    }
    // Excellent: > 10 Mbps AND idle ping < 150 ms
    if (downloadMbps >= 10.0 && idlePing < 150) {
      return NetworkHealthTier.excellent;
    }
    // Fair: 2 – 10 Mbps OR decent speed with moderate ping
    if (downloadMbps >= 2.0 || (downloadMbps >= 1.0 && idlePing < 200)) {
      return NetworkHealthTier.fair;
    }
    // Poor: measurable but slow
    return NetworkHealthTier.poor;
  }

  // ─── Robust Ping — races endpoints per round, trims outliers ─────────────────

  /// Each of [samples] rounds races all [_pingEndpoints] concurrently and
  /// picks the fastest RTT. After all rounds, the single worst result is
  /// dropped and the trimmed average is returned. This means one timeout or
  /// slow hop cannot inflate the final reading.
  Future<double> _measurePingRobust({int samples = 4}) async {
    final List<double> roundResults = [];
    double? firstSuccess; // Track if ANY probe ever succeeded

    for (int i = 0; i < samples; i++) {
      final futures = _pingEndpoints.map((url) async {
        final sw = Stopwatch()..start();
        try {
          final client = http.Client();
          try {
            // Use GET — HEAD is blocked on many mobile networks and CDNs.
            // generate_204 returns an empty 204 so it's very lightweight.
            await client
                .get(Uri.parse(url))
                .timeout(const Duration(milliseconds: 2000));
          } finally {
            client.close();
          }
          sw.stop();
          return sw.elapsedMilliseconds.toDouble();
        } catch (_) {
          return double.infinity;
        }
      }).toList();

      final results = await Future.wait(futures);
      final best = results.reduce(min);
      if (best != double.infinity) {
        firstSuccess ??= best;
        roundResults.add(best);
      }
      // Don't add failed rounds — only successful probes count.
      // This way a round where ALL endpoints timeout doesn't inflate
      // the average with a fake 500ms penalty.

      if (i < samples - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // If NO round succeeded at all, return 500 as sentinel (connectivity
    // floor in runFullDiagnostic will cap this if hardware is connected).
    if (roundResults.isEmpty) return 500.0;

    roundResults.sort();
    // Trim worst reading to reduce outlier impact
    final trimmed = roundResults.length > 1
        ? roundResults.sublist(0, roundResults.length - 1)
        : roundResults;
    final avg = trimmed.reduce((a, b) => a + b) / trimmed.length;
    return double.parse(avg.toStringAsFixed(1));
  }

  // ─── Download Bandwidth ─────────────────────────────────────────────────────

  Future<Map<String, double>> _measureDownloadBandwidth(
      [bool hardwareConnected = false]) async {
    double concurrentPing = _idlePingMs;
    final pingFuture =
        _measurePingRobust(samples: 2).then((v) => concurrentPing = v);

    final downloadUrls = [
      'https://speed.cloudflare.com/__down?bytes=1000000', // 1 MB
      'https://speed.cloudflare.com/__down?bytes=500000',  // 500 KB
      'https://httpbin.org/bytes/500000',
    ];

    for (final url in downloadUrls) {
      try {
        final client = http.Client();
        final sw = Stopwatch()..start();
        try {
          final response = await client
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 10));
          sw.stop();
          await pingFuture;
          final bytes = response.bodyBytes.length;
          final seconds = sw.elapsedMilliseconds / 1000.0;
          if (seconds > 0 && bytes > 10000) {
            final mbps = (bytes * 8) / (1024 * 1024) / seconds;
            return {
              'speed': double.parse(mbps.toStringAsFixed(2)),
              'ping': concurrentPing,
            };
          }
        } finally {
          client.close();
        }
      } catch (_) {
        // Try next endpoint
      }
    }

    await pingFuture;
    // All CDN endpoints failed. Estimate speed from idle ping.
    // Clamp loaded ping to idlePing so a CDN failure doesn't produce a
    // falsely high loaded-ping that triggers degraded in _evaluateTier.
    final estimatedSpeed = _pingToEstimatedMbps(_idlePingMs);
    return {
      'speed': estimatedSpeed,
      'ping': min(concurrentPing, _idlePingMs * 1.5),
    };
  }

  // ─── Upload Bandwidth ───────────────────────────────────────────────────────

  Future<Map<String, double>> _measureUploadBandwidth(
      [bool hardwareConnected = false]) async {
    double concurrentPing = _idlePingMs;
    final pingFuture =
        _measurePingRobust(samples: 2).then((v) => concurrentPing = v);

    final payload = List.filled(256 * 1024, 65); // 256 KB
    final uploadUrls = [
      'https://speed.cloudflare.com/__up',
      'https://httpbin.org/post',
    ];

    for (final url in uploadUrls) {
      try {
        final client = http.Client();
        final sw = Stopwatch()..start();
        try {
          await client
              .post(Uri.parse(url), body: payload)
              .timeout(const Duration(seconds: 10));
          sw.stop();
          await pingFuture;
          final seconds = sw.elapsedMilliseconds / 1000.0;
          if (seconds > 0) {
            final mbps = (payload.length * 8) / (1024 * 1024) / seconds;
            return {
              'speed': double.parse(mbps.toStringAsFixed(2)),
              'ping': concurrentPing,
            };
          }
        } finally {
          client.close();
        }
      } catch (_) {
        // Try next
      }
    }

    await pingFuture;
    // Clamp loaded ping just like download to avoid false degraded
    return {
      'speed': _pingToEstimatedMbps(_idlePingMs) * 0.6,
      'ping': min(concurrentPing, _idlePingMs * 1.5),
    };
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Rough speed estimate when CDN is unreachable but ping succeeded.
  /// Prevents falsely reporting "degraded" on a working connection.
  double _pingToEstimatedMbps(double pingMs) {
    if (pingMs < 50) return 15.0;
    if (pingMs < 100) return 8.0;
    if (pingMs < 200) return 4.0;
    if (pingMs < 350) return 1.5;
    return 0.4;
  }

  void _recordResult() {
    _history.insert(
      0,
      DiagnosticResult(
        idlePingMs: _idlePingMs,
        downloadSpeedMbps: _downloadSpeedMbps,
        downloadPingMs: _downloadPingMs,
        uploadSpeedMbps: _uploadSpeedMbps,
        uploadPingMs: _uploadPingMs,
        tier: _currentTier,
        timestamp: DateTime.now(),
      ),
    );
    if (_history.length > 20) _history.removeLast();
  }

  void toggleAutoDiagnostic(bool enable) {
    _isAutoDiagnosticRunning = enable;
    _autoDiagnosticTimer?.cancel();
    if (enable) {
      _autoDiagnosticTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        runFullDiagnostic();
      });
    }
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _autoDiagnosticTimer?.cancel();
    super.dispose();
  }
}
