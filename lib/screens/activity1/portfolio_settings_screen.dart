import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_badge.dart';
import '../../providers/app_settings_provider.dart';

class PortfolioSettingsScreen extends StatefulWidget {
  const PortfolioSettingsScreen({super.key});

  @override
  State<PortfolioSettingsScreen> createState() => _PortfolioSettingsScreenState();
}

class _PortfolioSettingsScreenState extends State<PortfolioSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _partnerController;
  late TextEditingController _courseController;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    _nameController = TextEditingController(text: settings.studentName);
    _partnerController = TextEditingController(text: settings.partnerName);
    _courseController = TextEditingController(text: settings.courseSection);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _partnerController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      context.read<AppSettingsProvider>().updateProfile(
        studentName: _nameController.text,
        partnerName: _partnerController.text,
        courseSection: _courseController.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile saved! Dashboard updated."),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity 1: Portfolio & Settings"),
        actions: [
          IconButton(
            tooltip: "Toggle Theme",
            icon: Icon(settings.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => context.read<AppSettingsProvider>().toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Switcher Card
            Card(
              child: ListTile(
                leading: Icon(
                  settings.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  color: isDark ? Colors.amber[300] : Colors.amber[700],
                ),
                title: const Text("App Theme", style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(settings.isDarkMode ? "Dark Mode" : "Light Mode"),
                trailing: Switch.adaptive(
                  value: settings.isDarkMode,
                  activeTrackColor: Colors.blueGrey,
                  onChanged: (_) => context.read<AppSettingsProvider>().toggleTheme(),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const SectionHeader(title: "Student Profile"),
            const SizedBox(height: 4),

            // Profile Edit Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: "Your Name",
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                        ),
                        validator: (v) => v!.trim().isEmpty ? "Name required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _partnerController,
                        decoration: const InputDecoration(
                          labelText: "Partner Name",
                          prefixIcon: Icon(Icons.people_outline, size: 20),
                        ),
                        validator: (v) => v!.trim().isEmpty ? "Partner name required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _courseController,
                        decoration: const InputDecoration(
                          labelText: "Course / Section",
                          prefixIcon: Icon(Icons.school_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text("Save Changes"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const SectionHeader(title: "Current Active Session"),
            const SizedBox(height: 4),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow("Lead Student", settings.studentName, isDark),
                    const Divider(height: 16),
                    _buildInfoRow("Pair Partner", settings.partnerName, isDark),
                    const Divider(height: 16),
                    _buildInfoRow("Course Section", settings.courseSection, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
