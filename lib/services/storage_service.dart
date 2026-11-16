import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_config.dart';
import '../core/proof_image.dart';
import '../models/delivery_proof.dart';
import 'supabase_service.dart';

abstract interface class ProofGateway {
  Future<Map<String, dynamic>> call(Map<String, dynamic> body);
  Future<void> upload(String path, Uint8List bytes, String mimeType);
}

class ExistingProofObject implements Exception {
  const ExistingProofObject();
}

class SupabaseProofGateway implements ProofGateway {
  SupabaseProofGateway(
      {SupabaseClient? client, FirebaseProofTokenProvider? tokens})
      : _client = client,
        _tokens = tokens ?? FirebaseProofTokenProvider();
  final SupabaseClient? _client;
  final FirebaseProofTokenProvider _tokens;
  SupabaseClient get client => _client ?? Supabase.instance.client;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> body) async {
    final token = await _tokens.token(forceRefresh: true);
    try {
      final response = await client.functions.invoke('proof-broker',
          headers: {'Authorization': 'Bearer $token'}, body: body);
      if (response.status != 200 || response.data is! Map) {
        throw StateError(
            'Proof service did not confirm the operation. Retry safely.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      final error = details is Map ? details['error'] : null;
      throw StateError(error is Map && error['message'] is String
          ? error['message'] as String
          : 'Proof service is unavailable. Retry the same photograph.');
    }
  }

  @override
  Future<void> upload(String path, Uint8List bytes, String mimeType) async {
    await _tokens.token(forceRefresh: true);
    try {
      await client.storage.from('delivery-proofs').uploadBinary(path, bytes,
          fileOptions: FileOptions(
              contentType: mimeType, upsert: false, cacheControl: '0'));
    } on StorageException catch (e) {
      if (e.statusCode == '409' ||
          e.error == 'Duplicate' ||
          e.message.contains('already exists')) {
        throw const ExistingProofObject();
      }
      throw StateError(
          'Private photo upload failed. Retry the same photograph.');
    }
  }
}

class StorageService {
  StorageService({ProofGateway? gateway, String Function()? newAttemptId})
      : _gateway = gateway,
        _newAttemptId = newAttemptId ?? _uuid;
  final ProofGateway? _gateway;
  final String Function() _newAttemptId;
  final _pending = <String, String>{};
  final _active = <String>{};
  bool get isConfigured => _gateway != null || AppConfig.proofStorageConfigured;
  ProofGateway get gateway => _gateway ?? SupabaseProofGateway();
  String? notificationWarning;
  static String _uuid() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<DeliveryProof> submitProof(
      {required String deliveryId,
      required Uint8List bytes,
      Map<String, dynamic> location = const {},
      String? notes,
      String? recipientName,
      DateTime? capturedAt}) async {
    if (!isConfigured) {
      throw StateError(
          'Secure Supabase proof storage is not configured. No photo was uploaded and the delivery was not completed.');
    }
    if (!_active.add(deliveryId)) {
      throw StateError('A proof submission is already in progress.');
    }
    try {
      final image = await compute(validateProofImage, bytes);
      final id = _pending.putIfAbsent(deliveryId, _newAttemptId);
      final response = await gateway.call({
        'action': 'begin',
        'deliveryId': deliveryId,
        'attemptId': id,
        'mimeType': image.mimeType,
        'sizeBytes': image.sizeBytes,
        'sha256': image.sha256,
        'capturedLocation': location,
        'notes': notes ?? '',
        'recipientName': recipientName ?? '',
        if (capturedAt != null)
          'capturedAt': capturedAt.toUtc().toIso8601String()
      });
      Map<String, dynamic> completed = response;
      if (response['state'] != 'completed') {
        final path = response['path'], attempt = response['attemptId'];
        if (response['bucket'] != 'delivery-proofs' ||
            path is! String ||
            attempt is! String ||
            !RegExp(r'^[A-Za-z0-9_-]{1,128}/[A-Za-z0-9_-]{1,128}/[0-9a-f-]{36}\.(jpg|png|webp)$')
                .hasMatch(path) ||
            path.split('/')[1] != deliveryId) {
          throw StateError(
              'Proof service returned an invalid private upload authorization.');
        }
        _pending[deliveryId] = attempt;
        try {
          await gateway.upload(path, bytes, image.mimeType);
        } on ExistingProofObject {
          /* Lost-response retry: only trusted byte verification can turn this into success. */
        }
        completed = await gateway.call({
          'action': 'complete',
          'deliveryId': deliveryId,
          'attemptId': attempt
        });
      }
      final data = completed['proof'];
      if (completed['state'] != 'completed' ||
          data is! Map ||
          data['deliveryId'] != deliveryId ||
          data['verificationStatus'] != 'verified' ||
          data['storageProvider'] != 'supabase' ||
          data['bucket'] != 'delivery-proofs' ||
          data['sha256'] != image.sha256) {
        throw StateError(
            'Trusted proof verification did not confirm completion.');
      }
      final proof = DeliveryProof.fromMap(Map<String, dynamic>.from(data),
          documentId: deliveryId);
      notificationWarning = completed['notificationWarning'] as String? ??
          data['notificationWarning'] as String?;
      _pending.remove(deliveryId);
      return proof;
    } finally {
      _active.remove(deliveryId);
    }
  }

  Future<void> discardPending(String deliveryId) async {
    if (!isConfigured) {
      throw StateError('Secure proof storage is not configured.');
    }
    if (_active.contains(deliveryId)) {
      throw StateError('Wait for the current submission to finish.');
    }
    await gateway.call({'action': 'discard', 'deliveryId': deliveryId});
    _pending.remove(deliveryId);
  }

  Future<String> signedProofUrl(String deliveryId) async {
    if (!isConfigured) {
      throw StateError('Secure proof viewing is not configured.');
    }
    final result =
        await gateway.call({'action': 'view', 'deliveryId': deliveryId});
    final uri = Uri.tryParse(result['url'] as String? ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.host.endsWith('.supabase.co') ||
        !uri.path.startsWith('/storage/v1/object/sign/delivery-proofs/')) {
      throw StateError(
          'Proof service returned an invalid private viewing URL.');
    }
    return uri.toString();
  }
}
