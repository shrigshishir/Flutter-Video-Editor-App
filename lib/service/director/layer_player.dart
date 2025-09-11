import 'dart:io';
import 'dart:async';
import 'package:flutter_video_editor_app/model/model.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';

class LayerPlayer {
  Layer layer;
  int currentAssetIndex = -1;

  int _newPosition = 0;
  Timer? _imageTimer;
  int? _lastVideoPosition; // For position stagnation detection

  VideoPlayerController? _videoController;
  VideoPlayerController? get videoController => _videoController;

  // Audio player for audio assets (background music)
  AudioPlayer? _audioPlayer;
  Timer? _audioPositionTimer;

  // Track the current video file path to manage video controller reuse
  String? _currentVideoPath;

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

    // Handle audio assets with just_audio
    if (asset.type == AssetType.audio && !asset.deleted) {
      // Check if we need to create/recreate audio player for different file
      bool needNewAudioPlayer = _audioPlayer == null;

      if (_audioPlayer != null) {
        // Check if it's a different file - for now, we'll recreate for simplicity
        await _audioPlayer!.dispose();
        _audioPlayer = null;
        needNewAudioPlayer = true;
      }

      if (needNewAudioPlayer) {
        try {
          // Verify the file exists and has valid extension
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
          await _audioPlayer!.setFilePath(asset.srcPath);
        } catch (e) {
          print('Error initializing audio controller for ${asset.srcPath}: $e');
          _audioPlayer = null;
        }
      }
      return;
    }

    // Handle video assets with VideoPlayerController
    if (asset.type == AssetType.video && !asset.deleted) {
      // Check if we need to create/recreate video controller for different file
      bool needNewVideoController =
          _videoController == null || _currentVideoPath != asset.srcPath;

      if (_videoController != null && _currentVideoPath != asset.srcPath) {
        // Different video file, dispose old controller
        print('Disposing existing video controller for different video file');
        await _videoController!.dispose();
        _videoController = null;
        needNewVideoController = true;
      }

      if (needNewVideoController) {
        try {
          // Additional check: verify the file exists and has valid extension
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

    if (currentAssetIndex == -1) {
      return;
    }

    final asset = layer.assets[currentAssetIndex];

    // For image assets, we only need to set the currentAssetIndex
    if (asset.type == AssetType.image) {
      return;
    }

    // Initialize controller for this asset if needed
    await _initializeForAsset(currentAssetIndex);

    // Handle audio assets
    if (asset.type == AssetType.audio) {
      if (_audioPlayer == null) return;

      _newPosition = pos - asset.begin;

      // Set volume and seek to position
      await _audioPlayer!.setVolume(layer.volume ?? 1.0);
      final seekPosition = Duration(milliseconds: asset.cutFrom + _newPosition);
      await _audioPlayer!.seek(seekPosition);
      // Don't auto-play during preview
      return;
    }

    // Handle video assets
    if (asset.type == AssetType.video) {
      if (_videoController == null) {
        return;
      }

      if (!_videoController!.value.isInitialized) {
        try {
          await _videoController!.initialize();
        } catch (e) {
          print('Failed to initialize video controller: $e');
          return;
        }
      }

      _newPosition = pos - asset.begin;

      // Mute for preview only
      await _videoController!.setVolume(0.0);

      // Seek to position within the asset (considering cutFrom offset)
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

    // For image assets, use timer-based position updates
    if (asset.type == AssetType.image) {
      _startImagePlayback(pos, asset);
      return;
    }

    // Initialize controller for this asset if needed
    await _initializeForAsset(currentAssetIndex);

    // Handle audio assets with just_audio
    if (asset.type == AssetType.audio) {
      if (_audioPlayer == null) return;

      await _audioPlayer!.setVolume(0.2);
      _newPosition = pos - asset.begin;

      // Ensure we don't start playing beyond the asset's duration
      if (_newPosition >= asset.duration) {
        print('Warning: Attempted to play beyond audio asset duration');
        return;
      }

      // Seek to position within the asset (considering cutFrom offset)
      final seekPosition = Duration(milliseconds: asset.cutFrom + _newPosition);
      await _audioPlayer!.seek(seekPosition);
      await _audioPlayer!.play();
      _startAudioPlayback();
      return;
    }

    // Handle video assets with VideoPlayerController
    if (asset.type == AssetType.video) {
      if (_videoController == null) return;

      // Set normal volume for video
      await _videoController!.setVolume(layer.volume ?? 1.0);
      _newPosition = pos - asset.begin;

      // Ensure we don't start playing beyond the asset's duration
      if (_newPosition >= asset.duration) {
        print('Warning: Attempted to play beyond video asset duration');
        return;
      }

      // Seek to position within the asset (considering cutFrom offset)
      final seekPosition = Duration(milliseconds: asset.cutFrom + _newPosition);
      await _videoController!.seekTo(seekPosition);
      await _videoController!.play();
      _videoController!.addListener(_videoListener);
    }
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
          } else if (nextAsset.type == AssetType.video) {
            // Switch to video playback
            _playVideoAsset(nextAsset.begin, nextAssetIndex);
          } else if (nextAsset.type == AssetType.audio) {
            // Switch to audio playback
            _playAudioAsset(nextAsset.begin, nextAssetIndex);
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

  void _startAudioPlayback() {
    if (_audioPlayer == null) return;

    const int frameRate = 30; // 30 FPS for smooth playback
    const int updateInterval = 1000 ~/ frameRate; // ~33ms per frame

    _audioPositionTimer = Timer.periodic(Duration(milliseconds: updateInterval), (
      timer,
    ) {
      if (_audioPlayer == null || !_audioPlayer!.playing) {
        timer.cancel();
        _audioPositionTimer = null;
        return;
      }

      final currentPosition = _audioPlayer!.position;
      final asset = layer.assets[currentAssetIndex];

      // Calculate timeline position (asset begin + current position within asset - cutFrom offset)
      final timelinePosition =
          asset.begin + currentPosition.inMilliseconds - asset.cutFrom;
      _newPosition = timelinePosition;

      // Update the position callback
      if (_onMove != null) {
        _onMove!(timelinePosition);
      }

      // Check if we've reached the end of the current audio asset
      final assetEndPosition = asset.begin + asset.duration;
      final cutToPosition = asset.cutFrom + asset.duration;

      if (currentPosition.inMilliseconds >= cutToPosition ||
          timelinePosition >= assetEndPosition) {
        timer.cancel();
        _audioPositionTimer = null;
        _audioPlayer!.stop();

        // Check if there's a next asset
        int nextAssetIndex = currentAssetIndex + 1;
        if (nextAssetIndex < layer.assets.length) {
          currentAssetIndex = nextAssetIndex;
          final nextAsset = layer.assets[nextAssetIndex];

          print(
            'Audio finished, moving to next asset: $nextAssetIndex, type: ${nextAsset.type}',
          );

          if (nextAsset.type == AssetType.audio) {
            // Continue with next audio
            _playAudioAsset(nextAsset.begin, nextAssetIndex);
          } else if (nextAsset.type == AssetType.video) {
            // Switch to video playback
            _playVideoAsset(nextAsset.begin, nextAssetIndex);
          } else if (nextAsset.type == AssetType.image) {
            // Switch to image playback
            _startImagePlayback(nextAsset.begin, nextAsset);
          }

          // Notify about position jump but don't end playback
          if (_onJump != null) {
            _onJump!();
          }
        } else {
          // End of all assets
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

  Future<void> _playAudioAsset(int startPos, int assetIndex) async {
    await _initializeForAsset(assetIndex);
    if (_audioPlayer != null) {
      final asset = layer.assets[assetIndex];
      await _audioPlayer!.setVolume(layer.volume ?? 1.0);
      _newPosition = startPos;

      // Ensure we don't start playing beyond the asset's duration
      if (_newPosition >= asset.duration) {
        print('Warning: Attempted to play audio beyond asset duration');
        return;
      }

      final seekPosition = Duration(
        milliseconds: asset.cutFrom + (_newPosition - asset.begin),
      );
      await _audioPlayer!.seek(seekPosition);
      await _audioPlayer!.play();
      _startAudioPlayback();
    }
  }

  Future<void> _playVideoAsset(int startPos, int assetIndex) async {
    await _initializeForAsset(assetIndex);
    if (_videoController != null) {
      final asset = layer.assets[assetIndex];
      await _videoController!.setVolume(layer.volume ?? 1.0);
      _newPosition = startPos;

      // Ensure we don't start playing beyond the asset's duration
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

        if (nextAsset.type == AssetType.video) {
          // Initialize and play next video
          await _initializeForAsset(nextAssetIndex);
          if (_videoController != null) {
            _newPosition = nextAsset.begin;
            final seekPosition = Duration(milliseconds: nextAsset.cutFrom);
            await _videoController!.seekTo(seekPosition);
            await _videoController!.play();
            _videoController!.addListener(_videoListener);
          }
        } else if (nextAsset.type == AssetType.audio) {
          // Switch to audio playback
          _playAudioAsset(nextAsset.begin, nextAssetIndex);
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

    // Stop audio position timer if running
    if (_audioPositionTimer != null) {
      _audioPositionTimer!.cancel();
      _audioPositionTimer = null;
    }

    // Stop video if playing
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      await _videoController!.pause();
    }

    // Stop audio if playing
    if (_audioPlayer != null && _audioPlayer!.playing) {
      await _audioPlayer!.stop();
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

    // Clean up audio position timer
    if (_audioPositionTimer != null) {
      _audioPositionTimer!.cancel();
      _audioPositionTimer = null;
    }

    // Clean up video controller
    if (_videoController != null) {
      await _videoController!.dispose();
      _videoController = null;
    }

    // Clean up audio player
    if (_audioPlayer != null) {
      await _audioPlayer!.dispose();
      _audioPlayer = null;
    }
  }
}
