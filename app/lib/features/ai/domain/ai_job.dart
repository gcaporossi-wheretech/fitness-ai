/// Represents an async AI job (vision scan or coach generation).
class AIJob {
  const AIJob({
    required this.jobId,
    required this.jobType,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.result,
    this.error,
  });

  final String jobId;
  final String jobType; // vision_scan, coach_generate
  final String status; // pending, processing, completed, failed
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? result;
  final String? error;

  bool get isPending => status == 'pending' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory AIJob.fromJson(Map<String, dynamic> json) {
    return AIJob(
      jobId: json['job_id'] as String,
      jobType: (json['job_type'] ?? 'unknown') as String,
      status: (json['status'] ?? 'pending') as String,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      result: json['result'] as Map<String, dynamic>?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'job_id': jobId,
        'job_type': jobType,
        'status': status,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'result': result,
        'error': error,
      };
}
