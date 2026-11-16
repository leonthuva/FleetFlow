import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fleet_flow/providers/auth_provider.dart';
import 'package:fleet_flow/screens/auth/login_screen.dart';
import 'package:fleet_flow/screens/admin/admin_dashboard_screen.dart';
import 'package:fleet_flow/services/delivery_service.dart';

void main() {
  test('role comes from the UID document, never the email', () async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u', email: 'admin@example.com'));
    final provider = AuthProvider(auth: auth, firestore: db);
    addTearDown(provider.dispose);
    await db.doc('users/u').set({'role': 'driver', 'displayName': 'Driver'});
    expect(
        await provider.signIn(email: 'admin@example.com', password: 'password'),
        isTrue);
    expect(provider.currentUser!.isDriver, isTrue);
    expect(provider.currentUser!.id, 'u');
    await db.doc('users/u').update({'role': 'invalid'});
    await Future<void>.delayed(Duration.zero);
    expect(provider.currentUser, isNull);
  });
  test('missing role fails closed and sign out clears session', () async {
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'u'));
    final provider =
        AuthProvider(auth: auth, firestore: FakeFirebaseFirestore());
    addTearDown(provider.dispose);
    expect(
        await provider.signIn(
            email: 'driver@example.com', password: 'password'),
        isFalse);
    expect(provider.errorMessage, contains('approved role'));
    await provider.signOut();
    expect(provider.isAuthenticated, isFalse);
  });
  testWidgets('login validates fields and has no role impersonation controls',
      (tester) async {
    final provider = AuthProvider();
    addTearDown(provider.dispose);
    await tester
        .pumpWidget(MaterialApp(home: LoginScreen(authProvider: provider)));
    final button = find.widgetWithText(FilledButton, 'Sign In');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsNothing);
  });
  testWidgets('manager portal rejects missing verified role', (tester) async {
    final provider = AuthProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
        MaterialApp(home: AdminDashboardScreen(authProvider: provider)));
    expect(find.text('Manager Authorization Required'), findsOneWidget);
  });
  testWidgets('manager metrics and terminal history use Firestore records',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    await db.doc('users/u').set({'role': 'admin'});
    await db.doc('deliveries/D1').set({
      'recipientName': 'Customer',
      'status': 'cancelled',
      'driverId': 'd',
      'address': 'Colombo'
    });
    final auth = AuthProvider(
        auth: MockFirebaseAuth(mockUser: MockUser(uid: 'u')), firestore: db);
    addTearDown(auth.dispose);
    await auth.signIn(email: 'u@example.com', password: 'password');
    await tester.pumpWidget(MaterialApp(
        home: AdminDashboardScreen(
            authProvider: auth,
            service: DeliveryService(firestore: db, currentUid: () => 'u'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 deliveries'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'History'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery History'), findsOneWidget);
    expect(find.textContaining('D1 - Customer'), findsOneWidget);
  });
}
