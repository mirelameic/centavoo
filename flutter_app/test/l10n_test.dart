import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every pt key has an en translation', () {
    final pt = jsonDecode(File('lib/l10n/arb/app_pt_BR.arb').readAsStringSync()) as Map<String, dynamic>;
    final en = jsonDecode(File('lib/l10n/arb/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final ptKeys = pt.keys.where((k) => !k.startsWith('@')).toSet();
    final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
    expect(enKeys, ptKeys, reason: 'app_en.arb is missing or has extra keys compared to app_pt.arb');
  });
}
