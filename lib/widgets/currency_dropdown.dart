import 'package:flutter/material.dart';
import 'package:centavoo/logic/format.dart';

Widget currencyDropdown({required String label, required String value, required ValueChanged<String> onChanged}) {
  final options = supportedCurrencies.contains(value) ? supportedCurrencies : [value, ...supportedCurrencies];
  return DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final c in options)
        DropdownMenuItem(value: c, child: Text(currencySymbol(c) == c ? c : '$c (${currencySymbol(c)})')),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}
