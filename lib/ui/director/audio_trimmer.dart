import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor_app/model/model.dart';
import 'package:flutter_video_editor_app/service/director_service.dart';
import 'package:flutter_video_editor_app/service_locator.dart';
import 'package:flutter_video_editor_app/ui/director/params.dart';
import 'package:flutter_video_editor_app/ui/director/shared_trimmer_components.dart';

class AudioTrimmer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;
  final bool isEndTrimmer;

  AudioTrimmer(this.layerIndex, this.isEndTrimmer, {Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.selected$,
      initialData: Selected(-1, -1),
      builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
        if (layerIndex != 2) return Container(); // Only for audio layer

        final data = selected.data;
        if (data == null ||
            data.layerIndex != layerIndex ||
            data.assetIndex == -1 ||
            directorService.isDragging) {
          return Container();
        }

        Asset asset =
            directorService.layers[layerIndex].assets[data.assetIndex];
        if (asset.type != AssetType.audio) return Container();

        // Calculate position with trimmer drag updates
        double left = asset.begin * directorService.pixelsPerSecond / 1000.0;
        if (isEndTrimmer) {
          left += asset.duration * directorService.pixelsPerSecond / 1000.0;
          if (directorService.isClipperDraggingEnd) {
            left += directorService.dxClipperDrag;
          }
          // Minimum duration constraint (1 second)
          if (left <
              (asset.begin + 1000) * directorService.pixelsPerSecond / 1000.0) {
            left =
                (asset.begin + 1000) * directorService.pixelsPerSecond / 1000.0;
          }
        } else {
          if (!directorService.isClipperDraggingEnd) {
            left += directorService.dxClipperDrag;
          }
          // Maximum position constraint
          if (left >
              (asset.begin + asset.duration - 1000) *
                  directorService.pixelsPerSecond /
                  1000.0) {
            left =
                (asset.begin + asset.duration - 1000) *
                directorService.pixelsPerSecond /
                1000.0;
          }
          if (left < asset.begin * directorService.pixelsPerSecond / 1000.0) {
            left = asset.begin * directorService.pixelsPerSecond / 1000.0;
          }
        }

        return Positioned(
          left:
              MediaQuery.of(context).size.width / 2 +
              left -
              (isEndTrimmer ? 8 : 8),
          child: GestureDetector(
            child: TrimmerHandle(
              isActive: directorService.dxClipperDrag != 0,
              height: Params.getLayerHeight(
                context,
                directorService.layers[layerIndex].type,
              ),
            ),
            onHorizontalDragStart: (detail) =>
                directorService.clipperDragStart(isEndTrimmer),
            onHorizontalDragUpdate: (detail) => directorService
                .clipperDragUpdate(isEndTrimmer, detail.delta.dx),
            onHorizontalDragEnd: (detail) =>
                directorService.clipperDragEnd(isEndTrimmer),
          ),
        );
      },
    );
  }
}

/// Enhanced overlay showing trimmed regions for audio assets
class AudioTrimmerOverlay extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;

  AudioTrimmerOverlay(this.layerIndex, {Key? key}) : super(key: key);

  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).round();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.selected$,
      initialData: Selected(-1, -1),
      builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
        if (layerIndex != 2) return Container(); // Only for audio layer

        final data = selected.data;
        if (data == null ||
            data.layerIndex != layerIndex ||
            data.assetIndex == -1 ||
            directorService.isDragging) {
          return Container();
        }

        Asset asset =
            directorService.layers[layerIndex].assets[data.assetIndex];
        if (asset.type != AssetType.audio) return Container();

        // Calculate display dimensions
        double left = asset.begin * directorService.pixelsPerSecond / 1000.0;
        double width =
            asset.duration * directorService.pixelsPerSecond / 1000.0;

        // Apply real-time trimmer drag adjustments
        if (directorService.isClipperDragging) {
          if (!directorService.isClipperDraggingEnd) {
            // Start trimming
            left += directorService.dxClipperDrag;
            width -= directorService.dxClipperDrag;
          } else {
            // End trimming
            width += directorService.dxClipperDrag;
          }
        }

        return Positioned(
          left: MediaQuery.of(context).size.width / 2 + left,
          child: TrimmerOverlayBorder(
            width: width,
            height: Params.getLayerHeight(
              context,
              directorService.layers[layerIndex].type,
            ),
            child: Container(
              padding: EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎵 ${asset.title}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${_formatDuration(asset.duration)} ${asset.cutFrom > 0 ? '(${_formatDuration(asset.cutFrom)} cut)' : ''}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
