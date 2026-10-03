import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum NetworkType { wifi, cellular, ethernet, offline }

class HandoverEvent {
  final DateTime timestamp;
  final NetworkType from;
  final NetworkType to;
  final String note;

  HandoverEvent({
    required this.timestamp,
    required this.from,
    required this.to,
    required this.note,
  });
}

class QueuedRequest {
  final String id;
  final String description;
  final DateTime timestamp;
  final int payloadBytes;
  int retryAttempts;
  String status; // 'queued', 'retrying', 'completed', 'dropped'
  String? error;

  QueuedRequest({
    required this.id,
    required this.description,
    required this.timestamp,
    this.payloadBytes = 256,
    this.retryAttempts = 0,
    this.status = 'queued',
    this.error,
  });
}

class NetworkMonitorProvider extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkType _activeType = NetworkType.offline;
  bool _isManualSimulation = false;
  NetworkType? _simulatedType;

  // Handover history & stats
  final List<HandoverEvent> _handoverHistory = [];
  int _handoverCount = 0;
  DateTime _lastStateChange = DateTime.now();

  // Request Queuing system
  final List<QueuedRequest> _queue = [];
  final List<QueuedRequest> _completedRequests = [];
  bool _isProcessingQueue = false;
  bool _autoSyncEnabled = false;
  Timer? _autoSyncTimer;

  NetworkType get activeType => _isManualSimulation ? (_simulatedType ?? NetworkType.offline) : _activeType;
  bool get isConnected => activeType != NetworkType.offline;
  bool get isWifi => activeType == NetworkType.wifi;
  bool get isCellular => activeType == NetworkType.cellular;
  bool get isOffline => activeType == NetworkType.offline;
  bool get isManualSimulation => _isManualSimulation;

  List<HandoverEvent> get handoverHistory => List.unmodifiable(_handoverHistory);
  int get handoverCount => _handoverCount;
  DateTime get lastStateChange => _lastStateChange;

  List<QueuedRequest> get queue => List.unmodifiable(_queue);
  List<QueuedRequest> get completedRequests => List.unmodifiable(_completedRequests);
  int get pendingCount => _queue.where((r) => r.status != 'completed').length;
  bool get isProcessingQueue => _isProcessingQueue;
  bool get autoSyncEnabled => _autoSyncEnabled;

  NetworkMonitorProvider() {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    // Initial check
    _connectivity.checkConnectivity().then((results) {
      _handleConnectivityChange(results);
    }).catchError((_) {
      _updateActiveType(NetworkType.offline, note: "Initial check failed");
    });

    // Stream listener
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (_isManualSimulation) return; // Keep simulation override

    NetworkType resolved = NetworkType.offline;
    if (results.contains(ConnectivityResult.wifi)) {
      resolved = NetworkType.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      resolved = NetworkType.cellular;
    } else if (results.contains(ConnectivityResult.ethernet)) {
      resolved = NetworkType.ethernet;
    } else if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      resolved = NetworkType.offline;
    }

    _updateActiveType(resolved, note: "Hardware stream callback");
  }

  void _updateActiveType(NetworkType newType, {required String note}) {
    if (_activeType != newType) {
      final oldType = _activeType;
      _activeType = newType;
      _lastStateChange = DateTime.now();
      _handoverCount++;

      final event = HandoverEvent(
        timestamp: DateTime.now(),
        from: oldType,
        to: newType,
        note: note,
      );
      _handoverHistory.insert(0, event);
      if (_handoverHistory.length > 50) _handoverHistory.removeLast();

      notifyListeners();

      // Graceful Recovery: Resume/drain queued requests when connection is re-established
      if (newType != NetworkType.offline && _queue.isNotEmpty) {
        drainQueue();
      }
    }
  }

  // Simulation Controls for Testing/Lab Grading
  void toggleSimulation(bool enable) {
    _isManualSimulation = enable;
    if (!enable) {
      _simulatedType = null;
      // Re-read actual hardware connectivity
      _connectivity.checkConnectivity().then((results) {
        _handleConnectivityChange(results);
      });
    } else {
      _simulatedType = _activeType;
      notifyListeners();
    }
  }

  void simulateHandover(NetworkType targetType) {
    _isManualSimulation = true;
    final oldType = activeType;
    _simulatedType = targetType;
    _lastStateChange = DateTime.now();
    _handoverCount++;

    final event = HandoverEvent(
      timestamp: DateTime.now(),
      from: oldType,
      to: targetType,
      note: "Simulated Handover (${oldType.name.toUpperCase()} -> ${targetType.name.toUpperCase()})",
    );
    _handoverHistory.insert(0, event);
    notifyListeners();

    if (targetType != NetworkType.offline && _queue.isNotEmpty) {
      drainQueue();
    }
  }

  // Request Queuing System & Long-Running Network Request Simulation
  Future<String> sendOrQueueRequest({String? customDesc}) async {
    final reqId = "REQ-${DateTime.now().millisecondsSinceEpoch % 10000}";
    final description = customDesc ?? "Data Packet #$reqId";
    final request = QueuedRequest(
      id: reqId,
      description: description,
      timestamp: DateTime.now(),
      payloadBytes: 1024 + (reqId.hashCode.abs() % 2048),
    );

    if (isOffline) {
      request.status = 'queued';
      request.error = 'Offline: Saved to queue';
      _queue.add(request);
      notifyListeners();
      return "Network offline: $description buffered in queue";
    }

    _queue.add(request);
    notifyListeners();
    _executeSingleRequest(request);
    return "Transmitting $description...";
  }

  Future<void> _executeSingleRequest(QueuedRequest req) async {
    if (isOffline) {
      req.status = 'queued';
      req.error = 'Link dropped. Queued for auto-retry.';
      notifyListeners();
      return;
    }

    req.status = 'transmitting';
    req.retryAttempts++;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 600));
      if (isOffline) {
        throw Exception("Connection lost during handover");
      }
      req.status = 'completed';
      req.error = null;
      _queue.remove(req);
      _completedRequests.insert(0, req);
      if (_completedRequests.length > 20) _completedRequests.removeLast();
    } catch (e) {
      req.status = 'queued';
      req.error = 'Handover detected. Queued.';
    } finally {
      notifyListeners();
    }
  }

  // Graceful Recovery: Drain queue when network is restored
  Future<void> drainQueue() async {
    if (_isProcessingQueue || isOffline || _queue.isEmpty) return;
    _isProcessingQueue = true;
    notifyListeners();

    final pending = List<QueuedRequest>.from(_queue.where((r) => r.status != 'completed'));
    for (final req in pending) {
      if (isOffline) break; // If network dropped again during recovery, stop and keep in queue
      await _executeSingleRequest(req);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    _isProcessingQueue = false;
    notifyListeners();
  }

  void toggleAutoSync(bool enable) {
    _autoSyncEnabled = enable;
    _autoSyncTimer?.cancel();
    if (enable) {
      _autoSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        sendOrQueueRequest();
      });
    }
    notifyListeners();
  }

  void clearCompleted() {
    _completedRequests.clear();
    notifyListeners();
  }

  void clearQueue() {
    _queue.clear();
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
    _subscription?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}
