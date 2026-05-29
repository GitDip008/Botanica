enum SubscriptionTier {
  free,
  premium;

  bool get isPremium => this == SubscriptionTier.premium;
}

enum EffectiveAccess { free, premium, adminPro }

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final SubscriptionTier tier;
  final DateTime joinedAt;
  final bool isAdmin;

  // ── Daily usage tracking ──────────────────────────────────────────────────
  /// IDs of chat sessions the user has sent at least one message in today.
  /// Counter = length of this set. Opening the same chat twice doesn't double-count.
  final List<String> chatsUsedTodayIds;
  final int huntsCompletedToday;
  final DateTime? lastUsageReset;

  /// Admin email allow-list. Anyone here gets isAdmin=true and unlimited access.
  static const adminEmails = <String>{
    'admin@botanica.fi',
    'shourovdip147@gmail.com',
  };

  // ── Tier rules ────────────────────────────────────────────────────────────
  static const freeDailyChatLimit = 10;
  static const freeDailyHuntLimit = 1;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.tier = SubscriptionTier.free,
    required this.joinedAt,
    this.isAdmin = false,
    this.chatsUsedTodayIds = const [],
    this.huntsCompletedToday = 0,
    this.lastUsageReset,
  });

  EffectiveAccess get access {
    if (isAdmin) return EffectiveAccess.adminPro;
    if (tier.isPremium) return EffectiveAccess.premium;
    return EffectiveAccess.free;
  }

  bool get hasUnlimitedAccess => isAdmin || tier.isPremium;

  /// Number of distinct chats the user has used today.
  int get chatsUsedToday => chatsUsedTodayIds.length;

  int get chatsRemaining => hasUnlimitedAccess
      ? 999999
      : (freeDailyChatLimit - chatsUsedToday).clamp(0, freeDailyChatLimit);

  /// True if the user is allowed to send a message in the given chat session
  /// right now. Free-tier rules:
  ///   • If this chat is already counted today → always allow
  ///   • Otherwise allow only if they haven't hit the 10-chat daily cap
  bool canChatInSession(String chatId) {
    if (hasUnlimitedAccess) return true;
    if (chatsUsedTodayIds.contains(chatId)) return true;
    return chatsUsedTodayIds.length < freeDailyChatLimit;
  }

  /// Legacy convenience for screens that don't have a chat id yet.
  bool get canChat => hasUnlimitedAccess || chatsRemaining > 0;

  bool get canStartHunt =>
      hasUnlimitedAccess || huntsCompletedToday < freeDailyHuntLimit;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'tier': tier.name,
        'joinedAt': joinedAt.toIso8601String(),
        'isAdmin': isAdmin,
        'chatsUsedTodayIds': chatsUsedTodayIds,
        'huntsCompletedToday': huntsCompletedToday,
        'lastUsageReset': lastUsageReset?.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String? ?? '',
        photoUrl: json['photoUrl'] as String?,
        tier: SubscriptionTier.values.firstWhere(
          (t) => t.name == json['tier'],
          orElse: () => SubscriptionTier.free,
        ),
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        isAdmin: (json['isAdmin'] as bool?) ?? false,
        chatsUsedTodayIds: ((json['chatsUsedTodayIds'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        huntsCompletedToday: (json['huntsCompletedToday'] as int?) ?? 0,
        lastUsageReset: json['lastUsageReset'] == null
            ? null
            : DateTime.parse(json['lastUsageReset'] as String),
      );

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    SubscriptionTier? tier,
    DateTime? joinedAt,
    bool? isAdmin,
    List<String>? chatsUsedTodayIds,
    int? huntsCompletedToday,
    DateTime? lastUsageReset,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      tier: tier ?? this.tier,
      joinedAt: joinedAt ?? this.joinedAt,
      isAdmin: isAdmin ?? this.isAdmin,
      chatsUsedTodayIds: chatsUsedTodayIds ?? this.chatsUsedTodayIds,
      huntsCompletedToday: huntsCompletedToday ?? this.huntsCompletedToday,
      lastUsageReset: lastUsageReset ?? this.lastUsageReset,
    );
  }
}
