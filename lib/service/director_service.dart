import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor/dao/project_dao.dart';
import 'package:flutter_video_editor/model/generated_video.dart';
import 'package:flutter_video_editor/model/model.dart';
import 'package:flutter_video_editor/model/project.dart';
import 'package:flutter_video_editor/service/director/generator.dart';
import 'package:flutter_video_editor/service/director/layer_player.dart';
import 'package:flutter_video_editor/service/project_service.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Orchestrates multi-layer video timeline editing operations and playback coordination.
///
/// This service manages the entire video editing workflow including:
/// - Multi-layer timeline management (Layer 0: video/images, Layer 1: text, Layer 2: audio)
/// - Synchronized playback across all layers using LayerPlayer instances
/// - Asset manipulation (add, delete, cut, drag/drop, resize)
/// - Volume control system with asset-level and layer-level hierarchy
/// - File management with persistent storage for imported media
/// - Project persistence and state management through reactive streams
/// - Timeline scrubbing, scaling, and position tracking
///
/// The service coordinates between UI components and the underlying LayerPlayer
/// system to provide a cohesive video editing experience.
class DirectorService {
  Project? project;
  final logger = locator.get<Logger>();
  final projectService = locator.get<ProjectService>();
  final generator = locator.get<Generator>();
  final projectDao = locator.get<ProjectDao>();

  late List<Layer> layers;
  bool _isInitialized = false;

  // Flags for concurrency
  bool isEntering = false;
  bool isExiting = false;
  bool isPlaying = false;
  bool isPreviewing = false;
  int mainLayerIndexForConcurrency = -1;
  bool isDragging = false;
  bool isSizerDragging = false;
  bool isCutting = false;
  bool isScaling = false;
  bool isAdding = false;
  bool isDeleting = false;
  bool isGenerating = false;
  bool get isOperating =>
      (isEntering ||
      isExiting ||
      isPlaying ||
      isPreviewing ||
      isDragging ||
      isSizerDragging ||
      isClipperDragging ||
      isCutting ||
      isScaling ||
      isAdding ||
      isDeleting ||
      isGenerating);
  double? _pixelsPerSecondOnInitScale;
  double? _scrollOffsetOnInitScale;
  double dxSizerDrag = 0;
  bool isSizerDraggingEnd = false;

  // Clipper variables for video/photo clipping
  bool isClipperDragging = false;
  double dxClipperDrag = 0;
  bool isClipperDraggingEnd = false;

  final BehaviorSubject<bool> _filesNotExist = BehaviorSubject.seeded(false);
  Stream<bool> get filesNotExist$ => _filesNotExist.stream;
  bool get filesNotExist => _filesNotExist.value;

  late List<LayerPlayer?> layerPlayers;

  final ScrollController scrollController = ScrollController();

  final BehaviorSubject<bool> _layersChanged = BehaviorSubject.seeded(false);
  Stream<bool> get layersChanged$ => _layersChanged.stream;
  bool get layersChanged => _layersChanged.value;

  final BehaviorSubject<Selected> _selected = BehaviorSubject.seeded(
    Selected(-1, -1),
  );
  Stream<Selected> get selected$ => _selected.stream;
  Selected get selected => _selected.value;
  Asset? get assetSelected {
    if (!_isInitialized ||
        selected.layerIndex == -1 ||
        selected.assetIndex == -1)
      return null;
    return layers[selected.layerIndex].assets[selected.assetIndex];
  }

  static const double DEFAULT_PIXELS_PER_SECONDS = 100.0 / 5.0;
  final BehaviorSubject<double> _pixelsPerSecond = BehaviorSubject.seeded(
    DEFAULT_PIXELS_PER_SECONDS,
  );
  Stream<double> get pixelsPerSecond$ => _pixelsPerSecond.stream;
  double get pixelsPerSecond => _pixelsPerSecond.value;

  final BehaviorSubject<bool> _appBar = BehaviorSubject.seeded(false);
  Stream<bool> get appBar$ => _appBar.stream;

  final BehaviorSubject<int> _position = BehaviorSubject.seeded(0);
  Stream<int> get position$ => _position.stream;
  int get position => _position.value;

  final BehaviorSubject<Asset?> _editingTextAsset = BehaviorSubject.seeded(
    null,
  );
  Stream<Asset?> get editingTextAsset$ => _editingTextAsset.stream;
  Asset? get editingTextAsset => _editingTextAsset.value;
  set editingTextAsset(Asset? value) {
    _editingTextAsset.add(value);
    _appBar.add(true);
  }

  String get positionMinutes {
    int minutes = (position / 1000 / 60).floor();
    return (minutes < 10) ? '0$minutes' : minutes.toString();
  }

  String get positionSeconds {
    int minutes = (position / 1000 / 60).floor();
    double seconds = (((position / 1000 - minutes * 60) * 10).floor() / 10);
    return (seconds < 10)
        ? '0${seconds.toStringAsFixed(1)}'
        : seconds.toStringAsFixed(1);
  }

  int get duration {
    if (!_isInitialized) return 0;
    int maxDuration = 0;
    for (int i = 0; i < layers.length; i++) {
      for (int j = layers[i].assets.length - 1; j >= 0; j--) {
        if (!(i == 1 && layers[i].assets[j].title == '')) {
          int dur = layers[i].assets[j].begin + layers[i].assets[j].duration;
          maxDuration = math.max(maxDuration, dur);
          break;
        }
      }
    }
    return maxDuration;
  }

  DirectorService() {
    scrollController.addListener(_listenerScrollController);
    _layersChanged.listen((bool onData) => _saveProject());
  }

  dispose() {
    _layersChanged.close();
    _selected.close();
    _pixelsPerSecond.close();
    _position.close();
    _appBar.close();
    _editingTextAsset.close();
    _filesNotExist.close();
  }

  setProject(Project _project) async {
    isEntering = true;

    _position.add(0);
    _selected.add(Selected(-1, -1));
    editingTextAsset = null;
    _pixelsPerSecond.add(DEFAULT_PIXELS_PER_SECONDS);
    _appBar.add(true);

    if (project != _project) {
      project = _project;
      if (_project.layersJson == null) {
        layers = [
          // Layer 0: Video/image assets with volume control
          Layer(type: "raster", volume: null),
          // Layer 1: Text overlays (handled by UI rendering)
          Layer(type: "vector"),
          // Layer 2: Audio tracks with volume control
          Layer(type: "audio", volume: null),
        ];
      } else {
        layers = List<Layer>.from(
          json
              .decode(_project.layersJson!)
              .map((layerMap) => Layer.fromJson(layerMap)),
        ).toList();
        _filesNotExist.add(checkSomeFileNotExists());
      }
      _isInitialized = true;
      _layersChanged.add(true);

      layerPlayers = List<LayerPlayer?>.filled(
        layers.length,
        null,
        growable: false,
      );
      for (int i = 0; i < layers.length; i++) {
        LayerPlayer? layerPlayer;
        if (i != 1) {
          layerPlayer = LayerPlayer(layers[i]);
          await layerPlayer.initialize();
        }
        layerPlayers[i] = layerPlayer;
      }
    }
    isEntering = false;
    await _previewOnPosition();
  }

  checkSomeFileNotExists() {
    if (!_isInitialized) return false;
    bool _someFileNotExists = false;
    for (int i = 0; i < layers.length; i++) {
      for (int j = 0; j < layers[i].assets.length; j++) {
        Asset asset = layers[i].assets[j];
        if (asset.srcPath != '' && !File(asset.srcPath).existsSync()) {
          asset.deleted = true;
          _someFileNotExists = true;
          print(asset.srcPath + ' does not exists');
        }
      }
    }
    return _someFileNotExists;
  }

  exitAndSaveProject() async {
    if (isPlaying) await stop();
    if (isOperating) return false;
    isExiting = true;
    _saveProject();

    Future.delayed(Duration(milliseconds: 500), () {
      project = null;
      layerPlayers.forEach((layerPlayer) {
        layerPlayer?.dispose();
        layerPlayer = null;
      });
      isExiting = false;
    });

    // _deleteThumbnailsNotUsed();
    return true;
  }

  _saveProject() {
    if (!_isInitialized || layers.isEmpty || project == null) return;
    project!.layersJson = json.encode(layers);
    project!.imagePath = layers[0].assets.isNotEmpty
        ? getFirstThumbnailMedPath()
        : null;
    projectService.update(project!);
  }

  String getFirstThumbnailMedPath() {
    for (int i = 0; i < layers[0].assets.length; i++) {
      Asset asset = layers[0].assets[i];
      if (asset.thumbnailMedPath != null &&
          File(asset.thumbnailMedPath!).existsSync()) {
        return asset.thumbnailMedPath!;
      }
    }
    return '';
  }

  _listenerScrollController() async {
    // When playing position is defined by the video player
    if (isPlaying) return;
    // In other case by the scroll manually
    _position.sink.add(
      ((scrollController.offset / pixelsPerSecond) * 1000).floor(),
    );
    // Delayed 10 to get more fuidity in scroll and preview
    Future.delayed(Duration(milliseconds: 10), () {
      _previewOnPosition();
    });
  }

  endScroll() async {
    _position.sink.add(
      ((scrollController.offset / pixelsPerSecond) * 1000).floor(),
    );
    // Delayed 200 because position may not be updated at this time
    Future.delayed(Duration(milliseconds: 200), () {
      _previewOnPosition();
    });
  }

  /// Updates the visual preview to show the frame at the current timeline position.
  ///
  /// Uses Layer 0 (video/images) to generate the preview frame. Called during
  /// timeline scrubbing to provide real-time visual feedback.
  _previewOnPosition() async {
    if (filesNotExist) return;
    if (isOperating) return;
    isPreviewing = true;
    scrollController.removeListener(_listenerScrollController);

    await layerPlayers[0]?.preview(position);
    _position.add(position);

    scrollController.addListener(_listenerScrollController);
    isPreviewing = false;
  }

  /// Starts synchronized playback across all timeline layers from current position.
  ///
  /// Layer 0 (video/images) serves as the master timeline, controlling position updates
  /// and providing callbacks for UI synchronization. Other layers play independently
  /// but are coordinated to start at the same timeline position.
  ///
  /// Text layer (Layer 1) is skipped as it's handled by UI rendering, not playback.
  play() async {
    if (filesNotExist) {
      _filesNotExist.add(true);
      return;
    }
    if (isOperating) return;
    if (position >= duration) return;
    logger.i('DirectorService.play()');
    isPlaying = true;
    scrollController.removeListener(_listenerScrollController);
    _appBar.add(true);
    _selected.add(Selected(-1, -1));

    int mainLayer = mainLayerForConcurrency();
    print('mainLayer: $mainLayer');

    for (int i = 0; i < layers.length; i++) {
      if (i == 1) {
        print('Skipping layer $i (text layer)');
        continue;
      }

      print(
        'Processing layer $i (${layers[i].type}), assets: ${layers[i].assets.length}',
      );

      if (i == 0) {
        // Layer 0 (raster/video) controls visual playback and position updates
        await layerPlayers[i]?.play(
          position,
          onMove: (int newPosition) {
            _position.add(newPosition);
            scrollController.animateTo(
              (300 + newPosition) / 1000 * pixelsPerSecond,
              duration: Duration(milliseconds: 100),
              curve: Curves.linear,
            );

            // Notify audio layers about position updates for monitoring
            for (
              int audioLayerIndex = 2;
              audioLayerIndex < layers.length;
              audioLayerIndex++
            ) {
              if (layers[audioLayerIndex].type == 'audio' &&
                  layerPlayers[audioLayerIndex] != null) {
                layerPlayers[audioLayerIndex]?.handlePositionUpdate(
                  newPosition,
                );
              }
            }
          },
          onEnd: () {
            print('DirectorService onEnd called - stopping playback');
            stop(); // Stop all layers when main layer finishes
          },
        );
      } else {
        await layerPlayers[i]?.play(position);
      }
      _position.add(position);
    }
  }

  /// Stops playback across all timeline layers and restores UI interaction.
  ///
  /// Coordinates shutdown of all LayerPlayer instances and re-enables
  /// scroll-based position updates for manual timeline scrubbing.
  stop() async {
    print('>> DirectorService.stop()');
    for (int i = 0; i < layers.length; i++) {
      if (i == 1) continue;
      await layerPlayers[i]?.stop();
    }
    isPlaying = false;
    scrollController.addListener(_listenerScrollController);
    _appBar.add(true);
  }

  int mainLayerForConcurrency() {
    int mainLayer = 0, mainLayerDuration = 0;
    for (int i = 0; i < layers.length; i++) {
      if (i != 1 &&
          layers[i].assets.isNotEmpty &&
          layers[i].assets.last.begin + layers[i].assets.last.duration >
              mainLayerDuration) {
        mainLayer = i;
        mainLayerDuration =
            layers[i].assets.last.begin + layers[i].assets.last.duration;
      }
    }
    return mainLayer;
  }

  /// Adds new media assets to the timeline through file picker dialogs.
  ///
  /// Handles different asset types (video, image, text, audio) and automatically
  /// places them in the appropriate layer. Files are copied to persistent storage
  /// and thumbnails are generated for visual assets.
  add(AssetType assetType) async {
    // Prevent multiple concurrent calls
    if (isOperating) {
      print('Add operation already in progress, ignoring request');
      return;
    }

    isAdding = true;
    print('>> DirectorService.add($assetType)');

    try {
      if (assetType == AssetType.video) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: true,
        );
        if (result == null) return;

        List<File> fileList = result.paths
            .whereType<String>()
            .map((path) => File(path))
            .toList();
        for (int i = 0; i < fileList.length; i++) {
          await _addAssetToLayer(0, AssetType.video, fileList[i].path);
          await _generateAllVideoThumbnails(layers[0].assets);
        }
      } else if (assetType == AssetType.image) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        if (result == null) return;

        List<File> fileList = result.paths
            .whereType<String>()
            .map((path) => File(path))
            .toList();
        for (int i = 0; i < fileList.length; i++) {
          await _addAssetToLayer(0, AssetType.image, fileList[i].path);
          // _generateKenBurnEffects(layers[0].assets.last);
          await _generateAllImageThumbnails(layers[0].assets);
        }
      } else if (assetType == AssetType.text) {
        editingTextAsset = Asset(
          type: AssetType.text,
          begin: position, // Start at current timeline position
          duration: 5000,
          title: '',
          srcPath: '',
          originalDuration: 5000, // Text assets can extend beyond original
        );
      } else if (assetType == AssetType.audio) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
          allowMultiple: false,
        );
        if (result == null) return;

        List<File> fileList = result.paths
            .whereType<String>()
            .map((path) => File(path))
            .toList();
        for (int i = 0; i < fileList.length; i++) {
          await _addAssetToLayer(2, AssetType.audio, fileList[i].path);
        }
      }
    } catch (e) {
      print('Error in add(): $e');
    } finally {
      isAdding = false;
    }
  }

  _generateAllVideoThumbnails(List<Asset> assets) async {
    await _generateVideoThumbnails(assets, VideoResolution.mini);
    await _generateVideoThumbnails(assets, VideoResolution.sd);
  }

  _generateVideoThumbnails(
    List<Asset> assets,
    VideoResolution videoResolution,
  ) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    await Directory(p.join(appDocDir.path, 'thumbnails')).create();
    for (int i = 0; i < assets.length; i++) {
      Asset asset = assets[i];
      if (((videoResolution == VideoResolution.mini &&
                  asset.thumbnailPath == null) ||
              asset.thumbnailMedPath == null) &&
          !asset.deleted) {
        String thumbnailFileName =
            p.setExtension(asset.srcPath, '').split('/').last +
            '_pos_${asset.cutFrom}.jpg';
        String thumbnailPath = p.join(
          appDocDir.path,
          'thumbnails',
          thumbnailFileName,
        );
        thumbnailPath = await generator.generateVideoThumbnail(
          asset.srcPath,
          thumbnailPath,
          asset.cutFrom,
          videoResolution,
        );

        if (videoResolution == VideoResolution.mini) {
          asset.thumbnailPath = thumbnailPath;
        } else {
          asset.thumbnailMedPath = thumbnailPath;
        }
        _layersChanged.add(true);
      }
    }
  }

  _generateAllImageThumbnails(List<Asset> assets) async {
    await _generateImageThumbnails(assets, VideoResolution.mini);
    await _generateImageThumbnails(assets, VideoResolution.sd);
  }

  _generateImageThumbnails(
    List<Asset> assets,
    VideoResolution videoResolution,
  ) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    await Directory(p.join(appDocDir.path, 'thumbnails')).create();
    for (int i = 0; i < assets.length; i++) {
      Asset asset = assets[i];
      if (((videoResolution == VideoResolution.mini &&
                  asset.thumbnailPath == null) ||
              asset.thumbnailMedPath == null) &&
          !asset.deleted) {
        String thumbnailFileName =
            p.setExtension(asset.srcPath, '').split('/').last + '_min.jpg';
        String thumbnailPath = p.join(
          appDocDir.path,
          'thumbnails',
          thumbnailFileName,
        );
        thumbnailPath = await generator.generateImageThumbnail(
          asset.srcPath,
          thumbnailPath,
          videoResolution,
        );
        if (videoResolution == VideoResolution.mini) {
          asset.thumbnailPath = thumbnailPath;
        } else {
          asset.thumbnailMedPath = thumbnailPath;
        }
        _layersChanged.add(true);
      }
    }
  }

  editTextAsset() {
    if (assetSelected == null) return;
    if (assetSelected!.type != AssetType.text) return;
    editingTextAsset = Asset.clone(assetSelected!);
    scrollController.animateTo(
      assetSelected!.begin / 1000 * pixelsPerSecond,
      duration: Duration(milliseconds: 300),
      curve: Curves.linear,
    );
  }

  saveTextAsset() {
    if (editingTextAsset == null) return;
    if (editingTextAsset!.title == '') {
      editingTextAsset!.title = 'No title';
    }
    if (assetSelected == null) {
      editingTextAsset!.begin = position;
      layers[1].assets.add(editingTextAsset!);
      reorganizeTextAssets(1);
    } else {
      layers[1].assets[selected.assetIndex] = editingTextAsset!;
    }
    _layersChanged.add(true);
    editingTextAsset = null;
  }

  reorganizeTextAssets(int layerIndex) {
    if (layers[layerIndex].assets.isEmpty) return;
    // After adding an asset in a position (begin = position),
    // it´s neccesary to sort
    layers[layerIndex].assets.sort((a, b) => a.begin - b.begin);

    // Configuring other assets and spaces after that
    for (int i = 1; i < layers[layerIndex].assets.length; i++) {
      Asset asset = layers[layerIndex].assets[i];
      Asset prevAsset = layers[layerIndex].assets[i - 1];

      if (prevAsset.title == '' && asset.title == '') {
        asset.begin = prevAsset.begin;
        asset.duration += prevAsset.duration;
        prevAsset.duration = 0; // To delete at the end
      } else if (prevAsset.title == '' && asset.title != '') {
        prevAsset.duration = asset.begin - prevAsset.begin;
      } else if (prevAsset.title != '' && asset.title == '') {
        asset.duration -= prevAsset.begin + prevAsset.duration - asset.begin;
        asset.duration = math.max(asset.duration, 0);
        asset.begin = prevAsset.begin + prevAsset.duration;
      } else if (prevAsset.title != '' && asset.title != '') {
        // Nothing, only insert space in a second loop if it´s neccesary
      }
    }

    // Remove duplicated spaces
    layers[layerIndex].assets.removeWhere((asset) => asset.duration <= 0);

    // Second loop to insert spaces between assets or move asset
    for (int i = 1; i < layers[layerIndex].assets.length; i++) {
      Asset asset = layers[layerIndex].assets[i];
      Asset prevAsset = layers[layerIndex].assets[i - 1];
      if (asset.begin > prevAsset.begin + prevAsset.duration) {
        Asset newAsset = Asset(
          type: AssetType.text,
          begin: prevAsset.begin + prevAsset.duration,
          duration: asset.begin - (prevAsset.begin + prevAsset.duration),
          title: '',
          srcPath: '',
        );
        layers[layerIndex].assets.insert(i, newAsset);
      } else {
        asset.begin = prevAsset.begin + prevAsset.duration;
      }
    }
    if (layers[layerIndex].assets.isNotEmpty &&
        layers[layerIndex].assets[0].begin > 0) {
      Asset newAsset = Asset(
        type: AssetType.text,
        begin: 0,
        duration: layers[layerIndex].assets[0].begin,
        title: '',
        srcPath: '',
      );
      layers[layerIndex].assets.insert(0, newAsset);
    }

    // Last space until video duration
    if (layers[layerIndex].assets.last.title == '') {
      layers[layerIndex].assets.last.duration =
          duration - layers[layerIndex].assets.last.begin;
    } else {
      Asset prevAsset = layers[layerIndex].assets.last;
      Asset asset = Asset(
        type: AssetType.text,
        begin: prevAsset.begin + prevAsset.duration,
        duration: duration - (prevAsset.begin + prevAsset.duration),
        title: '',
        srcPath: '',
      );
      layers[layerIndex].assets.add(asset);
    }
  }

  /// Reorganizes video/photo assets in Layer 0 to maintain sequential positioning
  /// Updates begin positions of all assets after any duration changes
  reorganizeVideoPhotoAssets(int layerIndex) {
    if (layers[layerIndex].assets.isEmpty) return;

    // Sort assets by begin time to ensure proper order
    layers[layerIndex].assets.sort((a, b) => a.begin.compareTo(b.begin));

    // Start with the first asset at the beginning of timeline
    layers[layerIndex].assets[0].begin = 0;

    // Update begin positions sequentially
    for (int i = 1; i < layers[layerIndex].assets.length; i++) {
      Asset currentAsset = layers[layerIndex].assets[i];
      Asset prevAsset = layers[layerIndex].assets[i - 1];

      // Set current asset to start right after previous asset ends
      currentAsset.begin = prevAsset.begin + prevAsset.duration;
    }
  }

  /// Adds a media file to the specified timeline layer.
  ///
  /// Handles file validation, copying to persistent storage, duration calculation,
  /// and timeline positioning. Creates Asset objects with proper metadata.
  _addAssetToLayer(int layerIndex, AssetType type, String srcPath) async {
    print('_addAssetToLayer: type=$type, srcPath=$srcPath');

    // Verify file exists
    final file = File(srcPath);
    if (!await file.exists()) {
      print('ERROR: File does not exist: $srcPath');
      return;
    }

    // Copy file to persistent location to avoid iOS temporary file cleanup
    String persistentPath = await _copyToPersistentLocation(srcPath, type);
    print('File copied to persistent location: $persistentPath');

    // Verify asset type matches file extension
    final extension = srcPath.toLowerCase().split('.').last;
    if (type == AssetType.image) {
      final imageExtensions = [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
        'webp',
        'svg',
        'heic',
      ];
      if (!imageExtensions.contains(extension)) {
        print(
          'WARNING: Image asset has non-image extension: $srcPath (extension: $extension)',
        );
      }
    } else if (type == AssetType.video) {
      final videoExtensions = [
        'mp4',
        'mov',
        'avi',
        'mkv',
        'wmv',
        'flv',
        '3gp',
        'm4v',
      ];
      if (!videoExtensions.contains(extension)) {
        print(
          'WARNING: Video asset has non-video extension: $srcPath (extension: $extension)',
        );
      }
    } else if (type == AssetType.audio) {
      final audioExtensions = [
        'mp3',
        'wav',
        'aac',
        'm4a',
        'ogg',
        'flac',
        'wma',
      ];
      if (!audioExtensions.contains(extension)) {
        print(
          'WARNING: Audio asset has non-audio extension: $srcPath (extension: $extension)',
        );
      }
    }

    int assetDuration;
    if (type == AssetType.video || type == AssetType.audio) {
      assetDuration = await generator.getVideoDuration(persistentPath);
    } else {
      assetDuration = 5000;
    }

    layers[layerIndex].assets.add(
      Asset(
        type: type,
        srcPath: persistentPath, // Use persistent path instead of original
        title: p.basename(srcPath),
        duration: assetDuration,
        begin:
            layerIndex ==
                2 // Audio assets start at current playhead position
            ? position
            : layers[layerIndex].assets.isEmpty
            ? 0
            : layers[layerIndex].assets.last.begin +
                  layers[layerIndex].assets.last.duration,
        originalDuration:
            assetDuration, // Store original duration for constraints
      ),
    );

    // layerPlayers[layerIndex]?.addMediaSource(
    //   layers[layerIndex].assets.length - 1,
    //   layers[layerIndex].assets.last,
    // );

    _layersChanged.add(true);
    _appBar.add(true);
  }

  /// Copy file from temporary location to persistent app documents directory
  Future<String> _copyToPersistentLocation(
    String srcPath,
    AssetType type,
  ) async {
    try {
      // Get app documents directory
      final appDocDir = await getApplicationDocumentsDirectory();

      // Create subdirectory based on asset type
      final subdirName = type == AssetType.image
          ? 'images'
          : type == AssetType.audio
          ? 'audio'
          : 'videos';
      final targetDir = Directory(p.join(appDocDir.path, 'media', subdirName));
      await targetDir.create(recursive: true);

      // Generate unique filename to avoid conflicts
      final originalFile = File(srcPath);
      final fileName = p.basename(srcPath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(fileName);
      final baseName = p.basenameWithoutExtension(fileName);
      final uniqueFileName = '${baseName}_$timestamp$extension';

      // Create target file path
      final targetPath = p.join(targetDir.path, uniqueFileName);

      // Copy file
      await originalFile.copy(targetPath);

      print('File copied from $srcPath to $targetPath');
      return targetPath;
    } catch (e) {
      print('ERROR copying file: $e');
      // Return original path as fallback
      return srcPath;
    }
  }

  select(int layerIndex, int assetIndex) async {
    if (isOperating) return;
    if (layerIndex == 1 && layers[layerIndex].assets[assetIndex].title == '') {
      _selected.add(Selected(-1, -1));
    } else {
      _selected.add(Selected(layerIndex, assetIndex));
    }
    _appBar.add(true);
  }

  dragStart(layerIndex, assetIndex) {
    if (isOperating) return;
    if (layerIndex == 1 && layers[layerIndex].assets[assetIndex].title == '')
      return;
    isDragging = true;
    Selected sel = Selected(layerIndex, assetIndex);
    sel.initScrollOffset = scrollController.offset;
    _selected.add(sel);
    _appBar.add(true);
  }

  dragSelected(
    int layerIndex,
    int assetIndex,
    double dragX,
    double scrollWidth,
  ) {
    if (layerIndex == 1 && layers[layerIndex].assets[assetIndex].title == '')
      return;
    Asset assetSelected = layers[layerIndex].assets[assetIndex];
    int closest = assetIndex;
    int pos =
        assetSelected.begin +
        ((dragX + scrollController.offset - selected.initScrollOffset) /
                pixelsPerSecond *
                1000)
            .floor();
    if (dragX + scrollController.offset - selected.initScrollOffset < 0) {
      closest = getClosestAssetIndexLeft(layerIndex, assetIndex, pos);
    } else {
      pos = pos + assetSelected.duration;
      closest = getClosestAssetIndexRight(layerIndex, assetIndex, pos);
    }
    updateScrollOnDrag(pos, scrollWidth);
    Selected sel = Selected(
      layerIndex,
      assetIndex,
      dragX: dragX,
      closestAsset: closest,
      initScrollOffset: selected.initScrollOffset,
      incrScrollOffset: scrollController.offset - selected.initScrollOffset,
    );
    _selected.add(sel);
  }

  updateScrollOnDrag(int pos, double scrollWidth) {
    double outOfScrollRight =
        pos * pixelsPerSecond / 1000 -
        scrollController.offset -
        scrollWidth / 2;
    double outOfScrollLeft =
        scrollController.offset -
        pos * pixelsPerSecond / 1000 -
        scrollWidth / 2 +
        32; // Layer header width: 32
    if (outOfScrollRight > 0 && outOfScrollLeft < 0) {
      scrollController.animateTo(
        scrollController.offset + math.min(outOfScrollRight, 50),
        duration: Duration(milliseconds: 100),
        curve: Curves.linear,
      );
    }
    if (outOfScrollRight < 0 && outOfScrollLeft > 0) {
      scrollController.animateTo(
        scrollController.offset - math.min(outOfScrollLeft, 50),
        duration: Duration(milliseconds: 100),
        curve: Curves.linear,
      );
    }
  }

  int getClosestAssetIndexLeft(int layerIndex, int assetIndex, int pos) {
    int closest = assetIndex;
    int distance = (pos - layers[layerIndex].assets[assetIndex].begin).abs();
    if (assetIndex < 1) return assetIndex;
    for (int i = assetIndex - 1; i >= 0; i--) {
      int d = (pos - layers[layerIndex].assets[i].begin).abs();
      if (d < distance) {
        closest = i;
        distance = d;
      }
    }
    return closest;
  }

  int getClosestAssetIndexRight(int layerIndex, int assetIndex, int pos) {
    int closest = assetIndex;
    int endAsset =
        layers[layerIndex].assets[assetIndex].begin +
        layers[layerIndex].assets[assetIndex].duration;
    int distance = (pos - endAsset).abs();
    if (assetIndex >= layers[layerIndex].assets.length - 1) return assetIndex;
    for (int i = assetIndex + 1; i < layers[layerIndex].assets.length; i++) {
      int end =
          layers[layerIndex].assets[i].begin +
          layers[layerIndex].assets[i].duration;
      int d = (pos - end).abs();
      if (d < distance) {
        closest = i;
        distance = d;
      }
    }
    return closest;
  }

  dragEnd() async {
    if (selected.layerIndex == 1) {
      moveTextAsset();
    } else if (selected.layerIndex == 2) {
      await moveAudioAsset();
    } else {
      await exchange();
    }
    isDragging = false;
    _appBar.add(true);
  }

  exchange() async {
    int layerIndex = selected.layerIndex;
    int assetIndex1 = selected.assetIndex;
    int assetIndex2 = selected.closestAsset;
    // Reset selected before
    _selected.add(Selected(-1, -1));

    if (layerIndex == -1 ||
        assetIndex1 == -1 ||
        assetIndex2 == -1 ||
        assetIndex1 == assetIndex2)
      return;

    Asset asset1 = layers[layerIndex].assets[assetIndex1];

    layers[layerIndex].assets.removeAt(assetIndex1);
    // await layerPlayers[layerIndex]?.removeMediaSource(assetIndex1);

    layers[layerIndex].assets.insert(assetIndex2, asset1);
    // await layerPlayers[layerIndex]?.addMediaSource(assetIndex2, asset1);

    refreshCalculatedFieldsInAssets(layerIndex, 0);

    // Reorganize Layer 0 assets after exchange to update timeline positions
    if (layerIndex == 0) {
      reorganizeVideoPhotoAssets(0);
    }

    _layersChanged.add(true);

    // Delayed 100 because it seems updating mediaSources is not immediate
    Future.delayed(Duration(milliseconds: 100), () async {
      await _previewOnPosition();
    });
  }

  moveTextAsset() {
    int layerIndex = selected.layerIndex;
    int assetIndex = selected.assetIndex;
    if (layerIndex == -1 || assetIndex == -1 || assetSelected == null) return;

    int pos =
        assetSelected!.begin +
        ((selected.dragX +
                    scrollController.offset -
                    selected.initScrollOffset) /
                pixelsPerSecond *
                1000)
            .floor();

    // Reset selected before
    _selected.add(Selected(-1, -1));

    layers[layerIndex].assets[assetIndex].begin = math.max(pos, 0);
    reorganizeTextAssets(layerIndex);
    _layersChanged.add(true);
    _previewOnPosition();
  }

  moveAudioAsset() async {
    int layerIndex = selected.layerIndex;
    int assetIndex = selected.assetIndex;
    if (layerIndex == -1 || assetIndex == -1 || assetSelected == null) return;

    int pos =
        assetSelected!.begin +
        ((selected.dragX +
                    scrollController.offset -
                    selected.initScrollOffset) /
                pixelsPerSecond *
                1000)
            .floor();

    // Reset selected before
    _selected.add(Selected(-1, -1));

    layers[layerIndex].assets[assetIndex].begin = math.max(pos, 0);
    // Audio assets can be positioned freely like text assets, no reorganization needed
    _layersChanged.add(true);

    // Refresh audio player to handle position changes
    await _refreshAudioPlayer(layerIndex);

    _previewOnPosition();
  }

  /// Cuts the currently selected video asset at the current playhead position.
  cutVideo() async {
    if (isOperating) return;

    /// This is a safeguard to prevent cutting when no asset is selected
    if (selected.layerIndex == -1 || selected.assetIndex == -1) return;

    /// Get the currently selected asset
    final Asset assetAfter =
        layers[selected.layerIndex].assets[selected.assetIndex];

    /// Calculates how far into the asset the cut position is
    /// [Position]: Current timeline playhead position (in ms)
    /// [AssetAfter.begin]: Where the asset begins on the timeline (in ms)
    final int diff = position - assetAfter.begin;
    if (diff <= 0 || diff >= assetAfter.duration) return;
    isCutting = true;

    /// Create an exact copy of the original asset
    final Asset assetBefore = Asset.clone(assetAfter);
    layers[selected.layerIndex].assets.insert(selected.assetIndex, assetBefore);

    /// For the first asset
    /// Duration becomes the time from asset start to cut position
    assetBefore.duration = diff;

    /// For the second asset
    /// [begin]: Timeline position shifts forward by diff milliseconds
    /// [cutFrom]: Source media starting point shifts forward (skips the first part)
    /// [duration]: Shortened by removing the first part
    assetAfter.begin = assetBefore.begin + diff;
    assetAfter.cutFrom = assetBefore.cutFrom + diff;
    assetAfter.duration = assetAfter.duration - diff;

    /// Media Source Updates

    /// 1. Remove the original media source at the selected asset index
    // layerPlayers[selected.layerIndex]?.removeMediaSource(selected.assetIndex);

    /// 2. Add the new media source for the asset before the cut
    // await layerPlayers[selected.layerIndex]?.addMediaSource(
    //   selected.assetIndex,
    //   assetBefore,
    // );

    /// 3. Add the new media source for the asset after the cut
    // await layerPlayers[selected.layerIndex]?.addMediaSource(
    //   selected.assetIndex + 1,
    //   assetAfter,
    // );

    /// Trigger UI refresh
    _layersChanged.add(true);

    if (assetAfter.type == AssetType.video) {
      assetAfter.thumbnailPath = null;
      _generateAllVideoThumbnails(layers[selected.layerIndex].assets);
    }

    /// Clears selection
    _selected.add(Selected(-1, -1));
    _appBar.add(true);

    // Delayed blocking 300 because it seems updating mediaSources is not immediate
    // because preview can fail
    Future.delayed(Duration(milliseconds: 300), () {
      isCutting = false;
    });
  }

  /// Removes the currently selected asset from the timeline.
  ///
  /// Handles cleanup of timeline positions for non-text assets and
  /// reorganizes text assets to maintain proper spacing and alignment.
  delete() {
    if (isOperating) return;
    if (selected.layerIndex == -1 ||
        selected.assetIndex == -1 ||
        assetSelected == null)
      return;
    print('>> DirectorService.delete()');
    isDeleting = true;
    AssetType type = assetSelected!.type;
    layers[selected.layerIndex].assets.removeAt(selected.assetIndex);
    // layerPlayers[selected.layerIndex]?.removeMediaSource(selected.assetIndex);
    if (type != AssetType.text) {
      refreshCalculatedFieldsInAssets(selected.layerIndex, selected.assetIndex);
    }
    _layersChanged.add(true);

    _selected.add(Selected(-1, -1));

    _filesNotExist.add(checkSomeFileNotExists());
    reorganizeTextAssets(1);

    // Reorganize Layer 0 if video/photo asset was deleted
    if (selected.layerIndex == 0) {
      reorganizeVideoPhotoAssets(0);
    }

    isDeleting = false;

    if (position > duration) {
      _position.add(duration);
      scrollController.jumpTo(duration / 1000 * pixelsPerSecond);
    }
    _layersChanged.add(true);
    _appBar.add(true);

    // Allow time for layer updates to complete before preview
    Future.delayed(Duration(milliseconds: 100), () {
      _previewOnPosition();
    });
  }

  refreshCalculatedFieldsInAssets(int layerIndex, int assetIndex) {
    for (int i = assetIndex; i < layers[layerIndex].assets.length; i++) {
      layers[layerIndex].assets[i].begin = (i == 0)
          ? 0
          : layers[layerIndex].assets[i - 1].begin +
                layers[layerIndex].assets[i - 1].duration;
    }
  }

  scaleStart() {
    if (isOperating) return;
    isScaling = true;
    _selected.add(Selected(-1, -1));
    _pixelsPerSecondOnInitScale = pixelsPerSecond;
    _scrollOffsetOnInitScale = scrollController.offset;
  }

  scaleUpdate(double scale) {
    if (!isScaling ||
        _pixelsPerSecondOnInitScale == null ||
        _scrollOffsetOnInitScale == null)
      return;
    double pixPerSecond = _pixelsPerSecondOnInitScale! * scale;
    pixPerSecond = math.min(pixPerSecond, 100);
    pixPerSecond = math.max(pixPerSecond, 1);
    _pixelsPerSecond.add(pixPerSecond);
    _layersChanged.add(true);
    scrollController.jumpTo(
      _scrollOffsetOnInitScale! * pixPerSecond / _pixelsPerSecondOnInitScale!,
    );
  }

  scaleEnd() {
    isScaling = false;
    _layersChanged.add(true);
  }

  Asset? getAssetByPosition(int layerIndex) {
    for (int i = 0; i < layers[layerIndex].assets.length; i++) {
      if (layers[layerIndex].assets[i].begin +
              layers[layerIndex].assets[i].duration -
              1 >=
          position) {
        return layers[layerIndex].assets[i];
      }
    }
    return null;
  }

  sizerDragStart(bool sizerEnd) {
    if (isOperating) return;
    isSizerDragging = true;
    isSizerDraggingEnd = sizerEnd;
    dxSizerDrag = 0;
  }

  sizerDragUpdate(bool sizerEnd, double dx) {
    dxSizerDrag += dx;
    _selected.add(selected); // To refresh UI
  }

  sizerDragEnd(bool sizerEnd) async {
    await executeSizer(sizerEnd);
    _selected.add(selected); // To refresh UI
    dxSizerDrag = 0;
    isSizerDragging = false;
  }

  /// Refreshes the video player for a specific layer to handle cutFrom changes
  _refreshVideoPlayer(int layerIndex) async {
    if (layerPlayers[layerIndex] != null) {
      // Re-initialize the layer player to handle new cutFrom values
      layerPlayers[layerIndex]?.dispose();
      layerPlayers[layerIndex] = LayerPlayer(layers[layerIndex]);
      await layerPlayers[layerIndex]?.initialize();

      // Refresh current position
      await _previewOnPosition();
    }
  }

  /// Refreshes the audio player for a specific layer to handle cutFrom changes
  _refreshAudioPlayer(int layerIndex) async {
    if (layerPlayers[layerIndex] != null) {
      // Re-initialize the layer player to handle new cutFrom values
      layerPlayers[layerIndex]?.dispose();
      layerPlayers[layerIndex] = LayerPlayer(layers[layerIndex]);
      await layerPlayers[layerIndex]?.initialize();

      // Refresh current position
      await _previewOnPosition();
    }
  }

  clipperDragStart(bool clipperEnd) {
    if (isOperating) return;
    isClipperDragging = true;
    isClipperDraggingEnd = clipperEnd;
    dxClipperDrag = 0;
  }

  clipperDragUpdate(bool clipperEnd, double dx) {
    dxClipperDrag += dx;
    _selected.add(selected); // To refresh UI
  }

  clipperDragEnd(bool clipperEnd) async {
    await executeClipper(clipperEnd);
    _selected.add(selected); // To refresh UI
    dxClipperDrag = 0;
    isClipperDragging = false;
  }

  executeClipper(bool clipperEnd) async {
    if (assetSelected == null) return;
    var asset = assetSelected!;
    if (asset.type == AssetType.video ||
        asset.type == AssetType.image ||
        asset.type == AssetType.audio) {
      int dxClipperDragMillis = (dxClipperDrag / pixelsPerSecond * 1000)
          .floor();
      if (!isClipperDraggingEnd) {
        // Front clipping: adjust cutFrom and duration, but keep begin position
        if (asset.duration - dxClipperDragMillis < 1000) {
          dxClipperDragMillis = asset.duration - 1000;
        }
        // For video and audio assets, increase cutFrom (clip from start)
        if (asset.type == AssetType.video || asset.type == AssetType.audio) {
          asset.cutFrom += dxClipperDragMillis;
          if (asset.cutFrom < 0) asset.cutFrom = 0;
        }
        // Only reduce duration, DON'T change begin position for front clipping
        asset.duration -= dxClipperDragMillis;
      } else {
        // End clipping: adjust duration only
        if (asset.duration + dxClipperDragMillis < 1000) {
          dxClipperDragMillis = -asset.duration + 1000;
        }

        // For video and audio assets, enforce original duration constraint
        if ((asset.type == AssetType.video || asset.type == AssetType.audio) &&
            asset.originalDuration != null) {
          int maxDuration = asset.originalDuration! - asset.cutFrom;
          if (asset.duration + dxClipperDragMillis > maxDuration) {
            dxClipperDragMillis = maxDuration - asset.duration;
          }
        }

        asset.duration += dxClipperDragMillis;
      }

      // Reorganize Layer 0 assets if duration changed (videos/images)
      if (asset.type == AssetType.video || asset.type == AssetType.image) {
        reorganizeVideoPhotoAssets(0);

        // Refresh video player if cutFrom changed (front clipping)
        if (asset.type == AssetType.video && !isClipperDraggingEnd) {
          await _refreshVideoPlayer(0);
        }
      }

      // Refresh audio player if cutFrom changed (front clipping)
      if (asset.type == AssetType.audio && !isClipperDraggingEnd) {
        await _refreshAudioPlayer(2);
      }

      // Force UI refresh for real-time updates
      _layersChanged.add(true); // Show timeline changes
    }

    // Always trigger selected stream update for UI refresh
    _selected.add(selected);
  }

  executeSizer(bool sizerEnd) async {
    if (assetSelected == null) return;
    var asset = assetSelected!;
    if (asset.type == AssetType.text || asset.type == AssetType.image) {
      int dxSizerDragMillis = (dxSizerDrag / pixelsPerSecond * 1000).floor();
      if (!isSizerDraggingEnd) {
        if (asset.begin + dxSizerDragMillis < 0) {
          dxSizerDragMillis = -asset.begin;
        }
        if (asset.duration - dxSizerDragMillis < 1000) {
          dxSizerDragMillis = asset.duration - 1000;
        }
        asset.begin += dxSizerDragMillis;
        asset.duration -= dxSizerDragMillis;
      } else {
        if (asset.duration + dxSizerDragMillis < 1000) {
          dxSizerDragMillis = -asset.duration + 1000;
        }
        // Text and image assets can extend beyond original duration (no constraint)
        asset.duration += dxSizerDragMillis;
      }
      if (asset.type == AssetType.text) {
        reorganizeTextAssets(1);
      } else if (asset.type == AssetType.image) {
        // Reorganize Layer 0 assets if image duration changed
        reorganizeVideoPhotoAssets(0);
      }
    }

    // Force UI refresh for real-time updates
    _layersChanged.add(true); // Show timeline changes

    // Always trigger selected stream update for UI refresh
    _selected.add(selected);
  }

  generateVideo(List<Layer> layers, VideoResolution videoResolution) async {
    // if (isOperating) return;
    isGenerating = true;
    try {
      final outputPath = await generator.generateVideoAll(
        layers,
        videoResolution,
      );

      // If video generation was successful and we have a valid path, save to database
      if (outputPath != null &&
          File(outputPath).existsSync() &&
          project != null) {
        final generatedVideo = GeneratedVideo(
          projectId: project!.id!,
          path: outputPath,
          date: DateTime.now(),
          resolution: generator.videoResolutionString(videoResolution),
          thumbnail:
              getFirstThumbnailMedPath(), // Use existing thumbnail from project
        );

        await projectDao.insertGeneratedVideo(generatedVideo);
        logger.i('Generated video saved to database: $outputPath');
      }
    } catch (e) {
      logger.e('Error generating video: $e');
    } finally {
      isGenerating = false;
      _layersChanged.add(true);
    }
  }

  /// Volume Control System
  ///
  /// Provides hierarchical volume control with asset-level overrides taking
  /// precedence over layer-level defaults. Updates are applied immediately
  /// to active playback instances.

  /// Updates the volume level for a specific asset
  ///
  /// [layerIndex] - The index of the layer containing the asset
  /// [assetIndex] - The index of the asset within the layer
  /// [volume] - The volume level (0.0 to 1.0)
  void updateAssetVolume(int layerIndex, int assetIndex, double volume) {
    if (layerIndex < 0 || layerIndex >= layers.length) return;
    if (assetIndex < 0 || assetIndex >= layers[layerIndex].assets.length) {
      return;
    }

    Asset asset = layers[layerIndex].assets[assetIndex];
    asset.volume = volume;

    // Update the current playing asset volume if it's the same asset
    if (layerPlayers.isNotEmpty &&
        layerPlayers[layerIndex] != null &&
        layerPlayers[layerIndex]!.currentAssetIndex == assetIndex) {
      // Apply volume to video controller if it's a video asset
      if (asset.type == AssetType.video &&
          layerPlayers[layerIndex]!.videoController != null) {
        layerPlayers[layerIndex]!.videoController!.setVolume(volume);
      }
      // Apply volume to audio player if it's an audio asset
      else if (asset.type == AssetType.audio &&
          layerPlayers[layerIndex]!.audioPlayer != null) {
        layerPlayers[layerIndex]!.audioPlayer!.setVolume(volume);
      }
    }

    _layersChanged.add(true);
    _saveProject();
  }

  /// Gets the effective volume for an asset (asset volume or layer volume fallback)
  double getEffectiveAssetVolume(int layerIndex, int assetIndex) {
    if (layerIndex < 0 || layerIndex >= layers.length) return 1.0;
    if (assetIndex < 0 || assetIndex >= layers[layerIndex].assets.length) {
      return 1.0;
    }

    Asset asset = layers[layerIndex].assets[assetIndex];

    // Return asset volume if set, otherwise use layer volume, otherwise default to 1.0
    // Apply same clamping as used in LayerPlayer and Generator for consistency
    double baseVolume = asset.volume ?? layers[layerIndex].volume ?? 1.0;
    return baseVolume.clamp(0.0, 1.0);
  }

  // _deleteThumbnailsNotUsed() async {
  //   // TODO: pending to implement
  //   Directory appDocDir = await getApplicationDocumentsDirectory();
  //   Directory fontsDir = Directory(p.join(appDocDir.parent.path, 'code_cache'));

  //   List<FileSystemEntity> entityList = fontsDir.listSync(
  //     recursive: true,
  //     followLinks: false,
  //   );
  //   for (FileSystemEntity entity in entityList) {
  //     if (!await FileSystemEntity.isFile(entity.path) &&
  //         entity.path.split('/').last.startsWith('open_director')) {}
  //     //print(entity.path);
  //   }
  // }
}
