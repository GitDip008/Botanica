import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_session.dart';
import '../services/chat_history_service.dart';
import '../services/language_service.dart';
import 'chat_continuation_screen.dart';
import 'main_nav_screen.dart';
import '../theme/tokens.dart';

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
            color: C.textFaint,
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
        backgroundColor: C.surface,
        title: Text(s.deleteSelectedTitle,
            style: const TextStyle(color: C.textHi)),
        content: Text(s.deleteChatBody,
            style: const TextStyle(color: C.accent)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.delete,
                  style: const TextStyle(color: C.danger))),
        ],
      ),
    );
    if (ok == true) {
      // Snapshot the selection BEFORE the await so a mid-flight stream
      // rebuild can't mutate it out from under us. This was the source of
      // the "only the last selected chat is deleted" bug.
      final ids = _selected.toList(growable: false);
      _clearSelection(); // visually exit selection mode immediately
      await ChatHistoryService.instance.deleteMany(ids);
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
        backgroundColor: C.surface,
        title: Text(s.renameChatTitle,
            style: const TextStyle(color: C.textHi)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          style: const TextStyle(color: C.textHi),
          decoration: InputDecoration(
            labelText: s.newName,
            labelStyle: const TextStyle(color: C.accent),
            counterStyle: const TextStyle(color: C.textFaint),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(s.save,
                  style: const TextStyle(color: C.accent))),
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
      backgroundColor: C.bg,
      appBar: _selectionMode
          ? AppBar(
              backgroundColor: C.bg,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: C.textHi),
                onPressed: _clearSelection,
              ),
              title: Text(s.selectedCount(_selected.length),
                  style: const TextStyle(color: C.textHi)),
              actions: [
                // When exactly one chat is selected → Pin + Rename
                if (single != null) ...[
                  IconButton(
                    tooltip: single.isPinned ? s.unpin : s.pin,
                    icon: Icon(
                      single.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: C.gold,
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
                    color: C.accent,
                  ),
                  onPressed: _toggleSelectAll,
                ),
                IconButton(
                  tooltip: s.delete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: C.danger),
                  onPressed: () => _deleteSelected(s),
                ),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded, color: C.textHi),
                onPressed: () =>
                    MainNavScreen.scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(s.chatsTitle),
              backgroundColor: C.bg,
              elevation: 0,
              automaticallyImplyLeading: false,
            ),
      body: StreamBuilder<List<ChatSession>>(
        stream: ChatHistoryService.instance.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: C.accent));
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
                    color: C.textFaint, size: 64),
                const SizedBox(height: 14),
                Text(s.noChatsYet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: C.textHi,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  s.noChatsYetBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.accent, fontSize: 13),
                ),
              ],
            );
          }
          final pinned = sessions.where((c) => c.isPinned).toList();
          final recent = sessions.where((c) => !c.isPinned).toList();

          Widget tile(ChatSession c) => Padding(
                key: ValueKey('chat-tile-${c.id}'),
                padding: const EdgeInsets.only(bottom: 10),
                child: _SessionTile(
                  key: ValueKey('chat-${c.id}'),
                  session: c,
                  selectionMode: _selectionMode,
                  selected: _selected.contains(c.id),
                  onToggle: () => _toggle(c.id),
                  onEnterSelection: () => _enterSelection(c.id),
                ),
              );

          return ListView(
            key: const PageStorageKey('chat-history-list'),
            padding: const EdgeInsets.all(16),
            children: [
              // Keep the New-chat card slot in the tree at all times so the
              // list layout doesn't jump when selection mode toggles. We just
              // collapse it to zero height while selecting.
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: _selectionMode
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _NewChatCard(s: s),
                      ),
              ),
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
    super.key,
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
                ? C.surfaceAlt
                : C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? C.accent
                  : C.line,
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
                      ? C.accent
                      : C.textFaint,
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
                          color: C.textHi,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      session.plantScientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: C.accent,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$msgCount ${msgCount == 1 ? s.message : s.messages} · ${formatter.format(session.updatedAt)}',
                      style: const TextStyle(color: C.textFaint, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (session.isPinned)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.push_pin_rounded,
                      color: C.gold, size: 14),
                ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: C.textFaint, size: 14),
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
      color: C.surface,
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
              colors: [C.surfaceAlt, C.accentDim],
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
