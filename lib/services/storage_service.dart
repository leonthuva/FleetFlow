import 'dart:io';
import 'dart:typed_data';

class StorageService {
  Future<String> uploadDeliveryProof(
      {required String deliveryId, File? file, Uint8List? bytes}) async {
    throw StateError(
        'Secure proof storage is not configured. Upload is unavailable; no file was saved.');
  }
}
