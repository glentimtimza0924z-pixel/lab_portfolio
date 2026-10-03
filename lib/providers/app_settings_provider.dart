import 'package:flutter/material.dart';

class AppSettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _studentName = "Alex Rivera";
  String _partnerName = "Taylor Smith";
  String _courseSection = "Mobile Computing - CS401";
  String _studentId = "2024-MC-0192";

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  String get studentName => _studentName;
  String get partnerName => _partnerName;
  String get courseSection => _courseSection;
  String get studentId => _studentId;

  String get displayName => _studentName;
  String get pairNames => "$_studentName & $_partnerName";

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void updateProfile({
    required String studentName,
    required String partnerName,
    required String courseSection,
    String? studentId,
  }) {
    _studentName = studentName.trim().isEmpty ? _studentName : studentName.trim();
    _partnerName = partnerName.trim().isEmpty ? _partnerName : partnerName.trim();
    _courseSection = courseSection.trim().isEmpty ? _courseSection : courseSection.trim();
    if (studentId != null && studentId.trim().isNotEmpty) {
      _studentId = studentId.trim();
    }
    notifyListeners();
  }
}
