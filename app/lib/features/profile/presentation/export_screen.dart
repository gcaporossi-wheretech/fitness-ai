import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:fitness_ai/core/network/api_client.dart';
import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/profile/data/export_service.dart';

/// Screen for exporting user data in JSON or CSV format.
/// Uses the native share sheet for file sharing.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _exporting = false;
  String? _statusMessage;
  bool _isError = false;

  Future<void> _exportData(String format) async {
    setState(() {
      _exporting = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      final api = ref.read(apiClientProvider);
      final service = ExportService(api);

      String content;
      String filename;
      String mimeType;

      if (format == 'json') {
        content = await service.exportAsJson();
        filename = 'fitnessai_export_${_dateStamp()}.json';
        mimeType = 'application/json';
      } else {
        content = await service.exportSessionsCsv();
        filename = 'fitnessai_sessions_${_dateStamp()}.csv';
        mimeType = 'text/csv';
      }

      // Write to temporary file for sharing
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content);

      // Share via native share sheet
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        subject: 'FitnessAI - Export dati',
      );

      if (mounted) {
        setState(() {
          _statusMessage = 'Export completato: $filename';
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Errore durante l\'export: $e';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Dati'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GlassmorphismCard(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Esporta i tuoi dati',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Scarica una copia di tutti i tuoi allenamenti, '
                      'schede e statistiche.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // JSON export
            _ExportOption(
              icon: Icons.code,
              title: 'JSON completo',
              description:
                  'Profilo, schede, sessioni. Compatibile con reimportazione.',
              onTap: _exporting ? null : () => _exportData('json'),
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),

            // CSV export
            _ExportOption(
              icon: Icons.table_chart,
              title: 'CSV sessioni',
              description:
                  'Sessioni in formato tabellare. Apribile con Excel/Sheets.',
              onTap: _exporting ? null : () => _exportData('csv'),
              color: AppColors.success,
            ),

            const SizedBox(height: AppSpacing.xl),

            if (_exporting)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),

            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: _isError
                      ? AppColors.error.withAlpha(25)
                      : AppColors.success.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _isError ? AppColors.error : AppColors.success,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final Color color;

  const _ExportOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphismCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.share, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
