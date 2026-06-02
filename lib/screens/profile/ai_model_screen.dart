import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../services/language_service.dart';

/// Shows which chat engine is active and lets users optionally download
/// the on-device Gemma model for offline fallback.
class AIModelScreen extends StatefulWidget {
  const AIModelScreen({super.key});

  @override
  State<AIModelScreen> createState() => _AIModelScreenState();
}

class _AIModelScreenState extends State<AIModelScreen> {
  bool _busy = false;
  bool _localInstalled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkInstalled();
  }

  Future<void> _checkInstalled() async {
    final ok = await ChatService.instance.local.isModelInstalled();
    if (mounted) setState(() => _localInstalled = ok);
  }

  Future<void> _installLocal() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ChatService.instance.tryInitLocal();
      if (mounted) {
        setState(() => _localInstalled = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text(LanguageService.instance.strings.offlineReady),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = LanguageService.instance.strings;
    final chat = ChatService.instance;
    final cloudActive = chat.cloud.isConfigured;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        title: Text(LanguageService.instance.strings.chatEngine),
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Currently active ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A3320), Color(0xFF0F2018)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF66BB6A)),
            ),
            child: Row(children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF66BB6A), size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(LanguageService.instance.strings.activeEngine,
                        style: const TextStyle(color: Color(0xFF81C784), fontSize: 11)),
                    Text(chat.activeEngine,
                        style: const TextStyle(
                            color: Color(0xFFE8F5E9),
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Engine list ─────────────────────────────────────
          _engineRow(
            icon: Icons.cloud_rounded,
            title: s.engineCloudTitle,
            subtitle: cloudActive ? s.engineCloudActive : s.engineCloudOff,
            iconColor: const Color(0xFF64B5F6),
            status: cloudActive ? s.statusActive : s.statusOff,
            statusColor: cloudActive
                ? const Color(0xFF66BB6A)
                : const Color(0xFF4A7A50),
          ),
          const SizedBox(height: 8),
          _engineRow(
            icon: Icons.memory_rounded,
            title: s.engineGemmaTitle,
            subtitle: _localInstalled
                ? s.engineGemmaInstalled
                : s.engineGemmaNotInstalled,
            iconColor: const Color(0xFF66BB6A),
            status: _localInstalled ? s.statusInstalled : s.statusNotInstalled,
            statusColor: _localInstalled
                ? const Color(0xFF66BB6A)
                : const Color(0xFF4A7A50),
          ),
          const SizedBox(height: 8),
          _engineRow(
            icon: Icons.bubble_chart_rounded,
            title: s.engineGeminiTitle,
            subtitle: s.engineGeminiBody,
            iconColor: const Color(0xFFFFB74D),
            status: s.statusAvailable,
            statusColor: const Color(0xFF81C784),
          ),

          const SizedBox(height: 28),

          if (!_localInstalled) ...[
            Text(
              s.offlineFallbackHeader,
              style: const TextStyle(
                color: Color(0xFF4A7A50),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.offlineFallbackBody,
              style: const TextStyle(color: Color(0xFF81C784), fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B0B14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF8C2336)),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 12)),
              ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _installLocal,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded),
              label: Text(
                _busy ? s.downloading : s.downloadOfflineModel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3D24),
                foregroundColor: const Color(0xFFE8F5E9),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],

          const SizedBox(height: 20),
          Text(
            s.aiModelFooter,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF4A7A50), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _engineRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(color: Color(0xFF81C784), fontSize: 11)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(status,
              style: TextStyle(
                  color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
