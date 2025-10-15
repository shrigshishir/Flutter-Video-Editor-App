import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor/model/model.dart';
import 'package:flutter_video_editor/service/director_service.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:flutter_video_editor/ui/director/params.dart';

class DragClosest extends StatelessWidget {
  final directorService = locator.get<DirectorService>();
  final int layerIndex;

  DragClosest(this.layerIndex, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.selected$,
      initialData: Selected(-1, -1),
      builder: (BuildContext context, AsyncSnapshot<Selected> selected) {
        Color color;
        double left;
        final data = selected.data;
        if (directorService.isDragging &&
            data != null &&
            data.closestAsset != -1 &&
            data.layerIndex == layerIndex) {
          color = Colors.pink;
          Asset closestAsset =
              directorService.layers[layerIndex].assets[data.closestAsset];
          if (data.closestAsset <= data.assetIndex) {
            left =
                closestAsset.begin * directorService.pixelsPerSecond / 1000.0;
          } else {
            left =
                (closestAsset.begin + closestAsset.duration) *
                directorService.pixelsPerSecond /
                1000.0;
          }
        } else {
          color = Colors.transparent;
          left = -1;
        }

        return Positioned(
          left: MediaQuery.of(context).size.width / 2 + left - 2,
          child: Container(
            height: Params.getLayerHeight(
              context,
              directorService.layers[layerIndex].type,
            ),
            width: 3,
            color: color,
          ),
        );
      },
    );
  }
}
