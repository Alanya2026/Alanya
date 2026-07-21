import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/status_provider.dart';
import '../../screens/status/status_viewer_screen.dart';
import '../../talky_models.dart';

/// Ouvre le viewer sur [statusId]. Retourne `false` si introuvable / expiré.
Future<bool> openStatusById(BuildContext context, int statusId) async {
  if (statusId <= 0) return false;

  final provider = context.read<StatusProvider>();
  var found = provider.findById(statusId);
  if (found == null) {
    await provider.refresh();
    if (!context.mounted) return false;
    found = provider.findById(statusId);
  }

  if (found == null || found.isExpired) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.statusNoLongerAvailable)),
      );
    }
    return false;
  }

  final isMine = provider.isMine(found);
  final group = isMine
      ? List<Statut>.from(provider.mine)
      : List<Statut>.from(provider.byAuthor[found.alanyaID] ?? const []);
  if (group.isEmpty) return false;

  final itemIndex = group.indexWhere((s) => s.id == statusId);
  if (!context.mounted) return false;

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => StatusViewerScreen(
        contactGroups: [group],
        startContactIndex: 0,
        startItemIndex: itemIndex >= 0 ? itemIndex : 0,
        isMine: isMine,
      ),
    ),
  );
  return true;
}
