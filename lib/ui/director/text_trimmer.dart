import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor/model/model.dart';
import 'package:flutter_video_editor/service/director_service.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:flutter_video_editor/ui/director/params.dart';
import 'package:flutter_video_editor/ui/director/shared_trimmer_components.dart';

class TextTrimmer extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;
  final bool isEndTrimmer;

  TextTrimmer(this.layerIndex, this.isEndTrimmer, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.selected$,
      initialData: Selected(-1, -1),
      builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
        if (layerIndex != 1) return Container(); // Only for text layer

        final data = selected.data;
        if (data == null ||
            data.layerIndex != layerIndex ||
            data.assetIndex == -1 ||
            directorService.isDragging) {
          return Container();
        }

        Asset asset =
            directorService.layers[layerIndex].assets[data.assetIndex];
        if (asset.type != AssetType.text) return Container();

        // Calculate position
        double left = asset.begin * directorService.pixelsPerSecond / 1000.0;
        if (isEndTrimmer) {
          left += asset.duration * directorService.pixelsPerSecond / 1000.0;
          if (directorService.isSizerDraggingEnd) {
            left += directorService.dxSizerDrag;
          }
          // Minimum duration constraint (1 second)
          if (left <
              (asset.begin + 1000) * directorService.pixelsPerSecond / 1000.0) {
            left =
                (asset.begin + 1000) * directorService.pixelsPerSecond / 1000.0;
          }
        } else {
          if (!directorService.isSizerDraggingEnd) {
            left += directorService.dxSizerDrag;
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
              (isEndTrimmer ? 8 : 8),
          child: GestureDetector(
            child: TrimmerHandle(
              isActive: directorService.dxSizerDrag != 0,
              height: Params.getLayerHeight(
                context,
                directorService.layers[layerIndex].type,
              ),
            ),
            onHorizontalDragStart: (detail) =>
                directorService.sizerDragStart(isEndTrimmer),
            onHorizontalDragUpdate: (detail) =>
                directorService.sizerDragUpdate(isEndTrimmer, detail.delta.dx),
            onHorizontalDragEnd: (detail) =>
                directorService.sizerDragEnd(isEndTrimmer),
          ),
        );
      },
    );
  }
}

/// Enhanced overlay showing trimmed regions for text assets
class TextTrimmerOverlay extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;

  TextTrimmerOverlay(this.layerIndex, {Key? key}) : super(key: key);

  String _formatDuration(int milliseconds) {
    double seconds = milliseconds / 1000.0;
    return '${seconds.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.selected$,
      initialData: Selected(-1, -1),
      builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
        if (layerIndex != 1) return Container(); // Only for text layer

        final data = selected.data;
        if (data == null ||
            data.layerIndex != layerIndex ||
            data.assetIndex == -1 ||
            directorService.isDragging) {
          return Container();
        }

        Asset asset =
            directorService.layers[layerIndex].assets[data.assetIndex];
        if (asset.type != AssetType.text) return Container();

        // Calculate asset bounds
        double assetLeft =
            asset.begin * directorService.pixelsPerSecond / 1000.0;
        double assetWidth =
            asset.duration * directorService.pixelsPerSecond / 1000.0;
        int currentDuration = asset.duration;

        // Apply drag adjustments
        if (directorService.isSizerDragging) {
          if (directorService.isSizerDraggingEnd) {
            assetWidth += directorService.dxSizerDrag;
            currentDuration =
                asset.duration +
                (directorService.dxSizerDrag /
                        directorService.pixelsPerSecond *
                        1000)
                    .floor();
          } else {
            assetLeft += directorService.dxSizerDrag;
            assetWidth -= directorService.dxSizerDrag;
            currentDuration =
                asset.duration -
                (directorService.dxSizerDrag /
                        directorService.pixelsPerSecond *
                        1000)
                    .floor();
          }
        }

        // Ensure minimum duration
        if (currentDuration < 1000) currentDuration = 1000;

        return Positioned(
          left: MediaQuery.of(context).size.width / 2 + assetLeft,
          child: TrimmerOverlayBorder(
            width: assetWidth,
            height: Params.getLayerHeight(
              context,
              directorService.layers[layerIndex].type,
            ),
            child: Center(
              child: Container(
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
            ),
          ),
        );
      },
    );
  }
}
