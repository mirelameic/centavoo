import 'dart:convert';
import 'dart:io';

void main() {
  final ptBrFile = File('lib/l10n/arb/app_pt_BR.arb');
  final ptFile = File('lib/l10n/arb/app_pt.arb');
  final enFile = File('lib/l10n/arb/app_en.arb');
  final ptBr = jsonDecode(ptBrFile.readAsStringSync()) as Map<String, dynamic>;
  final pt = jsonDecode(ptFile.readAsStringSync()) as Map<String, dynamic>;
  final en = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;

  bool hasStaleKeys(Map<String, dynamic> target) =>
      target.keys.any((key) => !key.startsWith('@') && !ptBr.containsKey(key));

  var enAdded = 0;
  for (final key in ptBr.keys) {
    if (key.startsWith('@')) continue;
    if (!en.containsKey(key)) {
      en[key] = '[TODO en] ${ptBr[key]}';
      enAdded++;
    }
  }
  var enSynced = enAdded > 0 || hasStaleKeys(en);

  var ptSynced = pt['@@locale'] != 'pt' || hasStaleKeys(pt);
  pt['@@locale'] = 'pt';
  for (final key in ptBr.keys) {
    if (key.startsWith('@')) continue;
    if (pt[key] != ptBr[key]) {
      pt[key] = ptBr[key];
      ptSynced = true;
    }
  }

  if (!enSynced && !ptSynced) {
    stdout.writeln('Nothing to draft — app_en.arb and app_pt.arb already match app_pt_BR.arb.');
    return;
  }

  Map<String, dynamic> ordered(Map<String, dynamic> template, Map<String, dynamic> target) {
    final out = <String, dynamic>{'@@locale': target['@@locale']};
    for (final key in template.keys) {
      if (key.startsWith('@')) continue;
      if (target.containsKey(key)) out[key] = target[key];
    }
    return out;
  }

  if (enSynced) {
    enFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(ordered(ptBr, en)));
    if (enAdded > 0) {
      stdout.writeln('Drafted $enAdded missing key(s) into app_en.arb — search for "[TODO en]" and fix by hand.');
    } else {
      stdout.writeln('Dropped stale key(s) from app_en.arb no longer present in app_pt_BR.arb.');
    }
  }
  if (ptSynced) {
    ptFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(ordered(ptBr, pt)));
    stdout.writeln('Synced app_pt.arb (the generic fallback gen-l10n requires) from app_pt_BR.arb.');
  }
}
