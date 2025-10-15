import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor/model/model.dart';
import 'package:flutter_video_editor/service/director_service.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:flutter_video_editor/ui/director/fullscreen_text_editor.dart';

class FullScreenTextEditorWrapper extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.editingTextAsset$,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<Asset?> editingTextAsset) {
        if (editingTextAsset.data == null) return Container();

        return Positioned.fill(
          child: FullScreenTextEditor(
            asset: editingTextAsset.data,
            onClose: () {
              directorService.editingTextAsset = null;
            },
          ),
        );
      },
    );
  }
}
