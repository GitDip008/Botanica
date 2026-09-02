import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/plant_info.dart';
import '../services/chat_service.dart';
import 'dart:typed_data';

import '../services/gemini_service.dart';
import '../services/language_service.dart';
import '../widgets/plant_tags_bar.dart';

class PlantResultScreen extends StatefulWidget {
  final String imagePath;

  /// The captured bytes. Required on web, where imagePath is a blob URL and
  /// File() throws "UnsupportedOperation: _Namespace".
  final Uint8List? imageBytes;
  final PlantInfo plantInfo;
  final GeminiService geminiService;

  const PlantResultScreen({
    super.key,
    required this.imagePath,
    this.imageBytes,
    required this.plantInfo,
    required this.geminiService,
  });

  @override
  State<PlantResultScreen> createState() => _PlantResultScreenState();
}

class _PlantResultScreenState extends State<PlantResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _inputCtrl.clear();
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final reply = await ChatService.instance.sendMessage(text);
      if (!mounted) return;
      // Handle free-tier daily limit
      if (reply == ChatService.chatLimitReachedMarker) {
        setState(() {
          _messages.add(const _ChatMessage(
            text:
                "You've reached today's free chat limit (10/day). 🌿\n\nUpgrade to **Premium** for unlimited conversations — or check back tomorrow!",
            isUser: false,
          ));
          _isSending = false;
        });
        _scrollToBottom();
        return;
      }
      setState(() {
        _messages.add(_ChatMessage(text: reply, isUser: false));
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: 'Error: $e', isUser: false));
          _isSending = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF66BB6A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.plantInfo.commonName,
          style: const TextStyle(
            color: Color(0xFFE8F5E9),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF66BB6A),
          indicatorWeight: 3,
          labelColor: const Color(0xFF66BB6A),
          unselectedLabelColor: const Color(0xFF4CAF50),
          tabs: [
            Tab(icon: const Icon(Icons.eco_rounded), text: s.tabPlant),
            Tab(icon: const Icon(Icons.chat_bubble_outline_rounded), text: s.tabChat),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPlantTab(),
          _buildChatTab(),
        ],
      ),
    );
  }

  Widget _buildPlantTab() {
    final info = widget.plantInfo;
    final s = context.watch<LanguageService>().strings;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image with gradient overlay — tap to zoom
          Stack(
            children: [
              if (widget.imagePath.isNotEmpty)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      barrierColor: Colors.black,
                      pageBuilder: (_, __, ___) =>
                          _ImageViewer(localPath: widget.imagePath, bytes: widget.imageBytes),
                    ),
                  ),
                  child: Hero(
                    tag: 'plant_image',
                    // Bytes first: they work everywhere. File only as a
                    // fallback for older call sites that pass a path alone.
                    child: widget.imageBytes != null
                        ? Image.memory(widget.imageBytes!,
                            height: 260, width: double.infinity, fit: BoxFit.cover)
                        : Image.file(File(widget.imagePath),
                            height: 260, width: double.infinity, fit: BoxFit.cover),
                  ),
                )
              else if (info.imageUrl != null)
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      barrierColor: Colors.black,
                      pageBuilder: (_, __, ___) =>
                          _ImageViewer(networkUrl: info.imageUrl!),
                    ),
                  ),
                  child: Hero(
                    tag: 'plant_image',
                    child: Image.network(
                      info.imageUrl!,
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, prog) {
                        if (prog == null) return child;
                        return Container(
                          height: 260,
                          color: const Color(0xFF1A2E1E),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF66BB6A), strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: const Color(0xFF1A2E1E),
                        child: const Center(
                            child: Text('🌿', style: TextStyle(fontSize: 64))),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 180,
                  width: double.infinity,
                  color: const Color(0xFF1A2E1E),
                  child: const Center(child: Text('🌿', style: TextStyle(fontSize: 64))),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFF0D1F14), Colors.transparent],
                    ),
                  ),
                ),
              ),
              if (!info.isPlant)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Center(
                      child: Text(
                        s.noPlantDetected,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                ),
            ],
          ).animate().fadeIn(duration: 500.ms),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Curated tags for this species, if the garden's own list
                // covers it. Local data — renders with no network call, and
                // shows nothing at all for the ~11k plants with no tags.
                PlantTagsBar(scientificName: info.scientificName),
                _InfoCard(
                  label: s.scientificNameLabel,
                  value: info.scientificName,
                  icon: Icons.science_rounded,
                ).animate().slideX(begin: -0.3, duration: 400.ms, delay: 100.ms),
                const SizedBox(height: 10),
                _InfoCard(
                  label: s.commonNameLabel,
                  value: info.commonName,
                  icon: Icons.local_florist_rounded,
                ).animate().slideX(begin: -0.3, duration: 400.ms, delay: 200.ms),
                if (info.finnishName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoCard(
                    label: s.finnishNameLabel,
                    value: info.finnishName,
                    icon: Icons.translate_rounded,
                  ).animate().slideX(begin: -0.3, duration: 400.ms, delay: 250.ms),
                ],
                const SizedBox(height: 10),
                _InfoCard(
                  label: s.familyLabel,
                  value: info.family,
                  icon: Icons.account_tree_rounded,
                ).animate().slideX(begin: -0.3, duration: 400.ms, delay: 300.ms),
                if (info.originRegion.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoCard(
                    label: s.originRegionLabel,
                    value: info.originRegion,
                    icon: Icons.public_rounded,
                  ).animate().slideX(begin: -0.3, duration: 400.ms, delay: 350.ms),
                ],
                if (info.greenhouseSection.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoCard(
                    label: s.findItInLabel,
                    value: info.greenhouseSection,
                    icon: Icons.location_on_rounded,
                  ).animate().slideX(begin: -0.3, duration: 400.ms, delay: 375.ms),
                ],
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2E1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2E7D32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description_rounded,
                              color: Color(0xFF66BB6A), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            s.descriptionUpper,
                            style: const TextStyle(
                              color: Color(0xFF66BB6A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        info.description,
                        style: const TextStyle(
                          color: Color(0xFFE8F5E9),
                          fontSize: 14.5,
                          height: 1.65,
                        ),
                      ),
                    ],
                  ),
                ).animate().slideX(begin: -0.3, duration: 400.ms, delay: 400.ms),
                if (info.funFact.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2E1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF57F17)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('💡', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Text(
                              'DID YOU KNOW?',
                              style: TextStyle(
                                color: Color(0xFFFFA726),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          info.funFact,
                          style: const TextStyle(
                            color: Color(0xFFE8F5E9),
                            fontSize: 14.5,
                            height: 1.65,
                          ),
                        ),
                      ],
                    ),
                  ).animate().slideX(begin: -0.3, duration: 400.ms, delay: 480.ms),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(
                      s.askAboutThisPlant,
                      style: const TextStyle(fontSize: 15),
                    ),
                    onPressed: () => _tabController.animateTo(1),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 550.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    final s = context.watch<LanguageService>().strings;
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF2E7D32), size: 52),
                      const SizedBox(height: 14),
                      Text(
                        s.askAnythingAboutPlant,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 17,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.plantInfo.scientificName,
                        style: const TextStyle(
                          color: Color(0xFF66BB6A),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _ChatBubble(message: _messages[i]),
                ),
        ),
        if (_isSending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: Color(0xFF66BB6A), strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(s.thinking,
                    style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          color: const Color(0xFF1A2E1E),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  style: const TextStyle(color: Color(0xFFE8F5E9)),
                  decoration: InputDecoration(
                    hintText: s.askAboutThisPlantHint,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

// ─── helpers ───────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E7D32)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF66BB6A), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF66BB6A),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  const _ChatMessage({required this.text, required this.isUser});
}

// ─── Full-screen image viewer with pinch-to-zoom ──────────────────────────────
class _ImageViewer extends StatelessWidget {
  final Uint8List? bytes;
  final String? localPath;
  final String? networkUrl;
  const _ImageViewer({this.localPath, this.networkUrl, this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Tap anywhere outside the image to close
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
          Center(
            child: Hero(
              tag: 'plant_image',
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: localPath != null
                    ? (bytes != null
                        ? Image.memory(bytes!)
                        : Image.file(File(localPath!)))
                    : Image.network(
                        networkUrl!,
                        loadingBuilder: (_, child, prog) {
                          if (prog == null) return child;
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF66BB6A)));
                        },
                      ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: message.isUser
              ? const Color(0xFF2E7D32)
              : const Color(0xFF1A2E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isUser
              ? null
              : Border.all(color: const Color(0xFF2E7D32)),
        ),
        child: message.isUser
            ? Text(
                message.text,
                style: const TextStyle(
                  color: Color(0xFFE8F5E9),
                  fontSize: 14,
                  height: 1.45,
                ),
              )
            : MarkdownBody(
                data: message.text,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 14,
                    height: 1.45,
                  ),
                  strong: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                  em: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                  listBullet: const TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 14,
                  ),
                  code: const TextStyle(
                    color: Color(0xFFC5E1A5),
                    fontSize: 13,
                    backgroundColor: Color(0xFF0D1F14),
                    fontFamily: 'monospace',
                  ),
                  h1: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  h2: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  h3: const TextStyle(
                    color: Color(0xFFE8F5E9),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  blockquote: const TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  blockSpacing: 8,
                ),
              ),
      ),
    );
  }
}
