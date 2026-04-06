// lib/widgets/warung_card_widget.dart
import 'package:flutter/material.dart';
import '../services/warung_service.dart';

class WarungCard extends StatelessWidget {
  final Warung warung;
  final VoidCallback onTap;
  final VoidCallback? onLeave;
  final bool isArchive;

  const WarungCard({
    super.key,
    required this.warung,
    required this.onTap,
    this.onLeave,
    this.isArchive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAlmostDead = warung.isAlmostExpired;
    final barColor = isArchive
        ? Colors.grey[400]!
        : isAlmostDead
            ? Colors.red[400]!
            : const Color(0xFF2D7A4F);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar waktu tersisa
            LinearProgressIndicator(
              value: isArchive ? 1.0 : warung.progressPercent,
              backgroundColor: Colors.grey[100],
              color: barColor,
              minHeight: 4,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row utama: nama + badge
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isArchive
                              ? Colors.grey[200]
                              : const Color(0xFF2D7A4F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.store,
                          color: isArchive ? Colors.grey : const Color(0xFF2D7A4F),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    warung.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isAlmostDead && !isArchive)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.red[200]!),
                                    ),
                                    child: Text(
                                      '⚠️ Segera Bubar',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (isArchive)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      '📦 Bubar',
                                      style: TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isArchive
                                  ? 'Bubar: ${_formatDate(warung.expiresAt)}'
                                  : '⏱ ${warung.formattedTimeRemaining}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isAlmostDead && !isArchive
                                    ? Colors.red[600]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Last message & info bawah
                  if (warung.lastMessage != null) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 0),
                    const SizedBox(height: 8),
                    Text(
                      warung.lastMessage!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${warung.currentMembers}/${warung.maxMembers} anggota',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'dibuat ${warung.createdByName}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const Spacer(),
                      if (!isArchive && onLeave != null)
                        InkWell(
                          onTap: onLeave,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              'Keluar',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red[400],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
