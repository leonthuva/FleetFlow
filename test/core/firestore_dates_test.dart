import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fleet_flow/core/firestore_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseFirestoreDate', () {
    test('returns null for null', () {
      expect(parseFirestoreDate(null), isNull);
    });

    test('returns the original DateTime', () {
      final date = DateTime.utc(2026, 11, 15, 12, 30);

      expect(parseFirestoreDate(date), same(date));
    });

    test('parses a Firestore Timestamp', () {
      final date = DateTime.utc(2026, 11, 15, 12, 30);
      final timestamp = Timestamp.fromDate(date);

      final parsed = parseFirestoreDate(timestamp);

      expect(parsed, isNotNull);
      expect(parsed!.isAtSameMomentAs(date), isTrue);
    });

    test('parses Unix milliseconds as UTC', () {
      final date = DateTime.utc(2026, 11, 15, 12, 30);

      final parsed = parseFirestoreDate(date.millisecondsSinceEpoch);

      expect(parsed, date);
      expect(parsed!.isUtc, isTrue);
    });

    test('parses an ISO-8601 string', () {
      final parsed = parseFirestoreDate('2026-11-15T12:30:00.000Z');

      expect(parsed, DateTime.utc(2026, 11, 15, 12, 30));
    });

    test('returns null for an invalid string', () {
      expect(parseFirestoreDate('not-a-date'), isNull);
    });

    test('returns null for an unsupported object', () {
      expect(parseFirestoreDate(Object()), isNull);
    });

    test('uses a legacy toDate method when present', () {
      final date = DateTime.utc(2026, 11, 15, 12, 30);

      final parsed = parseFirestoreDate(_LegacyDate(date));

      expect(parsed, date);
    });

    test('returns null when a legacy toDate method returns a non-DateTime', () {
      expect(parseFirestoreDate(const _InvalidLegacyDate()), isNull);
    });
  });
}

class _LegacyDate {
  const _LegacyDate(this.value);

  final DateTime value;

  DateTime toDate() => value;
}

class _InvalidLegacyDate {
  const _InvalidLegacyDate();

  String toDate() => 'invalid';
}
