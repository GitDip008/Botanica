import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/chat_session.dart';
import '../models/plant_info.dart';
import '../services/chat_history_service.dart';
import '../services/chat_service.dart';
import '../services/language_service.dart';

/// Continue an existing chat session — load all past messages, allow new ones.
class ChatContinuationScreen extends StatefulWidget {
  final ChatSession initialSession;
  const ChatContinuationScreen({super.key, required this.initialSession});

  @override
  State<ChatContinuationScreen> createState() => _ChatContinuationScreenState();
}

class _ChatContinuationScreenState extends State<ChatContinuationScreen> {
  late ChatSession _session;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;
  bool _resuming = true;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _resume();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _resume() async {
    // Make this the active session so new messages append to it
    final loaded =
        await ChatHistoryService.instance.resumeSession(_session.id);
    if (loaded != null) {
      _session = loaded;
    }
    // Re-seed the cloud LLM with the conversation history so it remembers
    final plant = PlantInfo(
      scientificName: _session.plantScientificName,
      commonName: _session.plantCommonName,
      family: _session.plantFamily,
      description:
          '${_session.plantCommonName} (${_session.plantScientificName})',
      imageUrl: _session.plantImageUrl,
      isPlant: true,
    );
    ChatService.instance.cloud.seedPlantContextWithHistory(
      plant,
      _session.messages
          .map((m) => (text: m.text, isUser: m.isUser))
          .toList(),
    );
    if (mounted) {
      setState(() => _resuming = false);
      _scrollToBottom();
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() {
      _isSending = true;
      _inputCtrl.clear();
      _session = _session.copyWith(
        messages: [
          ..._session.messages,
          ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
        ],
      );
    });
    _scrollToBottom();

    final reply = await ChatService.instance.sendMessage(text);
    if (!mounted) return;

    if (reply == ChatService.chatLimitReachedMarker) {
      setState(() {
        _session = _session.copyWith(messages: [
          ..._session.messages,
          ChatMessage(
            text:
                "You've reached today's free chat limit (10 conversations/day). 🌿\n\nUpgrade to **Premium** for unlimited chats, or come back tomorrow!",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ]);
        _isSending = false;
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _session = _session.copyWith(messages: [
        ..._session.messages,
        ChatMessage(text: reply, isUser: false, timestamp: DateTime.now()),
      ]);
      _isSending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Whole-chat actions (3-dot menu) ────────────────────────────────────
  Future<void> _renameDialog(dynamic s) async {
    final ctrl = TextEditingController(text: _session.plantCommonName);
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
      await ChatHistoryService.instance.setName(_session.id, newName);
      setState(() => _session = ChatSession(
            id: _session.id,
            plantCommonName: newName,
            plantScientificName: _session.plantScientificName,
            plantFamily: _session.plantFamily,
            plantImageUrl: _session.plantImageUrl,
            userPhotoPath: _session.userPhotoPath,
            createdAt: _session.createdAt,
            updatedAt: _session.updatedAt,
            messages: _session.messages,
            isPinned: _session.isPinned,
          ));
    }
  }

  Future<void> _deleteChat(dynamic s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111F16),
        title: Text(s.deleteChatTitle,
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
      await ChatHistoryService.instance.delete(_session.id);
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Per-message actions (long-press) ───────────────────────────────────
  Future<void> _showMessageMenu(int index, dynamic s) async {
    final msg = _session.messages[index];
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111F16),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFF2A4A2F),
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Color(0xFF66BB6A)),
              title: Text(s.copy,
                  style: const TextStyle(color: Color(0xFFE8F5E9))),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.text));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: const Color(0xFF2E7D32),
                  duration: const Duration(seconds: 1),
                  content: Text(s.copied),
                ));
              },
            ),
            // Edit — only the user's own messages
            if (msg.isUser)
              ListTile(
                leading:
                    const Icon(Icons.edit_rounded, color: Color(0xFF64B5F6)),
                title: Text(s.edit,
                    style: const TextStyle(color: Color(0xFFE8F5E9))),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMessage(index, s);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF5350)),
              title: Text(s.delete,
                  style: const TextStyle(color: Color(0xFFEF5350))),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessage(index);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _editMessage(int index, dynamic s) async {
    final ctrl = TextEditingController(text: _session.messages[index].text);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111F16),
        title: Text(s.editMessage,
            style: const TextStyle(color: Color(0xFFE8F5E9))),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          style: const TextStyle(color: Color(0xFFE8F5E9)),
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
    if (newText == null || newText.isEmpty) return;
    final updated = List<ChatMessage>.from(_session.messages);
    final old = updated[index];
    updated[index] = ChatMessage(
        text: newText, isUser: old.isUser, timestamp: old.timestamp);
    setState(() => _session = _session.copyWith(messages: updated));
    await ChatHistoryService.instance.updateMessages(_session.id, updated);
  }

  Future<void> _deleteMessage(int index) async {
    final updated = List<ChatMessage>.from(_session.messages)..removeAt(index);
    setState(() => _session = _session.copyWith(messages: updated));
    await ChatHistoryService.instance.updateMessages(_session.id, updated);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_session.plantCommonName,
                style: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text(_session.plantScientificName,
                style: const TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 11,
                    fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFE8F5E9)),
            color: const Color(0xFF111F16),
            onSelected: (v) {
              if (v == 'pin') {
                ChatHistoryService.instance
                    .setPinned(_session.id, !_session.isPinned);
                setState(() => _session =
                    _session.copyWith(isPinned: !_session.isPinned));
              } else if (v == 'rename') {
                _renameDialog(s);
              } else if (v == 'delete') {
                _deleteChat(s);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pin',
                child: Row(children: [
                  Icon(
                      _session.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: const Color(0xFFFFD54F), size: 18),
                  const SizedBox(width: 10),
                  Text(_session.isPinned ? s.unpin : s.pin,
                      style: const TextStyle(color: Color(0xFFE8F5E9))),
                ]),
              ),
              PopupMenuItem(
                value: 'rename',
                child: Row(children: [
                  const Icon(Icons.edit_rounded,
                      color: Color(0xFF64B5F6), size: 18),
                  const SizedBox(width: 10),
                  Text(s.rename,
                      style: const TextStyle(color: Color(0xFFE8F5E9))),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF5350), size: 18),
                  const SizedBox(width: 10),
                  Text(s.delete,
                      style: const TextStyle(color: Color(0xFFEF5350))),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_session.plantImageUrl != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _session.plantImageUrl!,
                    height: 130,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Expanded(
              child: _resuming
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF66BB6A)))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      itemCount: _session.messages.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onLongPress: () => _showMessageMenu(i, s),
                        child: _bubble(_session.messages[i]),
                      ),
                    ),
            ),
            if (_isSending)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 22),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Color(0xFF66BB6A), strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1F14),
                border: Border(top: BorderSide(color: Color(0xFF1E3D24))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: const TextStyle(color: Color(0xFFE8F5E9), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: s.askAboutThisPlant,
                        hintStyle: const TextStyle(
                            color: Color(0xFF4A7A50), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF111F16),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: Color(0xFF2A4A2F)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: Color(0xFF2A4A2F)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide:
                              const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: const Color(0xFF2E7D32),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isSending ? null : _send,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: m.isUser ? const Color(0xFF2E7D32) : const Color(0xFF111F16),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(m.isUser ? 16 : 4),
            bottomRight: Radius.circular(m.isUser ? 4 : 16),
          ),
          border: m.isUser ? null : Border.all(color: const Color(0xFF2A4A2F)),
        ),
        child: m.isUser
            ? Text(m.text,
                style: const TextStyle(
                    color: Color(0xFFE8F5E9), fontSize: 14, height: 1.45))
            : MarkdownBody(
                data: m.text,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                      color: Color(0xFFE8F5E9), fontSize: 14, height: 1.45),
                  strong: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                  em: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 14,
                      fontStyle: FontStyle.italic),
                  listBullet:
                      const TextStyle(color: Color(0xFF81C784), fontSize: 14),
                  h1: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                  h2: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                  h3: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                  blockSpacing: 8,
                ),
              ),
      ),
    );
  }
}
