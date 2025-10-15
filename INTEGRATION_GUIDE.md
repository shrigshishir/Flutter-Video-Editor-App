# Integration Guide: Adding Flutter Video Editor to Your App

This guide shows you how to integrate the Flutter Video Editor package into your main app with a TikTok-style flow.

## 📁 Project Structure

```
your_main_app/
├── pubspec.yaml
├── lib/
│   └── main.dart
└── ...

flutter_video_editor/  (this package)
├── pubspec.yaml
├── lib/
│   ├── flutter_video_editor.dart
│   └── src/
└── example/
```

## 🔧 Step 1: Add Package as Dependency

In your main app's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Add the video editor package
  flutter_video_editor:
    path: ../flutter_video_editor # Adjust path relative to your app

  # For video recording (optional, if you need it)
  image_picker: ^1.1.2
  video_player: ^2.9.2
```

Run:

```bash
flutter pub get
```

## 🎬 Step 2: TikTok-Style Flow Implementation

### Flow Diagram

```
User Records Video → Preview Screen → Edit Button → Video Editor → Get Edited Video
```

### Code Implementation

#### 1. Video Recording Screen

```dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RecordVideoScreen extends StatefulWidget {
  @override
  State<RecordVideoScreen> createState() => _RecordVideoScreenState();
}

class _RecordVideoScreenState extends State<RecordVideoScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _recordVideo() async {
    // Record video
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 1),
    );

    if (video != null) {
      // Go to preview screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPreviewScreen(
            videoPath: video.path,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _recordVideo,
          icon: Icon(Icons.videocam),
          label: Text('Record Video'),
        ),
      ),
    );
  }
}
```

#### 2. Preview Screen with Edit Button

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor/flutter_video_editor.dart';
import 'package:video_player/video_player.dart';

class VideoPreviewScreen extends StatefulWidget {
  final String videoPath;

  const VideoPreviewScreen({required this.videoPath});

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _controller;
  String? _editedVideoPath;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath));
    _controller.initialize().then((_) {
      setState(() {});
      _controller.setLooping(true);
      _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEditor() async {
    await _controller.pause();

    // Open the video editor
    final result = await VideoEditorWidget.openEditor(
      context,
      videoPath: widget.videoPath,
      config: VideoEditorConfig.quick(),
    );

    // Handle result
    if (result != null && result.success && mounted) {
      setState(() {
        _editedVideoPath = result.videoPath;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video edited successfully!')),
      );

      // Optionally update the video player to show edited video
      _controller.dispose();
      _controller = VideoPlayerController.file(File(result.videoPath));
      _controller.initialize().then((_) {
        setState(() {});
        _controller.play();
      });
    } else {
      // User cancelled, resume playback
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
          if (_controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),

          // Top bar
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Spacer(),
                if (_editedVideoPath != null)
                  Chip(
                    label: Text('Edited'),
                    backgroundColor: Colors.green,
                  ),
              ],
            ),
          ),

          // Bottom bar with Edit button (TikTok-style)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Handle share/next
                      },
                      child: Text('Next'),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _openEditor,
                      icon: Icon(Icons.edit),
                      label: Text('Edit Video'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        padding: EdgeInsets.symmetric(vertical: 16),
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
```

#### 3. Alternative: Using Navigator with Callbacks

```dart
Future<void> _openEditorWithCallbacks() async {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => VideoEditorWidget(
        videoPath: widget.videoPath,
        config: VideoEditorConfig.quick(),
        onComplete: (result) {
          if (result.success) {
            // Handle the edited video
            print('Edited video: ${result.videoPath}');
            _handleEditedVideo(result.videoPath);
          } else {
            print('Error: ${result.errorMessage}');
          }
          Navigator.pop(context);
        },
        onCancel: () {
          print('User cancelled editing');
          Navigator.pop(context);
        },
      ),
    ),
  );
}

void _handleEditedVideo(String videoPath) {
  setState(() {
    _editedVideoPath = videoPath;
  });

  // Update video player, upload to server, etc.
  _controller.dispose();
  _controller = VideoPlayerController.file(File(videoPath));
  _controller.initialize().then((_) {
    setState(() {});
    _controller.play();
  });
}
```

## ⚙️ Configuration Options

### Quick Mode (Recommended for TikTok-style)

```dart
VideoEditorConfig.quick()
```

Best for:

- Single video editing
- Fast, focused editing experience
- Mobile-first apps

### Full Mode

```dart
VideoEditorConfig.full()
```

Best for:

- Professional editing
- Multiple video clips
- Desktop/tablet apps

### Custom Configuration

```dart
VideoEditorConfig(
  projectTitle: 'My Video Project',
  showBackButton: true,
  autoSave: false,  // For quick edits
  allowMultipleClips: false,  // Single video only
  allowText: true,
  allowAudio: true,
  allowEffects: true,
  exportResolutions: [
    VideoExportResolution.hd720,
    VideoExportResolution.hd1080,
  ],
  defaultExportResolution: VideoExportResolution.hd1080,
  maxDurationSeconds: 60,  // Limit video length
)
```

## 📤 Handling Export Results

### VideoEditorResult Properties

```dart
if (result.success) {
  // Access edited video
  String videoPath = result.videoPath;
  int? duration = result.durationMs;
  VideoResolution? resolution = result.resolution;

  // Upload to server
  await uploadVideo(videoPath);

  // Share to social media
  await shareVideo(videoPath);

  // Save to gallery
  await saveToGallery(videoPath);
}
```

### Error Handling

```dart
if (result != null && !result.success) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Error'),
      content: Text(result.errorMessage ?? 'Unknown error'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

## 🎨 Customizing Theme

```dart
VideoEditorWidget.openEditor(
  context,
  videoPath: videoPath,
  config: VideoEditorConfig(
    theme: ThemeData(
      primaryColor: Colors.purple,
      colorScheme: ColorScheme.dark(
        primary: Colors.purple,
        secondary: Colors.pinkAccent,
      ),
      scaffoldBackgroundColor: Colors.black,
    ),
  ),
);
```

## 📱 Platform-Specific Setup

### iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to record videos</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for audio</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to save videos</string>
```

### Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## 🔍 Common Use Cases

### 1. Social Media App

```dart
// Record → Edit → Share flow
final video = await recordVideo();
final editedVideo = await editVideo(video.path);
await shareToSocial(editedVideo.videoPath);
```

### 2. Video Messaging App

```dart
// Record → Quick edit → Send flow
final result = await VideoEditorWidget.openEditor(
  context,
  videoPath: recordedPath,
  config: VideoEditorConfig.quick(),
);

if (result?.success == true) {
  await sendMessage(result!.videoPath);
}
```

### 3. Content Creation App

```dart
// Import → Full edit → Export flow
final result = await VideoEditorWidget.openEditor(
  context,
  videoPath: importedVideoPath,
  config: VideoEditorConfig.full(),
);

if (result?.success == true) {
  await exportToGallery(result!.videoPath);
}
```

## 🐛 Troubleshooting

### Package Not Found

```yaml
# Make sure path is correct relative to your app
dependencies:
  flutter_video_editor:
    path: ../flutter_video_editor # Adjust this path
```

### Video Not Loading

```dart
// Ensure file exists before passing to editor
final file = File(videoPath);
if (await file.exists()) {
  await VideoEditorWidget.openEditor(context, videoPath: videoPath);
} else {
  print('Video file not found!');
}
```

### Memory Issues

```dart
// Dispose video controller when done
@override
void dispose() {
  _controller.dispose();
  super.dispose();
}
```

## 📚 Additional Resources

- [Example App](../example) - Complete working example
- [API Documentation](../README.md) - Full API reference
- [GitHub Issues](https://github.com/shrigshishir/Flutter-Video-Editor-App/issues) - Report bugs

## 💡 Tips

1. **Use Quick Mode** for TikTok-style apps
2. **Handle Cancellation** gracefully with onCancel callback
3. **Show Loading** indicator while editor initializes
4. **Clean Up** video files when no longer needed
5. **Test on Real Devices** for best performance

---

Happy coding! 🎉
