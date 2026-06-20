import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/agent/agent_service.dart';
import '../../services/language_service.dart';
import '../../services/navigation/nav_graph.dart';
import '../navigation/navigation_view.dart';

/// Single chat-style screen the gardener / visitor uses to talk to the agent.
///
/// Phase 1 surface:
///   • Scrollable message thread (user vs agent bubbles)
///   • Text input + send
///   • Pending-action confirmation card with Edit / Cancel / Save
///   • Mic button placeholder (Phase 3 wires Whisper)
///
/// Pending actions stay in the thread as cards. Tapping Save calls the
/// (yet-to-exist Phase 4) `confirm_pending_action` callable. Cancel removes
/// the card. Edit re-sends the agent the original text + the correction.
class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Message> _messages = [];
  bool _busy = false;

  // ── Voice (Phase 3) ──
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechReady = false;
  bool _listening = false;
  bool _lastInputWasVoice = false;

  // ── Edit / correction loop ──
  PendingAction? _editingPending;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (mounted) setState(() {});
    } catch (_) {
      _speechReady = false;
    }
  }

  /// Locale for on-device speech recognition, from the app language.
  String get _sttLocale {
    switch (context.read<LanguageService>().current.name) {
      case 'fi':
        return 'fi_FI';
      case 'sv':
        return 'sv_SE';
      default:
        return 'en_US';
    }
  }

  String get _ttsLocale {
    switch (context.read<LanguageService>().current.name) {
      case 'fi':
        return 'fi-FI';
      case 'sv':
        return 'sv-SE';
      default:
        return 'en-US';
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechReady || _busy) return;
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: _sttLocale,
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
      onResult: (result) {
        _input.text = result.recognizedWords;
        _input.selection =
            TextSelection.collapsed(offset: _input.text.length);
        if (result.finalResult && _input.text.trim().isNotEmpty) {
          _lastInputWasVoice = true;
          setState(() => _listening = false);
          _send();
        }
      },
    );
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage(_ttsLocale);
      await _tts.setSpeechRate(0.5);
      await _tts.speak(text);
    } catch (_) {}
  }

  @override
  void dispose() {
    _speech.cancel();
    _tts.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    final wasVoice = _lastInputWasVoice;
    _lastInputWasVoice = false;
    final correction = _editingPending;
    _editingPending = null;
    _input.clear();
    setState(() {
      _messages.add(_Message.user(text));
      _busy = true;
    });
    _scrollToEnd();

    try {
      // .name gives the stable 'en'/'fi'/'sv' — .code has a legacy quirk
      // where en's code is the string 'English'.
      final lang = context.read<LanguageService>().current.name;
      final result = await AgentService.instance.send(
        text: text,
        language: lang,
        correctionOf: correction,
      );
      setState(() {
        // A corrected draft replaces the old card (server already cancelled
        // the original pending).
        if (correction != null) {
          _messages.removeWhere((m) =>
              m.kind == _Kind.pending &&
              m.pending?.pendingId == correction.pendingId);
        }
        _messages.add(_Message.agent(result.reply));
        for (final p in result.pendingActions) {
          _messages.add(_Message.pending(p));
        }
      });
      if (wasVoice && result.reply.isNotEmpty) {
        _speak(result.reply);
      }
    } catch (e) {
      setState(() => _messages.add(_Message.agent('⚠️  ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  /// DEMO: build a real door-to-door route (main gate → tropical greenhouse
  /// cell, which crosses outdoor → door → indoor) and open the map view.
  Future<void> _openDemoRoute() async {
    try {
      final graph = await NavGraph.load();
      final route = graph.route('gate_main', 'cell_G-HA');
      if (!mounted) return;
      await NavigationView.show(
        context,
        route: route,
        destinationLabel: 'Tropical room (Romeo A)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Route demo failed: $e')),
        );
      }
    }
  }

  Future<void> _undoLast() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await AgentService.instance.undoLast();
      setState(() => _messages.add(_Message.agent(
          result.ok ? '↩️ ${result.message}' : '⚠️ ${result.message}')));
    } catch (e) {
      setState(() => _messages.add(_Message.agent('⚠️ Undo failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _cancelPending(PendingAction p) async {
    setState(() {
      _messages.removeWhere(
        (m) => m.kind == _Kind.pending && m.pending?.pendingId == p.pendingId,
      );
    });
    try {
      await AgentService.instance.cancel(p.pendingId);
    } catch (_) {
      // Cancel is best-effort — the card is already gone locally.
    }
  }

  Future<void> _confirmPending(PendingAction p) async {
    setState(() => _busy = true);
    try {
      final result = await AgentService.instance.confirm(p.pendingId);
      setState(() {
        final idx = _messages.indexWhere(
          (m) => m.kind == _Kind.pending && m.pending?.pendingId == p.pendingId,
        );
        if (idx >= 0 && result.ok) {
          _messages[idx] = _Message.confirmed(p);
        } else if (idx >= 0) {
          _messages.add(_Message.agent('⚠️ ${result.message}'));
        }
      });
    } catch (e) {
      setState(() => _messages.add(_Message.agent('⚠️ Save failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPending(PendingAction p) async {
    // Correction loop: the next message the user sends carries this pending
    // as `correction_of` — the server cancels the old draft, logs the
    // correction for prompt mining, and the LLM emits a corrected tool call.
    setState(() => _editingPending = p);
    _input.text = '';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF1B4020),
      content: Text('Editing draft — describe what to change.',
          style: const TextStyle(color: Color(0xFFE8F5E9))),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        title: const Text('Botanica Agent'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Demo: route to greenhouse',
            icon: const Icon(Icons.directions_rounded, color: Color(0xFF66BB6A)),
            onPressed: _openDemoRoute,
          ),
          IconButton(
            tooltip: 'Undo last saved action',
            icon: const Icon(Icons.undo_rounded, color: Color(0xFF81C784)),
            onPressed: _busy ? null : _undoLast,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyHint()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        message: _messages[i],
                        onConfirm: _confirmPending,
                        onEdit: _editPending,
                        onCancel: _cancelPending,
                      ),
                    ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFF111F16),
                  color: Color(0xFF66BB6A),
                  minHeight: 2,
                ),
              ),
            _InputBar(
              controller: _input,
              onSend: _send,
              busy: _busy,
              micEnabled: _speechReady,
              listening: _listening,
              onMicTap: _toggleListening,
              editing: _editingPending != null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Internal message model ───────────────────────────────────────────────

enum _Kind { user, agent, pending, confirmed }

class _Message {
  final _Kind kind;
  final String? text;
  final PendingAction? pending;

  _Message._({required this.kind, this.text, this.pending});

  factory _Message.user(String t) => _Message._(kind: _Kind.user, text: t);
  factory _Message.agent(String t) => _Message._(kind: _Kind.agent, text: t);
  factory _Message.pending(PendingAction p) =>
      _Message._(kind: _Kind.pending, pending: p);
  factory _Message.confirmed(PendingAction p) =>
      _Message._(kind: _Kind.confirmed, pending: p);
}

// ─── UI parts ─────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.eco_rounded, color: Color(0xFF66BB6A), size: 64),
            SizedBox(height: 16),
            Text(
              'Ask me about a plant, log an update, or plan a tour.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFE8F5E9), fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Try:  "Fertilized the Valerian today"\n     "What is the Coffee plant?"\n     "I have 30 minutes, what should I see?"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF81C784), fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  final ValueChanged<PendingAction> onConfirm;
  final ValueChanged<PendingAction> onEdit;
  final ValueChanged<PendingAction> onCancel;

  const _MessageBubble({
    required this.message,
    required this.onConfirm,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    switch (message.kind) {
      case _Kind.user:
        return _UserBubble(text: message.text ?? '');
      case _Kind.agent:
        return _AgentBubble(text: message.text ?? '');
      case _Kind.pending:
        return _PendingCard(
          action: message.pending!,
          onConfirm: onConfirm,
          onEdit: onEdit,
          onCancel: onCancel,
        );
      case _Kind.confirmed:
        return _ConfirmedCard(action: message.pending!);
    }
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}

class _AgentBubble extends StatelessWidget {
  final String text;
  const _AgentBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A4A2F)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFFE8F5E9), fontSize: 14, height: 1.45),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final PendingAction action;
  final ValueChanged<PendingAction> onConfirm;
  final ValueChanged<PendingAction> onEdit;
  final ValueChanged<PendingAction> onCancel;

  const _PendingCard({
    required this.action,
    required this.onConfirm,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB300), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.fact_check_outlined,
                color: Color(0xFFFFD54F), size: 18),
            const SizedBox(width: 8),
            Text('CONFIRM CHANGE',
                style: TextStyle(
                    color: const Color(0xFFFFD54F),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 8),
          Text(action.preview,
              style: const TextStyle(
                  color: Color(0xFFE8F5E9), fontSize: 14, height: 1.45)),

          // ── Detailed change breakdown ──
          if (action.changes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('WHAT WILL CHANGE',
                style: TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 6),
            ...action.changes.map((c) => _ChangeRow(change: c)),
          ],

          // ── Exact SQL (read-only) ──
          if (action.sqlDisplay != null) ...[
            const SizedBox(height: 12),
            const Text('SQL TO RUN',
                style: TextStyle(
                    color: Color(0xFF64B5F6),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A0F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E3D24)),
              ),
              child: SelectableText(
                action.sqlDisplay!,
                style: const TextStyle(
                    color: Color(0xFF9FD9A0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.4),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Row(children: [
            TextButton(
              onPressed: () => onCancel(action),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFFEF5350))),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: () => onEdit(action),
              child: const Text('Edit',
                  style: TextStyle(color: Color(0xFF64B5F6))),
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Make changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              onPressed: () => onConfirm(action),
            ),
          ]),
        ],
      ),
    );
  }
}

/// One field-level change row inside the confirmation card.
class _ChangeRow extends StatelessWidget {
  final PlanChange change;
  const _ChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    final isNewRow = change.current == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isNewRow ? Icons.add_circle_outline : Icons.edit_outlined,
                size: 12,
                color: isNewRow
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFFFFB300)),
            const SizedBox(width: 6),
            Expanded(
              child: RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: '${change.table}.${change.column}  ',
                    style: const TextStyle(
                        color: Color(0xFF81C784),
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600),
                  ),
                  if (!isNewRow)
                    TextSpan(
                      text: '${change.current}  →  ',
                      style: const TextStyle(
                          color: Color(0xFFEF9A9A),
                          fontSize: 11.5,
                          fontFamily: 'monospace'),
                    ),
                  TextSpan(
                    text: change.next,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ),
          ]),
          if (change.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 1),
              child: Text(change.note,
                  style: const TextStyle(
                      color: Color(0xFF5F6B5F), fontSize: 10.5, height: 1.3)),
            ),
        ],
      ),
    );
  }
}

class _ConfirmedCard extends StatelessWidget {
  final PendingAction action;
  const _ConfirmedCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF15281A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline,
            color: Color(0xFF66BB6A), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Saved: ${action.preview}',
              style: const TextStyle(
                  color: Color(0xFFC5E1A5), fontSize: 13, height: 1.4)),
        ),
      ]),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool busy;
  final bool micEnabled;
  final bool listening;
  final VoidCallback onMicTap;
  final bool editing;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.busy,
    required this.micEnabled,
    required this.listening,
    required this.onMicTap,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1F14),
        border: Border(top: BorderSide(color: Color(0xFF1E3D24))),
      ),
      child: Row(children: [
        // Mic — tap to start/stop dictation. Pulses red while listening.
        IconButton(
          tooltip: listening ? 'Stop listening' : 'Speak',
          icon: Icon(
            listening ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: listening ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
          ),
          style: listening
              ? IconButton.styleFrom(
                  backgroundColor: const Color(0xFF3B0B14))
              : null,
          onPressed: micEnabled && !busy ? onMicTap : null,
        ),
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !busy,
            style: const TextStyle(color: Color(0xFFE8F5E9)),
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: listening
                  ? 'Listening…'
                  : editing
                      ? 'Describe the correction…'
                      : 'Type a message…',
              hintStyle: TextStyle(
                  color: listening
                      ? const Color(0xFFEF9A9A)
                      : editing
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFF4A7A50)),
              filled: true,
              fillColor: const Color(0xFF111F16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.send_rounded),
          onPressed: busy ? null : onSend,
        ),
      ]),
    );
  }
}
