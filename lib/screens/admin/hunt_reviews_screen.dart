// lib/screens/admin/hunt_reviews_screen.dart
//
// The review queue, and the per-person record of everything submitted.
//
// A visitor reaches the queue only when the identifier insists there is no
// plant in their photo and they have tried twice. Somebody is standing in a
// greenhouse waiting on the answer, so the queue is oldest-first and the whole
// decision is two taps on one screen.

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/hunt_submission_service.dart';

const _bg = Color(0xFF0A1A0F);
const _surface = Color(0xFF111F16);
const _border = Color(0xFF2A4A2F);
const _textPri = Color(0xFFE8F5E9);
const _textDim = Color(0xFF6E8A72);

// ─── Review queue ─────────────────────────────────────────────────────────────

class HuntReviewsScreen extends StatelessWidget {
  const HuntReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        title: const Text('Photo review requests',
            style: TextStyle(color: _textPri)),
        iconTheme: const IconThemeData(color: Color(0xFF66BB6A)),
      ),
      body: StreamBuilder<List<ReviewRequest>>(
        stream: HuntSubmissionService.instance.watchPendingReviews(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nothing waiting for review.',
                    style: TextStyle(color: Color(0xFF9CCC9F))),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: rows.length,
            itemBuilder: (_, i) => _ReviewCard(request: rows[i]),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.request});
  final ReviewRequest request;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _busy = false;

  Future<void> _decide(bool approved) async {
    final admin = AuthService.instance.currentUser?.id ?? '';
    setState(() => _busy = true);
    try {
      await HuntSubmissionService.instance.decideReview(
        id: widget.request.id,
        approved: approved,
        adminUid: admin,
      );
      // The card leaves the list on its own — the query watches for pending.
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save that: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final waited = DateTime.now().difference(r.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF5350)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The photo is the decision, so it leads and it is big.
          FutureBuilder<String?>(
            future: HuntSubmissionService.instance.photoUrl(r.photoPath),
            builder: (_, snap) => ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: snap.data == null
                    ? Container(
                        color: const Color(0xFF13301A),
                        child: const Center(
                          child: Text('No photo attached',
                              style: TextStyle(color: _textDim, fontSize: 12)),
                        ),
                      )
                    : GestureDetector(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.black,
                            insetPadding: const EdgeInsets.all(12),
                            child: InteractiveViewer(
                                child: Image.network(snap.data!)),
                          ),
                        ),
                        child: Image.network(snap.data!, fit: BoxFit.cover),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.displayName} · quest ${r.questIndex + 1}',
                    style: const TextStyle(
                        color: _textPri,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                // The admin cannot be expected to remember which quest is
                // which, so the answer they are judging against is right here.
                Text('Should be: ${r.plantName}',
                    style: const TextStyle(
                        color: Color(0xFF81C784), fontSize: 12.5)),
                if (r.typedAnswer.isNotEmpty)
                  Text('They typed: "${r.typedAnswer}"',
                      style: const TextStyle(color: _textDim, fontSize: 12.5)),
                Text(
                  waited.inMinutes < 1
                      ? 'Just now'
                      : 'Waiting ${waited.inMinutes} min',
                  style: const TextStyle(color: _textDim, fontSize: 11.5),
                ),
                const SizedBox(height: 12),
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF5350),
                            side: const BorderSide(color: Color(0xFFEF5350)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const Text('Decline'),
                          onPressed: () => _decide(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 17),
                          label: const Text('Approve'),
                          onPressed: () => _decide(true),
                        ),
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
}

// ─── Participants ─────────────────────────────────────────────────────────────

class ParticipantsScreen extends StatelessWidget {
  const ParticipantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        title: const Text('Participants', style: TextStyle(color: _textPri)),
        iconTheme: const IconThemeData(color: Color(0xFF66BB6A)),
      ),
      body: StreamBuilder<List<Participant>>(
        stream: HuntSubmissionService.instance.watchParticipants(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nobody has submitted anything yet.',
                    style: TextStyle(color: Color(0xFF9CCC9F))),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final p = rows[i];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ParticipantDetailScreen(participant: p)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF1B4020),
                          child: Text(
                            p.displayName.isEmpty
                                ? '?'
                                : p.displayName.characters.first.toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF81C784),
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.displayName,
                                  style: const TextStyle(
                                      color: _textPri,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                '${p.huntAttempts} submissions · '
                                '${p.huntSolved} correct',
                                style: const TextStyle(
                                    color: _textDim, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFF4A7A50)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Everything one person submitted, newest first — the photo they sent, the
/// name they typed, what the identifier made of it, and what it scored.
class ParticipantDetailScreen extends StatelessWidget {
  const ParticipantDetailScreen({super.key, required this.participant});
  final Participant participant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        title: Text(participant.displayName,
            style: const TextStyle(color: _textPri)),
        iconTheme: const IconThemeData(color: Color(0xFF66BB6A)),
      ),
      body: StreamBuilder<List<HuntSubmission>>(
        stream: HuntSubmissionService.instance
            .watchUserSubmissions(participant.uid),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(
              child: Text('No Plant Hunt submissions.',
                  style: TextStyle(color: Color(0xFF9CCC9F))),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: rows.length,
            itemBuilder: (_, i) => _SubmissionCard(s: rows[i]),
          );
        },
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.s});
  final HuntSubmission s;

  String get _when {
    final d = s.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: s.correct ? const Color(0xFF2E7D32) : _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String?>(
            future: HuntSubmissionService.instance.photoUrl(s.photoPath),
            builder: (_, snap) => GestureDetector(
              onTap: snap.data == null
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.black,
                          insetPadding: const EdgeInsets.all(12),
                          child: InteractiveViewer(
                              child: Image.network(snap.data!)),
                        ),
                      ),
              child: Container(
                width: 66,
                height: 66,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF13301A),
                  borderRadius: BorderRadius.circular(8),
                  image: snap.data == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(snap.data!), fit: BoxFit.cover),
                ),
                child: snap.data == null
                    ? const Icon(Icons.image_not_supported_outlined,
                        size: 16, color: Color(0xFF4A7A50))
                    : null,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      s.correct ? Icons.check_circle : Icons.cancel_outlined,
                      size: 15,
                      color: s.correct
                          ? Colors.greenAccent
                          : const Color(0xFF6E8A72),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Quest ${s.questIndex + 1} · ${s.plantName}',
                          style: const TextStyle(
                              color: _textPri,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text(s.correct ? '${s.points} pts' : '—',
                        style: TextStyle(
                            color: s.correct
                                ? const Color(0xFFFFD54F)
                                : _textDim,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Typed: "${s.typedAnswer}"',
                    style: const TextStyle(color: Color(0xFFCFE8D2), fontSize: 12.5)),
                Text(
                  [
                    'photo: ${s.photoVerdict}',
                    if (s.detectedName != null) 'saw ${s.detectedName}',
                    if (s.usedLocationHint) 'location hint',
                    if (s.usedPhotoHint) 'photo hint',
                    if (s.uncheckedPhoto) 'unchecked',
                    if (s.adminApproved) 'admin approved',
                  ].join(' · '),
                  style: const TextStyle(color: _textDim, fontSize: 11),
                ),
                Text(_when,
                    style: const TextStyle(
                        color: Color(0xFF4A7A50), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
