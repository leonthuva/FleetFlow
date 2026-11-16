import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fleet_flow/models/delivery.dart';
import 'package:fleet_flow/models/delivery_proof.dart';
import 'package:fleet_flow/services/delivery_service.dart';
import 'package:fleet_flow/screens/proof/proof_of_delivery_screen.dart';

class Picker extends ImagePicker {
  XFile? next;
  int calls = 0;
  @override
  Future<XFile?> pickImage(
      {required ImageSource source,
      double? maxWidth,
      double? maxHeight,
      int? imageQuality,
      CameraDevice preferredCameraDevice = CameraDevice.rear,
      bool requestFullMetadata = true}) async {
    calls++;
    return next;
  }
}

class ProofService extends DeliveryService {
  bool fail = true;
  int submissions = 0;
  @override
  bool get proofStorageAvailable => true;
  @override
  Future<DeliveryProof> submitProofOfDelivery(
      {required String deliveryId,
      File? photoFile,
      Uint8List? photoBytes,
      required Map<String, dynamic> location,
      String? notes,
      String? recipientName,
      DateTime? capturedAt}) async {
    submissions++;
    if (fail) throw StateError('Network unavailable; retry the same photo.');
    return DeliveryProof(
        id: deliveryId,
        deliveryId: deliveryId,
        timestamp: DateTime(2026),
        capturedLocation: {});
  }
}

void main() {
  testWidgets(
      'camera cancellation, validated preview, retake and upload failure/retry preserve truthful completion',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picker = Picker(), service = ProofService();
    int completed = 0;
    await tester.pumpWidget(MaterialApp(
        home: ProofOfDeliveryScreen(
            delivery: const Delivery(id: 'D1', status: 'arrived'),
            service: service,
            imagePicker: picker,
            onCompleted: () => completed++)));
    await tester.tap(find.text('Tap to Capture Handover Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo with Camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(picker.calls, 0);
    expect(completed, 0);
    picker.next = XFile.fromData(File('supabase/tests/fixtures/proof.png').readAsBytesSync(), mimeType:'image/png', name:'proof.png');
    await tester.tap(find.text('Tap to Capture Handover Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pumpAndSettle();
    expect(find.text('Retake Photo'), findsOneWidget);
    picker.next = null;
    await tester.tap(find.text('Retake Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Retake Photo'), findsOneWidget);
    await tester.ensureVisible(find.text('Confirm & Complete Delivery'));
    await tester.tap(find.text('Confirm & Complete Delivery'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Network unavailable'), findsOneWidget);
    expect(completed, 0);
    expect(service.submissions, 1);
    service.fail = false;
    await tester.ensureVisible(find.text('Confirm & Complete Delivery'));
    await tester.tap(find.text('Confirm & Complete Delivery'));
    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(service.submissions, 2);
    expect(find.text('Proof verified and delivery completed.'), findsOneWidget);
  });
}
