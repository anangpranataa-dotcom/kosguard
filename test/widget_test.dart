import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosguard/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Kosguard displays AuthScreen when unauthenticated', (tester) async {
    await tester.pumpWidget(const KosGuardApp());
    await tester.pumpAndSettle();

    expect(find.text('kosguard'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Daftar'), findsOneWidget);
  });

  testWidgets('HomeShell displays shared inventory UI', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeShell(
          currentUser: KGUser(
            id: 1,
            name: 'Ahmad Rizki',
            email: 'ahmad@test.com',
            roomNumber: '08',
            propertyName: 'Kost Kemuning',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Inventaris bersama'), findsOneWidget);
    expect(find.text('Laporkan'), findsOneWidget);
  });

  test('KGClaim reads claimant identity and room from nested claimant data', () {
    final claim = KGClaim.fromJson({
      'id': 301,
      'claimant': {
        'name': 'Penghuni',
        'room_number': 'A-04',
      },
      'user': {
        'name': 'Fallback',
        'room_number': 'B-02',
      },
    });

    expect(claim.claimantName, 'Penghuni');
    expect(claim.claimantRoom, 'A-04');
  });
}
