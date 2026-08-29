// lib/screens/admin/reported_posts_screen.dart
//
// Moderation queue for reported gallery posts.
//
// Hiding is the default action, not deleting. A hidden post drops out of the
// feed but survives in the database, so a call made in thirty seconds at a busy
// event can be reversed later — the same reasoning that keeps the garden's own
// records append-only. Deleting is there for content that must not sit in the
// database at all, and is deliberately the harder button to press.
//
// Every report is resolved with an explicit outcome, so the queue reflects
// decisions taken rather than merely items seen.

import 'package:flutter/material.dart';

import '../../models/gallery_post.dart';
import '../../services/gallery_service.dart';

class ReportedPostsScreen extends StatelessWidget {
  const ReportedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: const Text('Reported posts'),
      ),
      body: StreamBuilder<List<GalleryReport>>(
        stream: GalleryService.instance.watchOpenReports(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snap.data!;
          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 40, color: Color(0xFF2E7D32)),
                    SizedBox(height: 12),
                    Text('Nothing to review.',
                        style: TextStyle(color: Color(0xFF9CCC9F))),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (_, i) => _ReportCard(report: reports[i]),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatefulWidget {
  const _ReportCard({required this.report});
  final GalleryReport report;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  late Future<GalleryPost?> _post =
      GalleryService.instance.fetchPost(widget.report.postId);
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String snack) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1B4020),
            content: Text(snack,
                style: const TextStyle(color: Color(0xFFE8F5E9))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4A1A1A),
            content: Text('Failed: $e',
                style: const TextStyle(color: Color(0xFFFFCDD2))),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _post = GalleryService.instance.fetchPost(widget.report.postId);
        });
      }
    }
  }

  Future<void> _confirmDelete(GalleryPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F14),
        title: const Text('Delete permanently?',
            style: TextStyle(color: Color(0xFFE8F5E9), fontSize: 17)),
        content: const Text(
          'The post and its photo are removed for good. Hiding is reversible; '
          'this is not. Use it only when the content must not remain stored.',
          style: TextStyle(color: Color(0xFF9CCC9F), fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF81C784))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await GalleryService.instance.adminDeletePost(post);
      await GalleryService.instance.resolveReport(widget.report.id, 'deleted');
    }, 'Post deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5A2A2A)),
      ),
      child: FutureBuilder<GalleryPost?>(
        future: _post,
        builder: (context, snap) {
          final post = snap.data;
          final loading = snap.connectionState != ConnectionState.done;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (post == null)
                // The post is already gone — deleted by its owner, or by another
                // admin. Nothing to moderate, so let the report be closed.
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Color(0xFF6E8A72), size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('This post no longer exists.',
                            style: TextStyle(
                                color: Color(0xFF9CCC9F), fontSize: 13.5)),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => GalleryService.instance
                                      .resolveReport(r.id, 'post-gone'),
                                  'Report closed.',
                                ),
                        child: const Text('Close',
                            style: TextStyle(color: Color(0xFF81C784))),
                      ),
                    ],
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11)),
                  child: FutureBuilder<String?>(
                    future: GalleryService.instance.photoUrl(post.photoPath),
                    builder: (_, s) => AspectRatio(
                      aspectRatio: 4 / 3,
                      child: s.data == null
                          ? Container(
                              color: const Color(0xFF13301A),
                              child: const Center(
                                child: Icon(Icons.image_outlined,
                                    color: Color(0xFF4A7A50)),
                              ),
                            )
                          : Image.network(s.data!, fit: BoxFit.cover),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.caption.isNotEmpty)
                        Text(post.caption,
                            style: const TextStyle(
                                color: Color(0xFFE8F5E9),
                                fontSize: 14,
                                height: 1.4)),
                      const SizedBox(height: 6),
                      Text('by ${post.displayName}',
                          style: const TextStyle(
                              color: Color(0xFF4A7A50), fontSize: 12)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1414),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.flag_rounded,
                                size: 15, color: Color(0xFFEF5350)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Reported: ${r.reason}',
                                style: const TextStyle(
                                    color: Color(0xFFFFCDD2), fontSize: 12.5),
                              ),
                            ),
                            if (post.hidden)
                              const Text('HIDDEN',
                                  style: TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Hiding first, and styled as the primary action —
                            // it is the reversible one.
                            FilledButton.icon(
                              onPressed: () => _run(
                                () async {
                                  await GalleryService.instance
                                      .setHidden(post.id, !post.hidden);
                                  if (!post.hidden) {
                                    await GalleryService.instance
                                        .resolveReport(r.id, 'hidden');
                                  }
                                },
                                post.hidden
                                    ? 'Post restored.'
                                    : 'Post hidden from the feed.',
                              ),
                              icon: Icon(
                                  post.hidden
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  size: 17),
                              label:
                                  Text(post.hidden ? 'Restore' : 'Hide post'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF8D6E00),
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _run(
                                () => GalleryService.instance
                                    .resolveReport(r.id, 'dismissed'),
                                'Report dismissed.',
                              ),
                              icon: const Icon(Icons.done_rounded, size: 17),
                              label: const Text('Looks fine'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF81C784),
                                side: const BorderSide(
                                    color: Color(0xFF2E7D32)),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _confirmDelete(post),
                              icon: const Icon(Icons.delete_outline, size: 17),
                              label: const Text('Delete'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF9A9A),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
