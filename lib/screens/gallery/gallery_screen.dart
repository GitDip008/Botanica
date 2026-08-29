// lib/screens/gallery/gallery_screen.dart
//
// "My Garden Diary" — two tabs: the shared feed, and the visitor's own photos.
//
// The whole point of the storage split shows up here: "Mine" reads from the
// device and works with no signal at all, which is most of the greenhouses.
// "Shared" is the only tab that touches the network.

import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/gallery_post.dart';
import '../../services/auth_service.dart';
import '../../services/gallery_service.dart';
import 'gallery_compose.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<GalleryPost> _mine = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reloadMine();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _uid => AuthService.instance.currentUser?.id ?? '';

  Future<void> _reloadMine() async {
    final posts = await GalleryService.instance.loadLocal();
    if (mounted) {
      setState(() {
        _mine = posts;
        _loading = false;
      });
    }
  }

  Future<void> _compose() async {
    final made = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GalleryCompose()),
    );
    if (made == true) _reloadMine();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: const Text('Garden Diary'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF81C784),
          unselectedLabelColor: const Color(0xFF4A7A50),
          indicatorColor: const Color(0xFF81C784),
          tabs: const [Tab(text: 'Shared'), Tab(text: 'Mine')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Add photo'),
        onPressed: _compose,
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _Feed(uid: _uid),
          _MinePane(
            posts: _mine,
            loading: _loading,
            onChanged: _reloadMine,
          ),
        ],
      ),
    );
  }
}

// ── Shared feed ─────────────────────────────────────────────────────────────

class _Feed extends StatelessWidget {
  const _Feed({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GalleryPost>>(
      stream: GalleryService.instance.watchFeed(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snap.data!;
        if (posts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Nothing shared yet.\nBe the first to post a photo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CCC9F), height: 1.5),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: posts.length,
          itemBuilder: (_, i) => _FeedCard(post: posts[i], uid: uid),
        );
      },
    );
  }
}

class _FeedCard extends StatefulWidget {
  const _FeedCard({required this.post, required this.uid});
  final GalleryPost post;
  final String uid;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final reacted = p.reactedUids.contains(widget.uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(11)),
            child: FutureBuilder<String?>(
              future: GalleryService.instance.photoUrl(p.photoPath),
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
                if (p.caption.isNotEmpty)
                  Text(p.caption,
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9),
                          fontSize: 14.5,
                          height: 1.4)),
                if (p.plantName != null && p.plantName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(p.plantName!,
                        style: const TextStyle(
                            color: Color(0xFF81C784),
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic)),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(p.displayName,
                        style: const TextStyle(
                            color: Color(0xFF4A7A50), fontSize: 12)),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.uid.isEmpty
                          ? null
                          : () => GalleryService.instance
                              .toggleReaction(p, widget.uid),
                      icon: Icon(
                        reacted
                            ? Icons.local_florist_rounded
                            : Icons.local_florist_outlined,
                        color: reacted
                            ? const Color(0xFF81C784)
                            : const Color(0xFF4A7A50),
                        size: 20,
                      ),
                    ),
                    Text('${p.reactionCount}',
                        style: const TextStyle(
                            color: Color(0xFF81C784), fontSize: 13)),
                    if (p.uid != widget.uid)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Report',
                        onPressed: () => _report(p),
                        icon: const Icon(Icons.flag_outlined,
                            size: 18, color: Color(0xFF4A7A50)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _report(GalleryPost p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F14),
        title: const Text('Report this post?',
            style: TextStyle(color: Color(0xFFE8F5E9), fontSize: 17)),
        content: const Text(
          'A garden admin will review it. The post stays visible until they do.',
          style: TextStyle(color: Color(0xFF9CCC9F), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF81C784))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (ok != true || widget.uid.isEmpty) return;
    await GalleryService.instance.report(p, widget.uid, 'inappropriate');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1B4020),
          content: Text('Reported. Thank you.',
              style: TextStyle(color: Color(0xFFE8F5E9))),
        ),
      );
    }
  }
}

// ── The visitor's own photos ────────────────────────────────────────────────

class _MinePane extends StatelessWidget {
  const _MinePane({
    required this.posts,
    required this.loading,
    required this.onChanged,
  });

  final List<GalleryPost> posts;
  final bool loading;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No photos yet.\nYours stay on this phone unless you share them.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9CCC9F), height: 1.5),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: posts.length,
      itemBuilder: (_, i) =>
          _MineCard(post: posts[i], onChanged: onChanged),
    );
  }
}

class _MineCard extends StatefulWidget {
  const _MineCard({required this.post, required this.onChanged});
  final GalleryPost post;
  final Future<void> Function() onChanged;

  @override
  State<_MineCard> createState() => _MineCardState();
}

class _MineCardState extends State<_MineCard> {
  bool _busy = false;

  Future<void> _togglePublish() async {
    final p = widget.post;
    setState(() => _busy = true);
    try {
      if (p.isPublic) {
        await GalleryService.instance.unpublish(p);
      } else {
        await GalleryService.instance.publish(p);
      }
      await widget.onChanged();
    } on StateError {
      // The local file is gone — app data cleared, or a reinstall.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF4A1A1A),
            content: Text(
              'That photo is no longer on this device, so it cannot be shared.',
              style: TextStyle(color: Color(0xFFFFCDD2)),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4A1A1A),
            content: Text('Could not update: $e',
                style: const TextStyle(color: Color(0xFFFFCDD2))),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F14),
        title: const Text('Delete this photo?',
            style: TextStyle(color: Color(0xFFE8F5E9), fontSize: 17)),
        content: Text(
          widget.post.isPublic
              ? 'It will be removed from the shared feed and from this phone.'
              : 'It will be removed from this phone. This cannot be undone.',
          style: const TextStyle(color: Color(0xFF9CCC9F), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF81C784))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await GalleryService.instance.deleteLocal(widget.post);
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final file = p.localPath == null ? null : File(p.localPath!);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.isPublic ? const Color(0xFF2E7D32) : const Color(0xFF2A4A2F),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(11)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: file != null && file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFF13301A),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Photo no longer on this device',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF6E8A72), fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.caption.isNotEmpty)
                  Text(p.caption,
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9),
                          fontSize: 14.5,
                          height: 1.4)),
                if (p.plantName != null && p.plantName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(p.plantName!,
                        style: const TextStyle(
                            color: Color(0xFF81C784),
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic)),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      p.isPublic ? Icons.public_rounded : Icons.lock_outline,
                      size: 15,
                      color: p.isPublic
                          ? const Color(0xFF81C784)
                          : const Color(0xFF6E8A72),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      p.isPublic ? 'Shared' : 'Only you',
                      style: TextStyle(
                        color: p.isPublic
                            ? const Color(0xFF81C784)
                            : const Color(0xFF6E8A72),
                        fontSize: 12.5,
                      ),
                    ),
                    const Spacer(),
                    if (_busy)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      TextButton(
                        onPressed: _togglePublish,
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        child: Text(
                          p.isPublic ? 'Make private' : 'Share',
                          style: const TextStyle(
                              color: Color(0xFF81C784), fontSize: 13),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline,
                            size: 19, color: Color(0xFF6E8A72)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
