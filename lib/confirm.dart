import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';

Future<void> confirmDelete(BuildContext context, String message, VoidCallback onConfirm) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonDelete),
          ),
        ],
      );
    },
  );
  if (confirmed == true) onConfirm();
}
