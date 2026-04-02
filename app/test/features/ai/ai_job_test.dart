import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/ai/domain/ai_job.dart';

void main() {
  group('AIJob', () {
    test('isPending returns true for pending status', () {
      const job = AIJob(jobId: 'j1', jobType: 'vision_scan', status: 'pending');
      expect(job.isPending, true);
      expect(job.isCompleted, false);
      expect(job.isFailed, false);
    });

    test('isPending returns true for processing status', () {
      const job = AIJob(jobId: 'j1', jobType: 'coach_generate', status: 'processing');
      expect(job.isPending, true);
    });

    test('isCompleted returns true for completed status', () {
      const job = AIJob(
        jobId: 'j1',
        jobType: 'vision_scan',
        status: 'completed',
        result: {'equipment_name': 'Leg Press'},
      );
      expect(job.isCompleted, true);
      expect(job.isPending, false);
    });

    test('isFailed returns true for failed status', () {
      const job = AIJob(
        jobId: 'j1',
        jobType: 'coach_generate',
        status: 'failed',
        error: 'Insufficient credits',
      );
      expect(job.isFailed, true);
      expect(job.error, 'Insufficient credits');
    });

    test('fromJson creates correct job', () {
      final json = {
        'job_id': 'abc-123',
        'job_type': 'vision_scan',
        'status': 'completed',
        'created_at': '2026-04-02T10:00:00Z',
        'result': {'equipment_name': 'Cable Machine'},
      };
      final job = AIJob.fromJson(json);
      expect(job.jobId, 'abc-123');
      expect(job.jobType, 'vision_scan');
      expect(job.isCompleted, true);
      expect(job.result?['equipment_name'], 'Cable Machine');
    });

    test('toJson roundtrip preserves data', () {
      const job = AIJob(
        jobId: 'j1',
        jobType: 'coach_generate',
        status: 'pending',
      );
      final json = job.toJson();
      final restored = AIJob.fromJson(json);
      expect(restored.jobId, job.jobId);
      expect(restored.jobType, job.jobType);
      expect(restored.status, job.status);
    });
  });
}
