import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/activity_card.dart';
import '../core/widgets/metric_tile.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/status_badge.dart';
import '../providers/app_settings_provider.dart';
import '../providers/diagnostic_provider.dart';
import '../providers/local_chat_provider.dart';
import '../providers/network_monitor_provider.dart';
import 'activity1/portfolio_settings_screen.dart';
import 'activity2/network_monitor_screen.dart';
import 'activity3/dynamic_throttle_screen.dart';
import 'activity4/local_mesh_chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final netMonitor = context.watch<NetworkMonitorProvider>();
    final diagnostic = context.watch<DiagnosticProvider>();
    final chat = context.watch<LocalChatProvider>();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mobile Computing Lab"),
        actions: [
          IconButton(
            tooltip: "Settings",
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PortfolioSettingsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: "Toggle Theme",
            icon: Icon(settings.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => context.read<AppSettingsProvider>().toggleTheme(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Banner
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFEDF2F7),
                        child: Icon(
                          Icons.person_rounded,
                          color: isDark ? Colors.white70 : const Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              settings.studentName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Partner: ${settings.partnerName} • ${settings.courseSection}",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: "Edit Profile",
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PortfolioSettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Live Status Grid (Clean & Simple)
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: "Network",
                      value: netMonitor.activeType.name.toUpperCase(),
                      icon: Icons.wifi,
                      color: netMonitor.isConnected ? AppTheme.success : AppTheme.danger,
                      subtitle: "${netMonitor.handoverCount} handovers",
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: "Health Tier",
                      value: diagnostic.currentTier.name.toUpperCase(),
                      icon: Icons.speed,
                      color: diagnostic.currentTier == NetworkHealthTier.excellent
                          ? AppTheme.success
                          : AppTheme.info,
                      subtitle: "${diagnostic.downloadSpeedMbps.toStringAsFixed(1)} Mbps",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              const SectionHeader(
                title: "Laboratory Activities",
              ),
              const SizedBox(height: 4),

              // Activity 1
              ActivityCard(
                activityNumber: "ACTIVITY 1",
                tag: "STATE",
                title: "Portfolio & State Management",
                description: "Theme toggle, student pair profile, and responsive layout.",
                icon: Icons.palette_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PortfolioSettingsScreen()),
                  );
                },
                statusWidget: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      settings.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    StatusBadge(
                      label: settings.isDarkMode ? "DARK" : "LIGHT",
                      color: AppTheme.info,
                      isSmall: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Activity 2
              ActivityCard(
                activityNumber: "ACTIVITY 2",
                tag: "NETWORK",
                title: "Network Monitor & Handover",
                description: "Live connection state, handover audit, and request queue.",
                icon: Icons.cell_tower_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NetworkMonitorScreen()),
                  );
                },
                statusWidget: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${netMonitor.pendingCount} queued • ${netMonitor.completedRequests.length} done",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    StatusBadge(
                      label: netMonitor.activeType.name.toUpperCase(),
                      color: netMonitor.isConnected ? AppTheme.success : AppTheme.danger,
                      isSmall: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Activity 3
              ActivityCard(
                activityNumber: "ACTIVITY 3",
                tag: "THROTTLE",
                title: "Performance Throttle",
                description: "Latency and speed diagnostic with adaptive UI downscaling.",
                icon: Icons.speed_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DynamicThrottleScreen()),
                  );
                },
                statusWidget: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${diagnostic.idlePingMs.toStringAsFixed(0)}ms • ${diagnostic.downloadSpeedMbps.toStringAsFixed(1)} Mbps",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    StatusBadge(
                      label: diagnostic.currentTier.name.toUpperCase(),
                      color: diagnostic.currentTier == NetworkHealthTier.excellent
                          ? AppTheme.success
                          : AppTheme.info,
                      isSmall: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Activity 4
              ActivityCard(
                activityNumber: "ACTIVITY 4",
                tag: "MESH CHAT",
                title: "Serverless Local Chat",
                description: "Offline peer discovery and text messaging over local sockets.",
                icon: Icons.forum_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LocalMeshChatScreen()),
                  );
                },
                statusWidget: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      chat.isBroadcasting
                          ? "${chat.discoveredPeers.length} peers found"
                          : "Standby",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    StatusBadge(
                      label: chat.isBroadcasting ? "ONLINE" : "STANDBY",
                      color: chat.isBroadcasting ? AppTheme.success : Colors.grey,
                      isSmall: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
