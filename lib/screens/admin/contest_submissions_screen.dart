// lib/screens/admin/contest_submissions_screen.dart
//
// Every contest submission, for checking after the event.
//
// Two questions this answers that the public leaderboard cannot:
//   1. Where was each plant actually photographed? (map link per entry)
//   2. Which plants did visitors type by hand because they are not in the
//      garden's index? Those are gaps in the records, and the count is the
//      point — the curator wants a number, not an anecdote.
//
// ponytail: no CSV export, no date filter, no pagination. A one-day event
// produces a few hundred rows; add those when a contest outgrows one screen.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/contest.dart';
import '../../services/contest_service.dart';

class ContestSubmissionsScreen extends StatelessWidget {
  const ContestSubmissionsScreen({super.key, required this.contest});
  final Contest contest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: const Text('Contest submissions'),
      ),
      body: StreamBuilder<List<ContestEntry>>(
        stream: ContestService.instance.watchEntries(contest.id),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (all.isEmpty) {
            return const Center(
              child: Text('No submissions yet.',
                  style: TextStyle(color: Color(0xFF9CCC9F))),
            );
          }

          final offIndex = all.where((e) => !e.fromIndex).toList();
          final offIndexPlants =
              offIndex.map((e) => e.plantName).toSet().toList()..sort();
          final withGps = all.where((e) => e.hasLocation).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  _Stat(value: '${all.length}', label: 'submissions'),
                  const SizedBox(width: 10),
                  _Stat(value: '$withGps', label: 'with location'),
                  const SizedBox(width: 10),
                  _Stat(
                    value: '${offIndexPlants.length}',
                    label: 'not in records',
                    warn: offIndexPlants.isNotEmpty,
                  ),
                ],
              ),

              if (offIndexPlants.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('TYPED BY HAND — MISSING FROM THE PLANT INDEX',
                    style: TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E1A00),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8D6E00)),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final name in offIndexPlants)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A0F00),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(name,
                              style: const TextStyle(
                                  color: Color(0xFFFFE7A3), fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),
              const Text('ALL SUBMISSIONS',
                  style: TextStyle(
                      color: Color(0xFF81C784),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1)),
              const SizedBox(height: 8),
              for (final e in all) _SubmissionCard(entry: e),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.warn = false});
  final String value;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF111F16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: warn ? const Color(0xFF8D6E00) : const Color(0xFF2A4A2F)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: warn
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFF81C784),
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF6E8A72), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.entry});
  final ContestEntry entry;

  String get _when {
    final d = entry.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The submitted photo sits next to the name that submitted it,
              // which is the whole point of this screen: checking that a
              // winning entry is really the plant it claims to be.
              if (entry.photoPath != null)
                FutureBuilder<String?>(
                  future: ContestService.instance.photoUrl(entry.photoPath),
                  builder: (_, s) => GestureDetector(
                    onTap: s.data == null
                        ? null
                        : () => showDialog<void>(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.black,
                                insetPadding: const EdgeInsets.all(12),
                                child: InteractiveViewer(
                                  child: Image.network(s.data!),
                                ),
                              ),
                            ),
                    child: Container(
                      width: 64,
                      height: 64,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13301A),
                        borderRadius: BorderRadius.circular(8),
                        image: s.data == null
                            ? null
                            : DecorationImage(
                                image: NetworkImage(s.data!),
                                fit: BoxFit.cover),
                      ),
                      child: s.data == null
                          ? const Icon(Icons.hourglass_empty_rounded,
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
                        Flexible(
                          child: Text(entry.plantName,
                              style: const TextStyle(
                                  color: Color(0xFFE8F5E9),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (!entry.fromIndex)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.edit_note_rounded,
                                size: 15, color: Color(0xFFFFD54F)),
                          ),
                      ],
                    ),
                    Text(
                      [
                        entry.displayName.isEmpty
                            ? 'Visitor'
                            : entry.displayName,
                        if (entry.teamName != null) 'Team ${entry.teamName}',
                        if (entry.plantSection.isNotEmpty) entry.plantSection,
                      ].join('  ·  '),
                      style: const TextStyle(
                          color: Color(0xFF6E8A72), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Text(_when,
                  style: const TextStyle(
                      color: Color(0xFF4A7A50), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                entry.hasLocation
                    ? Icons.place_rounded
                    : Icons.location_off_rounded,
                size: 14,
                color: entry.hasLocation
                    ? const Color(0xFF81C784)
                    : const Color(0xFF4A7A50),
              ),
              const SizedBox(width: 5),
              if (entry.hasLocation)
                InkWell(
                  onTap: () => launchUrl(Uri.parse(entry.mapsUrl!),
                      mode: LaunchMode.externalApplication),
                  child: Text(
                    '${entry.lat!.toStringAsFixed(5)}, '
                    '${entry.lng!.toStringAsFixed(5)}  ·  open in Maps',
                    style: const TextStyle(
                        color: Color(0xFF81C784),
                        fontSize: 11.5,
                        decoration: TextDecoration.underline),
                  ),
                )
              else
                const Text('no location',
                    style:
                        TextStyle(color: Color(0xFF4A7A50), fontSize: 11.5)),
              if (entry.photoPath == null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.no_photography_rounded,
                    size: 14, color: Color(0xFF4A7A50)),
                const SizedBox(width: 4),
                const Text('no photo',
                    style:
                        TextStyle(color: Color(0xFF4A7A50), fontSize: 11.5)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
