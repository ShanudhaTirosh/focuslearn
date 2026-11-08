import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';
import 'planner_models.dart';
import 'planner_repository.dart';

enum _RecurrenceChoice { none, daily, weekly, monthly }

/// Editor for timetable events with recurrence rule synthesis and meeting link preview.
class EventEditScreen extends ConsumerStatefulWidget {
  const EventEditScreen({
    super.key,
    this.event,
    required this.initialDate,
  });

  final TimetableEvent? event;
  final DateTime initialDate;

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _meetingUrl = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  String? _selectedSubjectId;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late DateTime _eventDate;
  _RecurrenceChoice _recurrence = _RecurrenceChoice.none;
  final Set<String> _weeklyDays = <String>{};

  @override
  void initState() {
    super.initState();
    final ev = widget.event;
    if (ev != null) {
      _title.text = ev.title;
      _location.text = ev.location ?? '';
      _meetingUrl.text = ev.meetingUrl ?? '';
      _notes.text = ev.notes ?? '';
      _selectedSubjectId = ev.subjectId;
      _eventDate = ev.startUtc.toLocal();
      _startTime = TimeOfDay.fromDateTime(ev.startUtc.toLocal());
      _endTime = TimeOfDay.fromDateTime(ev.endUtc.toLocal());

      if (ev.rrule != null && ev.rrule!.isNotEmpty) {
        if (ev.rrule!.contains('FREQ=DAILY')) {
          _recurrence = _RecurrenceChoice.daily;
        } else if (ev.rrule!.contains('FREQ=WEEKLY')) {
          _recurrence = _RecurrenceChoice.weekly;
        } else if (ev.rrule!.contains('FREQ=MONTHLY')) {
          _recurrence = _RecurrenceChoice.monthly;
        }
      }
    } else {
      _eventDate = widget.initialDate;
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 30);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _meetingUrl.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
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

  String? _buildRrule() {
    switch (_recurrence) {
      case _RecurrenceChoice.none:
        return null;
      case _RecurrenceChoice.daily:
        return 'FREQ=DAILY';
      case _RecurrenceChoice.weekly:
        if (_weeklyDays.isEmpty) {
          const names = <String>['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
          final weekdayName = names[_eventDate.weekday - 1];
          return 'FREQ=WEEKLY;BYDAY=$weekdayName';
        }
        final sorted = _weeklyDays.toList()..sort();
        return 'FREQ=WEEKLY;BYDAY=${sorted.join(',')}';
      case _RecurrenceChoice.monthly:
        return 'FREQ=MONTHLY';
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      return;
    }

    final startUtc = DateTime.utc(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endUtc = DateTime.utc(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final event = TimetableEvent(
      id: widget.event?.id ?? generateUuidV4(Random.secure()),
      title: title,
      startUtc: startUtc,
      endUtc: endUtc,
      subjectId: _selectedSubjectId,
      location: _location.text.trim().isNotEmpty ? _location.text.trim() : null,
      meetingUrl: _meetingUrl.text.trim().isNotEmpty ? _meetingUrl.text.trim() : null,
      notes: _notes.text.trim().isNotEmpty ? _notes.text.trim() : null,
      rrule: _buildRrule(),
    );

    await ref.read(plannerRepositoryProvider).saveEvent(event);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? <Subject>[];

    final meetingClassification = _meetingUrl.text.isNotEmpty ? validateMeetingUrl(_meetingUrl.text) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event != null ? l10n.plannerEditEvent : l10n.plannerAddEvent),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppTextField(
                  controller: _title,
                  label: l10n.displayNameLabel,
                ),
                const SizedBox(height: Spacing.md),
                DropdownButtonFormField<String?>(
                  value: _selectedSubjectId,
                  decoration: InputDecoration(labelText: l10n.plannerSubjects),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('No Subject')), // l10n-ok
                    ...subjects.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (id) => setState(() => _selectedSubjectId = id),
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(true),
                        child: Text(_startTime.format(context)),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    const Text('-'), // l10n-ok
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(false),
                        child: Text(_endTime.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                AppTextField(
                  controller: _location,
                  label: 'Classroom / Location', // l10n-ok
                ),
                const SizedBox(height: Spacing.md),
                AppTextField(
                  controller: _meetingUrl,
                  label: 'Online Class Link (Zoom / Meet / Teams)', // l10n-ok
                  onChanged: (_) => setState(() {}),
                ),
                if (meetingClassification != null) ...<Widget>[
                  const SizedBox(height: Spacing.xs),
                  Row(
                    children: <Widget>[
                      Icon(
                        meetingClassification.code == 'ok' ? Icons.check_circle_outline : Icons.error_outline,
                        size: 16,
                        color: meetingClassification.code == 'ok' ? colors.success : colors.error,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        (meetingClassification.provider != null && meetingClassification.provider != 'other') ? 'Known Service (${meetingClassification.provider})' : 'External Host', // l10n-ok
                        style: TextStyle(
                          fontSize: 12,
                          color: meetingClassification.code == 'ok' ? colors.textMuted : colors.error,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: Spacing.lg),
                Text(l10n.plannerRepeat, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: Spacing.xs),
                SegmentedButton<_RecurrenceChoice>(
                  segments: <ButtonSegment<_RecurrenceChoice>>[
                    ButtonSegment<_RecurrenceChoice>(value: _RecurrenceChoice.none, label: Text(l10n.plannerRepeatNone)),
                    ButtonSegment<_RecurrenceChoice>(value: _RecurrenceChoice.daily, label: Text(l10n.plannerRepeatDaily)),
                    ButtonSegment<_RecurrenceChoice>(value: _RecurrenceChoice.weekly, label: Text(l10n.plannerRepeatWeekly)),
                    ButtonSegment<_RecurrenceChoice>(value: _RecurrenceChoice.monthly, label: Text(l10n.plannerRepeatMonthly)),
                  ],
                  selected: <_RecurrenceChoice>{_recurrence},
                  onSelectionChanged: (set) => setState(() => _recurrence = set.first),
                ),
                const SizedBox(height: Spacing.xl),
                AppButton(
                  label: l10n.plannerSave,
                  onPressed: _save,
                ),
                if (widget.event != null) ...<Widget>[
                  const SizedBox(height: Spacing.sm),
                  AppButton(
                    label: l10n.plannerDelete,
                    kind: AppButtonKind.secondary,
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      await ref.read(plannerRepositoryProvider).deleteEvent(widget.event!.id);
                      if (mounted) nav.pop();
                    },
                  ),
                ],
                const SizedBox(height: Spacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
