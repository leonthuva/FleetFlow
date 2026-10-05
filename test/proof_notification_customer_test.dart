import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/models/app_notification.dart';
import 'package:fleet_flow/models/delivery.dart';
import 'package:fleet_flow/models/delivery_proof.dart';
import 'package:fleet_flow/providers/notification_provider.dart';
import 'package:fleet_flow/screens/customer/customer_tracking_screen.dart';
import 'package:fleet_flow/screens/notifications/notifications_screen.dart';
import 'package:fleet_flow/screens/proof/proof_of_delivery_screen.dart';
import 'package:fleet_flow/services/delivery_service.dart';

void main() {
  group('Member 5: Delivery Proof & Notification Models', () {
    test('DeliveryProof fromMap and toMap match agreed Firestore schema', () {
      final now = DateTime.now();
      final proof = DeliveryProof(
        id: 'proof_123',
        deliveryId: 'DEL-8801',
        photoURL: 'https://storage.googleapis.com/test.jpg',
        timestamp: now,
        capturedLocation: {
          'lat': 37.7749,
          'lng': -122.4194,
          'address': '742 Evergreen Terrace',
        },
        notes: 'Left at reception',
        recipientName: 'Alice',
      );

      final map = proof.toMap();
      expect(map['id'], 'proof_123');
      expect(map['deliveryId'], 'DEL-8801');
      expect(map['photoURL'], 'https://storage.googleapis.com/test.jpg');
      expect(map['capturedLocation']['lat'], 37.7749);
      expect(map['recipientName'], 'Alice');

      final reconstructed = DeliveryProof.fromMap(map);
      expect(reconstructed.id, 'proof_123');
      expect(reconstructed.deliveryId, 'DEL-8801');
      expect(reconstructed.notes, 'Left at reception');
    });

    test('AppNotification helpers return correct types and colors', () {
      final notif = AppNotification(
        notificationId: 'n1',
        recipientId: 'all_managers',
        title: 'Delivered',
        message: 'Order completed',
        type: NotificationType.deliveryCompleted,
        timestamp: DateTime.now(),
        read: false,
      );

      expect(notif.read, isFalse);
      expect(NotificationType.getLabel(notif.type), 'Delivered');
      expect(NotificationType.getColor(notif.type), Colors.green);
      expect(NotificationType.getIcon(notif.type), Icons.check_circle_outline);
    });
  });

  group('Member 5: Delivery State Machine & Service', () {
    test('DeliveryService lifecycle and proof completion flow', () async {
      final service = DeliveryService();
      final initial = service.getDeliveryById('DEL-8803');
      expect(initial, isNotNull);
      expect(initial!.status, DeliveryStatus.assigned);

      // Advance status
      final updated = await service.updateStatus(
        deliveryId: 'DEL-8803',
        newStatus: DeliveryStatus.pickedUp,
      );
      expect(updated.status, DeliveryStatus.pickedUp);

      // Submit mock proof
      final proof = await service.submitProofOfDelivery(
        deliveryId: 'DEL-8803',
        location: {'lat': 37.0, 'lng': -122.0, 'address': '45 West Elm'},
        notes: 'Package handed directly',
        recipientName: 'Bob Vance',
      );

      expect(proof.deliveryId, 'DEL-8803');
      final completed = service.getDeliveryById('DEL-8803');
      expect(completed!.status, DeliveryStatus.completed);
      expect(completed.proofPhotoUrl, isNotEmpty);
    });
  });

  group('Member 5: Screen Widgets', () {
    testWidgets('CustomerTrackingScreen renders order status and progress stepper',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerTrackingScreen(deliveryId: 'DEL-8801'),
        ),
      );

      expect(find.text('Track Your Delivery'), findsOneWidget);
      expect(find.text('ORDER DEL-8801'), findsOneWidget);
      expect(find.text('Driver is On The Way to You'), findsOneWidget);
      expect(find.text('Your Driver: Marcus Vance'), findsOneWidget);
      expect(find.text('In Transit'), findsNWidgets(2));
    });

    testWidgets('CustomerTrackingScreen displays Proof of Delivery photo when delivered',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerTrackingScreen(deliveryId: 'DEL-8804'),
        ),
      );

      expect(find.text('Delivered & Handed Over'), findsOneWidget);
      expect(find.text('Proof of Delivery (Photo Confirmed)'), findsOneWidget);
      expect(find.text('Handover to: G. Fisherman'), findsOneWidget);
    });

    testWidgets('NotificationsScreen displays feed and handles filters',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = NotificationProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(notificationProvider: provider),
        ),
      );

      expect(find.text('Fleet Notifications'), findsOneWidget);
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.textContaining('Unread ('), findsOneWidget);
      expect(find.text('Proof Submitted & Completed'), findsOneWidget);
    });

    testWidgets('ProofOfDeliveryScreen shows explanation dialog on camera tap',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const delivery = Delivery(
        id: 'DEL-9900',
        destination: '123 Main St',
        assignedDriverId: 'Test Driver',
        status: DeliveryStatus.arrived,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ProofOfDeliveryScreen(delivery: delivery),
        ),
      );

      expect(find.text('Proof of Delivery (POD)'), findsOneWidget);
      expect(find.text('ARRIVED AT DESTINATION'), findsOneWidget);
      expect(find.text('Tap to Capture Handover Photo'), findsOneWidget);

      // Tap on photo capture area (opens source options)
      await tester.tap(find.text('Tap to Capture Handover Photo'));
      await tester.pumpAndSettle();

      expect(find.text('Take Photo with Camera'), findsOneWidget);
      await tester.tap(find.text('Take Photo with Camera'));
      await tester.pumpAndSettle();

      // Camera Permission Explanation Dialog should appear as per spec
      expect(find.text('Camera Permission Required'), findsOneWidget);
      expect(find.text('Continue to Camera'), findsOneWidget);
    });
  });
}
