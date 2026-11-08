import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_core/focuslearn_core.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

import '../../l10n/generated/app_localizations.dart';
import '../planner/planner_models.dart';
import '../planner/planner_repository.dart';
import 'notes_models.dart';
import 'notes_repository.dart';

/// Note editor with title, body, subject tagging, and delete actions.
class NoteEditScreen extends ConsumerStatefulWidget {
  const NoteEditScreen({super.key, this.note});

  final Note? note;

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    if (n != null) {
      _title.text = n.title;
      _body.text = n.body;
      _selectedSubjectId = n.subjectId;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final note = Note(
      id: widget.note?.id ?? generateUuidV4(Random.secure()),
      title: title,
      body: _body.text,
      subjectId: _selectedSubjectId,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
    );

    await ref.read(notesRepositoryProvider).saveNote(note);
    ref.invalidate(notesProvider);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? <Subject>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note != null ? l10n.notesTitle : l10n.notesNew),
        actions: <Widget>[
          if (widget.note != null)
            IconButton(
              tooltip: l10n.notesDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref.read(notesRepositoryProvider).deleteNote(widget.note!.id);
                ref.invalidate(notesProvider);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
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
                    const DropdownMenuItem<String?>(value: null, child: Text('General')), // l10n-ok
                    ...subjects.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (id) => setState(() => _selectedSubjectId = id),
                ),
                const SizedBox(height: Spacing.md),
                TextField(
                  controller: _body,
                  maxLines: 14,
                  decoration: InputDecoration(
                    labelText: l10n.notesTitle,
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md)),
                  ),
                ),
                const SizedBox(height: Spacing.xl),
                AppButton(
                  label: l10n.plannerSave,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
