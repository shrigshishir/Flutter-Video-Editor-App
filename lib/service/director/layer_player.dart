import 'dart:io';
import 'dart:async';
import 'package:flutter_video_editor_app/model/model.dart';
import 'package:video_player/video_player.dart';

class LayerPlayer {
  Layer layer;
  int currentAssetIndex = -1;

  int _newPosition = 0;
  Timer? _imageTimer;
  int? _lastVideoPosition; // For position stagnation detection

  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  void Function(int)? _onMove;
  void Function()? _onJump;
  void Function()? _onEnd;

  LayerPlayer(this.layer);

  Future<void> initialize() async {
    // Initialize with the first video asset if available
    if (layer.assets.isNotEmpty) {
      await _initializeForAsset(0);
    }
  }

  Future<void> _initializeForAsset(int assetIndex) async {
    if (assetIndex < 0 || assetIndex >= layer.assets.length) return;

    final asset = layer.assets[assetIndex];

    // Dispose previous controller if exists
    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
    }

    // Create controller for video and audio assets
    if ((asset.type == AssetType.video || asset.type == AssetType.audio) &&
        !asset.deleted) {
      try {
        // Additional check: verify the file exists and has valid extension
        final file = File(asset.srcPath);
        if (!await file.exists()) {
          print(
            '${asset.type == AssetType.video ? 'Video' : 'Audio'} file does not exist: ${asset.srcPath}',
          );
          return;
        }

        final extension = asset.srcPath.toLowerCase().split('.').last;

        if (asset.type == AssetType.video) {
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
        } else if (asset.type == AssetType.audio) {
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
        }

        _videoController = VideoPlayerController.file(file);
        await _videoController!.initialize();
      } catch (e) {
        print(
          'Error initializing ${asset.type == AssetType.video ? 'video' : 'audio'} controller for ${asset.srcPath}: $e',
        );
        _videoController = null;
      }
    }
  }

  Future<void> preview(int pos) async {
    currentAssetIndex = getAssetByPosition(pos);
    if (currentAssetIndex == -1) return;

    final asset = layer.assets[currentAssetIndex];

    // For image assets, we only need to set the currentAssetIndex
    if (asset.type == AssetType.image) {
      return;
    }

    if (asset.type != AssetType.video && asset.type != AssetType.audio) return;

    // Initialize controller for this asset if needed
    await _initializeForAsset(currentAssetIndex);

    if (_videoController == null) return;

    _newPosition = pos - asset.begin;
    await _videoController!.setVolume(0);

    // Seek to position within the asset (considering cutFrom offset)
    final seekPosition = Duration(milliseconds: asset.cutFrom + _newPosition);
    await _videoController!.seekTo(seekPosition);
    await _videoController!.play();
    await _videoController!.pause();
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

    // For image assets, use timer-based position updates
    if (asset.type == AssetType.image) {
      _startImagePlayback(pos, asset);
      return;
    }

    if (asset.type != AssetType.video && asset.type != AssetType.audio) return;

    // Initialize controller for this asset if needed
    await _initializeForAsset(currentAssetIndex);

    if (_videoController == null) return;

    await _videoController!.setVolume(layer.volume ?? 1.0);
    _newPosition = pos - asset.begin;

    // FIXED: Ensure we don't start playing beyond the asset's duration
    if (_newPosition >= asset.duration) {
      print('Warning: Attempted to play beyond asset duration');
      return;
    }

    // Seek to position within the asset (considering cutFrom offset)
    final seekPosition = Duration(milliseconds: asset.cutFrom + _newPosition);
    await _videoController!.seekTo(seekPosition);
    await _videoController!.play();
    _videoController!.addListener(_videoListener);
  }

  void _startImagePlayback(int startPos, Asset asset) {
    _newPosition = startPos;
    const int frameRate = 30; // 30 FPS for smooth playback
    const int updateInterval = 1000 ~/ frameRate; // ~33ms per frame

    _imageTimer = Timer.periodic(Duration(milliseconds: updateInterval), (
      timer,
    ) {
      _newPosition += updateInterval;

      if (_onMove != null) {
        _onMove!(_newPosition);
      }

      // Check if we've reached the end of the current image asset
      if (_newPosition >= asset.begin + asset.duration) {
        timer.cancel();
        _imageTimer = null;

        // Check if there's a next asset
        int nextAssetIndex = currentAssetIndex + 1;
        if (nextAssetIndex < layer.assets.length) {
          currentAssetIndex = nextAssetIndex;
          final nextAsset = layer.assets[nextAssetIndex];

          print(
            'Image finished,  moving to next asset: $nextAssetIndex, type: ${nextAsset.type}',
          );

          if (nextAsset.type == AssetType.image) {
            // Continue with next image
            _startImagePlayback(nextAsset.begin, nextAsset);
          } else if (nextAsset.type == AssetType.video ||
              nextAsset.type == AssetType.audio) {
            // Switch to video/audio playback
            _playVideoAsset(nextAsset.begin, nextAssetIndex);
          }

          // Notify about position jump but don't end playback
          if (_onJump != null) {
            _onJump!();
          }
        } else {
          // End of all assets - now we can call onEnd
          currentAssetIndex = -1;
          if (_onJump != null) {
            _onJump!();
          }
          if (_onEnd != null) {
            _onEnd!();
          }
        }
      }
    });
  }

  Future<void> _playVideoAsset(int startPos, int assetIndex) async {
    await _initializeForAsset(assetIndex);
    if (_videoController != null) {
      final asset = layer.assets[assetIndex];
      await _videoController!.setVolume(layer.volume ?? 1.0);
      _newPosition = startPos;

      // FIXED: Ensure we don't start playing beyond the asset's duration
      final relativePos = startPos - asset.begin;
      if (relativePos >= asset.duration) {
        print(
          'Warning: Attempted to play beyond asset duration in _playVideoAsset',
        );
        return;
      }

      // Seek to position within the asset (considering cutFrom offset)
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
    if (_videoController == null || currentAssetIndex == -1) return;

    final asset = layer.assets[currentAssetIndex];
    final videoPosition = _videoController!.value.position.inMilliseconds;

    // Calculate the actual position in the timeline
    _newPosition = (videoPosition - asset.cutFrom) + asset.begin;

    if (_onMove != null) {
      _onMove!(_newPosition);
    }

    // Multi-method end detection for better reliability across different video types
    final assetDuration = asset.duration;
    final relativePosition = videoPosition - asset.cutFrom;
    final playerValue = _videoController!.value;

    // Method 1: Duration-based check with tolerance
    bool durationBasedEnd =
        relativePosition >= (assetDuration - 100); // 100ms tolerance

    // Method 2: Player state check - video has stopped playing naturally
    bool playerBasedEnd = !playerValue.isPlaying && !playerValue.isBuffering;

    // Method 3: Position stagnation check (for videos that get stuck near the end)
    bool positionStagnant = false;
    if (_lastVideoPosition != null) {
      int positionDifference = (videoPosition - _lastVideoPosition!).abs();
      positionStagnant =
          positionDifference < 50 &&
          relativePosition >=
              (assetDuration -
                  500); // Position hasn't moved much and we're near the end
    }
    _lastVideoPosition = videoPosition;

    // Combined end detection - any method can trigger the end
    bool isAtEnd =
        durationBasedEnd ||
        (playerBasedEnd && relativePosition >= (assetDuration * 0.8)) ||
        positionStagnant;

    print(
      'Video end detection for asset $currentAssetIndex: duration=$durationBasedEnd, player=$playerBasedEnd, stagnant=$positionStagnant, combined=$isAtEnd, relativePos=$relativePosition, assetDuration=$assetDuration',
    );

    if (isAtEnd) {
      // Remove listener to prevent multiple triggers
      _videoController!.removeListener(_videoListener);

      // Ensure video is paused
      if (_videoController!.value.isPlaying) {
        await _videoController!.pause();
      }

      // Check if there's a next asset to play
      int nextAssetIndex = currentAssetIndex + 1;
      if (nextAssetIndex < layer.assets.length) {
        // Move to next asset
        currentAssetIndex = nextAssetIndex;
        final nextAsset = layer.assets[nextAssetIndex];

        print('Moving to next asset: $nextAssetIndex, type: ${nextAsset.type}');

        if (nextAsset.type == AssetType.video ||
            nextAsset.type == AssetType.audio) {
          // Initialize and play next video/audio
          await _initializeForAsset(nextAssetIndex);
          if (_videoController != null) {
            _newPosition = nextAsset.begin;
            final seekPosition = Duration(milliseconds: nextAsset.cutFrom);
            await _videoController!.seekTo(seekPosition);
            await _videoController!.play();
            _videoController!.addListener(_videoListener);
          }
        } else if (nextAsset.type == AssetType.image) {
          // Switch to image playback
          _startImagePlayback(nextAsset.begin, nextAsset);
        }

        // Notify about position jump but don't end playback
        if (_onJump != null) {
          _onJump!();
        }
      } else {
        // End of all assets - now we can call onEnd
        currentAssetIndex = -1;
        if (_onJump != null) {
          _onJump!();
        }
        if (_onEnd != null) {
          _onEnd!();
        }
      }
    }
  }

  Future<void> stop() async {
    // Stop image timer if running
    if (_imageTimer != null) {
      _imageTimer!.cancel();
      _imageTimer = null;
    }

    // Stop video if playing
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      await _videoController!.pause();
    }
  }

  Future<void> addMediaSource(int index, Asset asset) async {
    // This method is no longer needed with standard video_player
    // Each asset will have its own controller initialized when needed
  }

  Future<void> removeMediaSource(int index) async {
    // This method is no longer needed with standard video_player
    // Controllers are managed per asset
  }

  Future<void> dispose() async {
    // Clean up image timer
    if (_imageTimer != null) {
      _imageTimer!.cancel();
      _imageTimer = null;
    }

    // Clean up video controller
    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
    }
  }
}
