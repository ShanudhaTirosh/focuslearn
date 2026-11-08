import 'package:flutter/material.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';

/// Safely validates and launches an online class/meeting link.
/// If the domain is not a recognised platform (Zoom, Google Meet, Microsoft Teams),
/// prompts the student with a warning modal before leaving the app.
class MeetingLauncher {
  static Future<void> launch(BuildContext context, String rawUrl) async {
    final l10n = AppLocalizations.of(context);
    final classification = validateMeetingUrl(rawUrl);

    if (classification.code != 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorInvalidFormat)),
      );
      return;
    }

    final normalized = classification.normalized ?? rawUrl;
    final uri = Uri.parse(normalized);
    final host = uri.host;
    final isKnownService = classification.provider != null && classification.provider != 'other';

    if (isKnownService) {
      await _open(context, uri);
    } else {
      if (!context.mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(l10n.plannerOpenLinkConfirm),
            content: Text(l10n.plannerOpenLinkWarning(host)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.plannerOpen),
              ),
            ],
          );
        },
      );

      if (proceed == true && context.mounted) {
        await _open(context, uri);
      }
    }
  }

  static Future<void> _open(BuildContext context, Uri uri) async {
    final l10n = AppLocalizations.of(context);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authUnknown)),
        );
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authUnknown)),
        );
      }
    }
  }
}
