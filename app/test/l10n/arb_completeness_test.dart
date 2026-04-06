import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tests that all localization keys exist in both IT and EN ARB files.
void main() {
  late Map<String, dynamic> itArb;
  late Map<String, dynamic> enArb;

  setUpAll(() {
    final itFile = File('lib/l10n/app_it.arb');
    final enFile = File('lib/l10n/app_en.arb');

    expect(itFile.existsSync(), isTrue, reason: 'app_it.arb must exist');
    expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist');

    itArb = jsonDecode(itFile.readAsStringSync()) as Map<String, dynamic>;
    enArb = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
  });

  test('IT ARB file has valid JSON', () {
    expect(itArb, isNotEmpty);
    expect(itArb['@@locale'], 'it');
  });

  test('EN ARB file has valid JSON', () {
    expect(enArb, isNotEmpty);
    expect(enArb['@@locale'], 'en');
  });

  test('All IT keys exist in EN', () {
    final itKeys = itArb.keys
        .where((k) => !k.startsWith('@'))
        .toSet();
    final enKeys = enArb.keys
        .where((k) => !k.startsWith('@'))
        .toSet();

    final missingInEn = itKeys.difference(enKeys);
    expect(
      missingInEn,
      isEmpty,
      reason: 'Keys in IT but missing in EN: $missingInEn',
    );
  });

  test('All EN keys exist in IT', () {
    final itKeys = itArb.keys
        .where((k) => !k.startsWith('@'))
        .toSet();
    final enKeys = enArb.keys
        .where((k) => !k.startsWith('@'))
        .toSet();

    final missingInIt = enKeys.difference(itKeys);
    expect(
      missingInIt,
      isEmpty,
      reason: 'Keys in EN but missing in IT: $missingInIt',
    );
  });

  test('No empty values in IT', () {
    final emptyKeys = itArb.entries
        .where((e) => !e.key.startsWith('@') && e.value is String && (e.value as String).isEmpty)
        .map((e) => e.key)
        .toList();
    expect(emptyKeys, isEmpty, reason: 'Empty values in IT: $emptyKeys');
  });

  test('No empty values in EN', () {
    final emptyKeys = enArb.entries
        .where((e) => !e.key.startsWith('@') && e.value is String && (e.value as String).isEmpty)
        .map((e) => e.key)
        .toList();
    expect(emptyKeys, isEmpty, reason: 'Empty values in EN: $emptyKeys');
  });

  test('IT and EN have the same number of keys', () {
    final itKeys = itArb.keys.where((k) => !k.startsWith('@')).length;
    final enKeys = enArb.keys.where((k) => !k.startsWith('@')).length;
    expect(itKeys, enKeys, reason: 'IT has $itKeys keys, EN has $enKeys keys');
  });

  test('At least 50 localization keys defined', () {
    final keyCount = itArb.keys.where((k) => !k.startsWith('@')).length;
    expect(keyCount, greaterThanOrEqualTo(50),
        reason: 'Expected at least 50 keys, found $keyCount');
  });
}
