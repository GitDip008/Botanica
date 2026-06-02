import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/language_service.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final String latestVersion;
  final String downloadUrl;
  const UpdateRequiredScreen({
    super.key,
    required this.latestVersion,
    required this.downloadUrl,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update_rounded,
                  color: Color(0xFFFFD54F), size: 88),
              const SizedBox(height: 20),
              Text(s.updateRequired,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(s.updateRequiredBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF81C784),
                      fontSize: 14,
                      height: 1.5)),
              if (latestVersion.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3D24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('v$latestVersion',
                      style: const TextStyle(
                          color: Color(0xFF66BB6A),
                          fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 32),
              if (downloadUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(downloadUrl),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(s.updateNow,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
