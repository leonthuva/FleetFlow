import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/core/proof_image.dart';
import 'package:fleet_flow/services/storage_service.dart';
import 'package:fleet_flow/services/supabase_service.dart';
import 'package:fleet_flow/services/delivery_service.dart';

const attempt = '12345678-1234-4234-8234-123456789abc';

class FakeGateway implements ProofGateway {
  final List<Map<String, dynamic>> calls = [];
  bool failUpload = false, failComplete = false, invalidVerification = false;
  int uploads = 0;
  Map<String, dynamic>? begin;
  Future<void> Function()? persist;
  Completer<void>? pauseUpload;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> body) async {
    calls.add(body);
    if (body['action'] == 'begin') {
      begin = body;
      return {
        'state': 'pending',
        'bucket': 'delivery-proofs',
        'attemptId': attempt,
        'path': 'driver/D1/$attempt.png'
      };
    }
    if (body['action'] == 'discard') return {'state': 'discarded'};
    if (body['action'] == 'view') {
      return {
        'url':
            'https://example.supabase.co/storage/v1/object/sign/delivery-proofs/driver/D1/$attempt.png?token=temporary',
        'expiresIn': 60
      };
    }
    if (failComplete) {
      failComplete = false;
      throw StateError('Injected verification failure');
    }
    await persist?.call();
    return {
      'state': 'completed',
      'proof': {
        'deliveryId': 'D1',
        'driverId': 'driver',
        'uploadId': attempt,
        'storageProvider': 'supabase',
        'bucket': 'delivery-proofs',
        'storagePath': 'driver/D1/$attempt.png',
        'sha256': begin!['sha256'],
        'mimeType': 'image/png',
        'sizeBytes': begin!['sizeBytes'],
        'verificationStatus': invalidVerification ? 'pending' : 'verified',
        'verifiedAt': DateTime(2026).toIso8601String(),
        'timestamp': DateTime(2026).toIso8601String(),
        'capturedLocation': {}
      }
    };
  }

  @override
  Future<void> upload(String path, Uint8List bytes, String mimeType) async {
    uploads++;
    await pauseUpload?.future;
    if (failUpload) {
      failUpload = false;
      throw StateError('Injected upload failure');
    }
    if (uploads > 1) throw const ExistingProofObject();
  }
}

void main() {
  final png = File('supabase/tests/fixtures/proof.png').readAsBytesSync();
  for (final entry in [
    ('jpg', 'image/jpeg'),
    ('png', 'image/png'),
    ('webp', 'image/webp')
  ]) {
    test('actual ${entry.$2} decoder validates content and digest', () {
      final bytes =
          File('supabase/tests/fixtures/proof.${entry.$1}').readAsBytesSync();
      final info = validateProofImage(bytes);
      expect(info.mimeType, entry.$2);
      expect(info.width, 2);
      expect(info.height, 2);
      expect(info.sha256, hasLength(64));
    });
  }
  test('empty oversized fake and truncated photos are rejected', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List(5000001),
      Uint8List.fromList([255, 216, 255, 0]),
      Uint8List.fromList(png.take(36).toList())
    ]) {
      expect(() => validateProofImage(bytes), throwsFormatException);
    }
  });
  test(
      'Firebase token bridge requires approved role claim and uses Firebase session only',
      () async {
    final auth = MockFirebaseAuth(
        mockUser:
            MockUser(uid: 'driver', customClaim: {'role': 'authenticated'}),
        signedIn: true);
    expect(
        await FirebaseProofTokenProvider(auth: auth).token(forceRefresh: true),
        isNotEmpty);
    final missing =
        MockFirebaseAuth(mockUser: MockUser(uid: 'driver'), signedIn: true);
    await expectLater(
        FirebaseProofTokenProvider(auth: missing).token(), throwsStateError);
    await auth.signOut();
    await expectLater(
        FirebaseProofTokenProvider(auth: auth).token(), throwsStateError);
  });
  test('upload and trusted verification produce only a private canonical proof',
      () async {
    final gateway = FakeGateway();
    final storage =
        StorageService(gateway: gateway, newAttemptId: () => attempt);
    final proof = await storage.submitProof(deliveryId: 'D1', bytes: png);
    expect(proof.isVerifiedPrivateProof, isTrue);
    expect(proof.photoURL, isEmpty);
    expect(proof.toMap().containsKey('photoUrl'), isFalse);
    expect(gateway.calls.map((c) => c['action']), ['begin', 'complete']);
    expect(gateway.uploads, 1);
    expect(await storage.signedProofUrl('D1'),
        contains('/object/sign/delivery-proofs/'));
  });
  test(
      'failed upload and verification retry the same idempotency key without fake success',
      () async {
    final gateway = FakeGateway()..failUpload = true;
    final storage =
        StorageService(gateway: gateway, newAttemptId: () => attempt);
    await expectLater(
        storage.submitProof(deliveryId: 'D1', bytes: png), throwsStateError);
    expect(gateway.calls.any((c) => c['action'] == 'complete'), isFalse);
    gateway.failComplete = true;
    await expectLater(
        storage.submitProof(deliveryId: 'D1', bytes: png), throwsStateError);
    final result = await storage.submitProof(deliveryId: 'D1', bytes: png);
    expect(result.isVerifiedPrivateProof, isTrue);
    expect(
        gateway.calls
            .where((c) => c['action'] == 'begin')
            .map((c) => c['attemptId'])
            .toSet(),
        {attempt});
  });
  test(
      'duplicate taps and unverified responses are rejected; discard uses the broker',
      () async {
    final gateway = FakeGateway()..pauseUpload = Completer<void>();
    final storage =
        StorageService(gateway: gateway, newAttemptId: () => attempt);
    final first = storage.submitProof(deliveryId: 'D1', bytes: png);
    await expectLater(
        storage.submitProof(deliveryId: 'D1', bytes: png), throwsStateError);
    gateway.pauseUpload!.complete();
    await first;
    gateway.invalidVerification = true;
    await expectLater(
        storage.submitProof(deliveryId: 'D1', bytes: png), throwsStateError);
    await storage.discardPending('D1');
    expect(gateway.calls.last['action'], 'discard');
  });
  test(
      'delivery service confirms server persistence and preserves lifecycle/ownership',
      () async {
    final db = FakeFirebaseFirestore();
    await db.doc('users/driver').set({'role': 'driver'});
    await db
        .doc('deliveries/D1')
        .set({'driverId': 'driver', 'status': 'arrived'});
    final gateway = FakeGateway();
    final service = DeliveryService(
        firestore: db,
        currentUid: () => 'driver',
        storage: StorageService(gateway: gateway, newAttemptId: () => attempt));
    await expectLater(
        service.updateStatus(deliveryId: 'D1', newStatus: 'completed'),
        throwsStateError);
    await expectLater(
        service.submitProofOfDelivery(
            deliveryId: 'D1', photoBytes: png, location: {}),
        throwsStateError);
    gateway.persist = () async {
      await db.doc('deliveries/D1').update({
        'status': 'completed',
        'proofStoragePath': 'driver/D1/$attempt.png'
      });
    };
    final proof = await service
        .submitProofOfDelivery(deliveryId: 'D1', photoBytes: png, location: {});
    expect(proof.isVerifiedPrivateProof, isTrue);
    expect(service.getDeliveryById('D1')!.status, 'completed');
    await db.doc('deliveries/D1').update({'driverId': 'other'});
    await expectLater(
        service.submitProofOfDelivery(
            deliveryId: 'D1', photoBytes: png, location: {}),
        throwsStateError);
  });
}
