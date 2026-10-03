import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_badge.dart';
import '../../providers/network_monitor_provider.dart';

class NetworkMonitorScreen extends StatelessWidget {
  const NetworkMonitorScreen({super.key});

  Color _getNetworkColor(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return const Color(0xFF2E7D32);
      case NetworkType.cellular:
        return const Color(0xFF2B6CB0);
      case NetworkType.ethernet:
        return const Color(0xFF5A67D8);
      case NetworkType.offline:
        return const Color(0xFFC53030);
    }
  }

  IconData _getNetworkIcon(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return Icons.wifi;
      case NetworkType.cellular:
        return Icons.cell_tower;
      case NetworkType.ethernet:
        return Icons.settings_ethernet;
      case NetworkType.offline:
        return Icons.wifi_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    final netMonitor = context.watch<NetworkMonitorProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('HH:mm:ss');
    final activeColor = _getNetworkColor(netMonitor.activeType);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity 2: Network Monitor"),
        actions: [
          if (netMonitor.completedRequests.isNotEmpty)
            IconButton(
              tooltip: "Clear Completed",
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () {
                netMonitor.clearCompleted();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Completed list cleared"),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Network Interface Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "CURRENT CONNECTION",
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        StatusBadge(
                          label: netMonitor.isManualSimulation ? "SIMULATION" : "LIVE STREAM",
                          color: netMonitor.isManualSimulation ? AppTheme.warning : AppTheme.info,
                          isSmall: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: activeColor.withValues(alpha: 0.3)),
                          ),
                          child: Icon(_getNetworkIcon(netMonitor.activeType), size: 26, color: activeColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                netMonitor.activeType.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: activeColor,
                                ),
                              ),
                              Text(
                                netMonitor.isOffline
                                  ? "Offline: Requests will wait in queue"
                                  : "Connected: Ready to transmit data",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Handovers: ${netMonitor.handoverCount}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        Text(
                          "Updated: ${timeFormat.format(netMonitor.lastStateChange)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Handover Simulator Buttons (Direct & Functional)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Switch Network (Handover Test)",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildHandoverBtn(
                            context,
                            label: "Wi-Fi",
                            icon: Icons.wifi,
                            isActive: netMonitor.activeType == NetworkType.wifi,
                            onTap: () {
                              netMonitor.simulateHandover(NetworkType.wifi);
                              _showToast(context, "Switched to Wi-Fi");
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHandoverBtn(
                            context,
                            label: "Cellular",
                            icon: Icons.cell_tower,
                            isActive: netMonitor.activeType == NetworkType.cellular,
                            onTap: () {
                              netMonitor.simulateHandover(NetworkType.cellular);
                              _showToast(context, "Switched to Cellular");
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHandoverBtn(
                            context,
                            label: "Offline",
                            icon: Icons.wifi_off,
                            isActive: netMonitor.activeType == NetworkType.offline,
                            isDanger: true,
                            onTap: () {
                              netMonitor.simulateHandover(NetworkType.offline);
                              _showToast(context, "Disconnected: Link Dropped");
                            },
                          ),
                        ),
                      ],
                    ),
                    if (netMonitor.isManualSimulation) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            netMonitor.toggleSimulation(false);
                            _showToast(context, "Returned to Live Hardware Stream");
                          },
                          icon: const Icon(Icons.restore, size: 16),
                          label: const Text("Reset to Real Device Stream", style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Metrics Row
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: "Queue Buffer",
                    value: "${netMonitor.pendingCount}",
                    icon: Icons.hourglass_top_rounded,
                    color: netMonitor.pendingCount > 0 ? AppTheme.warning : AppTheme.info,
                    subtitle: netMonitor.isProcessingQueue ? "Draining..." : "Safe from loss",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricTile(
                    label: "Delivered",
                    value: "${netMonitor.completedRequests.length}",
                    icon: Icons.task_alt_rounded,
                    color: AppTheme.success,
                    subtitle: "Handover safe",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Actions Bar (Direct & Functional)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final msg = await netMonitor.sendOrQueueRequest();
                              if (context.mounted) _showToast(context, msg);
                            },
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text("Send Packet", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: netMonitor.queue.isEmpty || netMonitor.isOffline
                                ? null
                                : () async {
                                    await netMonitor.drainQueue();
                                    if (context.mounted) _showToast(context, "Queue drained!");
                                  },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text("Drain Queue", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final next = !netMonitor.autoSyncEnabled;
                          netMonitor.toggleAutoSync(next);
                          _showToast(context, next ? "Auto sync started (every 4s)" : "Auto sync stopped");
                        },
                        icon: Icon(
                          netMonitor.autoSyncEnabled ? Icons.stop_circle_outlined : Icons.sync,
                          size: 16,
                          color: netMonitor.autoSyncEnabled ? AppTheme.danger : null,
                        ),
                        label: Text(
                          netMonitor.autoSyncEnabled ? "Stop Auto Stream" : "Start Auto Stream (4s)",
                          style: TextStyle(
                            fontSize: 12,
                            color: netMonitor.autoSyncEnabled ? AppTheme.danger : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Queue List
            SectionHeader(
              title: "Queue Buffer (${netMonitor.queue.length})",
              trailing: netMonitor.queue.isNotEmpty
                  ? TextButton(
                      onPressed: () => netMonitor.clearQueue(),
                      child: const Text("Clear", style: TextStyle(fontSize: 12)),
                    )
                  : null,
            ),
            if (netMonitor.queue.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  child: Center(
                    child: Text(
                      "Queue is empty. Tap 'Send Packet' to test.",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: netMonitor.queue.length,
                itemBuilder: (context, index) {
                  final req = netMonitor.queue[index];
                  return Card(
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        req.status == 'transmitting' ? Icons.sync : Icons.schedule_send_rounded,
                        color: req.status == 'transmitting' ? AppTheme.info : AppTheme.warning,
                      ),
                      title: Text(req.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        "Payload: ${req.payloadBytes}B • Retries: ${req.retryAttempts}\n${req.error ?? 'Pending'}",
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: StatusBadge(
                        label: req.status.toUpperCase(),
                        color: req.status == 'transmitting' ? AppTheme.info : AppTheme.warning,
                        isSmall: true,
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),

            // Recent Handover Log
            SectionHeader(title: "Handover Log (${netMonitor.handoverHistory.length})"),
            if (netMonitor.handoverHistory.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      "No handovers yet.",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: netMonitor.handoverHistory.length.clamp(0, 6),
                itemBuilder: (context, index) {
                  final event = netMonitor.handoverHistory[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${event.from.name.toUpperCase()} ➜ ${event.to.name.toUpperCase()}",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  event.note,
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timeFormat.format(event.timestamp),
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandoverBtn(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDanger ? AppTheme.danger : (isActive ? AppTheme.info : Colors.blueGrey);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : (isDark ? const Color(0xFF1E242E) : const Color(0xFFF7FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : (isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0)),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isActive ? color : (isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? color : null,
              ),
            ),
          ],
        ),
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
