import 'package:flutter_test/flutter_test.dart';
import 'package:master_compilation_app/main.dart';

void main() {
  testWidgets('App launches and displays dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const MasterCompilationApp());
    expect(find.textContaining('Mobile Computing'), findsWidgets);
  });
}
