import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../services/usage_tracking_service.dart';

/// Horizontal bar chart of how often each feature has been used.
class FeatureUsageChart extends StatelessWidget {
  const FeatureUsageChart({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return StreamBuilder<Map<String, int>>(
      stream: UsageTrackingService.instance.watchCounts(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(color: Color(0xFF66BB6A))),
          );
        }
        final counts = snap.data ?? const <String, int>{};
        final total = counts.values.fold<int>(0, (sum, v) => sum + v);
        if (total == 0) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111F16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A4A2F)),
            ),
            child: Center(
              child: Text(s.noDataYet,
                  style: const TextStyle(color: Color(0xFF81C784))),
            ),
          );
        }
        final maxCount = counts.values.fold<int>(0, (m, v) => v > m ? v : m);

        // Sort by count descending
        final entries = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111F16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A4A2F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with total
              Row(
                children: [
                  const Icon(Icons.insights_rounded,
                      color: Color(0xFF66BB6A), size: 18),
                  const SizedBox(width: 8),
                  Text(s.totalUses,
                      style: const TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('$total',
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9),
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 14),
              ...entries.map((e) => _BarRow(
                    label: _labelFor(e.key, s),
                    count: e.value,
                    max: maxCount,
                    color: _colorFor(e.key),
                  )),
            ],
          ),
        );
      },
    );
  }

  String _labelFor(String key, dynamic s) {
    switch (key) {
      case UsageTrackingService.featurePlantId:
        return s.featurePlantId;
      case UsageTrackingService.featurePlantHunt:
        return s.featurePlantHunt;
      case UsageTrackingService.featureChat:
        return s.featureChat;
      case UsageTrackingService.featureBloom:
        return s.featureBloom;
      case UsageTrackingService.featureMap:
        return s.featureMap;
      case UsageTrackingService.featureTrails:
        return s.featureTrails;
      case UsageTrackingService.featureSoundscape:
        return s.featureSoundscape;
      case UsageTrackingService.featureSearch:
        return s.featureSearch;
      case UsageTrackingService.featureReport:
        return s.featureReport;
      case UsageTrackingService.featureEvent:
        return s.featureEvent;
      default:
        return key;
    }
  }

  Color _colorFor(String key) {
    switch (key) {
      case UsageTrackingService.featurePlantId:
        return const Color(0xFF66BB6A);
      case UsageTrackingService.featurePlantHunt:
        return const Color(0xFFB39DDB);
      case UsageTrackingService.featureChat:
        return const Color(0xFF64B5F6);
      case UsageTrackingService.featureBloom:
        return const Color(0xFFFFB74D);
      case UsageTrackingService.featureMap:
        return const Color(0xFF4FC3F7);
      case UsageTrackingService.featureTrails:
        return const Color(0xFFFF8A65);
      case UsageTrackingService.featureSoundscape:
        return const Color(0xFF4DB6AC);
      case UsageTrackingService.featureSearch:
        return const Color(0xFFFFD54F);
      case UsageTrackingService.featureReport:
        return const Color(0xFFF48FB1);
      case UsageTrackingService.featureEvent:
        return const Color(0xFF9CCC65);
      default:
        return const Color(0xFF81C784);
    }
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int count;
  final int max;
  final Color color;
  const _BarRow({
    required this.label,
    required this.count,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = max == 0 ? 0.0 : count / max;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              Text('$count',
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: const Color(0xFF1A2E1E),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
