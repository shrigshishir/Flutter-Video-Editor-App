# Flutter Video Editor Package

A TikTok-style video editor package for Flutter. Edit videos with text overlays, audio tracks, effects, and more. Designed to be easily integrated into any Flutter app.

![Demo Screenshots from attached images - TikTok-style video editing interface]

> **Package Integration Ready**: This is a Flutter package that can be integrated into your existing app to provide video editing capabilities with a modern TikTok-like interface.

## ✨ Features

- 🎬 **Multi-Layer Timeline** - Video, text, and audio layers
- 📝 **Text Overlays** - Add stylized text with 20+ fonts
- 🎵 **Audio Tracks** - Import background music
- ✂️ **Video Trimming** - Cut and splice video clips
- 🎨 **Effects** - Ken Burns effect for images
- 📤 **Export** - Save in multiple resolutions (480p to 4K)
- 🔧 **Easy Integration** - Drop-in widget with callbacks
- 💅 **TikTok-Style UI** - Modern, intuitive interface

## 🚀 Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_video_editor:
    path: ../flutter_video_editor # Local path to this package
```

### Basic Usage

```dart
import 'package:flutter_video_editor/flutter_video_editor.dart';

// Open the editor and get result
final result = await VideoEditorWidget.openEditor(
  context,
  videoPath: '/path/to/your/video.mp4',
  config: VideoEditorConfig.quick(),
);

if (result != null && result.success) {
  print('Edited video: ${result.videoPath}');
}
```

## 📱 TikTok-Like Flow Integration

Perfect for apps with video recording → preview → edit flow:

```dart
// 1. User records video
final video = await ImagePicker().pickVideo(source: ImageSource.camera);

// 2. Preview screen with "Edit" button
ElevatedButton.icon(
  onPressed: () async {
    final result = await VideoEditorWidget.openEditor(
      context,
      videoPath: video.path,
      config: VideoEditorConfig.quick(),
    );
    if (result?.success == true) {
      // Use edited video
      _handleEditedVideo(result!.videoPath);
    }
  },
  icon: Icon(Icons.edit),
  label: Text('Edit Video'),
);
```

See [example/](./example) for complete implementation.

## ⚙️ Configuration

### Quick Mode (TikTok-style)

```dart
VideoEditorConfig.quick() // Single video, fast editing
```

### Full Mode (All features)

```dart
VideoEditorConfig.full() // Multiple clips, advanced features
```

### Custom Config

```dart
VideoEditorConfig(
  projectTitle: 'My Video',
  showBackButton: true,
  allowMultipleClips: false,
  allowText: true,
  allowAudio: true,
  exportResolutions: [
    VideoExportResolution.hd720,
    VideoExportResolution.hd1080,
  ],
)
```

## 📖 API Reference

### VideoEditorWidget

Main widget for video editing.

```dart
VideoEditorWidget({
  required String videoPath,      // Video file to edit
  VideoEditorConfig config,       // Configuration
  Function(VideoEditorResult)? onComplete,  // Completion callback
  VoidCallback? onCancel,         // Cancel callback
})
```

### VideoEditorResult

```dart
class VideoEditorResult {
  final String videoPath;         // Path to edited video
  final bool success;             // Success status
  final String? errorMessage;     // Error if failed
  final int? durationMs;          // Video duration
  final VideoResolution? resolution; // Resolution
}
```

## 🎨 Features in Detail

### Text Overlays

- 20+ Google Fonts
- Customizable colors, sizes, positions
- Timeline-based duration control
- Drag-and-drop positioning
- Background color/transparency

### Audio Tracks

- Import MP3, WAV files
- Volume control per track
- Trim and position on timeline
- Mix with original audio

### Video Editing

- Multi-clip timeline
- Trim/cut functionality
- Ken Burns effect for images
- Volume control
- Drag and drop clips

### Export

- Multiple resolutions (480p, 720p, 1080p, 4K)
- Progress tracking
- Background processing
- Automatic file management

## 📋 Requirements

- Flutter SDK: ^3.9.0
- Dart SDK: ^3.9.0
- iOS: 12.0+
- Android: API 21+

## 🔐 Permissions

### iOS (`Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to record videos</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for audio</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to save videos</string>
```

### Android (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

## 🏗️ Architecture

```
flutter_video_editor/
├── lib/
│   ├── flutter_video_editor.dart      # Main export
│   ├── src/
│   │   ├── video_editor_widget.dart   # Main widget
│   │   └── models/                    # Data models
│   ├── ui/                            # UI components
│   ├── service/                       # Business logic
│   └── model/                         # Internal models
└── example/                           # Example app
```

## 💡 Example App

The [example/](./example) directory contains a complete demo app showing:

1. Video recording with camera
2. TikTok-style preview screen
3. Integration with the video editor
4. Handling edited video results

Run it:

```bash
cd example
flutter run
```

## 🤝 Contributing

Contributions welcome! Please submit Pull Requests.

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Credits

- UI inspired by TikTok
- Uses FFmpeg for video processing
- Fonts from Google Fonts
- Forked from [open_director](https://github.com/jmfvarela/open_director)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/shrigshishir/Flutter-Video-Editor-App/issues)
- **Discussions**: [GitHub Discussions](https://github.com/shrigshishir/Flutter-Video-Editor-App/discussions)

---
