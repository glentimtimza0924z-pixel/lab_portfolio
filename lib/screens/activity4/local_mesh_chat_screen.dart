import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/metric_tile.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/local_chat_provider.dart';

class LocalMeshChatScreen extends StatefulWidget {
  const LocalMeshChatScreen({super.key});

  @override
  State<LocalMeshChatScreen> createState() => _LocalMeshChatScreenState();
}

class _LocalMeshChatScreenState extends State<LocalMeshChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final studentName = context.read<AppSettingsProvider>().studentName;
      if (studentName.isNotEmpty) {
        context.read<LocalChatProvider>().updateMyName(studentName);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    final chat = context.read<LocalChatProvider>();
    // If no peers are added yet, automatically add demo peer so message gets routed and answered
    if (chat.discoveredPeers.isEmpty) {
      chat.addSimulatedPeer();
    }

    chat.sendChatMessage(text);
    _messageController.clear();

    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showPeerDialog(MeshPeer peer) {
    final chat = context.read<LocalChatProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(peer.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Node ID: ${peer.id}"),
            const SizedBox(height: 4),
            Text("Address: ${peer.address}:${peer.port}"),
            const SizedBox(height: 4),
            Text("Status: ${peer.isConnected ? 'Connected' : 'Discovered'}"),
          ],
        ),
        actions: [
          if (!peer.isConnected)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                chat.initiateHandshake(peer);
              },
              child: const Text("Pair & Connect"),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                chat.sendChatMessage("Ping from ${chat.myName}");
              },
              child: const Text("Send Ping"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<LocalChatProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity 4: Mesh Chat"),
        actions: [
          if (chat.messages.isNotEmpty)
            IconButton(
              tooltip: "Clear Chat",
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                chat.clearChat();
                _showToast(context, "Chat cleared");
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Top Status & Mesh Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A202C) : const Color(0xFFFFFFFF),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.hub_rounded,
                      size: 22,
                      color: chat.isBroadcasting ? AppTheme.success : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${chat.myName} (${chat.myId})",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            chat.isBroadcasting
                                ? "Mesh Active (UDP 8888 • TCP 8889)"
                                : "Serverless Engine Standby",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: chat.isBroadcasting ? AppTheme.danger : AppTheme.lightPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        if (chat.isBroadcasting) {
                          chat.stopMeshServices();
                          _showToast(context, "Mesh stopped");
                        } else {
                          chat.startMeshServices();
                          _showToast(context, "Mesh started: Broadcasting UDP 8888");
                        }
                      },
                      child: Text(
                        chat.isBroadcasting ? "Stop Mesh" : "Start Mesh",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        label: "Peers Found",
                        value: "${chat.discoveredPeers.length}",
                        icon: Icons.radar_rounded,
                        color: AppTheme.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricTile(
                        label: "Connected",
                        value: "${chat.connectedPeers.length}",
                        icon: Icons.link_rounded,
                        color: chat.connectedPeers.isNotEmpty ? AppTheme.success : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Discovered Peers Bar & Add Peer Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14181F) : const Color(0xFFF7FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                if (chat.discoveredPeers.isEmpty) ...[
                  const Expanded(
                    child: Text(
                      "No peers found yet",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: chat.discoveredPeers.map((peer) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: Icon(
                                peer.isConnected ? Icons.check_circle : Icons.device_hub,
                                size: 14,
                                color: peer.isConnected ? AppTheme.success : Colors.grey,
                              ),
                              label: Text(
                                peer.name,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: peer.isConnected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              onPressed: () => _showPeerDialog(peer),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Messages View
          Expanded(
            child: chat.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        const Text("No messages yet", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          "Type below to test.",
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chat.messages[index];
                      return _buildChatBubble(msg, isDark, timeFormat);
                    },
                  ),
          ),

          // Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A202C) : const Color(0xFFFFFFFF),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: "Type message...",
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFEDF2F7),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg, bool isDark, DateFormat timeFormat) {
    final isMe = msg.isMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isMe ? "You" : msg.senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                timeFormat.format(msg.timestamp),
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            constraints: const BoxConstraints(maxWidth: 270),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe
                  ? (isDark ? const Color(0xFF2D3748) : const Color(0xFF2C3E50))
                  : (isDark ? const Color(0xFF1E242E) : const Color(0xFFEDF2F7)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(10),
                topRight: const Radius.circular(10),
                bottomLeft: Radius.circular(isMe ? 10 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 10),
              ),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                fontSize: 13,
                color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A202C)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
