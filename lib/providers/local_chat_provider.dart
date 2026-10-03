import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum MeshMode { localNetworkSocket, nearbyBluetooth }

class MeshPeer {
  final String id;
  final String name;
  final String address;
  final int port;
  final DateTime lastSeen;
  bool isConnected;
  bool isHandshaking;

  MeshPeer({
    required this.id,
    required this.name,
    required this.address,
    this.port = 8889,
    required this.lastSeen,
    this.isConnected = false,
    this.isHandshaking = false,
  });

  MeshPeer copyWith({
    bool? isConnected,
    bool? isHandshaking,
    DateTime? lastSeen,
    String? name,
  }) {
    return MeshPeer(
      id: id,
      name: name ?? this.name,
      address: address,
      port: port,
      lastSeen: lastSeen ?? this.lastSeen,
      isConnected: isConnected ?? this.isConnected,
      isHandshaking: isHandshaking ?? this.isHandshaking,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final String status; // 'sending', 'sent', 'delivered'

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.status = 'delivered',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'type': 'chat',
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json, {required bool isMe}) {
    return ChatMessage(
      id: json['id'] as String? ?? UniqueKey().toString(),
      senderId: json['senderId'] as String? ?? 'peer',
      senderName: json['senderName'] as String? ?? 'Nearby Peer',
      text: json['text'] as String? ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isMe: isMe,
      status: 'delivered',
    );
  }
}

class LocalChatProvider extends ChangeNotifier {
  static const int udpBroadcastPort = 8888;
  static const int tcpChatPort = 8889;

  String _myId = "PEER-${DateTime.now().millisecondsSinceEpoch % 10000}";
  String _myName = "Device Alpha";
  MeshMode _activeMode = MeshMode.localNetworkSocket;

  // Socket references
  RawDatagramSocket? _udpBeaconSocket;
  ServerSocket? _tcpServer;
  final Map<String, Socket> _connectedSockets = {};

  bool _isBroadcasting = false;
  bool _isScanning = false;
  Timer? _beaconTimer;
  Timer? _peerPruneTimer;

  final Map<String, MeshPeer> _discoveredPeers = {};
  final List<ChatMessage> _messages = [];

  // Getters
  String get myId => _myId;
  String get myName => _myName;
  MeshMode get activeMode => _activeMode;
  bool get isBroadcasting => _isBroadcasting;
  bool get isScanning => _isScanning;
  List<MeshPeer> get discoveredPeers => _discoveredPeers.values.toList();
  List<MeshPeer> get connectedPeers => _discoveredPeers.values.where((p) => p.isConnected).toList();
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  LocalChatProvider() {
    _initMyId();
    _startPeerPruner();
  }

  void updateMyName(String name) {
    if (name.trim().isNotEmpty) {
      _myName = name.trim();
      notifyListeners();
    }
  }

  void _initMyId() {
    _myId = "NODE-${(1000 + (DateTime.now().millisecondsSinceEpoch % 9000))}";
  }

  // Set Mode
  void setMeshMode(MeshMode mode) {
    _activeMode = mode;
    notifyListeners();
  }

  // Start Discovery and Broadcast
  Future<void> startMeshServices() async {
    await stopMeshServices();
    _isBroadcasting = true;
    _isScanning = true;
    notifyListeners();

    try {
      // 1. Start TCP Server for incoming peer sockets
      _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, tcpChatPort);
      _tcpServer!.listen(_handleIncomingTcpConnection, onError: (e) {
        debugPrint("TCP Server error: $e");
      });

      // 2. Start UDP Socket for Beacon Broadcast & Discovery
      _udpBeaconSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpBroadcastPort,
        reuseAddress: true,
        reusePort: false,
      );
      _udpBeaconSocket!.broadcastEnabled = true;
      _udpBeaconSocket!.listen(_handleUdpPacket);

      // 3. Broadcast Beacon periodically
      _beaconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _broadcastPresenceBeacon();
      });

      // Initial broadcast
      _broadcastPresenceBeacon();
    } catch (e) {
      debugPrint("Socket Mesh initialization exception: $e");
      // Fallback: If socket fails on restricted environment, add local mesh simulator
    }
    notifyListeners();
  }

  Future<void> stopMeshServices() async {
    _beaconTimer?.cancel();
    _isBroadcasting = false;
    _isScanning = false;

    for (final socket in _connectedSockets.values) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _connectedSockets.clear();

    try {
      _udpBeaconSocket?.close();
      _udpBeaconSocket = null;
    } catch (_) {}

    try {
      await _tcpServer?.close();
      _tcpServer = null;
    } catch (_) {}

    for (final key in _discoveredPeers.keys) {
      _discoveredPeers[key] = _discoveredPeers[key]!.copyWith(isConnected: false);
    }
    notifyListeners();
  }

  // Broadcast Presence Beacon over UDP subnet
  void _broadcastPresenceBeacon() {
    if (_udpBeaconSocket == null || !_isBroadcasting) return;

    final beaconData = jsonEncode({
      'type': 'BEACON',
      'id': _myId,
      'name': _myName,
      'port': tcpChatPort,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final bytes = utf8.encode(beaconData);
    try {
      _udpBeaconSocket!.send(bytes, InternetAddress("255.255.255.255"), udpBroadcastPort);
    } catch (e) {
      // Ignore broadcast errors on non-wifi loopbacks
    }
  }

  // Handle Incoming UDP Packets
  void _handleUdpPacket(RawSocketEvent event) {
    if (event == RawSocketEvent.read && _udpBeaconSocket != null) {
      final datagram = _udpBeaconSocket!.receive();
      if (datagram == null) return;

      try {
        final messageStr = utf8.decode(datagram.data);
        final data = jsonDecode(messageStr) as Map<String, dynamic>;

        if (data['type'] == 'BEACON') {
          final peerId = data['id'] as String;
          if (peerId == _myId) return; // Ignore own beacon

          final peerName = data['name'] as String? ?? "Node ${peerId.substring(0, 4)}";
          final peerPort = data['port'] as int? ?? tcpChatPort;
          final peerAddress = datagram.address.address;

          final existing = _discoveredPeers[peerId];
          _discoveredPeers[peerId] = MeshPeer(
            id: peerId,
            name: peerName,
            address: peerAddress,
            port: peerPort,
            lastSeen: DateTime.now(),
            isConnected: existing?.isConnected ?? false,
          );
          notifyListeners();
        }
      } catch (e) {
        // Ignore malformed packets
      }
    }
  }

  // Handle Incoming TCP Connection Handshake
  void _handleIncomingTcpConnection(Socket socket) {
    socket.listen(
      (data) {
        _handleIncomingPayload(data, socket);
      },
      onError: (e) {
        _disconnectSocket(socket);
      },
      onDone: () {
        _disconnectSocket(socket);
      },
    );
  }

  // Connect & Handshake with Discovered Peer
  Future<bool> initiateHandshake(MeshPeer peer) async {
    peer.isHandshaking = true;
    notifyListeners();

    try {
      final socket = await Socket.connect(
        peer.address,
        peer.port,
        timeout: const Duration(seconds: 4),
      );

      _connectedSockets[peer.id] = socket;

      socket.listen(
        (data) => _handleIncomingPayload(data, socket),
        onError: (_) => _disconnectPeer(peer.id),
        onDone: () => _disconnectPeer(peer.id),
      );

      // Send Handshake Init
      final handshakePayload = jsonEncode({
        'type': 'HANDSHAKE_INIT',
        'senderId': _myId,
        'senderName': _myName,
        'timestamp': DateTime.now().toIso8601String(),
      });
      socket.write("$handshakePayload\n");

      peer.isConnected = true;
      peer.isHandshaking = false;
      _discoveredPeers[peer.id] = peer;
      notifyListeners();
      return true;
    } catch (e) {
      peer.isHandshaking = false;
      peer.isConnected = false;
      notifyListeners();
      return false;
    }
  }

  void _handleIncomingPayload(List<int> rawBytes, Socket socket) {
    try {
      final rawString = utf8.decode(rawBytes);
      final lines = rawString.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final data = jsonDecode(line) as Map<String, dynamic>;
        final type = data['type'] as String?;

        if (type == 'HANDSHAKE_INIT') {
          final senderId = data['senderId'] as String;
          final senderName = data['senderName'] as String;
          _connectedSockets[senderId] = socket;

          _discoveredPeers[senderId] = MeshPeer(
            id: senderId,
            name: senderName,
            address: socket.remoteAddress.address,
            lastSeen: DateTime.now(),
            isConnected: true,
          );

          // Reply with ACK
          final ack = jsonEncode({
            'type': 'HANDSHAKE_ACK',
            'senderId': _myId,
            'senderName': _myName,
          });
          socket.write("$ack\n");
          notifyListeners();
        } else if (type == 'HANDSHAKE_ACK') {
          final senderId = data['senderId'] as String;
          if (_discoveredPeers.containsKey(senderId)) {
            _discoveredPeers[senderId] = _discoveredPeers[senderId]!.copyWith(isConnected: true);
            notifyListeners();
          }
        } else if (type == 'chat') {
          final msg = ChatMessage.fromJson(data, isMe: false);
          _messages.add(msg);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Payload parsing error: $e");
    }
  }

  // Send Text Payload across established peer-to-peer mesh
  Future<void> sendChatMessage(String text) async {
    if (text.trim().isEmpty) return;

    final msgId = "MSG-${DateTime.now().millisecondsSinceEpoch}";
    final chatMsg = ChatMessage(
      id: msgId,
      senderId: _myId,
      senderName: _myName,
      text: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
      status: _connectedSockets.isNotEmpty ? 'sent' : 'queued',
    );

    _messages.add(chatMsg);
    notifyListeners();

    final payload = "${jsonEncode(chatMsg.toJson())}\n";

    // Broadcast across all connected sockets
    for (final socket in _connectedSockets.values) {
      try {
        socket.write(payload);
      } catch (e) {
        debugPrint("Error routing payload to peer: $e");
      }
    }

    // Interactive Demo / Solo testing responder:
    final hasSim = _discoveredPeers.values.any((p) => p.id.startsWith("SIM-") && p.isConnected);
    if (hasSim) {
      Timer(const Duration(milliseconds: 500), () {
        if (_disposed) return;
        final simPeer = _discoveredPeers.values.firstWhere((p) => p.id.startsWith("SIM-"));
        _messages.add(ChatMessage(
          id: "SIM-RESP-${DateTime.now().millisecondsSinceEpoch}",
          senderId: simPeer.id,
          senderName: simPeer.name,
          text: "Echo: Received \"${text.trim()}\" via local mesh socket.",
          timestamp: DateTime.now(),
          isMe: false,
        ));
        notifyListeners();
      });
    }
  }

  void _disconnectPeer(String peerId) {
    final socket = _connectedSockets.remove(peerId);
    try {
      socket?.destroy();
    } catch (_) {}

    if (_discoveredPeers.containsKey(peerId)) {
      _discoveredPeers[peerId] = _discoveredPeers[peerId]!.copyWith(isConnected: false);
      notifyListeners();
    }
  }

  void _disconnectSocket(Socket socket) {
    String? matchedId;
    _connectedSockets.forEach((id, s) {
      if (s == socket) matchedId = id;
    });
    if (matchedId != null) {
      _disconnectPeer(matchedId!);
    }
  }

  // Simulated Peer for solo testing/lab evaluation
  void addSimulatedPeer() {
    _isBroadcasting = true;
    _isScanning = true;
    final simId = "SIM-BOT-${100 + (DateTime.now().millisecondsSinceEpoch % 900)}";
    final simPeer = MeshPeer(
      id: simId,
      name: "Nearby Peer (Lab Node)",
      address: "127.0.0.1",
      lastSeen: DateTime.now(),
      isConnected: true,
    );
    _discoveredPeers[simId] = simPeer;

    // Send welcome simulated message
    _messages.add(ChatMessage(
      id: "SIM-HELLO-${DateTime.now().millisecondsSinceEpoch}",
      senderId: simId,
      senderName: simPeer.name,
      text: "Connected to local mesh! Send a test message.",
      timestamp: DateTime.now(),
      isMe: false,
    ));
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }

  void _startPeerPruner() {
    _peerPruneTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      _discoveredPeers.removeWhere((id, peer) {
        // If not connected and not seen in 30s, prune
        if (!peer.isConnected && now.difference(peer.lastSeen).inSeconds > 30) {
          return true;
        }
        return false;
      });
      notifyListeners();
    });
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
    _beaconTimer?.cancel();
    _peerPruneTimer?.cancel();
    for (final socket in _connectedSockets.values) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _connectedSockets.clear();
    try {
      _udpBeaconSocket?.close();
      _udpBeaconSocket = null;
    } catch (_) {}
    try {
      _tcpServer?.close();
      _tcpServer = null;
    } catch (_) {}
    super.dispose();
  }
}
