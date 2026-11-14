import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/generated/app_localizations.dart';
import 'camera_calc_models.dart';
import 'camera_calc_repository.dart';
import 'scientific_calc_screen.dart';

/// AI Camera Calculator with image scanning, OCR transcription,
/// deterministic math verification, and practice generation.
class CameraCalcScreen extends ConsumerStatefulWidget {
  const CameraCalcScreen({super.key});

  @override
  ConsumerState<CameraCalcScreen> createState() => _CameraCalcScreenState();
}

class _CameraCalcScreenState extends ConsumerState<CameraCalcScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _questionController = TextEditingController();

  XFile? _selectedImage;
  String? _base64Image;
  bool _isLoading = false;
  String? _errorMessage;
  String _language = 'en'; // 'en', 'si', 'ta'
  CameraProblemSolution? _solution;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);

      setState(() {
        _selectedImage = file;
        _base64Image = b64;
        _errorMessage = null;
      });

      // Automatically solve after picking
      _solve(action: 'solve');
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not access image. You can type the question manually.';
      });
    }
  }

  Future<void> _solve({String action = 'solve'}) async {
    final text = _questionController.text.trim();
    if (_base64Image == null && text.isEmpty) {
      setState(() {
        _errorMessage = 'Please take a photo or enter a math/physics question.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(cameraCalcRepositoryProvider);
      final sol = await repo.solveProblem(
        imageBase64: _base64Image,
        problemText: text.isNotEmpty ? text : null,
        language: _language,
        action: action,
      );

      setState(() {
        _solution = sol;
        _isLoading = false;
        if (_questionController.text.isEmpty && sol.problemUnderstood.isNotEmpty) {
          _questionController.text = sol.problemUnderstood;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calcCamera),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Language',
            initialValue: _language,
            onSelected: (val) {
              setState(() => _language = val);
              if (_solution != null) _solve();
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(value: 'en', child: Text('English')),
              PopupMenuItem(value: 'si', child: Text('සිංහල (Sinhala)')),
              PopupMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)')),
            ],
            icon: const Icon(Icons.language_outlined),
          ),
          IconButton(
            tooltip: 'Offline Scientific Calc',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ScientificCalcScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Capture & Input Section
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.md),
                    if (_selectedImage != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.image_outlined, size: 16),
                            const SizedBox(width: Spacing.xs),
                            Expanded(
                              child: Text(
                                'Selected: ${_selectedImage!.name}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() {
                                _selectedImage = null;
                                _base64Image = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                    ],
                    TextField(
                      controller: _questionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Question / Equation (Type or Edit scanned text)',
                        hintText: 'e.g. A ball is dropped from 50m. Calculate time to ground.',
                      ),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _isLoading ? null : () => _solve(action: 'solve'),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Solve Problem'),
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...<Widget>[
                const SizedBox(height: Spacing.md),
                Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.info_outline, color: colors.error),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Solution Section
              if (_solution != null) ...<Widget>[
                const SizedBox(height: Spacing.lg),
                _buildVerificationBadge(_solution!.verification, colors, theme),
                const SizedBox(height: Spacing.md),
                _buildSolutionCard(_solution!, colors, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(
    DeterministicVerification verification,
    AppColors colors,
    ThemeData theme,
  ) {
    final isVerified = verification.status == VerificationStatus.verified;
    final isMismatch = verification.status == VerificationStatus.mismatch;

    final badgeColor = isVerified
        ? Colors.green
        : isMismatch
            ? Colors.orange
            : colors.primary;

    final icon = isVerified
        ? Icons.verified_outlined
        : isMismatch
            ? Icons.warning_amber_rounded
            : Icons.info_outline;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: badgeColor, size: 28),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isVerified
                      ? 'Deterministic Verification Passed'
                      : isMismatch
                          ? 'Verification Discrepancy Alert'
                          : 'Analytical Assessment',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  verification.message,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.text),
                ),
                if (verification.exactValue != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Exact Engine Calculation: ${verification.exactValue}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionCard(
    CameraProblemSolution sol,
    AppColors colors,
    ThemeData theme,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  sol.problemTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
              if (sol.formulaUsed != null && sol.formulaUsed!.isNotEmpty)
                Chip(
                  label: Text(sol.formulaUsed!, style: const TextStyle(fontSize: 12)),
                  backgroundColor: colors.surfaceVariant,
                ),
            ],
          ),
          const Divider(),

          // Final Answer Highlight
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Final Answer:', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  sol.finalAnswer,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Spacing.md),
          Text('Step-by-Step Working:', style: theme.textTheme.titleSmall),
          const SizedBox(height: Spacing.xs),
          for (var i = 0; i < sol.steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: colors.surfaceVariant,
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(sol.steps[i], style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),

          if (sol.explanation != null && sol.explanation!.isNotEmpty) ...<Widget>[
            const Divider(),
            Text('Concept & Method:', style: theme.textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
            Text(sol.explanation!, style: theme.textTheme.bodySmall),
          ],

          const SizedBox(height: Spacing.lg),
          // Follow-up Actions
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _solve(action: 'explain_differently'),
                icon: const Icon(Icons.lightbulb_outlined, size: 18),
                label: const Text('Explain Differently'),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _solve(action: 'practice_question'),
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('Similar Practice Question'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
