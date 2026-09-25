import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/language_service.dart';
import '../theme/tokens.dart';

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
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update_rounded,
                  color: C.gold, size: 88),
              const SizedBox(height: 20),
              Text(s.updateRequired,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: C.textHi,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(s.updateRequiredBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: C.accent,
                      fontSize: 14,
                      height: 1.5)),
              if (latestVersion.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: C.line,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('v$latestVersion',
                      style: const TextStyle(
                          color: C.accent,
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
                      backgroundColor: C.accentDim,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
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
