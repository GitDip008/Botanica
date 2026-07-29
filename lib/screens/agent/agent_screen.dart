import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/agent/agent_service.dart';
import '../../services/auth_service.dart';
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
  List<String> _suggestions = const [];
  bool _busy = false;
  /// Whether this account may record updates (garden staff). Server-decided.
  bool _canUpdate = false;
  /// Whether an update-mode conversation is currently open.
  bool _updateMode = false;

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
    _probeUpdateMode();
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
    _input.clear();
    await _sendTurn(text);
  }

  /// Last 15 user/agent text turns, oldest→newest, for the agent's memory.
  List<Map<String, String>> _history() {
    final turns = _messages
        .where((m) => m.kind == _Kind.user || m.kind == _Kind.agent)
        .where((m) => (m.text ?? '').trim().isNotEmpty)
        .map((m) => {
              'role': m.kind == _Kind.user ? 'user' : 'assistant',
              'content': m.text!.trim(),
            })
        .toList();
    return turns.length > 15 ? turns.sublist(turns.length - 15) : turns;
  }

  /// One turn. [context] is set when the user tapped a disambiguation button
  /// (pins the exact plant). Used by both typing and button taps.
  Future<void> _sendTurn(String text, {AgentContext? context}) async {
    if (text.isEmpty || _busy) return;
    final wasVoice = _lastInputWasVoice;
    _lastInputWasVoice = false;
    final correction = _editingPending;
    _editingPending = null;

    final history = _history(); // capture BEFORE adding this user turn
    setState(() {
      _messages.add(_Message.user(text));
      _suggestions = const []; // clear stale quick-replies
      _busy = true;
    });
    _scrollToEnd();

    try {
      // .name gives the stable 'en'/'fi'/'sv' — .code has a legacy quirk
      // where en's code is the string 'English'.
      final lang = LanguageService.instance.current.name;
      final result = await AgentService.instance.send(
        text: text,
        language: lang,
        context: context,
        correctionOf: correction,
        history: history,
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
        if (result.clarification != null &&
            result.clarification!.options.isNotEmpty) {
          _messages.add(_Message.clarify(result.clarification!));
        }
        for (final p in result.pendingActions) {
          _messages.add(_Message.pending(p));
        }
        _suggestions = result.suggestions;
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

  /// Ask the server whether this account may record updates, and whether a mode
  /// session is already open (it survives app restarts within its TTL).
  ///
  /// The role lives in Firestore server-side, so the server is the authority —
  /// a permission-denied here IS the answer for a visitor. Deliberately not
  /// mirrored into client state: two copies of an authorization fact drift.
  Future<void> _probeUpdateMode() async {
    try {
      final r = await AgentService.instance.setUpdateMode(
        'status',
        language: LanguageService.instance.current.name,
      );
      if (!mounted) return;
      setState(() {
        _canUpdate = true;
        _updateMode = r.active;
      });
    } catch (_) {
      // Visitor, or offline. Either way: no button.
    }
  }

  Future<void> _toggleUpdateMode() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await AgentService.instance.setUpdateMode(
        _updateMode ? 'exit' : 'start',
        language: LanguageService.instance.current.name,
      );
      if (!mounted) return;
      setState(() {
        _updateMode = r.active;
        if (r.reply.isNotEmpty) _messages.add(_Message.agent(r.reply));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_Message.agent('⚠️ $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Starter quick-replies shown on the empty screen — role-aware + localized.
  List<String> _starterSuggestions() {
    final lang = LanguageService.instance.current.name;
    final staff = AuthService.instance.currentUser?.isAdmin ?? false;
    String t(String en, String fi, String sv) =>
        lang == 'fi' ? fi : (lang == 'sv' ? sv : en);
    if (staff) {
      return [
        t('What needs attention?', 'Mikä tarvitsee huomiota?', 'Vad behöver uppmärksamhet?'),
        t('Find a plant', 'Etsi kasvi', 'Hitta en växt'),
        t('Record an action', 'Kirjaa toimenpide', 'Registrera en åtgärd'),
      ];
    }
    return [
      t('Find a plant', 'Etsi kasvi', 'Hitta en växt'),
      t('Plan a 30-minute tour', 'Suunnittele 30 min kierros', 'Planera en 30-min rundtur'),
      t("What's interesting to see?", 'Mitä kannattaa nähdä?', 'Vad är intressant att se?'),
    ];
  }

  /// User tapped a clarification button.
  void _onClarifyOption(ClarOption opt) {
    if (_busy) return;
    _sendTurn(
      opt.sendText,
      context: opt.hankintaID != null
          ? AgentContext(scannedHankintaID: opt.hankintaID)
          : null,
    );
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
      final r = await AgentService.instance.cancel(p.pendingId);
      // In update mode the server answers with "tell me just what to change",
      // which the gardener needs to see — otherwise declining looks like the
      // conversation simply stopped.
      if (mounted && r.message.isNotEmpty && r.message != 'Cancelled.') {
        setState(() => _messages.add(_Message.agent(r.message)));
      }
    } catch (_) {
      // Cancel is best-effort — the card is already gone locally.
    }
  }

  Future<void> _confirmPending(PendingAction p) async {
    setState(() => _busy = true);
    try {
      final result = await AgentService.instance
          .confirm(p.pendingId, language: LanguageService.instance.current.name);
      setState(() {
        final idx = _messages.indexWhere(
          (m) => m.kind == _Kind.pending && m.pending?.pendingId == p.pendingId,
        );
        if (idx >= 0 && result.ok) {
          _messages[idx] = _Message.confirmed(p);
        } else if (idx >= 0) {
          _messages.add(_Message.agent('⚠️ ${result.message}'));
        }
        // Update mode: offer [Update another] / [Done] after either outcome, so
        // the gardener is never left guessing whether the mode is still on.
        if (result.clarification != null &&
            result.clarification!.options.isNotEmpty) {
          _messages.add(_Message.clarify(result.clarification!));
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
          // Gardener-only: enter the slot-filling update conversation. Hidden
          // from visitors, and the server refuses them regardless.
          if (_canUpdate)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: FilledButton.icon(
                onPressed: _busy ? null : _toggleUpdateMode,
                icon: Icon(
                  _updateMode ? Icons.check_rounded : Icons.edit_note_rounded,
                  size: 18,
                ),
                label: Text(_updateMode ? 'Done' : 'Update'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _updateMode ? const Color(0xFF2E7D32) : const Color(0xFF1B4020),
                  foregroundColor: const Color(0xFFE8F5E9),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
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
                  ? _EmptyHint(
                      suggestions: _starterSuggestions(),
                      onSuggestion: _sendTurn,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        message: _messages[i],
                        onConfirm: _confirmPending,
                        onEdit: _editPending,
                        onCancel: _cancelPending,
                        onClarifyOption: _onClarifyOption,
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
            if (_suggestions.isNotEmpty && !_busy)
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: [
                    for (final s in _suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(s),
                          labelStyle: const TextStyle(
                              color: Color(0xFFE8F5E9), fontSize: 12.5),
                          backgroundColor: const Color(0xFF173024),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            final text = s;
                            setState(() => _suggestions = const []);
                            _sendTurn(text);
                          },
                        ),
                      ),
                  ],
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

enum _Kind { user, agent, pending, confirmed, clarify }

class _Message {
  final _Kind kind;
  final String? text;
  final PendingAction? pending;
  final Clarification? clarification;

  _Message._({required this.kind, this.text, this.pending, this.clarification});

  factory _Message.user(String t) => _Message._(kind: _Kind.user, text: t);
  factory _Message.agent(String t) => _Message._(kind: _Kind.agent, text: t);
  factory _Message.pending(PendingAction p) =>
      _Message._(kind: _Kind.pending, pending: p);
  factory _Message.confirmed(PendingAction p) =>
      _Message._(kind: _Kind.confirmed, pending: p);
  factory _Message.clarify(Clarification c) =>
      _Message._(kind: _Kind.clarify, clarification: c);
}

// ─── UI parts ─────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  const _EmptyHint({required this.suggestions, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    // Centred when there's room, scrollable when the keyboard shrinks the area
    // (prevents the "bottom overflowed by N pixels" banner).
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco_rounded,
                        color: Color(0xFF66BB6A), size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Ask me about a plant, log an update, or plan a tour.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFE8F5E9), fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in suggestions)
                          ActionChip(
                            label: Text(s),
                            labelStyle: const TextStyle(
                                color: Color(0xFFE8F5E9), fontSize: 13),
                            backgroundColor: const Color(0xFF173024),
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onSuggestion(s),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  final ValueChanged<PendingAction> onConfirm;
  final ValueChanged<PendingAction> onEdit;
  final ValueChanged<PendingAction> onCancel;
  final ValueChanged<ClarOption> onClarifyOption;

  const _MessageBubble({
    required this.message,
    required this.onConfirm,
    required this.onEdit,
    required this.onCancel,
    required this.onClarifyOption,
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
      case _Kind.clarify:
        return _ClarifyCard(
          clarification: message.clarification!,
          onSelect: onClarifyOption,
        );
    }
  }
}

/// "Which plant?" / "Did you mean?" — renders the options as tappable chips
/// plus a hint that the user can still type the correct name.
class _ClarifyCard extends StatelessWidget {
  final Clarification clarification;
  final ValueChanged<ClarOption> onSelect;

  const _ClarifyCard({required this.clarification, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF13251A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2E7D32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: clarification.options
                  .map((o) => ActionChip(
                        label: Text(o.label),
                        labelStyle: const TextStyle(
                            color: Color(0xFFE8F5E9), fontSize: 13),
                        backgroundColor: const Color(0xFF1E3D24),
                        side: const BorderSide(color: Color(0xFF66BB6A)),
                        onPressed: () => onSelect(o),
                      ))
                  .toList(),
            ),
            if (clarification.allowFreeText) ...[
              const SizedBox(height: 8),
              Text(
                clarification.kind == 'did_you_mean'
                    ? '…or type the correct name.'
                    : '…or type the section / plant id.',
                style: const TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
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

          // ── Plain-language sentence first ──
          // A gardener confirming a write should not have to read a table name
          // to know what they are agreeing to. The technical detail stays below
          // for whoever wants it.
          if (action.plainSummary != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF13301A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2E7D32), width: 1),
              ),
              child: Text(
                action.plainSummary!,
                style: const TextStyle(
                    color: Color(0xFFE8F5E9), fontSize: 14, height: 1.45),
              ),
            ),
          if (action.plainSummary != null) const SizedBox(height: 10),

          Text(action.preview,
              style: TextStyle(
                  color: action.plainSummary != null
                      ? const Color(0xFF9CCC9F)
                      : const Color(0xFFE8F5E9),
                  fontSize: action.plainSummary != null ? 12 : 14,
                  height: 1.45)),

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

          // ── Exact database operation (read-only) ──
          if (action.sqlDisplay != null) ...[
            const SizedBox(height: 12),
            const Text('DATABASE OPERATION',
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
