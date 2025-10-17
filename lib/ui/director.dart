import 'dart:core';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor/model/fonts.dart';
import 'package:flutter_video_editor/model/model.dart';
import 'package:flutter_video_editor/model/project.dart';
import 'package:flutter_video_editor/service/director_service.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:flutter_video_editor/ui/common/animated_dialog.dart';
import 'package:flutter_video_editor/ui/director/app_bar.dart';
import 'package:flutter_video_editor/ui/director/asset_selection.dart';
import 'package:flutter_video_editor/ui/director/audio_trimmer.dart';
import 'package:flutter_video_editor/ui/director/drag_closest.dart';
import 'package:flutter_video_editor/ui/director/fullscreen_text_editor_wrapper.dart';
import 'package:flutter_video_editor/ui/director/params.dart';
import 'package:flutter_video_editor/ui/director/text_trimmer.dart';
import 'package:flutter_video_editor/ui/director/video_photo_clipper.dart';
import 'package:flutter_video_editor/ui/director/volume_control.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';

class DirectorScreen extends StatefulWidget {
  final Project project;
  const DirectorScreen(this.project, {super.key});

  @override
  State<DirectorScreen> createState() => _DirectorScreen(project);
}

class _DirectorScreen extends State<DirectorScreen>
    with WidgetsBindingObserver {
  final directorService = locator.get<DirectorService>();
  late final StreamSubscription<bool> _dialogFilesNotExistSubscription;

  _DirectorScreen(Project project) {
    directorService.setProject(project);
    _dialogFilesNotExistSubscription = directorService.filesNotExist$.listen((
      val,
    ) {
      if (val) {
        // Delayed because widgets are building
        Future.delayed(const Duration(milliseconds: 100), () {
          AnimatedDialog.show(
            context,
            title: 'Some assets have been deleted',
            child: const Text(
              'To continue you must recover deleted assets in your device '
              'or remove them from the timeline (marked in red).',
            ),
            button2Text: 'OK',
            onPressedButton2: () {
              Navigator.of(context).pop();
            },
          );
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Configure image cache for better quality timeline thumbnails
    PaintingBinding.instance.imageCache.maximumSize =
        1000; // Increase cache size
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        200 << 20; // 200MB cache
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dialogFilesNotExistSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      Params.fixHeight = true;
    } else if (state == AppLifecycleState.resumed) {
      Params.fixHeight = false;
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    // To release memory
    imageCache.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.grey.shade900,
      ),
      child: WillPopScope(
        onWillPop: () async {
          if (directorService.editingTextAsset != null) {
            directorService.editingTextAsset = null;
            return false;
          }
          bool exit = await directorService.exitAndSaveProject();
          if (exit) Navigator.pop(context);
          return false;
        },
        child: Scaffold(
          // body: Colors.grey.shade900,
          body: GestureDetector(
            onTap: () {
              if (directorService.editingTextAsset == null) {
                directorService.select(-1, -1);
              }
              // Hide keyboard
              FocusScope.of(context).requestFocus(FocusNode());
            },
            child: Container(
              color: Colors.grey.shade900,
              child: const _Director(),
            ),
          ),
        ),
      ),
    );
  }
}

class _Director extends StatelessWidget {
  const _Director({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    return Column(
      children: <Widget>[
        Container(
          // height:
          //     Params.getPlayerHeight(context) +
          //     (MediaQuery.of(context).orientation == Orientation.landscape
          //         ? 0
          //         : Params.APP_BAR_HEIGHT * 2),
          child: MediaQuery.of(context).orientation == Orientation.landscape
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[AppBar1(), const _Video(), AppBar2()],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[AppBar1(), const _Video(), AppBar2()],
                ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: Container(
            child: Stack(
              alignment: const Alignment(0, -1),
              children: <Widget>[
                SingleChildScrollView(
                  child: Stack(
                    alignment: const Alignment(-1, -1),
                    children: <Widget>[
                      GestureDetector(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification scrollState) {
                            if (scrollState is ScrollEndNotification) {
                              directorService.endScroll();
                            }
                            return false;
                          },
                          child: const _TimeLine(),
                        ),
                        onScaleStart: (ScaleStartDetails details) {
                          directorService.scaleStart();
                        },
                        onScaleUpdate: (ScaleUpdateDetails details) {
                          directorService.scaleUpdate(details.horizontalScale);
                        },
                        onScaleEnd: (ScaleEndDetails details) {
                          directorService.scaleEnd();
                        },
                      ),
                      const _LayerHeaders(),
                    ],
                  ),
                ),
                const _PositionLine(),
                const _PositionMarker(),
                FullScreenTextEditorWrapper(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PositionLine extends StatelessWidget {
  const _PositionLine({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: Params.getTimelineHeight(context) - 4,
      margin: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      color: Colors.grey.shade100,
    );
  }
}

class _PositionMarker extends StatelessWidget {
  const _PositionMarker({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    return Container(
      width: 58,
      height: Params.RULER_HEIGHT - 4,
      margin: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      color: Theme.of(context).colorScheme.secondary,
      child: StreamBuilder<int>(
        stream: directorService.position$,
        initialData: 0,
        builder: (BuildContext context, AsyncSnapshot<int> position) {
          return Center(
            child: Text(
              '${directorService.positionMinutes}:${directorService.positionSeconds}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}

class _TimeLine extends StatelessWidget {
  const _TimeLine({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    return StreamBuilder<bool>(
      stream: directorService.layersChanged$,
      initialData: false,
      builder: (BuildContext context, AsyncSnapshot<bool> layersChanged) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: directorService.scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Ruler(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: directorService.layers
                    .asMap()
                    .map((index, layer) => MapEntry(index, _LayerAssets(index)))
                    .values
                    .toList(),
              ),
              Container(height: Params.getLayerBottom(context)),
            ],
          ),
        );
      },
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    return CustomPaint(
      painter: RulerPainter(context),
      child: Container(
        height: Params.RULER_HEIGHT - 4,
        width:
            MediaQuery.of(context).size.width +
            directorService.pixelsPerSecond * directorService.duration / 1000,
        margin: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      ),
    );
  }
}

class RulerPainter extends CustomPainter {
  final BuildContext context;
  RulerPainter(this.context);

  getSecondsPerDivision(double pixPerSec) {
    if (pixPerSec > 40) {
      return 1;
    } else if (pixPerSec > 20) {
      return 2;
    } else if (pixPerSec > 10) {
      return 5;
    } else if (pixPerSec > 4) {
      return 10;
    } else if (pixPerSec > 1.5) {
      return 30;
    } else {
      return 60;
    }
  }

  getTimeText(int seconds) {
    return '${(seconds / 60).floor() < 10 ? '0' : ''}'
        '${(seconds / 60).floor()}'
        '.${seconds - (seconds / 60).floor() * 60 < 10 ? '0' : ''}'
        '${seconds - (seconds / 60).floor() * 60}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final directorService = locator.get<DirectorService>();
    final double width =
        directorService.duration / 1000 * directorService.pixelsPerSecond +
        MediaQuery.of(context).size.width;

    final paint = Paint();
    paint.color = Theme.of(context).primaryColor;
    Rect rect = Rect.fromLTWH(0, 2, width, size.height - 4);
    canvas.drawRect(rect, paint);

    paint.color = Colors.grey.shade400;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;

    Path path = Path();
    path.moveTo(0, size.height - 2);
    path.relativeLineTo(width, 0);
    path.close();
    canvas.drawPath(path, paint);

    int secondsPerDivision = getSecondsPerDivision(
      directorService.pixelsPerSecond,
    );
    final double pixelsPerDivision =
        secondsPerDivision * directorService.pixelsPerSecond;
    final int numberOfDivisions =
        ((width - MediaQuery.of(context).size.width / 2) / pixelsPerDivision)
            .floor();

    for (int i = 0; i <= numberOfDivisions; i++) {
      int seconds = i * secondsPerDivision;
      String text = getTimeText(seconds);

      final TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        text: TextSpan(
          text: text,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
        ),
      );

      textPainter.layout();
      double x = MediaQuery.of(context).size.width / 2 + i * pixelsPerDivision;
      textPainter.paint(canvas, Offset(x + 6, 6));

      Path path = Path();
      path.moveTo(x + 1, size.height - 4);
      path.relativeLineTo(0, -8);
      path.moveTo(x + 1 + 0.5 * pixelsPerDivision, size.height - 4);
      path.relativeLineTo(0, -2);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _LayerHeaders extends StatelessWidget {
  const _LayerHeaders({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: Params.RULER_HEIGHT - 4,
          width: 33,
          color: Colors.transparent,
          margin: const EdgeInsets.fromLTRB(0, 2, 0, 2),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: directorService.layers
              .asMap()
              .map(
                (index, layer) => MapEntry(index, _LayerHeader((layer).type)),
              )
              .values
              .toList(),
        ),
      ],
    );
  }
}

class _Video extends StatefulWidget {
  const _Video({Key? key}) : super(key: key);

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  // Text Editing Variables
  Asset? _activeItem;
  Offset? _initPos;
  Offset? _currentPos;
  double? _currentScale;
  double? _currentRotation;
  bool _inAction = false;

  @override
  Widget build(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    return StreamBuilder<int>(
      stream: directorService.position$,
      builder: (BuildContext context, AsyncSnapshot<int> position) {
        var backgroundContainer = Container(
          color: Colors.black,
          height: Params.getPlayerHeight(context),
          width: Params.getPlayerWidth(context),
        );
        if (directorService.layerPlayers.isEmpty) {
          return backgroundContainer;
        }
        final layerPlayer = directorService.layerPlayers[0];
        if (layerPlayer == null) {
          return backgroundContainer;
        }
        int assetIndex = layerPlayer.currentAssetIndex;
        if (assetIndex == -1 ||
            assetIndex >= directorService.layers[0].assets.length) {
          return backgroundContainer;
        }
        AssetType type = directorService.layers[0].assets[assetIndex].type;
        return Container(
          height: Params.getPlayerHeight(context),
          width: Params.getPlayerWidth(context),
          child: GestureDetector(
            onScaleStart: (details) {
              if (_activeItem == null) return;

              _initPos = details.focalPoint;
              _currentPos = Offset(_activeItem!.x, _activeItem!.y);
              _currentScale = _activeItem?.scale;
              _currentRotation = _activeItem?.rotation;
              _inAction = true;
            },
            onScaleUpdate: (details) {
              if (_activeItem == null) return;
              final screenWidth = Params.getPlayerWidth(context);
              final screenHeight = Params.getPlayerHeight(context);
              final delta = details.focalPoint - _initPos!;
              final left = (delta.dx / screenWidth) + _currentPos!.dx;
              final top = (delta.dy / screenHeight) + _currentPos!.dy;

              setState(() {
                _activeItem!.x = left.clamp(0.0, 1.0);
                _activeItem!.y = top.clamp(0.0, 1.0);
                _activeItem!.rotation = details.rotation + _currentRotation!;
                _activeItem!.scale = (details.scale * _currentScale!).clamp(
                  0.5,
                  3.0,
                );
              });
            },
            onScaleEnd: (details) {
              _inAction = false;
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                backgroundContainer,
                (type == AssetType.video && layerPlayer.videoController != null)
                    ? VideoPlayer(layerPlayer.videoController!)
                    : _ImagePlayer(
                        directorService.layers[0].assets[assetIndex],
                      ),
                _TextPlayer(
                  activeItem: _activeItem,
                  inAction: _inAction,
                  onItemSelected: (asset, position) {
                    if (_inAction) return;
                    setState(() {
                      _inAction = true;
                      _activeItem = asset;
                      _initPos = position;
                      _currentPos = Offset(asset.x, asset.y);
                      _currentScale = asset.scale;
                      _currentRotation = asset.rotation;
                    });
                  },
                  onItemDeselected: () {
                    setState(() {
                      _activeItem = null;
                      _inAction = false;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImagePlayer extends StatelessWidget {
  final Asset asset;
  const _ImagePlayer(this.asset, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    if (asset.deleted) return Container();
    return StreamBuilder<int>(
      stream: directorService.position$,
      initialData: 0,
      builder: (BuildContext context, AsyncSnapshot<int> position) {
        if (directorService.layerPlayers.isEmpty ||
            directorService.layerPlayers[0] == null) {
          return Container();
        }
        int assetIndex = directorService.layerPlayers[0]!.currentAssetIndex;

        // Additional safety checks
        if (assetIndex == -1 ||
            directorService.layers.isEmpty ||
            directorService.layers[0].assets.isEmpty ||
            assetIndex >= directorService.layers[0].assets.length) {
          return Container();
        }

        double ratio =
            ((directorService.position -
                        directorService.layers[0].assets[assetIndex].begin) /
                    directorService.layers[0].assets[assetIndex].duration)
                .clamp(0.0, 1.0);
        return KenBurnEffect(
          asset.thumbnailMedPath ?? asset.srcPath,
          ratio,
          zSign: asset.kenBurnZSign,
          xTarget: asset.kenBurnXTarget,
          yTarget: asset.kenBurnYTarget,
        );
      },
    );
  }
}

class KenBurnEffect extends StatelessWidget {
  final String path;
  final double ratio;
  // Effect configuration
  final int zSign;
  final double xTarget;
  final double yTarget;

  const KenBurnEffect(
    this.path,
    this.ratio, {
    this.zSign = 0, // Options: {-1, 0, +1}
    this.xTarget = 0, // Options: {0, 0.5, 1}
    this.yTarget = 0, // Options; {0, 0.5, 1}
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Start and end positions
    double xStart = (zSign == 1) ? 0 : (0.5 - xTarget);
    double xEnd = (zSign == 1)
        ? (0.5 - xTarget)
        : ((zSign == -1) ? 0 : (xTarget - 0.5));
    double yStart = (zSign == 1) ? 0 : (0.5 - yTarget);
    double yEnd = (zSign == 1)
        ? (0.5 - yTarget)
        : ((zSign == -1) ? 0 : (yTarget - 0.5));
    double zStart = (zSign == 1) ? 0 : 1;
    double zEnd = (zSign == -1) ? 0 : 1;

    // Interpolation
    double x = xStart * (1 - ratio) + xEnd * ratio;
    double y = yStart * (1 - ratio) + yEnd * ratio;
    double z = zStart * (1 - ratio) + zEnd * ratio;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Transform.translate(
            offset: Offset(
              x * 0.2 * Params.getPlayerWidth(context),
              y * 0.2 * Params.getPlayerHeight(context),
            ),
            child: Transform.scale(
              scale: 1 + z * 0.2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
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

class _TextPlayer extends StatefulWidget {
  final Asset? activeItem;
  final bool inAction;
  final Function(Asset, Offset) onItemSelected;
  final Function() onItemDeselected;

  const _TextPlayer({
    Key? key,
    required this.activeItem,
    required this.inAction,
    required this.onItemSelected,
    required this.onItemDeselected,
  }) : super(key: key);

  @override
  State<_TextPlayer> createState() => _TextPlayerState();
}

class _TextPlayerState extends State<_TextPlayer> {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: directorService.position$,
      initialData: directorService.position,
      builder: (BuildContext context, AsyncSnapshot<int> positionSnapshot) {
        final currentPosition = positionSnapshot.data ?? 0;

        return StreamBuilder<Asset?>(
          stream: directorService.editingTextAsset$,
          initialData: null,
          builder: (BuildContext context, AsyncSnapshot<Asset?> editingTextAsset) {
            // If we're editing a text asset with fullscreen editor, hide all text placeholders
            if (editingTextAsset.data != null) {
              return Container(); // Hide text placeholders when fullscreen editor is active
            }

            // Get all text assets that should be visible at current position
            List<Widget> visibleTextWidgets = [];

            if (directorService.layers.length > 1) {
              // Make sure text layer exists
              for (Asset asset in directorService.layers[1].assets) {
                if (asset.type == AssetType.text &&
                    asset.title.isNotEmpty &&
                    !asset.deleted &&
                    _isAssetVisibleAtPosition(asset, currentPosition)) {
                  visibleTextWidgets.add(_buildItemWidget(asset));
                }
              }
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [...visibleTextWidgets],
            );
          },
        );
      },
    );
  }

  /// Check if a text asset should be visible at the given position
  bool _isAssetVisibleAtPosition(Asset asset, int position) {
    final startTime = asset.begin;
    final endTime = asset.begin + asset.duration;
    return position >= startTime && position < endTime;
  }

  /// Builds the widget for each text asset
  Widget _buildItemWidget(Asset e) {
    final screenWidth = Params.getPlayerWidth(context);
    final screenHeight = Params.getPlayerHeight(context);
    Font font = Font.getByPath(e.font);

    // Build the text widget
    Widget textWidget = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.85),
      child: Text(
        e.title,
        textAlign: TextAlign.center,
        style: TextStyle(
          height: 1,
          fontSize:
              e.fontSize * screenWidth / MediaQuery.of(context).textScaleFactor,
          fontStyle: font.style,
          fontFamily: font.family,
          fontWeight: font.weight,
          color: Color(e.fontColor),
          backgroundColor: Color(e.boxcolor),
        ),
      ),
    );

    return Positioned(
      left: e.x * screenWidth,
      top: e.y * screenHeight,
      child: FractionalTranslation(
        translation: const Offset(
          -0.5,
          -0.5,
        ), // Center text by translating -50% of its own size
        child: Transform.scale(
          scale: e.scale,
          child: Transform.rotate(
            angle: e.rotation,
            child: Listener(
              onPointerDown: (details) {
                widget.onItemSelected(e, details.position);
              },
              onPointerUp: (details) {
                widget.onItemDeselected();
              },
              child: GestureDetector(
                onDoubleTap: () {
                  // Handle double-tap to edit text - use proper workflow
                  // First select the asset, then call editTextAsset
                  directorService.select(
                    1,
                    directorService.layers[1].assets.indexOf(e),
                  );
                  directorService.editTextAsset();
                },
                child: Container(
                  decoration: widget.activeItem == e
                      ? BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(4.0),
                        )
                      : null,
                  child: textWidget,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerHeader extends StatelessWidget {
  final String type;
  const _LayerHeader(this.type, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      height: Params.getLayerHeight(context, type),
      width: 28.0,
      margin: const EdgeInsets.fromLTRB(0, 1, 1, 1),
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Icon(
        type == "video_photo"
            ? Icons.videocam
            : type == "text"
            ? Icons.text_fields
            : Icons.music_note,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

class _LayerAssets extends StatelessWidget {
  final int layerIndex;
  const _LayerAssets(this.layerIndex, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    return Stack(
      alignment: const Alignment(0, 0),
      children: [
        // Layer 2 (audio) uses absolute positioning like text layers
        (layerIndex == 2)
            ? Container(
                height: Params.getLayerHeight(
                  context,
                  directorService.layers[layerIndex].type,
                ),
                width:
                    MediaQuery.of(context).size.width +
                    directorService.pixelsPerSecond *
                        directorService.duration /
                        1000,
                margin: const EdgeInsets.all(1),
                child: Stack(
                  children: directorService.layers[layerIndex].assets
                      .asMap()
                      .map(
                        (assetIndex, asset) => MapEntry(
                          assetIndex,
                          Positioned(
                            left:
                                MediaQuery.of(context).size.width / 2 +
                                asset.begin *
                                    directorService.pixelsPerSecond /
                                    1000.0,
                            child: _Asset(layerIndex, assetIndex),
                          ),
                        ),
                      )
                      .values
                      .toList(),
                ),
              )
            : Container(
                height: Params.getLayerHeight(
                  context,
                  directorService.layers[layerIndex].type,
                ),
                margin: const EdgeInsets.all(1),
                child: Row(
                  children: [
                    // Half left screen in blank
                    Container(width: MediaQuery.of(context).size.width / 2),
                    Row(
                      children: directorService.layers[layerIndex].assets
                          .asMap()
                          .map(
                            (assetIndex, asset) => MapEntry(
                              assetIndex,
                              _Asset(layerIndex, assetIndex),
                            ),
                          )
                          .values
                          .toList(),
                    ),
                    Container(width: MediaQuery.of(context).size.width / 2 - 2),
                  ],
                ),
              ),
        AssetSelection(layerIndex),
        // Enable enhanced trimmer for text assets (Layer 1)
        (layerIndex == 1)
            ? TextTrimmerOverlay(layerIndex)
            : Container(), // Highlight overlay
        (layerIndex == 1)
            ? TextTrimmer(layerIndex, false)
            : Container(), // Start trimmer
        (layerIndex == 1)
            ? TextTrimmer(layerIndex, true)
            : Container(), // End trimmer
        // Enable clipper for video/photo assets (Layer 0)
        (layerIndex == 0)
            ? VideoPhotoClipperOverlay(layerIndex)
            : Container(), // Clip highlight overlay
        (layerIndex == 0)
            ? VideoPhotoClipper(layerIndex, false)
            : Container(), // Start clipper
        (layerIndex == 0)
            ? VideoPhotoClipper(layerIndex, true)
            : Container(), // End clipper
        // Enable trimmer for audio assets (Layer 2)
        (layerIndex == 2)
            ? AudioTrimmerOverlay(layerIndex)
            : Container(), // Audio trim highlight overlay
        (layerIndex == 2)
            ? AudioTrimmer(layerIndex, false)
            : Container(), // Start audio trimmer
        (layerIndex == 2)
            ? AudioTrimmer(layerIndex, true)
            : Container(), // End audio trimmer
        (layerIndex != 1 && layerIndex != 0)
            ? DragClosest(layerIndex)
            : Container(),
      ],
    );
  }
}

class _Asset extends StatelessWidget {
  final int layerIndex;
  final int assetIndex;
  const _Asset(this.layerIndex, this.assetIndex, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final directorService = locator.get<DirectorService>();
    Asset asset = directorService.layers[layerIndex].assets[assetIndex];
    Color backgroundColor = Colors.transparent;
    Color borderColor = Colors.transparent;
    if (asset.deleted) {
      backgroundColor = Colors.red.shade200;
      borderColor = Colors.red;
    } else if (layerIndex == 0) {
      backgroundColor = Colors.blue.shade200;
      borderColor = Colors.blue;
    } else if (layerIndex == 1 && asset.title != '') {
      backgroundColor = Color(0xFF3B5998);
      borderColor = Colors.blue;
    } else if (layerIndex == 2) {
      backgroundColor = Colors.orange.shade200;
      borderColor = Colors.orange;
    }
    return GestureDetector(
      child: Container(
        height: Params.getLayerHeight(
          context,
          directorService.layers[layerIndex].type,
        ),
        width: asset.duration * directorService.pixelsPerSecond / 1000.0,
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: BorderSide(width: 2, color: borderColor),
            bottom: BorderSide(width: 2, color: borderColor),
            left: BorderSide(
              width: (assetIndex == 0) ? 1 : 0,
              color: borderColor,
            ),
            right: BorderSide(width: 1, color: borderColor),
          ),
          image: (() {
            if (asset.deleted || directorService.isGenerating) return null;

            // If asset is an image, use the source path directly.
            if (asset.type == AssetType.image) {
              final path = asset.srcPath;
              if (path.isNotEmpty) {
                return DecorationImage(
                  image: FileImage(File(path)),
                  fit: BoxFit.cover,
                  alignment: Alignment.topLeft,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                );
              }
            }

            // If asset is a video, prefer thumbnails (medium -> low), otherwise don't try to decode the video file.
            final thumb = _getBestThumbnailPath(asset);
            if (thumb.isNotEmpty && thumb != asset.srcPath) {
              final thumbFile = File(thumb);
              if (thumbFile.existsSync()) {
                return DecorationImage(
                  image: FileImage(thumbFile),
                  fit: BoxFit.cover,
                  alignment: Alignment.topLeft,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                );
              }
            }

            // No valid image available.
            return null;
          }()),
        ),
        // Add volume control for video assets and text for text assets
        child: _buildAssetChild(context, layerIndex, assetIndex, asset),
      ),
      onTap: () => directorService.select(layerIndex, assetIndex),
      onLongPressStart: (LongPressStartDetails details) {
        directorService.dragStart(layerIndex, assetIndex);
      },
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
        directorService.dragSelected(
          layerIndex,
          assetIndex,
          details.offsetFromOrigin.dx,
          MediaQuery.of(context).size.width,
        );
      },
      onLongPressEnd: (LongPressEndDetails details) {
        directorService.dragEnd();
      },
    );
  }

  Widget _buildAssetChild(
    BuildContext context,
    int layerIndex,
    int assetIndex,
    Asset asset,
  ) {
    if (layerIndex == 1) {
      // Text layer - show title
      return Center(child: Text(asset.title));
    } else if ((layerIndex == 0 && asset.type == AssetType.video) ||
        (layerIndex == 2 && asset.type == AssetType.audio)) {
      // Video assets (Layer 0) and Audio assets (Layer 2) - show volume control
      return Stack(
        children: [
          Positioned(
            top: 4,
            left: 4,
            child: VolumeIndicatorWidget(
              volume: asset.volume,
              onTap: () {
                _showVolumePopup(context, layerIndex, assetIndex, asset);
              },
            ),
          ),
        ],
      );
    } else {
      // Other assets - no overlay
      return const SizedBox.shrink();
    }
  }

  void _showVolumePopup(
    BuildContext context,
    int layerIndex,
    int assetIndex,
    Asset asset,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Transparent background that closes popup when tapped
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),
          // Volume popup positioned near the volume button
          Positioned(
            left: position.dx - 60, // Position to the left of the button
            top:
                position.dy -
                80, // Position above the button to show the full vertical slider
            child: VolumeSliderPopup(
              layerIndex: layerIndex,
              assetIndex: assetIndex,
              asset: asset,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the best available thumbnail path for display quality
  /// Prioritizes: original source (for images) > medium thumbnail > low thumbnail
  String _getBestThumbnailPath(Asset asset) {
    // For images, prefer original source for best quality
    if (asset.type == AssetType.image) {
      return asset.srcPath;
    }

    // For videos, prefer medium quality thumbnail over low quality
    return asset.thumbnailMedPath ?? asset.thumbnailPath ?? asset.srcPath;
  }
}
