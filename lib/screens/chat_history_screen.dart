import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_session.dart';
import '../services/chat_history_service.dart';
import '../services/language_service.dart';
import 'chat_continuation_screen.dart';
import 'main_nav_screen.dart';

/// All-tier accessible list of past plant conversations. Tap one to continue.
class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final Set<String> _selected = {};
  bool get _selectionMode => _selected.isNotEmpty;
  List<ChatSession> _allSessions = const [];

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Color(0xFF4A7A50),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4),
      );

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _enterSelection(String id) {
    setState(() => _selected.add(id));
  }

  void _clearSelection() => setState(() => _selected.clear());

  void _toggleSelectAll() {
    setState(() {
      if (_selected.length == _allSessions.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_allSessions.map((c) => c.id));
      }
    });
  }

  Future<void> _deleteSelected(dynamic s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111F16),
        title: Text(s.deleteSelectedTitle,
            style: const TextStyle(color: Color(0xFFE8F5E9))),
        content: Text(s.deleteChatBody,
            style: const TextStyle(color: Color(0xFF81C784))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.delete,
                  style: const TextStyle(color: Color(0xFFEF5350)))),
        ],
      ),
    );
    if (ok == true) {
      await ChatHistoryService.instance.deleteMany(_selected);
      _clearSelection();
    }
  }

  /// The single selected session, or null if 0 or >1 selected.
  ChatSession? get _singleSelected {
    if (_selected.length != 1) return null;
    final id = _selected.first;
    for (final c in _allSessions) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _pinSingle() async {
    final c = _singleSelected;
    if (c == null) return;
    await ChatHistoryService.instance.setPinned(c.id, !c.isPinned);
    _clearSelection();
  }

  Future<void> _renameSingle(dynamic s) async {
    final c = _singleSelected;
    if (c == null) return;
    final ctrl = TextEditingController(text: c.plantCommonName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111F16),
        title: Text(s.renameChatTitle,
            style: const TextStyle(color: Color(0xFFE8F5E9))),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          style: const TextStyle(color: Color(0xFFE8F5E9)),
          decoration: InputDecoration(
            labelText: s.newName,
            labelStyle: const TextStyle(color: Color(0xFF81C784)),
            counterStyle: const TextStyle(color: Color(0xFF4A7A50)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(s.save,
                  style: const TextStyle(color: Color(0xFF66BB6A)))),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ChatHistoryService.instance.setName(c.id, newName);
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    final allSelected =
        _allSessions.isNotEmpty && _selected.length == _allSessions.length;
    final single = _singleSelected;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: _selectionMode
          ? AppBar(
              backgroundColor: const Color(0xFF0D1F14),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFFE8F5E9)),
                onPressed: _clearSelection,
              ),
              title: Text(s.selectedCount(_selected.length),
                  style: const TextStyle(color: Color(0xFFE8F5E9))),
              actions: [
                // When exactly one chat is selected → Pin + Rename
                if (single != null) ...[
                  IconButton(
                    tooltip: single.isPinned ? s.unpin : s.pin,
                    icon: Icon(
                      single.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: const Color(0xFFFFD54F),
                    ),
                    onPressed: _pinSingle,
                  ),
                  IconButton(
                    tooltip: s.rename,
                    icon: const Icon(Icons.edit_rounded,
                        color: Color(0xFF64B5F6)),
                    onPressed: () => _renameSingle(s),
                  ),
                ],
                IconButton(
                  tooltip: allSelected ? s.deselectAll : s.selectAll,
                  icon: Icon(
                    allSelected
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    color: const Color(0xFF66BB6A),
                  ),
                  onPressed: _toggleSelectAll,
                ),
                IconButton(
                  tooltip: s.delete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF5350)),
                  onPressed: () => _deleteSelected(s),
                ),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFFE8F5E9)),
                onPressed: () =>
                    MainNavScreen.scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(s.chatsTitle),
              backgroundColor: const Color(0xFF0D1F14),
              elevation: 0,
              automaticallyImplyLeading: false,
            ),
      body: StreamBuilder<List<ChatSession>>(
        stream: ChatHistoryService.instance.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF66BB6A)));
          }
          final sessions = snap.data ?? const [];
          _allSessions = sessions;
          if (sessions.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _NewChatCard(s: s),
                const SizedBox(height: 32),
                const Icon(Icons.forum_outlined,
                    color: Color(0xFF4A7A50), size: 64),
                const SizedBox(height: 14),
                Text(s.noChatsYet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  s.noChatsYetBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF81C784), fontSize: 13),
                ),
              ],
            );
          }
          final pinned = sessions.where((c) => c.isPinned).toList();
          final recent = sessions.where((c) => !c.isPinned).toList();

          Widget tile(ChatSession c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SessionTile(
                  session: c,
                  selectionMode: _selectionMode,
                  selected: _selected.contains(c.id),
                  onToggle: () => _toggle(c.id),
                  onEnterSelection: () => _enterSelection(c.id),
                ),
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_selectionMode) ...[
                _NewChatCard(s: s),
                const SizedBox(height: 16),
              ],
              if (pinned.isNotEmpty) ...[
                _sectionLabel(s.pinnedSection),
                const SizedBox(height: 8),
                ...pinned.map(tile),
                const SizedBox(height: 16),
              ],
              if (recent.isNotEmpty) ...[
                _sectionLabel(s.recentChats),
                const SizedBox(height: 8),
                ...recent.map(tile),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEnterSelection;
  const _SessionTile({
    required this.session,
    this.selectionMode = false,
    this.selected = false,
    required this.onToggle,
    required this.onEnterSelection,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    final msgCount = session.messages.length;
    final formatter = DateFormat('MMM d · HH:mm');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (selectionMode) {
            onToggle();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChatContinuationScreen(initialSession: session),
              ),
            );
          }
        },
        onLongPress: () {
          if (selectionMode) {
            onToggle();
          } else {
            onEnterSelection();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1A3320)
                : const Color(0xFF111F16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFF2A4A2F),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFF4A7A50),
                  size: 24,
                ),
                const SizedBox(width: 12),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: session.plantImageUrl != null
                    ? Image.network(
                        session.plantImageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.plantCommonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9),
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      session.plantScientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$msgCount ${msgCount == 1 ? s.message : s.messages} · ${formatter.format(session.updatedAt)}',
                      style: const TextStyle(color: Color(0xFF4A7A50), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (session.isPinned)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.push_pin_rounded,
                      color: Color(0xFFFFD54F), size: 14),
                ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF4A7A50), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    // General-botany chats (no plant) get a chat bubble icon instead of a leaf.
    final isGeneral = session.plantScientificName == 'Botanica';
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFF1A2E1E),
      child: Center(
        child: isGeneral
            ? const Text('🌱', style: TextStyle(fontSize: 26))
            : const Text('🌿', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}

// ─── New chat card ───────────────────────────────────────────────────────────
class _NewChatCard extends StatelessWidget {
  final dynamic s;
  const _NewChatCard({required this.s});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          // Start a "general botany" chat — no specific plant context.
          final session = await ChatHistoryService.instance
              .startGeneralSession(generalName: s.generalBotany);
          if (session == null || !context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatContinuationScreen(initialSession: session),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B4020), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Text('🌱', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.startNewChat,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(s.identifyOrSearchToBegin,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
