import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'event_providers.dart';
import 'models/event.dart';
import 'models/world.dart';
import 'world_date_picker.dart';

/// Single screen used for both event creation and editing. Pass [existing]
/// to enter edit mode.
class EventEditScreen extends ConsumerStatefulWidget {
  const EventEditScreen({
    super.key,
    required this.worldId,
    required this.calendar,
    this.existing,
  });

  final String worldId;
  final CalendarConfigData calendar;
  final Event? existing;

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _capacityCtl = TextEditingController();
  late WorldDateData _startDate;
  WorldDateData? _endDate;
  WorldDateData? _deadline;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtl.text = e.title;
      _descCtl.text = e.description;
      _capacityCtl.text = e.capacity?.toString() ?? '';
      _startDate = e.startDate;
      _endDate = e.endDate == e.startDate ? null : e.endDate;
      _deadline = e.registrationDeadline == e.startDate ? null : e.registrationDeadline;
    } else {
      _startDate = widget.calendar.currentDate;
      _endDate = null;
      _deadline = null;
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _capacityCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    final user = ref.read(authStateChangesProvider).valueOrNull;
    if (user == null) {
      setState(() => _error = 'Not signed in');
      return;
    }
    final capacity = _capacityCtl.text.trim().isEmpty
        ? null
        : int.tryParse(_capacityCtl.text.trim());
    if (_capacityCtl.text.trim().isNotEmpty && (capacity == null || capacity < 1)) {
      setState(() => _error = 'Capacity must be a positive number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(eventRepositoryProvider);
      final event = (widget.existing ??
              Event(
                id: '',
                worldId: widget.worldId,
                title: title,
                startDate: _startDate,
                registrationDeadline: _deadline ?? _startDate,
                createdByUid: user.uid,
              ))
          .copyWith(
        title: title,
        description: _descCtl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        registrationDeadline: _deadline ?? _startDate,
        capacity: capacity,
      );
      if (_isEdit) {
        await repo.updateEvent(event);
      } else {
        await repo.createEvent(event);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit event' : 'New event'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          TextField(
            controller: _titleCtl,
            decoration: const InputDecoration(labelText: 'Title'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtl,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Plain text only — no markdown for MVP',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          WorldDatePicker(
            label: 'Start date',
            calendar: widget.calendar,
            initial: _startDate,
            onChanged: (d) => setState(() => _startDate = d),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Multi-day event'),
            value: _endDate != null,
            onChanged: (v) => setState(() {
              _endDate = v ? _startDate : null;
            }),
          ),
          if (_endDate != null) ...[
            WorldDatePicker(
              label: 'End date',
              calendar: widget.calendar,
              initial: _endDate ?? _startDate,
              onChanged: (d) => setState(() => _endDate = d),
            ),
            const SizedBox(height: 16),
          ],
          WorldDatePicker(
            label: 'Registration deadline (default = start date)',
            calendar: widget.calendar,
            initial: _deadline ?? _startDate,
            onChanged: (d) => setState(() => _deadline = d),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _capacityCtl,
            decoration: const InputDecoration(
              labelText: 'Capacity',
              hintText: 'Leave blank for unlimited',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
    );
  }
}
