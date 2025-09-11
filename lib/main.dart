import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_video_editor_app/core/app_theme/app_theme.dart';
import 'package:flutter_video_editor_app/service_locator.dart';
import 'package:flutter_video_editor_app/ui/project_list.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  //CustomImageCache(); // Disabled at this time
  //setupDevice(); // Disabled at this time
  setupLocator();
  runApp(MyApp());
}

setupDevice() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Status bar disabled
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: darkTheme(),
      home: Scaffold(body: ProjectList()),
    );
  }
}

class CustomImageCache extends WidgetsFlutterBinding {
  @override
  ImageCache createImageCache() {
    ImageCache imageCache = super.createImageCache();
    imageCache.maximumSize = 5;
    return imageCache;
  }
}
