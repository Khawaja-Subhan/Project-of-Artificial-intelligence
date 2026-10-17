import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:disco_meter_reader/main.dart';
import 'package:disco_meter_reader/services/storage/database_service.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('DISCO Meter Reader app initializes properly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // Initialize mock database service
    final db = DatabaseService.instance;
    await db.initialize();

    // Build the app
    await tester.pumpWidget(const DiscoMeterReaderApp());
    await tester.pump();

    // Verify main shell loads
    expect(find.byType(DiscoMeterReaderApp), findsOneWidget);
  });
}



