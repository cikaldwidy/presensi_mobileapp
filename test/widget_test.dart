import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_mobileapp/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows login screen when there is no saved token',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PresensiApp());
    await tester.pumpAndSettle();

    expect(find.text('Presensi RS'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
