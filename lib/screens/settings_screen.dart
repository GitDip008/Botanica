import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/app_strings.dart';
import '../services/language_service.dart';

/// Dedicated settings screen. Currently just language — more settings can
/// be added here in the future.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        title: Text(s.settings),
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel(s.settings.toUpperCase()),
          const SizedBox(height: 10),
          _LanguageTile(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: Color(0xFF4A7A50),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4),
      );
}

class _LanguageTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final s = lang.strings;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showLanguageDialog(context, lang),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111F16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A4A2F)),
          ),
          child: Row(
            children: [
              const Icon(Icons.language_rounded,
                  color: Color(0xFF66BB6A), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.language,
                        style: const TextStyle(
                            color: Color(0xFFE8F5E9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(lang.current.displayName,
                        style: const TextStyle(
                            color: Color(0xFF81C784), fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF4A7A50), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, LanguageService lang) {
    final s = lang.strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111F16),
        title: Text(s.selectLanguage,
            style: const TextStyle(color: Color(0xFFE8F5E9))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLanguage.values.map((option) {
            final selected = option == lang.current;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFF4A7A50),
              ),
              title: Text(option.displayName,
                  style: const TextStyle(color: Color(0xFFE8F5E9))),
              onTap: () async {
                await lang.setLanguage(option);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel)),
        ],
      ),
    );
  }
}
