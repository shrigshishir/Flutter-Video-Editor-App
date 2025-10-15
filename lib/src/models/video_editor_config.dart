import 'package:flutter/material.dart';

/// Configuration for the video editor
class VideoEditorConfig {
  /// Project title (defaults to filename if not provided)
  final String? projectTitle;

  /// Whether to show the back button
  final bool showBackButton;

  /// Whether to auto-save the project
  final bool autoSave;

  /// Custom theme for the editor
  final ThemeData? theme;

  /// Maximum video duration in seconds (null = no limit)
  final int? maxDurationSeconds;

  /// Whether to allow adding additional video clips
  final bool allowMultipleClips;

  /// Whether to allow adding audio
  final bool allowAudio;

  /// Whether to allow adding text
  final bool allowText;

  /// Whether to allow effects
  final bool allowEffects;

  /// Export resolution options
  final List<VideoExportResolution> exportResolutions;

  /// Default export resolution
  final VideoExportResolution? defaultExportResolution;

  const VideoEditorConfig({
    this.projectTitle,
    this.showBackButton = true,
    this.autoSave = true,
    this.theme,
    this.maxDurationSeconds,
    this.allowMultipleClips = true,
    this.allowAudio = true,
    this.allowText = true,
    this.allowEffects = true,
    this.exportResolutions = const [
      VideoExportResolution.hd720,
      VideoExportResolution.hd1080,
      VideoExportResolution.uhd4k,
    ],
    this.defaultExportResolution,
  });

  /// Create a minimal config for quick editing (TikTok-style)
  factory VideoEditorConfig.quick() {
    return const VideoEditorConfig(
      showBackButton: true,
      autoSave: false,
      allowMultipleClips: false,
      exportResolutions: [
        VideoExportResolution.hd720,
        VideoExportResolution.hd1080,
      ],
      defaultExportResolution: VideoExportResolution.hd1080,
    );
  }

  /// Create a full-featured config
  factory VideoEditorConfig.full() {
    return const VideoEditorConfig(
      showBackButton: true,
      autoSave: true,
      allowMultipleClips: true,
      allowAudio: true,
      allowText: true,
      allowEffects: true,
    );
  }
}

/// Export resolution presets
enum VideoExportResolution {
  sd480(width: 640, height: 480, label: '480p (SD)'),
  hd720(width: 1280, height: 720, label: '720p (HD)'),
  hd1080(width: 1920, height: 1080, label: '1080p (Full HD)'),
  uhd4k(width: 3840, height: 2160, label: '4K (UHD)');

  final int width;
  final int height;
  final String label;

  const VideoExportResolution({
    required this.width,
    required this.height,
    required this.label,
  });

  @override
  String toString() => label;
}
