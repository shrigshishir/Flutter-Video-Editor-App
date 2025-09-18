import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor_app/model/model.dart';
import 'package:flutter_video_editor_app/service/director_service.dart';
import 'package:flutter_video_editor_app/service_locator.dart';
import 'package:flutter_video_editor_app/ui/director/params.dart';
import 'package:flutter_video_editor_app/ui/director/shared_trimmer_components.dart';

class VideoPhotoClipper extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;
  final bool isEndClipper;

  VideoPhotoClipper(this.layerIndex, this.isEndClipper, {Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.selected$,
      initialData: Selected(-1, -1),
      builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
        if (layerIndex != 0) return Container(); // Only for video/photo layer

        final data = selected.data;
        if (data == null ||
            data.layerIndex != layerIndex ||
            data.assetIndex == -1 ||
            directorService.isDragging) {
          return Container();
        }

        Asset asset =
            directorService.layers[layerIndex].assets[data.assetIndex];
        if (asset.type != AssetType.video && asset.type != AssetType.image)
          return Container();

        // Calculate position with clipper drag updates
        double left = asset.begin * directorService.pixelsPerSecond / 1000.0;
        if (isEndClipper) {
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
          if (left < 0) left = 0;
        }

        return Positioned(
          left:
              MediaQuery.of(context).size.width / 2 +
              left -
              (isEndClipper ? 8 : 8),
          child: GestureDetector(
            child: TrimmerHandle(
              isActive: directorService.dxClipperDrag != 0,
              height: Params.getLayerHeight(
                context,
                directorService.layers[layerIndex].type,
              ),
            ),
            onHorizontalDragStart: (detail) =>
                directorService.clipperDragStart(isEndClipper),
            onHorizontalDragUpdate: (detail) => directorService
                .clipperDragUpdate(isEndClipper, detail.delta.dx),
            onHorizontalDragEnd: (detail) =>
                directorService.clipperDragEnd(isEndClipper),
          ),
        );
      },
    );
  }
}

/// Enhanced overlay showing clipped regions for video/photo assets
class VideoPhotoClipperOverlay extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;

  VideoPhotoClipperOverlay(this.layerIndex, {Key? key}) : super(key: key);

  String _formatDuration(int milliseconds) {
    double seconds = milliseconds / 1000.0;
    if (seconds >= 60) {
      int minutes = (seconds / 60).floor();
      double remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds.toStringAsFixed(1)}s';
    }
    return '${seconds.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.selected$,
      initialData: Selected(-1, -1),
      builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
        if (layerIndex != 0) return Container(); // Only for video/photo layer

        final data = selected.data;
        if (data == null ||
            data.layerIndex != layerIndex ||
            data.assetIndex == -1 ||
            directorService.isDragging) {
          return Container();
        }

        Asset asset =
            directorService.layers[layerIndex].assets[data.assetIndex];
        if (asset.type != AssetType.video && asset.type != AssetType.image)
          return Container();

        // Calculate asset bounds
        double assetLeft =
            asset.begin * directorService.pixelsPerSecond / 1000.0;
        double assetWidth =
            asset.duration * directorService.pixelsPerSecond / 1000.0;
        int currentDuration = asset.duration;
        int currentCutFrom = asset.cutFrom;

        // Apply drag adjustments
        if (directorService.isClipperDragging) {
          if (directorService.isClipperDraggingEnd) {
            // End clipping: adjust duration
            assetWidth += directorService.dxClipperDrag;
            int deltaMillis =
                (directorService.dxClipperDrag /
                        directorService.pixelsPerSecond *
                        1000)
                    .floor();
            currentDuration = asset.duration + deltaMillis;
          } else {
            // Start clipping: adjust cutFrom and begin
            assetLeft += directorService.dxClipperDrag;
            assetWidth -= directorService.dxClipperDrag;
            int deltaMillis =
                (directorService.dxClipperDrag /
                        directorService.pixelsPerSecond *
                        1000)
                    .floor();
            currentDuration = asset.duration - deltaMillis;
            currentCutFrom = asset.cutFrom + deltaMillis;
          }
        }

        // Ensure minimum duration
        if (currentDuration < 1000) currentDuration = 1000;
        if (currentCutFrom < 0) currentCutFrom = 0;

        return Positioned(
          left: MediaQuery.of(context).size.width / 2 + assetLeft,
          child: TrimmerOverlayBorder(
            width: assetWidth,
            height: Params.getLayerHeight(
              context,
              directorService.layers[layerIndex].type,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(currentDuration),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (asset.type == AssetType.video && currentCutFrom > 0)
                    SizedBox(height: 2),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
