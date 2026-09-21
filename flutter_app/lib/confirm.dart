import 'package:flutter/material.dart';

Future<void> confirmDelete(BuildContext context, String message, VoidCallback onConfirm) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  if (confirmed == true) onConfirm();
}
