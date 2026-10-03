import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/metric_tile.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_badge.dart';
import '../../providers/diagnostic_provider.dart';

class DynamicThrottleScreen extends StatelessWidget {
  const DynamicThrottleScreen({super.key});

  Color _getTierColor(NetworkHealthTier tier) {
    switch (tier) {
      case NetworkHealthTier.excellent:
        return const Color(0xFF2E7D32);
      case NetworkHealthTier.fair:
        return const Color(0xFF2B6CB0);
      case NetworkHealthTier.poor:
        return const Color(0xFFD97706);
      case NetworkHealthTier.degraded:
        return const Color(0xFFC53030);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diagnostic = context.watch<DiagnosticProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tierColor = _getTierColor(diagnostic.currentTier);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity 3: Performance Throttle"),
        actions: [
          IconButton(
            tooltip: "Run Test",
            icon: diagnostic.isRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: diagnostic.isRunning
                ? null
                : () async {
                    _showToast(context, "Running diagnostic sequence...");
                    await diagnostic.runFullDiagnostic();
                    if (context.mounted) {
                      _showToast(context, "Completed! Tier: ${diagnostic.currentTier.name.toUpperCase()}");
                    }
                  },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Tier Banner
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "CURRENT HEALTH TIER",
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        StatusBadge(
                          label: diagnostic.currentTier.name.toUpperCase(),
                          color: tierColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (diagnostic.isRunning) ...[
                      LinearProgressIndicator(
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      diagnostic.stepProgressMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Diagnostic Sequence Metrics Grid
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: "Idle Latency",
                    value: diagnostic.idlePingMs.toStringAsFixed(0),
                    unit: "ms",
                    icon: Icons.speed,
                    color: tierColor,
                    subtitle: "Baseline ping",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricTile(
                    label: "Download",
                    value: diagnostic.downloadSpeedMbps.toStringAsFixed(1),
                    unit: "Mbps",
                    icon: Icons.arrow_downward_rounded,
                    color: tierColor,
                    subtitle: "${diagnostic.downloadPingMs.toStringAsFixed(0)}ms loaded",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: "Upload",
                    value: diagnostic.uploadSpeedMbps.toStringAsFixed(1),
                    unit: "Mbps",
                    icon: Icons.arrow_upward_rounded,
                    color: tierColor,
                    subtitle: "${diagnostic.uploadPingMs.toStringAsFixed(0)}ms loaded",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetricTile(
                    label: "Auto Test",
                    value: diagnostic.isAutoDiagnosticRunning ? "ON" : "OFF",
                    icon: Icons.timer_outlined,
                    color: diagnostic.isAutoDiagnosticRunning ? AppTheme.info : Colors.grey,
                    subtitle: "Every 25s",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Actions & Preset Tiers
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: diagnostic.isRunning
                                ? null
                                : () async {
                                    _showToast(context, "Testing network...");
                                    await diagnostic.runFullDiagnostic();
                                    if (context.mounted) {
                                      _showToast(context, "Finished: ${diagnostic.currentTier.name.toUpperCase()}");
                                    }
                                  },
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text("Run Diagnostic", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final next = !diagnostic.isAutoDiagnosticRunning;
                              diagnostic.toggleAutoDiagnostic(next);
                              _showToast(context, next ? "Auto test enabled" : "Auto test stopped");
                            },
                            icon: Icon(
                              diagnostic.isAutoDiagnosticRunning ? Icons.pause : Icons.repeat,
                              size: 16,
                            ),
                            label: Text(
                              diagnostic.isAutoDiagnosticRunning ? "Stop Auto" : "Auto (25s)",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Simulation Presets (Select Tier):",
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPresetBtn(
                            context,
                            tier: NetworkHealthTier.excellent,
                            label: "Excellent",
                            current: diagnostic.currentTier,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildPresetBtn(
                            context,
                            tier: NetworkHealthTier.fair,
                            label: "Fair",
                            current: diagnostic.currentTier,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildPresetBtn(
                            context,
                            tier: NetworkHealthTier.poor,
                            label: "Poor",
                            current: diagnostic.currentTier,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildPresetBtn(
                            context,
                            tier: NetworkHealthTier.degraded,
                            label: "Degraded",
                            current: diagnostic.currentTier,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Adaptive UI Showcase
            SectionHeader(
              title: "Adaptive Content Showcase",
              trailing: StatusBadge(
                label: diagnostic.currentTier.name.toUpperCase(),
                color: tierColor,
                isSmall: true,
              ),
            ),
            const SizedBox(height: 4),

            _buildAdaptiveShowcase(context, diagnostic.currentTier),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetBtn(
    BuildContext context, {
    required NetworkHealthTier tier,
    required String label,
    required NetworkHealthTier current,
  }) {
    final isSelected = tier == current;
    final color = _getTierColor(tier);

    return InkWell(
      onTap: () {
        context.read<DiagnosticProvider>().setManualTierPreset(tier);
        _showToast(context, "Switched to $label Tier");
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : null,
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveShowcase(BuildContext context, NetworkHealthTier tier) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (tier) {
      case NetworkHealthTier.excellent:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("HD Multimedia Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                    StatusBadge(label: "4K Ready", color: AppTheme.success, isSmall: true),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isDark ? const Color(0xFF242C38) : const Color(0xFFE2E8F0),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.satellite_alt_rounded, size: 36, color: Colors.blueGrey[400]),
                        const SizedBox(height: 4),
                        const Text("HD Satellite Map & LIDAR (2.4 MB)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case NetworkHealthTier.fair:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Compressed Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                    StatusBadge(label: "Optimized", color: AppTheme.info, isSmall: true),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isDark ? const Color(0xFF1E242E) : const Color(0xFFEDF2F7),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.image_outlined, size: 22, color: Colors.blueGrey),
                      SizedBox(width: 10),
                      Text("Compressed Map Asset (180 KB)", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case NetworkHealthTier.poor:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Data Saver Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                    StatusBadge(label: "Throttled", color: AppTheme.warning, isSmall: true),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.data_saver_on_rounded, size: 18, color: AppTheme.warning),
                      SizedBox(width: 8),
                      Text("Media replaced with lightweight vector placeholders.", style: TextStyle(fontSize: 11.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case NetworkHealthTier.degraded:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Text-Only Emergency Mode", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger)),
                    StatusBadge(label: "Degraded", color: AppTheme.danger, isSmall: true),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "High latency detected. All media blocked to preserve bandwidth.",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
    }
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
