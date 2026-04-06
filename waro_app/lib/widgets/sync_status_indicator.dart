// lib/widgets/sync_status_indicator.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../sync/sync_queue.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncQueueManager>(
      builder: (context, sync, _) {
        if (sync.isSyncing) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (sync.failedCount > 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: '${sync.failedCount} item gagal sync. Tap untuk coba lagi.',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => sync.processBatch(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${sync.failedCount}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (sync.pendingCount > 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: '${sync.pendingCount} item menunggu sync',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_sync, color: Colors.white70, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${sync.pendingCount}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        // Semua tersinkronisasi
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.cloud_done, color: Colors.white70, size: 18),
        );
      },
    );
  }
}
