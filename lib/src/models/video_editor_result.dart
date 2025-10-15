/// Result returned after video editing is complete
class VideoEditorResult {
  /// Path to the edited/generated video file
  final String videoPath;

  /// Whether the video was successfully edited
  final bool success;

  /// Optional error message if editing failed
  final String? errorMessage;

  /// Duration of the edited video in milliseconds
  final int? durationMs;

  /// Resolution of the edited video
  final VideoResolution? resolution;

  const VideoEditorResult({
    required this.videoPath,
    required this.success,
    this.errorMessage,
    this.durationMs,
    this.resolution,
  });

  /// Create a successful result
  factory VideoEditorResult.success({
    required String videoPath,
    int? durationMs,
    VideoResolution? resolution,
  }) {
    return VideoEditorResult(
      videoPath: videoPath,
      success: true,
      durationMs: durationMs,
      resolution: resolution,
    );
  }

  /// Create a failed result
  factory VideoEditorResult.failure({required String errorMessage}) {
    return VideoEditorResult(
      videoPath: '',
      success: false,
      errorMessage: errorMessage,
    );
  }

  /// Create a cancelled result
  factory VideoEditorResult.cancelled() {
    return const VideoEditorResult(
      videoPath: '',
      success: false,
      errorMessage: 'User cancelled editing',
    );
  }
}

/// Video resolution options
class VideoResolution {
  final int width;
  final int height;

  const VideoResolution({required this.width, required this.height});

  String get label => '${width}x$height';

  @override
  String toString() => label;
}
