import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/holiday_hours_service.dart';
import '../services/language_service.dart';
import '../theme/tokens.dart';

class EditHolidaysScreen extends StatefulWidget {
  const EditHolidaysScreen({super.key});

  @override
  State<EditHolidaysScreen> createState() => _EditHolidaysScreenState();
}

class _EditHolidaysScreenState extends State<EditHolidaysScreen> {
  final List<({TextEditingController label, TextEditingController hours})>
      _rows = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.label.dispose();
      r.hours.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final doc = await HolidayHoursService.instance.get();
    if (!mounted) return;
    if (doc != null && doc.entries.isNotEmpty) {
      for (final e in doc.entries) {
        _rows.add((
          label: TextEditingController(text: e.label),
          hours: TextEditingController(text: e.hours),
        ));
      }
    } else {
      _addEmptyRow();
    }
    setState(() => _loading = false);
  }

  void _addEmptyRow() {
    _rows.add((
      label: TextEditingController(),
      hours: TextEditingController(),
    ));
  }

  void _removeRow(int i) {
    _rows[i].label.dispose();
    _rows[i].hours.dispose();
    _rows.removeAt(i);
    setState(() {});
  }

  Future<void> _pasteFromWebsite(dynamic s) async {
    final pasteCtrl = TextEditingController();
    final parsed = await showDialog<List<HolidayEntry>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: Text(s.pasteFromWebsite,
            style: const TextStyle(color: C.textHi)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.pasteHolidayInstructions,
                  style: const TextStyle(
                      color: C.accent, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: pasteCtrl,
                maxLines: 10,
                minLines: 6,
                autofocus: true,
                style: const TextStyle(
                    color: C.textHi, fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  hintText:
                      'Good Friday 3rd April closed\nSat 4th April 10 -16\n...',
                  hintStyle: TextStyle(color: C.textFaint, fontSize: 11),
                  filled: true,
                  fillColor: C.bg,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () {
              final parsed = HolidayHoursService.parse(pasteCtrl.text);
              Navigator.pop(ctx, parsed);
            },
            child: Text(s.parse,
                style: const TextStyle(color: C.accent)),
          ),
        ],
      ),
    );
    if (parsed == null || parsed.isEmpty) return;

    // Replace existing rows with parsed ones
    for (final r in _rows) {
      r.label.dispose();
      r.hours.dispose();
    }
    _rows.clear();
    for (final e in parsed) {
      _rows.add((
        label: TextEditingController(text: e.label),
        hours: TextEditingController(text: e.hours),
      ));
    }
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: C.accentDim,
        content: Text(s.parsedCount(parsed.length)),
      ));
    }
  }

  Future<void> _save(dynamic s) async {
    setState(() => _saving = true);
    final entries = _rows
        .where((r) =>
            r.label.text.trim().isNotEmpty || r.hours.text.trim().isNotEmpty)
        .map((r) =>
            HolidayEntry(label: r.label.text.trim(), hours: r.hours.text.trim()))
        .toList();
    await HolidayHoursService.instance.save(entries);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: C.accentDim,
      content: Text(s.holidaysSaved),
    ));
    setState(() => _saving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text(s.editHolidays),
        backgroundColor: C.bg,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: s.pasteFromWebsite,
            icon: const Icon(Icons.content_paste_rounded,
                color: C.accent),
            onPressed: _loading ? null : () => _pasteFromWebsite(s),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: C.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var i = 0; i < _rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Row(
                      labelCtrl: _rows[i].label,
                      hoursCtrl: _rows[i].hours,
                      labelHint: s.dateLabel,
                      hoursHint: s.hours,
                      onDelete: () => _removeRow(i),
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => setState(_addEmptyRow),
                  icon: const Icon(Icons.add_rounded,
                      color: C.accent),
                  label: Text(s.addRow,
                      style: const TextStyle(color: C.accent)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(s),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.accentDim,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(s.save,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  final TextEditingController labelCtrl;
  final TextEditingController hoursCtrl;
  final String labelHint;
  final String hoursHint;
  final VoidCallback onDelete;
  const _Row({
    required this.labelCtrl,
    required this.hoursCtrl,
    required this.labelHint,
    required this.hoursHint,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: labelCtrl,
              style: const TextStyle(color: C.textHi, fontSize: 13),
              decoration: InputDecoration(
                hintText: labelHint,
                hintStyle:
                    const TextStyle(color: C.textFaint, fontSize: 12),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: hoursCtrl,
              style: const TextStyle(color: C.accent, fontSize: 13),
              decoration: InputDecoration(
                hintText: hoursHint,
                hintStyle:
                    const TextStyle(color: C.textFaint, fontSize: 12),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: C.danger, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
