import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

class ValidatedProofImage {
  const ValidatedProofImage(
      this.mimeType, this.sizeBytes, this.sha256, this.width, this.height);
  final String mimeType, sha256;
  final int sizeBytes, width, height;
}

/// Pure decoder, run off the UI thread. The trusted backend repeats validation.
ValidatedProofImage validateProofImage(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 5000000) {
    throw const FormatException('Photo must be between 1 byte and 5 MB.');
  }
  image.Decoder decoder;
  String mime;
  if (bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255) {
    decoder = image.JpegDecoder();
    mime = 'image/jpeg';
  } else if (bytes.length >= 8 &&
      bytes[0] == 137 &&
      String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG' &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10) {
    decoder = image.PngDecoder();
    mime = 'image/png';
  } else if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    decoder = image.WebPDecoder();
    mime = 'image/webp';
  } else {
    throw const FormatException(
        'Choose a genuine JPEG, PNG or WebP photograph.');
  }
  try {
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width < 1 ||
        info.height < 1 ||
        info.width > 4096 ||
        info.height > 4096 ||
        info.width * info.height > 4000000 ||
        info.numFrames > 1) {
      throw const FormatException(
          'Choose a still image up to 4 megapixels. Retake the photo at a smaller size.');
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null ||
        decoded.width != info.width ||
        decoded.height != info.height) {
      throw const FormatException('The photograph is damaged or incomplete.');
    }
    return ValidatedProofImage(mime, bytes.length,
        sha256.convert(bytes).toString(), info.width, info.height);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('The photograph could not be decoded.');
  }
}
