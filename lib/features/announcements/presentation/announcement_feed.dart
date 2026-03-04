import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/announcement_repository.dart';
import '../data/announcement_model.dart';

class AnnouncementFeed extends ConsumerWidget {
  const AnnouncementFeed({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repository = ref.watch(announcementRepositoryProvider);
    final announcementsStream = repository.streamAnnouncements(limit: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Company Announcements',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (isAdmin)
                TextButton.icon(
                  onPressed: () {
                    // Navigate to create screen using GoRouter context from parent
                    // We will handle navigation in the parent or pass a callback,
                    // but standard way is context.push
                    // We'll rely on the parent to handle the 'View All' if needed,
                    // or just put the Create button here?
                    // The user requirement said "Top section... Scrollable".
                    // Admin needs "Create Post".
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Post'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 150, // Fixed height for horizontal scroll
          child: StreamBuilder<List<Announcement>>(
            stream: announcementsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final announcements = snapshot.data ?? [];

              if (announcements.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 48,
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No announcements yet',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final announcement = announcements[index];
                  return _AnnouncementCard(
                    announcement: announcement,
                    isDark: isDark,
                    isAdmin: isAdmin,
                    onDelete: isAdmin
                        ? () => repository.deleteAnnouncement(announcement.id)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.isDark,
    required this.isAdmin,
    this.onDelete,
  });

  final Announcement announcement;
  final bool isDark;
  final bool isAdmin;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          if (announcement.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: announcement.imageUrl!,
                height: 60,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 60,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 60,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            )
          else
            Container(
              height: 40, // Smaller header if no image
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign, color: Colors.blue.shade400),
                  const SizedBox(width: 8),
                  Text(
                    'Announcement',
                    style: TextStyle(
                      color: Colors.blue.shade400,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Content Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          announcement.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin)
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Announcement?'),
                                content: const Text(
                                  'This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      if (onDelete != null) onDelete!();
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.red.shade300,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat(
                      'MMM dd, hh:mm a',
                    ).format(announcement.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      announcement.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                        height: 1.3,
                      ),
                      maxLines: announcement.imageUrl != null ? 3 : 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
