import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor_app/model/model.dart';
import 'package:flutter_video_editor_app/service/director_service.dart';
import 'package:flutter_video_editor_app/service_locator.dart';
import 'package:flutter_video_editor_app/ui/director/params.dart';
import 'package:flutter_video_editor_app/ui/director/bottom_sheets.dart';

class AppBar1 extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.appBar$,
      builder: (BuildContext context, AsyncSnapshot<bool> appBar) {
        bool isLandscape =
            (MediaQuery.of(context).orientation == Orientation.landscape);
        if (directorService.editingTextAsset == null) {
          if (isLandscape) {
            return _AppBar1Landscape();
          } else {
            return _AppBar1Portrait();
          }
        } else {
          if (isLandscape) {
            return Container(width: Params.getSideMenuWidth(context));
          } else {
            return _AppBar1Portrait();
          }
        }
      },
    );
  }
}

class AppBar2 extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.appBar$,
      builder: (BuildContext context, AsyncSnapshot<bool> appBar) {
        bool isLandscape =
            (MediaQuery.of(context).orientation == Orientation.landscape);
        if (directorService.editingTextAsset == null) {
          if (isLandscape) {
            return _AppBar2Landscape();
          } else {
            return _AppBar2Portrait();
          }
        } else {
          if (isLandscape) {
            return _AppBar2EditingTextLandscape();
          } else {
            return _AppBar2EditingTextPortrait();
          }
        }
      },
    );
  }
}

class _AppBar1Landscape extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    children.add(_ButtonBack());
    if (directorService.selected.layerIndex != -1) {
      children.add(_ButtonDelete());
    } else {
      children.add(Container(height: 48));
    }
    if (directorService.assetSelected?.type == AssetType.video ||
        directorService.assetSelected?.type == AssetType.audio) {
      children.add(_ButtonCut());
    } else if (directorService.assetSelected?.type == AssetType.text) {
      children.add(_ButtonEdit());
    } else {
      children.add(Container(height: 48));
    }
    return Container(
      width: Params.getSideMenuWidth(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _AppBar1Portrait extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: _ButtonBack(),
      title: Text(directorService.project?.title ?? "Untitled Project"),
    );
  }
}

class _AppBar2Landscape extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    children.add(_ButtonAdd());
    if (directorService.layers[0].assets.isNotEmpty &&
        !directorService.isPlaying) {
      children.add(_ButtonPlay());
    }
    if (directorService.isPlaying) {
      children.add(_ButtonPause());
    }
    if (directorService.layers[0].assets.isNotEmpty) {
      children.add(_ButtonGenerate());
    }
    return Container(
      width: Params.getSideMenuWidth(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }
}

class _AppBar2Portrait extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    children.add(_ButtonAdd());
    if (directorService.layers[0].assets.isNotEmpty &&
        !directorService.isPlaying) {
      children.add(_ButtonPlay());
    }
    if (directorService.isPlaying) {
      children.add(_ButtonPause());
    }
    if (directorService.layers[0].assets.isNotEmpty) {
      children.add(_ButtonGenerate());
    }

    List<Widget> children2 = [];
    if (directorService.selected.layerIndex != -1) {
      children2.add(_ButtonDelete());
    }
    if (directorService.assetSelected?.type == AssetType.video ||
        directorService.assetSelected?.type == AssetType.audio) {
      children2.add(_ButtonCut());
    } else if (directorService.assetSelected?.type == AssetType.text) {
      children2.add(_ButtonEdit());
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: children2),
          Row(children: children),
        ],
      ),
    );
  }
}

class _AppBar2EditingTextLandscape extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Params.getSideMenuWidth(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            child: Text('SAVE'),
            onPressed: () {
              directorService.saveTextAsset();
            },
          ),
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              directorService.editingTextAsset = null;
            },
          ),
        ],
      ),
    );
  }
}

class _AppBar2EditingTextPortrait extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    children.add(_ButtonAdd());

    return Container(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            child: Text('SAVE'),
            onPressed: () {
              directorService.saveTextAsset();
            },
          ),
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              directorService.editingTextAsset = null;
            },
          ),
        ],
      ),
    );
  }
}

class _ButtonBack extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back_ios, color: Colors.white),
      tooltip: "Back",
      onPressed: () async {
        bool exit = await directorService.exitAndSaveProject();
        if (exit) Navigator.pop(context);
      },
    );
  }
}

class _ButtonDelete extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "delete",
      tooltip: "Delete selected",
      backgroundColor: Colors.pink,
      mini: MediaQuery.of(context).size.width < 900,
      onPressed: directorService.delete,
      child: Icon(Icons.delete, color: Colors.white),
    );
  }
}

class _ButtonCut extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "cut",
      tooltip: "Cut video selected",
      backgroundColor: Theme.of(context).colorScheme.secondary,
      mini: MediaQuery.of(context).size.width < 900,
      onPressed: directorService.cutVideo,
      child: Icon(Icons.content_cut, color: Colors.white),
    );
  }
}

class _ButtonEdit extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "edit",
      tooltip: "Edit",
      backgroundColor: Theme.of(context).colorScheme.secondary,
      mini: MediaQuery.of(context).size.width < 900,
      child: Icon(Icons.edit, color: Colors.white),
      onPressed: () {
        directorService.editTextAsset();
      },
    );
  }
}

class _ButtonAdd extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "add",
      tooltip: "Add media",
      backgroundColor: Theme.of(context).colorScheme.secondary,
      mini: MediaQuery.of(context).size.width < 900,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AddMediaBottomSheet(),
        );
      },
      child: Icon(Icons.add, color: Colors.white),
    );
  }
}

class _ButtonPlay extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "play",
      tooltip: "Play",
      backgroundColor: Theme.of(context).colorScheme.secondary,
      mini: MediaQuery.of(context).size.width < 900,
      onPressed: directorService.play,
      child: Icon(Icons.play_arrow, color: Colors.white),
    );
  }
}

class _ButtonPause extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "pause",
      tooltip: "Pause",
      backgroundColor: Theme.of(context).colorScheme.secondary,
      mini: MediaQuery.of(context).size.width < 900,
      onPressed: directorService.stop,
      child: Icon(Icons.pause, color: Colors.white),
    );
  }
}

class _ButtonGenerate extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: "generate",
      tooltip: "Generate video",
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      mini: MediaQuery.of(context).size.width < 900,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => SaveVideoBottomSheet(),
        );
      },
      child: Icon(Icons.save, color: Colors.white),
    );
  }
}
