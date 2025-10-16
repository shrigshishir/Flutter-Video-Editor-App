import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor/flutter_video_editor.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

void main() {
  // Initialize Flutter bindings before any platform/service calls.
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure app-level services are registered before the app starts.
  setupLocator();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Editor Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const VideoRecorderScreen(),
    );
  }
}

/// Example screen showing TikTok-like flow:
/// 1. User records/picks a video
/// 2. Preview screen shows the video with "Edit" button
/// 3. Clicking "Edit" opens the video editor
/// 4. After editing, user gets back the edited video
class VideoRecorderScreen extends StatefulWidget {
  const VideoRecorderScreen({super.key});

  @override
  State<VideoRecorderScreen> createState() => _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends State<VideoRecorderScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _recordVideo() async {
    try {
      // Record a video (or pick from gallery for this example)
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 1),
      );

      if (video != null) {
        // Automatically go to preview screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPreviewScreen(videoPath: video.path),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error recording video: $e')));
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        // Automatically go to preview screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPreviewScreen(videoPath: video.path),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking video: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, size: 100, color: Colors.white70),
            const SizedBox(height: 40),
            Text(
              'Video Editor Example',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton.icon(
              onPressed: _recordVideo,
              icon: const Icon(Icons.videocam),
              label: const Text('Record Video'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.photo_library),
              label: const Text('Pick from Gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preview screen showing the recorded video with edit options
/// This mimics TikTok's preview screen
class VideoPreviewScreen extends StatefulWidget {
  final String videoPath;

  const VideoPreviewScreen({super.key, required this.videoPath});

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _editedVideoPath;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller.initialize();
    await _controller.setLooping(true);
    await _controller.play();
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEditor() async {
    // Pause the video while editing
    await _controller.pause();

    // Open the video editor
    final result = await VideoEditorWidget.openEditor(
      context,
      videoPath: widget.videoPath,
      config: VideoEditorConfig.quick(), // TikTok-style quick editing
    );

    // Handle the result
    if (result != null && result.success && mounted) {
      setState(() {
        _editedVideoPath = result.videoPath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video saved successfully!'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Re-initialize with edited video
              _controller.dispose();
              _controller = VideoPlayerController.file(File(result.videoPath));
              _controller.initialize().then((_) {
                setState(() {});
                _controller.play();
              });
            },
          ),
        ),
      );
    } else if (mounted) {
      // Resume playback if cancelled
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          if (_isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Top bar with back button
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                if (_editedVideoPath != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Chip(
                      avatar: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: const Text(
                        'Edited',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  ),
              ],
            ),
          ),

          // Bottom bar with edit button (TikTok-style)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                top: 40,
                left: 20,
                right: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Next/Share button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Handle next/share action
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share video...')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Edit button (main CTA)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _openEditor,
                      icon: const Icon(Icons.edit),
                      label: const Text(
                        'Edit Video',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
