import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Wraps the `agent` Cloud Function callable. One `send()` per user turn —
/// whether the input was typed or spoken. Returns the agent's reply plus any
/// pending actions the UI needs to confirm.
class AgentService {
  AgentService._();
  static final AgentService instance = AgentService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-north1');

  /// Stable per-session id so the agent can keep short-term memory across
  /// turns. Generated once per chat screen and reused for every send.
  String? _sessionId;
  String get sessionId =>
      _sessionId ??= 'sess-${DateTime.now().millisecondsSinceEpoch}';
  void resetSession() => _sessionId = null;

  Future<AgentTurnResult> send({
    required String text,
    AgentContext? context,
    String language = 'en',
    PendingAction? correctionOf,
    List<Map<String, String>> history = const [],
  }) async {
    final callable = _functions.httpsCallable(
      'agent',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 75)),
    );
    final result = await callable.call<Map<String, dynamic>>({
      'text': text,
      'context': context?.toJson(),
      'language': language,
      'session_id': sessionId,
      if (history.isNotEmpty) 'history': history,
      if (correctionOf != null)
        'correction_of': {
          'pending_id': correctionOf.pendingId,
          'original_preview': correctionOf.preview,
        },
    });
    return AgentTurnResult.fromJson(result.data);
  }

  /// Commit a pending write. Returns the server's human-readable outcome, plus
  /// the follow-up choice when the write happened inside update mode.
  Future<({bool ok, String message, Clarification? clarification})> confirm(
    String pendingId, {
    String language = 'en',
  }) =>
      _confirmOp('confirm', pendingId, language: language);

  /// Discard a pending write.
  Future<({bool ok, String message, Clarification? clarification})> cancel(
          String pendingId) =>
      _confirmOp('cancel', pendingId);

  /// Soft-undo the most recent confirmed write (24h window server-side).
  Future<({bool ok, String message, Clarification? clarification})>
      undoLast() => _confirmOp('undo', null);

  Future<({bool ok, String message, Clarification? clarification})> _confirmOp(
      String op, String? pendingId, {String language = 'en'}) async {
    final callable = _functions.httpsCallable(
      'agentConfirm',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    final result = await callable.call<Map<String, dynamic>>({
      'op': op,
      'language': language,
      if (pendingId != null) 'pending_id': pendingId,
    });
    final clar = result.data['clarification'];
    return (
      ok: (result.data['ok'] as bool?) ?? false,
      message: (result.data['message'] as String?) ?? '',
      // In update mode the server appends [Update another] / [Done] here.
      clarification: clar == null
          ? null
          : Clarification.fromJson(Map<String, dynamic>.from(clar as Map)),
    );
  }

  /// Enter / leave gardener update mode. Server rejects visitors outright, so a
  /// permission-denied here means the account is not garden staff.
  ///
  /// Returns the prompt to show in the thread.
  Future<({bool active, String reply})> setUpdateMode(
    String op, {
    String language = 'en',
  }) async {
    final callable = _functions.httpsCallable(
      'agentUpdateMode',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    final result = await callable.call<Map<String, dynamic>>({
      'op': op,
      'language': language,
    });
    return (
      active: (result.data['active'] as bool?) ?? false,
      reply: (result.data['reply'] as String?) ?? '',
    );
  }
}

/// Caller-supplied location signals — none required. The more we send, the
/// better the resolver can narrow the candidate plant list before the LLM
/// sees anything.
class AgentContext {
  final int? scannedHankintaID;
  final String? indoorCellLabel;
  final String? outdoorSectionCode;
  final ({double lat, double lng})? gps;

  AgentContext({
    this.scannedHankintaID,
    this.indoorCellLabel,
    this.outdoorSectionCode,
    this.gps,
  });

  Map<String, dynamic> toJson() => {
        if (scannedHankintaID != null) 'scanned_hankintaID': scannedHankintaID,
        if (indoorCellLabel != null) 'indoor_cell_label': indoorCellLabel,
        if (outdoorSectionCode != null)
          'outdoor_section_code': outdoorSectionCode,
        if (gps != null) 'gps': {'lat': gps!.lat, 'lng': gps!.lng},
      };
}

/// One turn's worth of agent output.
class AgentTurnResult {
  final String reply;
  final dynamic data;
  final List<PendingAction> pendingActions;
  final Clarification? clarification;
  final List<String> suggestions;

  AgentTurnResult({
    required this.reply,
    this.data,
    this.pendingActions = const [],
    this.clarification,
    this.suggestions = const [],
  });

  factory AgentTurnResult.fromJson(Map<String, dynamic> j) {
    final list = (j['pending_actions'] as List?) ?? const [];
    final clar = j['clarification'];
    return AgentTurnResult(
      reply: (j['reply'] as String?) ?? '',
      data: j['data'],
      pendingActions: list
          .whereType<Map>()
          .map((m) => PendingAction.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      clarification: clar is Map
          ? Clarification.fromJson(Map<String, dynamic>.from(clar))
          : null,
      suggestions: ((j['suggestions'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

/// A "which plant?" or "did you mean?" prompt rendered as tappable buttons.
@immutable
class Clarification {
  final String kind; // "disambiguation" | "did_you_mean"
  final String question;
  final List<ClarOption> options;
  final bool allowFreeText;

  const Clarification({
    required this.kind,
    required this.question,
    required this.options,
    this.allowFreeText = true,
  });

  factory Clarification.fromJson(Map<String, dynamic> j) => Clarification(
        kind: (j['kind'] as String?) ?? 'disambiguation',
        question: (j['question'] as String?) ?? '',
        options: ((j['options'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => ClarOption.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        allowFreeText: (j['allow_free_text'] as bool?) ?? true,
      );
}

@immutable
class ClarOption {
  final String label;
  final String sendText;
  final int? hankintaID;

  const ClarOption({required this.label, required this.sendText, this.hankintaID});

  factory ClarOption.fromJson(Map<String, dynamic> j) => ClarOption(
        label: (j['label'] as String?) ?? '',
        sendText: (j['send_text'] as String?) ?? '',
        hankintaID: (j['hankintaID'] as num?)?.toInt(),
      );
}

/// A single field-level change in a pending write.
@immutable
class PlanChange {
  final String table;
  final String column;
  final String? current; // null = new row (INSERT)
  final String next;
  final String note;

  const PlanChange({
    required this.table,
    required this.column,
    required this.current,
    required this.next,
    required this.note,
  });

  factory PlanChange.fromJson(Map<String, dynamic> j) => PlanChange(
        table: (j['table'] as String?) ?? '',
        column: (j['column'] as String?) ?? '',
        current: j['current'] as String?,
        next: (j['next'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
      );
}

/// A write that has NOT yet committed. The UI shows it as a confirmation
/// card with the exact SQL + a detailed change breakdown. Tapping Save calls
/// `agentConfirm` which actually applies it to the database.
@immutable
class PendingAction {
  final String pendingId;
  final String tool;
  final String preview;
  final String? sqlDisplay;
  final List<PlanChange> changes;

  const PendingAction({
    required this.pendingId,
    required this.tool,
    required this.preview,
    this.sqlDisplay,
    this.changes = const [],
  });

  factory PendingAction.fromJson(Map<String, dynamic> j) => PendingAction(
        pendingId: (j['pending_id'] as String?) ?? '',
        tool: (j['tool'] as String?) ?? '',
        preview: (j['preview'] as String?) ?? '',
        sqlDisplay: j['sql_display'] as String?,
        changes: ((j['changes'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => PlanChange.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}
