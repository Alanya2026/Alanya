import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/connectivity_provider.dart';

/// Bandeau slim affiché au-dessus du contenu quand le réseau OS est down.
/// Indique aussi le nombre de messages en attente dans l'outbox.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  static const double height = 28;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, conn, _) {
        if (conn.isOnline) return const SizedBox.shrink();
        final chat = context.read<ChatProvider>();
        return FutureBuilder<int>(
          future: chat.repository.dao.pendingMessages().then((m) => m.length),
          builder: (context, snap) {
            final pending = snap.data ?? 0;
            return Material(
              color: const Color(0xFFFFB74D),
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      pending > 0
                          ? 'Hors ligne · $pending message${pending > 1 ? 's' : ''} en attente'
                          : 'Hors ligne',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
