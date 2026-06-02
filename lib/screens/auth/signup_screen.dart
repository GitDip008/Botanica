import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signUpWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        displayName: _nameCtrl.text.trim(),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFE8F5E9)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.createAccount,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9), fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(s.joinBotanicaSubtitle,
                    style: const TextStyle(color: Color(0xFF81C784), fontSize: 13)),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration(s.displayName, Icons.person_outline_rounded),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? s.enterYourName : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration(s.email, Icons.mail_outline_rounded),
                  validator: (v) {
                    if (v == null || v.isEmpty) return s.enterYourEmail;
                    if (!v.contains('@')) return s.invalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration(
                    s.password,
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF4A7A50),
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return s.atLeast6Chars;
                    return null;
                  },
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B0B14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF8C2336)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF5350), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 12))),
                    ]),
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _busy ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(s.createAccount,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),

                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111F16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A4A2F)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.eco_rounded, color: Color(0xFF66BB6A), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Free account includes unlimited plant ID, basic Plant Hunt, and 10 AI chats per day.',
                        style: TextStyle(color: Color(0xFF81C784), fontSize: 11),
                      ),
                    ),
                  ]),
                ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF81C784)),
      prefixIcon: Icon(icon, color: const Color(0xFF4A7A50)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF111F16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A4A2F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2A4A2F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
      ),
    );
  }
}
