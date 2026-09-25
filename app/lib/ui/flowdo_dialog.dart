import 'package:flutter/material.dart';

Future<bool> showFlowDoConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = '先留着',
  String confirmLabel = '确定',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        icon: Icon(
          destructive ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
          color: destructive ? scheme.error : scheme.primary,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
