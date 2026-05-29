import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/event_service.dart';
import '../services/language_service.dart';
import '../services/user_state.dart';

class EventRequestScreen extends StatefulWidget {
  const EventRequestScreen({super.key});

  @override
  State<EventRequestScreen> createState() => _EventRequestScreenState();
}

class _EventRequestScreenState extends State<EventRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _attendees = TextEditingController();
  final _space = TextEditingController();
  DateTime? _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _attendees.dispose();
    _space.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF66BB6A),
            surface: Color(0xFF111F16),
            onSurface: Color(0xFFE8F5E9),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? const TimeOfDay(hour: 14, minute: 0)
          : const TimeOfDay(hour: 16, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF66BB6A),
            surface: Color(0xFF111F16),
            onSurface: Color(0xFFE8F5E9),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _startTime == null || _endTime == null) return;
    final user = context.read<UserState>().user;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await EventService.instance.submit(
        userId: user.id,
        userName: user.displayName,
        userEmail: user.email,
        name: _name.text.trim(),
        description: _description.text.trim(),
        attendees: int.tryParse(_attendees.text.trim()) ?? 0,
        date: _date!,
        startTime: _startTime!.format(context),
        endTime: _endTime!.format(context),
        spaceRequirements: _space.text.trim(),
      );
      if (mounted) {
        final s = context.read<LanguageService>().strings;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text(s.eventSubmitted),
        ));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        title: Text(s.eventPlanner),
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.eventPlannerSubtitle,
                    style:
                        const TextStyle(color: Color(0xFF81C784), fontSize: 13)),
                const SizedBox(height: 20),
                _field(s.eventName, _name),
                const SizedBox(height: 12),
                _field(s.eventDescription, _description, maxLines: 4),
                const SizedBox(height: 12),
                _field(s.eventAttendees, _attendees, keyboard: TextInputType.number),
                const SizedBox(height: 12),
                _pickerTile(
                  icon: Icons.calendar_today_rounded,
                  label: s.eventDate,
                  value: _date == null
                      ? '—'
                      : DateFormat('EEE, MMM d, yyyy').format(_date!),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _pickerTile(
                        icon: Icons.play_circle_outline_rounded,
                        label: s.eventStartTime,
                        value: _startTime == null
                            ? '—'
                            : _startTime!.format(context),
                        onTap: () => _pickTime(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _pickerTile(
                        icon: Icons.stop_circle_outlined,
                        label: s.eventEndTime,
                        value: _endTime == null
                            ? '—'
                            : _endTime!.format(context),
                        onTap: () => _pickTime(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(s.eventSpace, _space, maxLines: 3),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _busy ||
                          _date == null ||
                          _startTime == null ||
                          _endTime == null
                      ? null
                      : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(s.submitForApproval,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {int maxLines = 1, TextInputType? keyboard}) {
    final s = context.read<LanguageService>().strings;
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: const TextStyle(color: Color(0xFFE8F5E9)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF81C784)),
        filled: true,
        fillColor: const Color(0xFF111F16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A4A2F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A4A2F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
        ),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? s.required : null,
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111F16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A4A2F)),
          ),
          child: Row(children: [
            Icon(icon, color: const Color(0xFF66BB6A), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF81C784), fontSize: 12)),
                  Text(value,
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF4A7A50), size: 14),
          ]),
        ),
      ),
    );
  }
}
