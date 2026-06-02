import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_session.dart';
import '../models/plant_info.dart';
import 'auth_service.dart';

/// Stores chat sessions in Firestore under /users/{uid}/chats/{sessionId}.
/// Available to all users regardless of subscription tier.
class ChatHistoryService {
  ChatHistoryService._();
  static final ChatHistoryService instance = ChatHistoryService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  ChatSession? _current;

  ChatSession? get current => _current;

  String? get _uid => AuthService.instance.currentUser?.id;

  /// Starts a new chat session for an identified plant.
  Future<ChatSession?> startSession({
    required PlantInfo plant,
    String? userPhotoPath,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    final docRef = _firestore.collection('users').doc(uid).collection('chats').doc();
    final now = DateTime.now();
    final session = ChatSession(
      id: docRef.id,
      plantCommonName: plant.commonName,
      plantScientificName: plant.scientificName,
      plantFamily: plant.family,
      plantImageUrl: plant.imageUrl,
      userPhotoPath: userPhotoPath,
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
    try {
      await docRef.set(session.toJson());
    } catch (_) {/* offline OK — will sync later */}
    _current = session;
    return session;
  }

  /// Appends a message to the current session and persists it.
  Future<void> appendMessage({
    required String text,
    required bool isUser,
  }) async {
    final session = _current;
    final uid = _uid;
    if (session == null || uid == null) return;

    final msg = ChatMessage(
      text: text,
      isUser: isUser,
      timestamp: DateTime.now(),
    );
    final updated = session.copyWith(
      messages: [...session.messages, msg],
      updatedAt: DateTime.now(),
    );
    _current = updated;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(session.id)
          .update({
        'messages': updated.messages.map((m) => m.toJson()).toList(),
        'updatedAt': updated.updatedAt.toIso8601String(),
      });
    } catch (_) {/* offline OK */}
  }

  /// Streams all chat sessions for the signed-in user, newest first.
  Stream<List<ChatSession>> watchAll() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatSession.fromJson(d.data())).toList());
  }

  /// Resumes an existing chat session — sets it as the current session so
  /// new messages get appended to it. Returns the loaded session.
  Future<ChatSession?> resumeSession(String sessionId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(sessionId)
          .get();
      if (!snap.exists) return null;
      _current = ChatSession.fromJson(snap.data()!);
      return _current;
    } catch (_) {
      return null;
    }
  }

  /// Loads a session by ID without making it current (read-only view).
  Future<ChatSession?> load(String sessionId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(sessionId)
          .get();
      if (!snap.exists) return null;
      return ChatSession.fromJson(snap.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Deletes a chat session by id.
  Future<void> delete(String sessionId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(sessionId)
          .delete();
      if (_current?.id == sessionId) _current = null;
    } catch (_) {}
  }

  void clearCurrent() => _current = null;

  /// Deletes multiple chat sessions in a single Firestore batch.
  ///
  /// Crucial that this is atomic: when we deleted sequentially with N awaits,
  /// each delete triggered a Firestore snapshot which re-rendered the chat
  /// list and could race with the in-flight iteration, leading to "only the
  /// last selected chat deleted" symptoms. A WriteBatch emits ONE snapshot
  /// after the whole commit lands, so the UI sees a single clean update.
  Future<void> deleteMany(Iterable<String> sessionIds) async {
    final uid = _uid;
    if (uid == null) return;
    final ids = sessionIds.toList(growable: false); // snapshot — caller-safe
    if (ids.isEmpty) return;
    try {
      final batch = _firestore.batch();
      final col =
          _firestore.collection('users').doc(uid).collection('chats');
      for (final id in ids) {
        batch.delete(col.doc(id));
      }
      await batch.commit();
      if (ids.contains(_current?.id)) _current = null;
    } catch (_) {
      // Fall back to sequential delete on batch failure so the user at least
      // sees progress.
      for (final id in ids) {
        await delete(id);
      }
    }
  }

  /// Overwrites the messages array of a session (used for edit / delete).
  Future<void> updateMessages(
      String sessionId, List<ChatMessage> messages) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(sessionId)
          .update({
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      if (_current?.id == sessionId) {
        _current = _current!.copyWith(messages: messages);
      }
    } catch (_) {}
  }

  /// Renames a chat session (updates its display name).
  Future<void> setName(String sessionId, String newName) async {
    final uid = _uid;
    if (uid == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(sessionId)
          .update({'plantCommonName': trimmed});
    } catch (_) {}
  }

  /// Pins or unpins a chat session.
  Future<void> setPinned(String sessionId, bool pinned) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(sessionId)
          .update({'isPinned': pinned});
    } catch (_) {}
  }

  /// Starts a "general botany" chat (no specific plant).
  Future<ChatSession?> startGeneralSession({
    required String generalName,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    final docRef =
        _firestore.collection('users').doc(uid).collection('chats').doc();
    final now = DateTime.now();
    final session = ChatSession(
      id: docRef.id,
      plantCommonName: generalName,
      plantScientificName: 'Botanica',
      plantFamily: 'Botany',
      plantImageUrl: null,
      userPhotoPath: null,
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
    try {
      await docRef.set(session.toJson());
    } catch (_) {}
    _current = session;
    return session;
  }
}
