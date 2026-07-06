/// AI 피팅 결과. models.py TryOnResult 와 일치.
class TryOnResult {
  final String imageUrl;
  final int fitScore;
  final String recommendedSize;
  final String analysis;

  const TryOnResult({
    required this.imageUrl,
    required this.fitScore,
    required this.recommendedSize,
    required this.analysis,
  });

  factory TryOnResult.fromJson(Map<String, dynamic> j) => TryOnResult(
        imageUrl: j['image_url'] as String? ?? '',
        fitScore: (j['fit_score'] as num?)?.toInt() ?? 0,
        recommendedSize: j['recommended_size'] as String? ?? 'M',
        analysis: j['analysis'] as String? ?? '',
      );
}

/// 비동기 피팅 잡. status: queued|processing|done|failed. 폴링으로 done/failed 까지.
class TryOnJob {
  final String id;
  final String status;
  final TryOnResult? result;
  final String? error;

  const TryOnJob({
    required this.id,
    required this.status,
    this.result,
    this.error,
  });

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isFinished => isDone || isFailed;

  factory TryOnJob.fromJson(Map<String, dynamic> j) => TryOnJob(
        id: j['id'] as String,
        status: j['status'] as String? ?? 'queued',
        result: j['result'] == null
            ? null
            : TryOnResult.fromJson(j['result'] as Map<String, dynamic>),
        error: j['error'] as String?,
      );
}
