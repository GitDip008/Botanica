import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_service.dart';
import '../../theme/tokens.dart';
import '../../widgets/ui_kit.dart';
import 'signup_screen.dart';
import '../../i18n/tr.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // AuthGate will swap screens automatically.
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Straight in, under a name of their choosing, no account.
  ///
  /// This is the primary path at an event. Researchers' Night is a four-hour
  /// drop-in; a sign-up wall between a visitor and the plant in front of them
  /// loses most of them at the door, and the University's programme promises
  /// the app will simply work.
  Future<void> _continueAsGuest() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _GuestNameDialog(),
    );
    if (name == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInAsGuest(displayName: name);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final s = context.read<LanguageService>().strings;
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text(s.resetPassword,
            style: const TextStyle(color: C.textHi)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.resetPasswordBody,
                style: const TextStyle(color: C.accent, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: C.textHi),
              decoration: InputDecoration(
                labelText: s.email,
                labelStyle: const TextStyle(color: C.textSoft),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: C.line)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: C.accent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(s.send,
                  style: const TextStyle(color: C.accent))),
        ],
      ),
    );
    if (email == null || email.isEmpty || !email.contains('@')) return;
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: C.accentDim,
          content: Text(s.resetLinkSent),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo + headline ───────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('logo.png', width: 88, height: 88),
                ).animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 20),
                Text(
                  s.welcomeBack,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: C.textHi,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.signInSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.accent, fontSize: 13),
                ),
                const SizedBox(height: 36),

                // ── Straight in, no account ──────────────────
                // Placed above the form on purpose: at a public event this is
                // the path almost everyone should take, and a button below a
                // password field is a button most people never reach.
                AppButton(
                  label: tr('Continue as guest'),
                  icon: Icons.bolt_rounded,
                  onPressed: _busy ? null : _continueAsGuest,
                ),
                const SizedBox(height: Sp.s),
                Text(
                  tr('No account, no email — just a name. Everything works, including the leaderboards.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: C.textFaint, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: Sp.xl),
                Row(children: [
                  Expanded(child: Container(height: 1, color: C.line)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(tr('or sign in'),
                        style: TextStyle(color: C.textFaint, fontSize: 12)),
                  ),
                  Expanded(child: Container(height: 1, color: C.line)),
                ]),
                const SizedBox(height: Sp.xl),

                // ── Email ────────────────────────────────────
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration(tr('Email'), Icons.mail_outline_rounded),
                  validator: (v) {
                    if (v == null || v.isEmpty) return s.enterYourEmail;
                    if (!v.contains('@')) return s.invalidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Password ─────────────────────────────────
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration(
                    tr('Password'),
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: C.textFaint,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return s.atLeast6Chars;
                    return null;
                  },
                ),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _forgotPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(s.forgotPassword,
                        style: const TextStyle(
                            color: C.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B0B14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8C2336)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: C.danger, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: Sp.l),

                // ── Sign in button ───────────────────────────
                // Tonal, not filled: "Continue as guest" is the primary action
                // on this screen, and two same-weight green buttons make a
                // visitor stop and choose instead of just going.
                ElevatedButton(
                  onPressed: _busy ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.surfaceAlt,
                    foregroundColor: C.textHi,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: C.accent),
                        )
                      : Text(s.signIn,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),

                // ── Divider ──────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider(color: C.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(s.or, style: const TextStyle(color: C.textFaint, fontSize: 12)),
                  ),
                  const Expanded(child: Divider(color: C.line)),
                ]),
                const SizedBox(height: 14),

                // ── Google sign-in ───────────────────────────
                OutlinedButton.icon(
                  onPressed: _busy ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 24, color: C.accent),
                  label: Text(s.continueWithGoogle,
                      style: const TextStyle(color: C.textHi, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: C.line),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Sign up link ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.noAccountQuestion,
                        style: const TextStyle(color: C.accent, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SignupScreen())),
                      child: Text(s.signUp,
                          style: const TextStyle(
                              color: C.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
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
      labelStyle: const TextStyle(color: C.textSoft),
      prefixIcon: Icon(icon, color: C.textFaint),
      suffixIcon: suffix,
      filled: true,
      fillColor: C.surface,
    );
  }
}


/// One field, one button. The only thing a guest has to decide is what the
/// leaderboard should call them.
class _GuestNameDialog extends StatefulWidget {
  const _GuestNameDialog();

  @override
  State<_GuestNameDialog> createState() => _GuestNameDialogState();
}

class _GuestNameDialogState extends State<_GuestNameDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: R.rm),
      title: Text(tr('What should we call you?'), style: T.h2),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Shown on the leaderboards. A first name or a nickname is fine.'),
            style: T.bodySm,
          ),
          const SizedBox(height: Sp.l),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLength: 24,
            style: const TextStyle(color: C.textHi),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _go(),
            decoration: InputDecoration(
              hintText: tr('e.g. Aino, or Team Kaktus'),
              hintStyle: const TextStyle(color: C.textFaint),
              counterStyle: const TextStyle(color: C.textFaint),
              filled: true,
              fillColor: C.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: R.rs,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Cancel'), style: TextStyle(color: C.textSoft)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: C.accent,
            foregroundColor: C.bg,
          ),
          onPressed: _ctrl.text.trim().isEmpty ? null : _go,
          child: Text(tr('Start exploring')),
        ),
      ],
    );
  }
}
