import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_video_editor_app/model/model.dart';
import 'package:flutter_video_editor_app/service_locator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class Generator {
  final logger = locator.get<Logger>();

  final BehaviorSubject<FFmpegStat> _ffmepegStat = BehaviorSubject.seeded(
    FFmpegStat(),
  );
  Stream<FFmpegStat> get ffmepegStat$ => _ffmepegStat.stream;
  FFmpegStat get ffmepegStat => _ffmepegStat.value;

  Future<int> getVideoDuration(String path) async {
    final info = await FFprobeKit.getMediaInformation(path);
    final properties = info.getMediaInformation()?.getAllProperties() ?? {};

    final duration = properties['format']['duration'];
    if (duration != null) {
      return (double.parse(duration) * 1000).round();
    }
    return 5000;
  }

  Future<String> generateVideoThumbnail(
    String srcPath,
    String thumbnailPath,
    int pos,
    VideoResolution videoResolution,
  ) async {
    VideoResolutionSize size = _videoResolutionSize(videoResolution);
    List<String> pathList = thumbnailPath.split('.');
    pathList[pathList.length - 2] += '_${size.width}x${size.height}';
    String path = pathList.join('.');
    String arguments =
        '-loglevel error -y -i "$srcPath" ' +
        '-ss ${pos / 1000} -vframes 1 -vf scale=-2:${size.height} "$path"';
    await FFmpegKit.execute(arguments);
    return path;
  }

  Future<String> generateImageThumbnail(
    String srcPath,
    String thumbnailPath,
    VideoResolution videoResolution,
  ) async {
    VideoResolutionSize size = _videoResolutionSize(videoResolution);
    List<String> pathList = thumbnailPath.split('.');
    pathList[pathList.length - 2] += '_${size.width}x${size.height}';
    String path = pathList.join('.');
    String arguments =
        '-loglevel error -y -r 1 -i "$srcPath" ' +
        '-ss 0 -vframes 1 -vf scale=-2:${size.height} "$path"';
    await FFmpegKit.execute(arguments);
    return path;
  }

  generateVideoAll(List<Layer> layers, VideoResolution videoResolution) async {
    // To free memory
    imageCache.clear();

    // Use app documents directory instead of hardcoded Android path
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String galleryDirPath = p.join(appDocDir.path, 'generated_videos');

    // Request permissions if needed (mainly for Android)
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }

    // Create directory if it doesn't exist
    await Directory(galleryDirPath).create(recursive: true);

    // Validate that the output directory exists and is writable
    if (!await Directory(galleryDirPath).exists()) {
      logger.e('Failed to create output directory: $galleryDirPath');
      return null;
    }

    // Validate input files exist
    for (var layer in layers) {
      for (var asset in layer.assets) {
        if (asset.srcPath.isNotEmpty && !await File(asset.srcPath).exists()) {
          logger.e('Input file does not exist: ${asset.srcPath}');
          return null;
        }
      }
    }

    // Check if we have any video or image assets to process
    bool hasVideoAssets = layers[0].assets.isNotEmpty;
    bool hasAudioAssets = layers[2].assets.isNotEmpty;

    if (!hasVideoAssets && !hasAudioAssets) {
      logger.e('No video or audio assets found for processing');
      return null;
    }

    logger.i(
      'Video generation started: ${layers[0].assets.length} video assets, ${layers[1].assets.length} text assets, ${layers[2].assets.length} audio assets',
    );

    String arguments = _commandLogLevel('error');
    arguments += _commandInputs(layers[0]);
    arguments += _commandInputs(layers[2]);
    arguments += ' -filter_complex "';
    arguments += _commandImageVideoFilters(layers[0], 0, videoResolution);

    // Process audio from video files in Layer 0
    arguments += _commandVideoAudioFilters(layers[0], 0);

    // Process dedicated audio files in Layer 2
    arguments += _commandAudioFilters(layers[2], layers[0].assets.length);

    // Concatenate video streams
    arguments += _commandConcatenateStreams(layers[0], 0, false);

    // Mix audio streams with timeline positioning (matching preview behavior)
    final audioMixing = _commandMixAudioStreamsWithTiming(layers[0], layers[2]);
    arguments += audioMixing;
    arguments += await _commandTextAssets(layers[1], videoResolution);
    arguments = arguments.substring(0, arguments.length - 1);
    arguments += '"';
    arguments += _commandCodecsAndFormat(CodecsAndFormat.H264AacMp4);
    String dateSuffix = dateTimeString(DateTime.now());
    String outputPath = p.join(galleryDirPath, 'Open_Director_$dateSuffix.mp4');

    // Determine if we have any audio (either from video files or dedicated audio files)
    bool hasAudio = audioMixing.isNotEmpty;

    arguments += _commandOutputFile(outputPath, hasAudio, true);

    // Log the full FFmpeg command for debugging
    logger.i('FFmpeg command: ffmpeg $arguments');
    logger.i('Output path: $outputPath');

    final out = await executeCommand(
      arguments,
      finished: true,
      outputPath: outputPath,
    );

    if (out == null) {
      logger.e('Video generation failed');
    } else {
      logger.i('Video generation successful: $out');
    }

    return out;
  }

  generateVideosForAssets(Layer layer, VideoResolution videoResolution) async {
    final Directory extStorDir = (await getExternalStorageDirectory())!;
    await Directory(p.join(extStorDir.path, 'temp')).create();
    int fileNum = 1;
    for (int i = 0; i < layer.assets.length; i++) {
      int rc = await generateVideoForAsset(
        i,
        fileNum,
        layer.assets.length,
        layer.assets[i],
        videoResolution,
      );
      if (rc != 0) return rc;
      fileNum++;
    }
    return 0;
  }

  generateVideoForAsset(
    int index,
    int fileNum,
    int totalFiles,
    Asset asset,
    VideoResolution videoResolution,
  ) async {
    String arguments = _commandLogLevel('error');
    arguments += _commandInput(asset.srcPath);
    arguments += ' -filter_complex "';

    // First scale to fit within target dimensions
    arguments += _commandScaleToFitFilter(videoResolution);

    // Then pad to exact target dimensions
    arguments += _commandPadForAspectRatioFilter(videoResolution);

    // Apply effects after scaling and padding
    if (asset.type == AssetType.image) {
      arguments += _commandKenBurnsEffectFilter(videoResolution, asset);
    } else if (asset.type == AssetType.video) {
      arguments += _commandTrimFilter(asset, false);
    }

    arguments += 'setsar=1';
    arguments += '[v]"';
    arguments += _commandCodecsAndFormat(CodecsAndFormat.H264AacMp4);

    final Directory extStorDir = (await getExternalStorageDirectory())!;
    String outputPath = p.join(extStorDir.path, 'temp', 'v$index.mp4');
    arguments += _commandOutputFile(outputPath, false, true);

    return await executeCommand(
      arguments,
      fileNum: fileNum,
      totalFiles: totalFiles,
    );
  }

  concatVideos(List<Layer> layers, VideoResolution videoResolution) async {
    String arguments = _commandLogLevel('error');
    String listPath = await _listForConcat(layers[0]);
    arguments += ' -f concat -safe 0 -i "$listPath" -c copy';

    final Directory extStorDir = (await getExternalStorageDirectory())!;
    String outputPath = p.join(extStorDir.path, 'temp', 'concanenated.mp4');
    arguments += ' -y "$outputPath"';

    return await executeCommand(arguments);
  }

  _listForConcat(Layer layer) async {
    final Directory extStorDir = (await getExternalStorageDirectory())!;
    String tempPath = p.join(extStorDir.path, 'temp');
    String list = '';
    for (int i = 0; i < layer.assets.length; i++) {
      list += "file '${p.join(tempPath, "v" + i.toString() + ".mp4")}'\n";
    }
    File file = await File(p.join(tempPath, 'list.txt')).writeAsString(list);
    return file.path;
  }

  Future<String?> executeCommand(
    String arguments, {
    String? outputPath,
    int? fileNum,
    int? totalFiles,
    bool finished = false,
  }) async {
    final completer = Completer<String?>();
    DateTime initTime = DateTime.now();

    try {
      final session = await FFmpegKit.execute(arguments);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // Verify the output file actually exists and has content
        if (outputPath != null && await File(outputPath).exists()) {
          int fileSize = await File(outputPath).length();
          if (fileSize > 0) {
            ffmepegStat.finished = finished;
            ffmepegStat.outputPath = outputPath;
            _ffmepegStat.add(ffmepegStat);
            Duration diffTime = DateTime.now().difference(initTime);
            logger.i('Video generation SUCCESS - Duration: $diffTime');
            completer.complete(outputPath);
          } else {
            logger.e('Output file is empty');
            final output = await session.getAllLogsAsString();
            logger.e('FFmpeg output: $output');
            ffmepegStat.error = true;
            _ffmepegStat.add(ffmepegStat);
            completer.complete(null);
          }
        } else {
          logger.e('Output file not created: $outputPath');
          final output = await session.getAllLogsAsString();
          logger.e('FFmpeg output: $output');
          ffmepegStat.error = true;
          _ffmepegStat.add(ffmepegStat);
          completer.complete(null);
        }
      } else {
        ffmepegStat.error = true;
        _ffmepegStat.add(ffmepegStat);
        final output = await session.getAllLogsAsString();
        logger.e('FFmpeg FAILED - Return code: $returnCode');
        logger.e('FFmpeg output: $output');
        completer.complete(null);
      }
    } catch (e) {
      logger.e('Exception during FFmpeg execution: $e');
      ffmepegStat.error = true;
      _ffmepegStat.add(ffmepegStat);
      completer.complete(null);
    }

    ffmepegStat.time = 0;
    return completer.future;
  }

  Future<void> finishVideoGeneration() async {
    _ffmepegStat.add(FFmpegStat());
    // ffmpeg_kit_flutter_new does not support cancel in the same way; you may need to manage this differently
  }

  String _commandLogLevel(String level) => '-loglevel $level ';

  String _commandInputs(Layer layer) {
    if (layer.assets.isEmpty) return "";
    return layer.assets
        .map((asset) => _commandInput(asset.srcPath))
        .reduce((a, b) => a + b);
  }

  String _commandInput(path) => ' -i "$path"';

  String _commandImageVideoFilters(
    Layer layer,
    int startIndex,
    VideoResolution videoResolution,
  ) {
    String arguments = "";
    for (var i = 0; i < layer.assets.length; i++) {
      arguments += '[${startIndex + i}:v]';

      // First scale down to fit within target dimensions
      arguments += _commandScaleToFitFilter(videoResolution);

      // Then pad to exact target dimensions
      arguments += _commandPadForAspectRatioFilter(videoResolution);

      // Apply effects after scaling and padding
      if (layer.assets[i].type == AssetType.image) {
        arguments += _commandKenBurnsEffectFilter(
          videoResolution,
          layer.assets[i],
        );
      } else if (layer.assets[i].type == AssetType.video) {
        arguments += _commandTrimFilter(layer.assets[i], false);
      }

      arguments += 'setsar=1,copy[v${startIndex + i}];';
    }
    return arguments;
  }

  String _commandAudioFilters(Layer layer, int startIndex) {
    String arguments = "";
    for (var i = 0; i < layer.assets.length; i++) {
      final asset = layer.assets[i];
      final volume = _getEffectiveVolume(asset, layer);

      arguments += '[${startIndex + i}:a]${_commandTrimFilter(asset, true)}';

      // Apply timeline positioning - add delay to match timeline position
      if (asset.begin > 0) {
        arguments += 'adelay=${asset.begin}:all=1,';
      }

      // Apply volume adjustment if not default (1.0)
      if (volume != 1.0) {
        arguments += 'volume=${volume.toStringAsFixed(2)},';
      }

      arguments += 'acopy[a${startIndex + i}];';
    }
    return arguments;
  }

  /// Processes audio tracks from video files, applying volume and timeline positioning
  String _commandVideoAudioFilters(Layer layer, int startIndex) {
    String arguments = "";
    for (var i = 0; i < layer.assets.length; i++) {
      final asset = layer.assets[i];

      // Only process video assets that have audio tracks
      if (asset.type == AssetType.video) {
        final volume = _getEffectiveVolume(asset, layer);

        arguments += '[${startIndex + i}:a]${_commandTrimFilter(asset, true)}';

        // Apply timeline positioning - add delay to match timeline position
        if (asset.begin > 0) {
          arguments += 'adelay=${asset.begin}:all=1,';
        }

        // Apply volume adjustment if not default (1.0)
        if (volume != 1.0) {
          arguments += 'volume=${volume.toStringAsFixed(2)},';
        }

        arguments += 'acopy[va${startIndex + i}];';
      }
    }
    return arguments;
  }

  /// Mixes audio streams with timeline positioning to match preview playback behavior
  String _commandMixAudioStreamsWithTiming(Layer videoLayer, Layer audioLayer) {
    List<String> audioStreams = [];

    // Collect audio streams from video files
    for (var i = 0; i < videoLayer.assets.length; i++) {
      if (videoLayer.assets[i].type == AssetType.video) {
        audioStreams.add('[va$i]');
      }
    }

    // Collect audio streams from dedicated audio files
    for (var i = 0; i < audioLayer.assets.length; i++) {
      audioStreams.add('[a${videoLayer.assets.length + i}]');
    }

    if (audioStreams.isEmpty) {
      return '';
    }

    if (audioStreams.length == 1) {
      // Single audio stream, just copy
      return '${audioStreams[0]}acopy[aout];';
    }

    // Mix multiple audio streams with proper timeline positioning
    // Since we've added adelay filters, streams will be positioned correctly on the timeline
    return '${audioStreams.join('')}amix=inputs=${audioStreams.length}:duration=longest:normalize=0[aout];';
  }

  /// Gets the effective volume for an asset during export, considering asset-level and layer-level volume settings.
  /// Priority: asset.volume > layer.volume > 1.0 (default)
  double _getEffectiveVolume(Asset asset, Layer layer) {
    final double baseVolume = asset.volume ?? layer.volume ?? 1.0;
    return baseVolume.clamp(0.0, 1.0);
  }

  String _commandTrimFilter(Asset asset, bool audio) =>
      '${audio ? "a" : ""}trim=${asset.cutFrom / 1000}' +
      ':${(asset.cutFrom + asset.duration) / 1000},' +
      '${audio ? "a" : ""}setpts=PTS-STARTPTS,';

  String _commandPadForAspectRatioFilter(VideoResolution videoResolution) {
    VideoResolutionSize size = _videoResolutionSize(videoResolution);

    // Simple padding approach that ensures even dimensions
    // This creates a canvas of the target size and centers the input video
    return "pad=${size.width}:${size.height}:(ow-iw)/2:(oh-ih)/2,";
  }

  String _commandScaleToFitFilter(VideoResolution videoResolution) {
    VideoResolutionSize size = _videoResolutionSize(videoResolution);
    // Scale to fit within target dimensions while preserving aspect ratio
    // This ensures the input is never larger than the target size
    return 'scale=${size.width}:${size.height}:force_original_aspect_ratio=decrease,';
  }

  VideoResolutionSize _videoResolutionSize(VideoResolution videoResolution) {
    switch (videoResolution) {
      case VideoResolution.fullHd:
        return VideoResolutionSize(width: 1920, height: 1080);
      case VideoResolution.hd:
        return VideoResolutionSize(width: 1280, height: 720);
      case VideoResolution.mini:
        return VideoResolutionSize(width: 64, height: 36);
      default:
        return VideoResolutionSize(width: 640, height: 360);
    }
  }

  String videoResolutionString(VideoResolution videoResolution) {
    switch (videoResolution) {
      case VideoResolution.fullHd:
        return 'Full HD 1080px';
      case VideoResolution.hd:
        return 'HD 720px';
      case VideoResolution.mini:
        return 'Thumbnail 36px';
      default:
        return 'SD 360px';
    }
  }

  String _commandKenBurnsEffectFilter(
    VideoResolution videoResolution,
    Asset asset,
  ) {
    VideoResolutionSize size = _videoResolutionSize(videoResolution);
    // Default framerate 25 in zoompan
    double d = asset.duration / 1000 * 25;
    String s = "${size.width}x${size.height}";
    // Zoom 20%
    String z = asset.kenBurnZSign == 1
        ? "'zoom+${0.2 / d}'"
        : (asset.kenBurnZSign == -1
              ? "'if(eq(on,1),1.2,zoom-${0.2 / d})'"
              : "1.2");
    String x = asset.kenBurnZSign != 0
        ? "'${asset.kenBurnXTarget}*(iw-iw/zoom)'"
        : (asset.kenBurnXTarget == 1
              ? "'(${asset.kenBurnXTarget}-on/$d)*(iw-iw/zoom)'"
              : (asset.kenBurnXTarget == 0
                    ? "'on/$d*(iw-iw/zoom)'"
                    : "'(iw-iw/zoom)/2'"));
    String y = asset.kenBurnZSign != 0
        ? "'${asset.kenBurnYTarget}*(ih-ih/zoom)'"
        : (asset.kenBurnYTarget == 1
              ? "'(${asset.kenBurnYTarget}-on/$d)*(ih-ih/zoom)'"
              : (asset.kenBurnYTarget == 0
                    ? "'on/$d*(ih-ih/zoom)'"
                    : "'(ih-ih/zoom)/2'"));
    return "zoompan=d=$d:s=$s:z=$z:x=$x:y=$y,";
  }

  String _commandConcatenateStreams(Layer layer, int startIndex, bool isAudio) {
    String arguments = "";
    // Concatenation
    // - n: Set the number of segments. Default is 2.
    // - v: Set the number of output video streams. Default is 1.
    // - a: Set the number of output audio streams. Default is 0.
    for (var i = startIndex; i < startIndex + layer.assets.length; i++) {
      arguments += '[${isAudio ? "a" : "v"}$i]';
    }
    if (layer.assets.length > 0) {
      arguments +=
          'concat=n=${layer.assets.length}' +
          ':v=${isAudio ? 0 : 1}:a=${isAudio ? 1 : 0}' +
          '[${isAudio ? "a" : "vprev"}];';
    }
    return arguments;
  }

  _commandTextAssets(Layer layer, VideoResolution videoResolution) async {
    //String arguments = '[0:v]';
    String arguments = '[vprev]';
    for (int i = 0; i < layer.assets.length; i++) {
      if (layer.assets[i].title != '') {
        arguments += await _commandDrawText(layer.assets[i], videoResolution);
      }
    }
    arguments += 'copy[v];';
    return arguments;
  }

  _commandDrawText(Asset asset, VideoResolution videoResolution) async {
    String fontFile = await _getFontPath(asset.font);
    String fontColor = '0x' + asset.fontColor.toRadixString(16).substring(2);
    VideoResolutionSize size = _videoResolutionSize(videoResolution);

    return "drawtext=" +
        "enable='between(t,${asset.begin / 1000},${(asset.begin + asset.duration) / 1000})':" +
        "x=${asset.x * size.width}:y=${asset.y * size.height}:" +
        "fontfile=$fontFile:fontsize=${asset.fontSize * size.width}:" +
        "fontcolor=$fontColor:alpha=${asset.alpha}:" +
        "borderw=${asset.borderw}:bordercolor=${colorStr(asset.bordercolor)}:" +
        "shadowcolor=${colorStr(asset.shadowcolor)}:shadowx=${asset.shadowx}:shadowy=${asset.shadowy}:" +
        "box=${asset.box ? 1 : 1}:boxborderw=${asset.boxborderw}:boxcolor=${colorStr(asset.boxcolor)}:" +
        "line_spacing=0:" +
        "text='${asset.title}',";
  }

  colorStr(int colorInt) {
    String colorStr = colorInt.toRadixString(16).padLeft(8, '0');
    String newColorStr = colorStr.substring(2) + colorStr.substring(0, 2);
    return '0x$newColorStr';
  }

  // Formats: https://ffmpeg.org/ffmpeg-formats.html
  String _commandCodecsAndFormat(CodecsAndFormat codecsAndFormat) {
    switch (codecsAndFormat) {
      // libvpx-vp9 https://trac.ffmpeg.org/wiki/Encode/VP9 (LGPL)
      // libvpx-vp9 has a lossless encoding mode that can be activated using -lossless 1
      // Opus, for VP9 https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio
      case CodecsAndFormat.VP9OpusWebm:
        return ' -c:v libvpx-vp9 -lossless 1 -c:a opus -f webm';
      // libx264 https://trac.ffmpeg.org/wiki/Encode/H.264 (GPL, not included)
      // Native encoder aac https://trac.ffmpeg.org/wiki/Encode/AAC
      case CodecsAndFormat.H264AacMp4:
        return ' -c:v libx264 -c:a aac -pix_fmt yuva420p -f mp4';
      // libxvid https://trac.ffmpeg.org/wiki/Encode/MPEG-4 (GPL, not included)
      case CodecsAndFormat.Xvid:
        return ' -c:v libxvid -c:a aac -f avi';
      // Native encoder mpeg4 https://trac.ffmpeg.org/wiki/Encode/MPEG-4 (LGPL)
      // qscale: 1 highest quality/largest filesize, 31 lowest quality/smallest filesize
      default:
        return ' -c:v mpeg4 -qscale:v 1 -c:a aac -f mp4';
    }
  }

  //String _commandFrameRate(int frameRate) => ' -r $frameRate';
  String _commandOutputFile(String path, bool withAudio, bool overwrite) =>
      ' -map "[v]" ${withAudio ? "-map \"[aout]\"" : ""} ${overwrite ? "-y" : ""} $path';

  String dateTimeString(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, "0")}' +
        '${dateTime.month.toString().padLeft(2, "0")}' +
        '${dateTime.day.toString().padLeft(2, "0")}' +
        '_${dateTime.hour.toString().padLeft(2, "0")}' +
        '${dateTime.minute.toString().padLeft(2, "0")}' +
        '${dateTime.second.toString().padLeft(2, "0")}';
  }

  _getFontPath(String relativePath) async {
    const String rootFontsPath = 'fonts';
    try {
      final ByteData fontFile = await rootBundle.load(
        p.join('assets', rootFontsPath, relativePath),
      );
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String fontPath = p.join(
        appDocDir.parent.path,
        rootFontsPath,
        relativePath,
      );
      File(fontPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(
          fontFile.buffer.asUint8List(
            fontFile.offsetInBytes,
            fontFile.lengthInBytes,
          ),
        );
      return fontPath;
    } catch (e) {
      logger.e('Error loading font asset: $relativePath', error: e);
      // Return a fallback or throw a more descriptive error
      throw Exception(
        'Unable to load font asset: "$relativePath". The asset does not exist or has empty data.',
      );
    }
  }
}

enum VideoResolution { sd, hd, fullHd, mini }

enum CodecsAndFormat { Mpeg4, Xvid, H264AacMp4, VP9OpusWebm }

class VideoResolutionSize {
  final int width;
  final int height;
  VideoResolutionSize({required this.width, required this.height});
}

class FFmpegStat {
  int time;
  int size;
  double bitrate;
  double speed;
  int videoFrameNumber;
  double videoQuality;
  double videoFps;
  bool finished;
  String? outputPath;
  bool error;
  int timeElapsed;
  int? fileNum;
  int? totalFiles;

  FFmpegStat({
    this.time = 0,
    this.size = 0,
    this.bitrate = 0,
    this.speed = 0,
    this.videoFrameNumber = 0,
    this.videoQuality = 0,
    this.videoFps = 0,
    this.outputPath,
    this.timeElapsed = 0,
    this.fileNum,
    this.totalFiles,
    this.finished = false,
    this.error = false,
  });
}
