import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_video_editor/service/director/generator.dart';
import 'package:flutter_video_editor/service/director_service.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:open_file/open_file.dart';

class ProgressDialog extends StatelessWidget {
  final directorService = locator.get<DirectorService>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: directorService.generator.ffmepegStat$,
      initialData: FFmpegStat(outputPath: ''),
      builder: (BuildContext context, AsyncSnapshot<FFmpegStat> ffmepegStat) {
        final stat = ffmepegStat.data ?? FFmpegStat(outputPath: '');
        String title = '';
        String progressText = '';
        double progress = 0;
        String buttonText = 'CANCEL';
        if ((stat.totalFiles ?? 0) != 0 && (stat.fileNum ?? 0) != 0) {
          title = 'Preprocessing files';
          progress =
              ((stat.fileNum ?? 0) -
                  1 +
                  (stat.time /
                      (directorService.duration == 0
                          ? 1
                          : directorService.duration))) /
              ((stat.totalFiles ?? 1) == 0 ? 1 : (stat.totalFiles ?? 1));
          progressText =
              'File ${(stat.fileNum ?? 0)} of ${(stat.totalFiles ?? 0)}';
        } else if (stat.time > 100) {
          title = 'Building your video';
          progress =
              stat.time /
              (directorService.duration == 0 ? 1 : directorService.duration);
          int remaining =
              ((stat.timeElapsed) *
                      ((directorService.duration == 0
                                  ? 1
                                  : directorService.duration) /
                              (stat.time == 0 ? 1 : stat.time) -
                          1))
                  .floor();
          int minutes = Duration(milliseconds: remaining).inMinutes;
          int seconds =
              Duration(milliseconds: remaining).inSeconds -
              60 * Duration(milliseconds: remaining).inMinutes;
          progressText = '$minutes min $seconds secs remaining';
        } else {
          title = 'Building your video';
          progress =
              stat.time /
              (directorService.duration == 0 ? 1 : directorService.duration);
          progressText = '';
        }
        Widget child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
                Padding(padding: EdgeInsets.symmetric(vertical: 4)),
                Text(progressText),
                Padding(padding: EdgeInsets.symmetric(vertical: 1)),
              ],
            ),
          ],
        );
        if (stat.finished) {
          title = 'Your video has been saved in the gallery';
          buttonText = 'OK';
          child = LinearProgressIndicator(value: progress, color: Colors.white);
        } else if (stat.error) {
          title = 'Error';
          buttonText = 'OK';
          child = Text(
            'An unexpected error occurred. We will work on it. '
            'Please try again or upgrade to new versions of the app if the error persists.',
          );
        }
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: MediaQuery.of(context).size.width / 2,
                child: child,
              ),
            ],
          ),
          actions: [
            stat.finished
                ? TextButton(
                    child: Text("OPEN VIDEO"),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () async {
                      OpenFile.open(stat.outputPath);
                    },
                  )
                : Container(),
            TextButton(
              child: Text(buttonText),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
                // Delay to not see changes in dialog
                Future.delayed(Duration(milliseconds: 100), () {
                  directorService.generator.finishVideoGeneration();
                });
              },
            ),
          ],
        );
      },
    );
  }
}
