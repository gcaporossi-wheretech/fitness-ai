import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/ai/data/ai_repository.dart';
import 'package:fitness_ai/features/ai/domain/vision_result.dart';
import 'package:fitness_ai/features/auth/domain/auth_state.dart';
import 'package:fitness_ai/features/auth/presentation/auth_notifier.dart';

/// AI Vision scan screen.
/// Captures a photo of gym equipment, sends to API, shows recognized
/// equipment and suggested exercises.
class VisionScanScreen extends ConsumerStatefulWidget {
  const VisionScanScreen({super.key});

  @override
  ConsumerState<VisionScanScreen> createState() => _VisionScanScreenState();
}

class _VisionScanScreenState extends ConsumerState<VisionScanScreen> {
  final _picker = ImagePicker();
  Uint8List? _capturedImage;
  bool _isScanning = false;
  String _statusMessage = '';
  VisionResult? _result;
  String? _error;

  Future<void> _capturePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _capturedImage = bytes;
      _result = null;
      _error = null;
    });
    _scanImage(bytes, picked.name);
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _capturedImage = bytes;
      _result = null;
      _error = null;
    });
    _scanImage(bytes, picked.name);
  }

  Future<void> _scanImage(Uint8List bytes, String filename) async {
    // Check credits
    final authState = ref.read(authNotifierProvider);
    if (authState is AuthAuthenticated && authState.user.aiCredits <= 0) {
      setState(() => _error = 'Crediti AI insufficienti');
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Invio immagine...';
      _error = null;
    });

    try {
      setState(() => _statusMessage = 'Analisi in corso...');
      final aiRepo = ref.read(aiRepositoryProvider);
      final result = await aiRepo.scanEquipment(
        imageBytes: bytes,
        filename: filename,
      );
      setState(() {
        _result = result;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Vision Scan')),
      body: SafeArea(
        child: Column(
          children: [
            // Image preview or capture prompt
            Expanded(
              flex: 2,
              child: _capturedImage != null
                  ? _ImagePreview(imageBytes: _capturedImage!)
                  : _CapturePrompt(
                      onCamera: _capturePhoto,
                      onGallery: _pickFromGallery,
                    ),
            ),
            // Status / results area
            Expanded(
              flex: 3,
              child: _isScanning
                  ? _ScanningIndicator(message: _statusMessage)
                  : _error != null
                      ? _ErrorView(
                          error: _error!,
                          onRetry: _capturePhoto,
                        )
                      : _result != null
                          ? _ResultView(result: _result!)
                          : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      // Retake button when result is shown
      floatingActionButton: _result != null
          ? FloatingActionButton.extended(
              onPressed: _capturePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Nuova scansione'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }
}

class _CapturePrompt extends StatelessWidget {
  const _CapturePrompt({required this.onCamera, required this.onGallery});
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt,
              size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Inquadra un macchinario',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'L\'AI riconoscera l\'attrezzo\ne ti suggerira gli esercizi',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlowButton(
                label: 'Scatta',
                onPressed: onCamera,
                icon: Icons.camera_alt,
                width: 140,
                height: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              GlowButton(
                label: 'Galleria',
                onPressed: onGallery,
                icon: Icons.photo_library,
                width: 140,
                height: 48,
                color: AppColors.bgElevated,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.imageBytes});
  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }
}

class _ScanningIndicator extends StatelessWidget {
  const _ScanningIndicator({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            GlowButton(
              label: 'Riprova',
              onPressed: onRetry,
              icon: Icons.refresh,
              height: 48,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final VisionResult result;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Equipment info
          GlassmorphismCard(
            borderColor: AppColors.success.withValues(alpha: 0.3),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.equipmentName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (result.brand != null)
                        Text(
                          result.brand!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
                NeonText(
                  result.confidencePercent,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                  color: result.confidence > 0.8
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Esercizi suggeriti',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Exercise list
          ...result.exercises.asMap().entries.map((entry) {
            final ex = entry.value;
            return StaggeredListItem(
              index: entry.key,
              child: GlassmorphismCard(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${ex.name} aggiunto al workout'),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.name,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (ex.muscleGroup != null)
                            Text(
                              ex.muscleGroup!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${ex.sets}x${ex.reps}',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.add_circle_outline,
                        color: AppColors.primary, size: 24),
                  ],
                ),
              ),
            );
          }),
          if (result.cached)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Risultato dalla cache',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textDisabled),
              ),
            ),
        ],
      ),
    );
  }
}
