import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/ai/data/ai_repository.dart';
import 'package:fitness_ai/features/ai/presentation/coach_result_screen.dart';
import 'package:fitness_ai/features/workout/data/workout_repository.dart';
import 'package:fitness_ai/features/auth/presentation/auth_notifier.dart';
import 'package:fitness_ai/features/auth/domain/auth_state.dart';

/// Multi-step AI Coach onboarding flow.
/// Step 1: Body photos (front, back, side) with visual guide
/// Step 2: Personal data (age, goals, frequency, limitations)
/// Step 3: Generation with loading animation
/// Step 4: Display generated plan
class CoachOnboardingScreen extends ConsumerStatefulWidget {
  const CoachOnboardingScreen({super.key});

  @override
  ConsumerState<CoachOnboardingScreen> createState() =>
      _CoachOnboardingScreenState();
}

class _CoachOnboardingScreenState
    extends ConsumerState<CoachOnboardingScreen> {
  int _currentStep = 0;
  final _picker = ImagePicker();

  // Step 1: Photos
  Uint8List? _frontPhoto;
  Uint8List? _backPhoto;
  Uint8List? _sidePhoto;

  // Step 2: Personal data
  final _ageController = TextEditingController();
  String _goal = 'build_muscle';
  int _frequency = 4;
  final _limitationsController = TextEditingController();

  // Step 3: Generation state
  bool _isGenerating = false;
  String _generationStatus = '';

  @override
  void dispose() {
    _ageController.dispose();
    _limitationsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(String position) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      switch (position) {
        case 'front':
          _frontPhoto = bytes;
          break;
        case 'back':
          _backPhoto = bytes;
          break;
        case 'side':
          _sidePhoto = bytes;
          break;
      }
    });
  }

  Future<void> _pickFromGallery(String position) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      switch (position) {
        case 'front':
          _frontPhoto = bytes;
          break;
        case 'back':
          _backPhoto = bytes;
          break;
        case 'side':
          _sidePhoto = bytes;
          break;
      }
    });
  }

  bool get _canProceedStep1 =>
      _frontPhoto != null || _backPhoto != null || _sidePhoto != null;

  bool get _canProceedStep2 => _ageController.text.isNotEmpty;

  Future<void> _startGeneration() async {
    // Check credits
    final authState = ref.read(authNotifierProvider);
    if (authState is AuthAuthenticated && authState.user.aiCredits <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Crediti AI insufficienti'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isGenerating = true;
      _currentStep = 2;
      _generationStatus = 'Invio dati al Coach AI...';
    });

    try {
      setState(() => _generationStatus = 'Generazione scheda personalizzata...');

      final photos = <({Uint8List bytes, String filename})>[];
      if (_frontPhoto != null) {
        photos.add((bytes: _frontPhoto!, filename: 'front.jpg'));
      }
      if (_backPhoto != null) {
        photos.add((bytes: _backPhoto!, filename: 'back.jpg'));
      }
      if (_sidePhoto != null) {
        photos.add((bytes: _sidePhoto!, filename: 'side.jpg'));
      }

      final known = ref.read(knownExerciseNamesProvider);
      final userData = <String, dynamic>{
        if (int.tryParse(_ageController.text) != null)
          'age': int.parse(_ageController.text),
        'goals': _goal,
        'available_days': _frequency,
        if (_limitationsController.text.trim().isNotEmpty)
          'limitations': _limitationsController.text.trim(),
        if (known.isNotEmpty) 'known_exercises': known.take(150).toList(),
      };

      final aiRepo = ref.read(aiRepositoryProvider);
      final result = await aiRepo.generateCoachPlan(
        photos: photos,
        userData: userData,
      );

      setState(() => _isGenerating = false);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CoachResultScreen(result: result),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _generationStatus = 'Errore: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach AI'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            _StepIndicator(currentStep: _currentStep),
            const SizedBox(height: AppSpacing.md),
            // Step content
            Expanded(
              child: switch (_currentStep) {
                0 => _buildPhotosStep(),
                1 => _buildPersonalDataStep(),
                2 => _buildGenerationStep(),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GradientText(
            'Foto del corpo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Scatta 3 foto per una scheda personalizzata.\nAlmeno una foto e richiesta.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _PhotoCard(
                  label: 'Fronte',
                  icon: Icons.person,
                  photo: _frontPhoto,
                  onTapCamera: () => _pickPhoto('front'),
                  onTapGallery: () => _pickFromGallery('front'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PhotoCard(
                  label: 'Retro',
                  icon: Icons.person_outline,
                  photo: _backPhoto,
                  onTapCamera: () => _pickPhoto('back'),
                  onTapGallery: () => _pickFromGallery('back'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PhotoCard(
                  label: 'Lato',
                  icon: Icons.accessibility_new,
                  photo: _sidePhoto,
                  onTapCamera: () => _pickPhoto('side'),
                  onTapGallery: () => _pickFromGallery('side'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GlowButton(
            label: 'Avanti',
            onPressed: () => setState(() => _currentStep = 1),
            enabled: _canProceedStep1,
            icon: Icons.arrow_forward,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text(
                'Salta le foto',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDataStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GradientText(
            'I tuoi dati',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Questi dati aiutano il Coach AI a personalizzare la scheda.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Age
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Eta',
              prefixIcon: Icon(Icons.cake_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Goal
          Text('Obiettivo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              _GoalChip(
                label: 'Massa muscolare',
                value: 'build_muscle',
                selected: _goal == 'build_muscle',
                onSelected: () => setState(() => _goal = 'build_muscle'),
              ),
              _GoalChip(
                label: 'Forza',
                value: 'strength',
                selected: _goal == 'strength',
                onSelected: () => setState(() => _goal = 'strength'),
              ),
              _GoalChip(
                label: 'Dimagrimento',
                value: 'lose_weight',
                selected: _goal == 'lose_weight',
                onSelected: () => setState(() => _goal = 'lose_weight'),
              ),
              _GoalChip(
                label: 'Tonificazione',
                value: 'tone',
                selected: _goal == 'tone',
                onSelected: () => setState(() => _goal = 'tone'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Frequency
          Text(
            'Frequenza settimanale: $_frequency giorni',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _frequency.toDouble(),
            min: 2,
            max: 6,
            divisions: 4,
            activeColor: AppColors.primary,
            label: '$_frequency',
            onChanged: (v) => setState(() => _frequency = v.round()),
          ),
          const SizedBox(height: AppSpacing.md),
          // Limitations
          TextFormField(
            controller: _limitationsController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Limitazioni o infortuni (opzionale)',
              prefixIcon: Icon(Icons.medical_services_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlowButton(
            label: 'Genera Scheda',
            onPressed: _startGeneration,
            enabled: _canProceedStep2,
            icon: Icons.auto_awesome,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text(
                'Torna alle foto',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isGenerating) ...[
              const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const NeonText(
                'Coach AI',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _generationStatus,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(Icons.error_outline,
                  size: 64, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                _generationStatus,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              GlowButton(
                label: 'Riprova',
                onPressed: _startGeneration,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Step progress indicator at the top.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _StepDot(label: 'Foto', isActive: currentStep >= 0, isDone: currentStep > 0),
          Expanded(child: _StepLine(isActive: currentStep > 0)),
          _StepDot(label: 'Dati', isActive: currentStep >= 1, isDone: currentStep > 1),
          Expanded(child: _StepLine(isActive: currentStep > 1)),
          _StepDot(label: 'Genera', isActive: currentStep >= 2, isDone: false),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.isActive, required this.isDone});
  final String label;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.success
                : isActive
                    ? AppColors.primary
                    : AppColors.bgElevated,
          ),
          child: Icon(
            isDone ? Icons.check : Icons.circle,
            size: isDone ? 18 : 10,
            color: isActive ? Colors.white : AppColors.textDisabled,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppColors.textPrimary : AppColors.textDisabled,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: isActive ? AppColors.primary : AppColors.bgElevated,
    );
  }
}

/// Photo capture card with camera and gallery options.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.label,
    required this.icon,
    required this.onTapCamera,
    required this.onTapGallery,
    this.photo,
  });

  final String label;
  final IconData icon;
  final Uint8List? photo;
  final VoidCallback onTapCamera;
  final VoidCallback onTapGallery;

  @override
  Widget build(BuildContext context) {
    return GlassmorphismCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderColor: photo != null
          ? AppColors.success.withValues(alpha: 0.3)
          : AppColors.primary.withValues(alpha: 0.1),
      child: Column(
        children: [
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Image.memory(
                photo!,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Center(
                child: Icon(icon, size: 40, color: AppColors.textDisabled),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onTapCamera,
                child: const Icon(Icons.camera_alt, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: onTapGallery,
                child: const Icon(Icons.photo_library, size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Selectable goal chip.
class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.bgElevated,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
