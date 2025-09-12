import 'dart:io';
import 'dart:async';
import 'package:flutter_video_editor_app/model/model.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

/// Manages playback of individual timeline layers containing video, audio, or image assets.
/// Handles precise timing, volume control, and trimming boundaries for each asset type.
/// Uses stream-based monitoring for reliable audio timing and ClippingAudioSource for boundary enforcement.
class LayerPlayer {
  Layer layer;
  int currentAssetIndex = -1;

  int _newPosition = 0;
  Timer? _imageTimer;
  int? _lastVideoPosition; // For position stagnation detection

  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  // Audio player for audio assets
  AudioPlayer? _audioPlayer;
  AudioPlayer? get audioPlayer => _audioPlayer;

  // Subscriptions for audio streams
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<ProcessingState>? _audioStateSubscription;

  // Track the current video file path to manage video controller reuse
  String? _currentVideoPath;

  void Function(int)? _onMove;
  void Function()? _onJump;
  void Function()? _onEnd;

  LayerPlayer(this.layer);

  /// Calculates the effective volume for an asset, considering asset-level and layer-level volume settings.
  ///
  /// Priority: asset.volume > layer.volume > 1.0 (default)
  /// Returns a clamped value between 0.0 and 1.0
  double _getEffectiveVolume(Asset asset) {
    double baseVolume = asset.volume ?? layer.volume ?? 1.0;
    return baseVolume.clamp(0.0, 1.0);
  }

  /// Initializes the layer player with the first asset if available
  Future<void> initialize() async {
    if (layer.assets.isNotEmpty) {
      await _initializeForAsset(0);
    }
  }

  /// Initializes the appropriate media player for a specific asset
  ///
  /// For audio assets: Creates a new AudioPlayer with ClippingAudioSource to respect asset trimming
  /// For video assets: Reuses existing VideoPlayerController if same source file, otherwise creates new one
  Future<void> _initializeForAsset(int assetIndex) async {
    if (assetIndex < 0 || assetIndex >= layer.assets.length) return;

    final asset = layer.assets[assetIndex];

    if (asset.type == AssetType.audio && !asset.deleted) {
      // Always dispose existing audio player to ensure clean state for trimmed segments
      if (_audioPlayer != null) {
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }

      try {
        final file = File(asset.srcPath);
        if (!await file.exists()) {
          print('Audio file does not exist: ${asset.srcPath}');
          return;
        }

        final extension = asset.srcPath.toLowerCase().split('.').last;
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
            'File does not have audio extension: ${asset.srcPath} (extension: $extension)',
          );
          return;
        }

        _audioPlayer = AudioPlayer();
        // Use ClippingAudioSource to automatically handle trimmed audio boundaries
        await _audioPlayer!.setAudioSource(
          ClippingAudioSource(
            child: ProgressiveAudioSource(Uri.file(asset.srcPath)),
            start: Duration(milliseconds: asset.cutFrom),
            end: Duration(milliseconds: asset.cutFrom + asset.duration),
          ),
        );
        print(
          'Audio player initialized with clip for ${asset.srcPath} (start: ${asset.cutFrom}, duration: ${asset.duration})',
        );
      } catch (e) {
        print('Error initializing audio controller for ${asset.srcPath}: $e');
        _audioPlayer = null;
      }
      return;
    }

    // Initialize video controller, reusing existing controller for same source file
    if (asset.type == AssetType.video && !asset.deleted) {
      bool needNewVideoController =
          _videoController == null || _currentVideoPath != asset.srcPath;

      if (_videoController != null && _currentVideoPath != asset.srcPath) {
        print('Disposing existing video controller for different video file');
        await _videoController!.dispose();
        _videoController = null;
        needNewVideoController = true;
      }

      if (needNewVideoController) {
        try {
          final file = File(asset.srcPath);
          if (!await file.exists()) {
            print('Video file does not exist: ${asset.srcPath}');
            return;
          }

          final extension = asset.srcPath.toLowerCase().split('.').last;
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
              'File does not have video extension: ${asset.srcPath} (extension: $extension)',
            );
            return;
          }

          _videoController = VideoPlayerController.file(
            file,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await _videoController!.initialize();
          _currentVideoPath = asset.srcPath;
        } catch (e) {
          print('Error initializing video controller for ${asset.srcPath}: $e');
          _videoController = null;
          _currentVideoPath = null;
        }
      }
    }
  }

  Future<void> preview(int pos) async {
    currentAssetIndex = getAssetByPosition(pos);
    if (currentAssetIndex == -1) return;

    final asset = layer.assets[currentAssetIndex];

    if (asset.type == AssetType.image) return;

    await _initializeForAsset(currentAssetIndex);

    if (asset.type == AssetType.audio) {
      if (_audioPlayer == null) return;

      _newPosition = pos - asset.begin;
      await Future.delayed(Duration(milliseconds: 50));
      final volume = _getEffectiveVolume(asset);
      await _audioPlayer!.setVolume(volume);
      print(
        'preview() audio: Setting volume to $volume for asset $currentAssetIndex',
      );

      final seekPosition = Duration(
        milliseconds: _newPosition,
      ); // Relative to clip
      await _audioPlayer!.seek(seekPosition);
      return;
    }

    if (asset.type == AssetType.video) {
      if (_videoController == null) return;

      if (!_videoController!.value.isInitialized) {
        try {
          await _videoController!.initialize();
        } catch (e) {
          print('Failed to initialize video controller: $e');
          return;
        }
      }

      _newPosition = pos - asset.begin;
      await _videoController!.setVolume(0.0);

      final seekPosition = Duration(milliseconds: asset.cutFrom + _newPosition);
      try {
        await _videoController!.seekTo(seekPosition);
        await _videoController!.play();
        await _videoController!.pause();
      } catch (e) {
        print('Error during video preview operations: $e');
      }
    }
  }

  Future<void> play(
    int pos, {
    void Function(int)? onMove,
    void Function()? onJump,
    void Function()? onEnd,
  }) async {
    _onMove = onMove;
    _onJump = onJump;
    _onEnd = onEnd;

    currentAssetIndex = getAssetByPosition(pos);
    if (currentAssetIndex == -1) return;

    final asset = layer.assets[currentAssetIndex];

    if (asset.type == AssetType.image) {
      _startImagePlayback(pos, asset);
      return;
    }

    await _initializeForAsset(currentAssetIndex);

    if (asset.type == AssetType.audio) {
      if (_audioPlayer == null) return;

      await Future.delayed(Duration(milliseconds: 50));
      final volume = _getEffectiveVolume(asset);
      await _audioPlayer!.setVolume(volume);
      print(
        'play() audio: Setting volume to $volume for current asset $currentAssetIndex',
      );

      _newPosition = pos - asset.begin;
      if (_newPosition >= asset.duration) {
        print('Warning: Attempted to play beyond audio asset duration');
        return;
      }

      final seekPosition = Duration(
        milliseconds: _newPosition,
      ); // Relative to clip
      await _audioPlayer!.seek(seekPosition);
      await _audioPlayer!.play();
      _startAudioPlayback();
      return;
    }

    if (asset.type == AssetType.video) {
      if (_videoController == null) return;

      await _videoController!.setVolume(_getEffectiveVolume(asset));
      _newPosition = pos - asset.begin;

      if (_newPosition >= asset.duration) {
        print('Warning: Attempted to play beyond video asset duration');
        return;
      }

      final seekPosition = Duration(milliseconds: asset.cutFrom + _newPosition);
      await _videoController!.seekTo(seekPosition);
      await _videoController!.play();
      _videoController!.addListener(_videoListener);
    }
  }

  void _startImagePlayback(int startPos, Asset asset) {
    // Remains the same
    _newPosition = startPos;
    const int frameRate = 30;
    const int updateInterval = 1000 ~/ frameRate;

    _imageTimer = Timer.periodic(Duration(milliseconds: updateInterval), (
      timer,
    ) {
      _newPosition += updateInterval;

      if (_onMove != null) _onMove!(_newPosition);

      if (_newPosition >= asset.begin + asset.duration) {
        timer.cancel();
        _imageTimer = null;

        int nextAssetIndex = currentAssetIndex + 1;
        if (nextAssetIndex < layer.assets.length) {
          currentAssetIndex = nextAssetIndex;
          final nextAsset = layer.assets[nextAssetIndex];
          print(
            'Image finished, moving to next asset: $nextAssetIndex, type: ${nextAsset.type}',
          );

          if (nextAsset.type == AssetType.image) {
            _startImagePlayback(nextAsset.begin, nextAsset);
          } else if (nextAsset.type == AssetType.video) {
            _playVideoAsset(nextAsset.begin, nextAssetIndex);
          } else if (nextAsset.type == AssetType.audio) {
            _playAudioAsset(nextAsset.begin, nextAssetIndex);
          }

          if (_onJump != null) _onJump!();
        } else {
          currentAssetIndex = -1;
          if (_onJump != null) _onJump!();
          if (_onEnd != null) _onEnd!();
        }
      }
    });
  }

  /// Starts audio playback with stream-based monitoring for precise timing control.
  /// Uses position and processing state streams to ensure proper trimming boundaries.
  void _startAudioPlayback() {
    if (_audioPlayer == null) return;

    // Cancel any existing subscriptions to prevent memory leaks
    _audioPositionSubscription?.cancel();
    _audioStateSubscription?.cancel();

    _audioPositionSubscription = _audioPlayer!.positionStream.listen((
      currentPosition,
    ) {
      final asset = layer.assets[currentAssetIndex];

      // Timeline position (clip-relative position)
      final timelinePosition = asset.begin + currentPosition.inMilliseconds;
      _newPosition = timelinePosition;

      if (_onMove != null) _onMove!(timelinePosition);

      // End check with tolerance (backup to completed state)
      if (currentPosition.inMilliseconds >= asset.duration - 50) {
        // 50ms tolerance
        print(
          'Audio position reached end: ${currentPosition.inMilliseconds} >= ${asset.duration}',
        );
        _handleAudioEnd();
      }
    });

    _audioStateSubscription = _audioPlayer!.processingStateStream.listen((
      state,
    ) {
      if (state == ProcessingState.completed) {
        print('Audio completed - proceeding to next');
        _handleAudioEnd();
      }
    });
  }

  /// Handles end of audio playback, cleaning up resources and transitioning to next asset.
  /// Called when audio reaches trimmed duration or processing completes.
  void _handleAudioEnd() {
    _audioPlayer?.stop();
    _audioPositionSubscription?.cancel();
    _audioStateSubscription?.cancel();

    int nextAssetIndex = currentAssetIndex + 1;
    if (nextAssetIndex < layer.assets.length) {
      currentAssetIndex = nextAssetIndex;
      final nextAsset = layer.assets[nextAssetIndex];
      print(
        'Audio finished, moving to next asset: $nextAssetIndex, type: ${nextAsset.type}',
      );

      if (nextAsset.type == AssetType.audio) {
        _playAudioAsset(nextAsset.begin, nextAssetIndex);
      } else if (nextAsset.type == AssetType.video) {
        _playVideoAsset(nextAsset.begin, nextAssetIndex);
      } else if (nextAsset.type == AssetType.image) {
        _startImagePlayback(nextAsset.begin, nextAsset);
      }

      if (_onJump != null) _onJump!();
    } else {
      currentAssetIndex = -1;
      if (_onJump != null) _onJump!();
      if (_onEnd != null) _onEnd!();
    }
  }

  /// Plays an audio asset from specified timeline position with proper volume and trimming.
  /// Initializes ClippingAudioSource for precise boundary control.
  Future<void> _playAudioAsset(int startPos, int assetIndex) async {
    await _initializeForAsset(assetIndex);
    if (_audioPlayer != null) {
      final asset = layer.assets[assetIndex];
      final volume = _getEffectiveVolume(asset);
      await Future.delayed(Duration(milliseconds: 50));
      await _audioPlayer!.setVolume(volume);

      _newPosition = startPos - asset.begin;
      if (_newPosition >= asset.duration) {
        print('Warning: Attempted to play audio beyond asset duration');
        return;
      }

      final seekPosition = Duration(
        milliseconds: _newPosition,
      ); // Relative to clip
      await _audioPlayer!.seek(seekPosition);
      await _audioPlayer!.play();
      _startAudioPlayback();
    }
  }

  /// Plays a video asset from specified timeline position with volume control.
  /// Seeks to trimmed position within the source file.
  Future<void> _playVideoAsset(int startPos, int assetIndex) async {
    await _initializeForAsset(assetIndex);
    if (_videoController != null) {
      final asset = layer.assets[assetIndex];
      await _videoController!.setVolume(_getEffectiveVolume(asset));
      _newPosition = startPos;

      final relativePos = startPos - asset.begin;
      if (relativePos >= asset.duration) {
        print(
          'Warning: Attempted to play beyond asset duration in _playVideoAsset',
        );
        return;
      }

      final seekPosition = Duration(milliseconds: asset.cutFrom + relativePos);
      await _videoController!.seekTo(seekPosition);
      await _videoController!.play();
      _videoController!.addListener(_videoListener);
    }
  }

  int getAssetByPosition(int? pos) {
    if (pos == null) return -1;
    for (int i = 0; i < layer.assets.length; i++) {
      int assetEnd = layer.assets[i].begin + layer.assets[i].duration - 1;
      if (layer.assets[i].begin <= pos && assetEnd >= pos) {
        return i;
      }
    }
    return -1;
  }

  void _videoListener() async {
    // Remains the same
    if (_videoController == null || currentAssetIndex == -1) return;

    final asset = layer.assets[currentAssetIndex];
    final videoPosition = _videoController!.value.position.inMilliseconds;

    _newPosition = (videoPosition - asset.cutFrom) + asset.begin;

    if (_onMove != null) _onMove!(_newPosition);

    final assetDuration = asset.duration;
    final relativePosition = videoPosition - asset.cutFrom;
    final playerValue = _videoController!.value;

    bool durationBasedEnd = relativePosition >= (assetDuration - 100);
    bool playerBasedEnd = !playerValue.isPlaying && !playerValue.isBuffering;
    bool positionStagnant = false;
    if (_lastVideoPosition != null) {
      int positionDifference = (videoPosition - _lastVideoPosition!).abs();
      positionStagnant =
          positionDifference < 50 && relativePosition >= (assetDuration - 500);
    }
    _lastVideoPosition = videoPosition;

    bool isAtEnd =
        durationBasedEnd ||
        (playerBasedEnd && relativePosition >= (assetDuration * 0.8)) ||
        positionStagnant;

    print(
      'Video end detection for asset $currentAssetIndex: duration=$durationBasedEnd, player=$playerBasedEnd, stagnant=$positionStagnant, combined=$isAtEnd, relativePos=$relativePosition, assetDuration=$assetDuration',
    );

    if (isAtEnd) {
      _videoController!.removeListener(_videoListener);

      if (_videoController!.value.isPlaying) {
        await _videoController!.pause();
      }

      int nextAssetIndex = currentAssetIndex + 1;
      if (nextAssetIndex < layer.assets.length) {
        currentAssetIndex = nextAssetIndex;
        final nextAsset = layer.assets[nextAssetIndex];
        print('Moving to next asset: $nextAssetIndex, type: ${nextAsset.type}');

        if (nextAsset.type == AssetType.video) {
          await _initializeForAsset(nextAssetIndex);
          if (_videoController != null) {
            final volume = _getEffectiveVolume(nextAsset);
            await _videoController!.setVolume(volume);
            print(
              'Video transition: Setting volume to $volume for asset $nextAssetIndex',
            );
            _newPosition = nextAsset.begin;
            final seekPosition = Duration(milliseconds: nextAsset.cutFrom);
            await _videoController!.seekTo(seekPosition);
            await _videoController!.play();
            _videoController!.addListener(_videoListener);
          }
        } else if (nextAsset.type == AssetType.audio) {
          _playAudioAsset(nextAsset.begin, nextAssetIndex);
        } else if (nextAsset.type == AssetType.image) {
          _startImagePlayback(nextAsset.begin, nextAsset);
        }

        if (_onJump != null) _onJump!();
      } else {
        currentAssetIndex = -1;
        if (_onJump != null) _onJump!();
        if (_onEnd != null) _onEnd!();
      }
    }
  }

  Future<void> stop() async {
    if (_imageTimer != null) {
      _imageTimer!.cancel();
      _imageTimer = null;
    }

    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      await _videoController!.pause();
    }

    if (_audioPlayer != null && _audioPlayer!.playing) {
      await _audioPlayer!.stop();
    }

    // Cancel audio subscriptions
    _audioPositionSubscription?.cancel();
    _audioStateSubscription?.cancel();
  }

  Future<void> dispose() async {
    if (_imageTimer != null) {
      _imageTimer!.cancel();
      _imageTimer = null;
    }

    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
    }

    if (_audioPlayer != null) {
      await _audioPlayer!.dispose();
      _audioPlayer = null;
    }

    // Cancel audio subscriptions
    _audioPositionSubscription?.cancel();
    _audioStateSubscription?.cancel();
  }
}
