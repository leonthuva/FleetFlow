import 'dart:math';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/core/tracking_code.dart';
import 'package:fleet_flow/screens/auth/login_screen.dart';
import 'package:fleet_flow/providers/auth_provider.dart';
import 'package:fleet_flow/screens/customer/track_delivery_screen.dart';
import 'package:fleet_flow/services/delivery_service.dart';

void main() {
  group('TrackingCode', () {
    test('generates 12 valid unambiguous characters', () {
      final seen = <String>{};
      for (var i = 0; i < 500; i++) {
        final c = TrackingCode.generate();
        expect(c, hasLength(12));
        expect(TrackingCode.isValid(c), isTrue);
        expect(c, isNot(matches(RegExp('[01OI]'))));
        seen.add(c);
      }
      expect(seen, hasLength(500));
    });
    test('normalizes case, spaces and dashes; formats in groups of four', () {
      expect(TrackingCode.normalize(' abcd-efgh jklm '), 'ABCDEFGHJKLM');
      expect(TrackingCode.format('ABCDEFGHJKLM'), 'ABCD-EFGH-JKLM');
      expect(TrackingCode.isValid('ABCDEFGHJKL'), isFalse);
      expect(TrackingCode.isValid('ABCDEFGHJKL0'), isFalse);
    });
    test('is deterministic only for a seeded random', () {
      expect(
          TrackingCode.generate(Random(1)), TrackingCode.generate(Random(1)));
    });
  });

  group('TrackDeliveryScreen', () {
    late FakeFirebaseFirestore db;
    late DeliveryService service;
    setUp(() {
      db = FakeFirebaseFirestore();
      service = DeliveryService(firestore: db, currentUid: () => null);
    });

    testWidgets('asks for a valid code before looking anything up',
        (tester) async {
      await tester
          .pumpWidget(MaterialApp(home: TrackDeliveryScreen(service: service)));
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.tap(find.text('Track'));
      await tester.pump();
      expect(find.textContaining('12-character'), findsOneWidget);
    });

    testWidgets('shows status and first names only for a known code',
        (tester) async {
      await db.doc('trackingLinks/ABCDEFGHJKLM').set({
        'deliveryId': 'DEL-0001',
        'status': 'in_transit',
        'recipientFirstName': 'Kamal',
        'driverFirstName': 'Nimal',
      });
      await tester
          .pumpWidget(MaterialApp(home: TrackDeliveryScreen(service: service)));
      await tester.enterText(find.byType(TextField), 'abcd-efgh-jklm');
      await tester.tap(find.text('Track'));
      await tester.pumpAndSettle();
      expect(find.text('In Transit'), findsOneWidget);
      expect(find.text('Hello Kamal'), findsOneWidget);
      expect(find.text('Driver: Nimal'), findsOneWidget);
      expect(find.textContaining('DEL-0001'), findsNothing);
    });

    testWidgets('unknown code gives a clear not-found message', (tester) async {
      await tester
          .pumpWidget(MaterialApp(home: TrackDeliveryScreen(service: service)));
      await tester.enterText(find.byType(TextField), 'AAAAAAAAAAAA');
      await tester.tap(find.text('Track'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No delivery found'), findsOneWidget);
    });

    testWidgets('login screen links to public tracking without sign-in',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = AuthProvider();
      addTearDown(auth.dispose);
      await tester
          .pumpWidget(MaterialApp(home: LoginScreen(authProvider: auth)));
      await tester.ensureVisible(find.text('Track a delivery'));
      await tester.tap(find.text('Track a delivery'));
      await tester.pumpAndSettle();
      expect(find.text('Track a Delivery'), findsOneWidget);
    });
  });
}
