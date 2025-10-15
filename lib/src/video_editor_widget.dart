import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor/model/model.dart';
import 'package:flutter_video_editor/model/project.dart';
import 'package:flutter_video_editor/service/director_service.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:flutter_video_editor/ui/director.dart';
import '../src/models/video_editor_config.dart';
import '../src/models/video_editor_result.dart' as editor_result;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Main widget for the Video Editor package
///
/// This widget provides a TikTok-style video editing interface that can be
/// integrated into any Flutter app. Simply pass a video file path and get
/// the edited video back through the callback.
///
/// Example usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => VideoEditorWidget(
///       videoPath: recordedVideoPath,
///       config: VideoEditorConfig.quick(),
///       onComplete: (result) {
///         if (result.success) {
///           print('Edited video: ${result.videoPath}');
///         }
///         Navigator.pop(context);
///       },
///       onCancel: () {
///         Navigator.pop(context);
///       },
///     ),
///   ),
/// );
/// ```
class VideoEditorWidget extends StatefulWidget {
  /// Path to the video file to edit
  final String videoPath;

  /// Configuration for the editor
  final VideoEditorConfig config;

  /// Callback when editing is complete
  final Function(editor_result.VideoEditorResult)? onComplete;

  /// Callback when user cancels editing
  final VoidCallback? onCancel;

  const VideoEditorWidget({
    super.key,
    required this.videoPath,
    this.config = const VideoEditorConfig(),
    this.onComplete,
    this.onCancel,
  });

  @override
  State<VideoEditorWidget> createState() => _VideoEditorWidgetState();

  /// Static method to open editor as a route and wait for result
  ///
  /// This is a convenience method that handles navigation for you.
  ///
  /// Example:
  /// ```dart
  /// final result = await VideoEditorWidget.openEditor(
  ///   context,
  ///   videoPath: recordedVideoPath,
  ///   config: VideoEditorConfig.quick(),
  /// );
  ///
  /// if (result != null && result.success) {
  ///   print('Edited video: ${result.videoPath}');
  /// }
  /// ```
  static Future<editor_result.VideoEditorResult?> openEditor(
    BuildContext context, {
    required String videoPath,
    VideoEditorConfig config = const VideoEditorConfig(),
  }) async {
    editor_result.VideoEditorResult? result;

    await Navigator.push<editor_result.VideoEditorResult>(
      context,
      MaterialPageRoute(
        builder: (context) => VideoEditorWidget(
          videoPath: videoPath,
          config: config,
          onComplete: (r) {
            result = r;
            Navigator.pop(context, r);
          },
          onCancel: () {
            result = editor_result.VideoEditorResult.cancelled();
            Navigator.pop(context, result);
          },
        ),
      ),
    );

    return result;
  }
}

class _VideoEditorWidgetState extends State<VideoEditorWidget> {
  final directorService = locator.get<DirectorService>();
  bool _isInitializing = true;
  String? _errorMessage;
  Project? _project;

  @override
  void initState() {
    super.initState();
    _initializeEditor();
  }

  Future<void> _initializeEditor() async {
    try {
      // Verify video file exists
      final videoFile = File(widget.videoPath);
      if (!await videoFile.exists()) {
        throw Exception('Video file not found: ${widget.videoPath}');
      }

      // Create a new project from the video
      final project = await _createProjectFromVideo(videoFile);

      setState(() {
        _project = project;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize editor: $e';
        _isInitializing = false;
      });
    }
  }

  Future<Project> _createProjectFromVideo(File videoFile) async {
    // Get app documents directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final projectsDir = Directory(p.join(appDocDir.path, 'projects'));
    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }

    // Create project title
    final projectTitle =
        widget.config.projectTitle ??
        p.basenameWithoutExtension(videoFile.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Copy video to project directory
    final projectDir = Directory(p.join(projectsDir.path, '$timestamp'));
    await projectDir.create(recursive: true);

    final copiedVideoPath = p.join(
      projectDir.path,
      'imported_${p.basename(videoFile.path)}',
    );
    await videoFile.copy(copiedVideoPath);

    // Create initial layer structure with the video
    final layers = [
      Layer(
        type: 'video_photo',
        assets: [
          Asset(
            type: AssetType.video,
            srcPath: copiedVideoPath,
            begin: 0,
            duration: 0, // Will be calculated by DirectorService
            title: '',
            deleted: false,
            volume: 1.0,
            font: 'Lato/Lato-Regular.ttf',
            fontSize: 0.1,
            fontColor: 0xFFFFFFFF,
            boxcolor: 0x00000000,
            x: 0.05,
            y: 0.8,
            cutFrom: 0,
          ),
        ],
      ),
      Layer(type: 'text', assets: []),
      Layer(type: 'audio', assets: [], volume: 1.0),
    ];

    // Create the project
    final project = Project(
      title: projectTitle,
      date: DateTime.now(),
      duration: 0, // Will be calculated
      layersJson: json.encode(layers.map((layer) => layer.toJson()).toList()),
    );
    project.id = timestamp;

    return project;
  }

  void _handleCancel() {
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      Navigator.of(context).pop(editor_result.VideoEditorResult.cancelled());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Loading video editor...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleCancel,
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_project == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Use the existing DirectorScreen with the created project
    return WillPopScope(
      onWillPop: () async {
        _handleCancel();
        return false;
      },
      child: DirectorScreen(_project!),
    );
  }
}
