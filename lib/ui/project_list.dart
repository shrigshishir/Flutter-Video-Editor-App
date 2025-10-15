import 'dart:io';
import 'package:flutter_video_editor/model/project.dart';
import 'package:flutter_video_editor/service/project_service.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:flutter_video_editor/ui/common/animated_dialog.dart';
import 'package:flutter_video_editor/ui/director.dart';
import 'package:flutter_video_editor/ui/generated_video_list.dart';
import 'package:flutter_video_editor/ui/project_edit.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';

class ProjectList extends StatelessWidget {
  final projectService = locator.get<ProjectService>();

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        (MediaQuery.of(context).orientation == Orientation.landscape);
    return Scaffold(
      appBar: AppBar(title: Text('Video Editor'), centerTitle: true),

      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          isLandscape
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CreateProject(),
                    SizedBox(width: 20),
                    ProjectListView(),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 20),
                    _CreateProject(),
                    SizedBox(height: 20),
                    ProjectListView(),
                  ],
                ),
        ],
      ),
    );
  }
}

class ProjectListView extends StatelessWidget {
  final projectService = locator.get<ProjectService>();

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        (MediaQuery.of(context).orientation == Orientation.landscape);
    return Container(
      height:
          (MediaQuery.of(context).size.height - 200) * (isLandscape ? 1 : 0.82),
      width: MediaQuery.of(context).size.width * (isLandscape ? 0.77 : 0.95),
      child: StreamBuilder(
        stream: projectService.projectListChanged$,
        initialData: false,
        builder: (BuildContext context, AsyncSnapshot<bool> layersChanged) {
          return GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.0,
            mainAxisSpacing: 4.0,
            crossAxisSpacing: 4.0,
            scrollDirection: isLandscape ? Axis.horizontal : Axis.vertical,
            children: projectService.projectList
                .asMap()
                .map((index, project) {
                  return MapEntry(
                    index,
                    _ProjectCard(projectService.projectList[index], index),
                  );
                })
                .values
                .toList(),
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final projectService = locator.get<ProjectService>();
  final Project project;
  final int index;

  _ProjectCard(this.project, this.index);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 5,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        child: Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 16.0 / 9.0,
                    child: (project.imagePath != null)
                        ? Image.file(
                            File(project.imagePath!),
                            fit: BoxFit.cover,
                          )
                        : Container(color: Colors.grey[300]),
                  ),
                  AspectRatio(
                    aspectRatio: 16.0 / 9.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: FractionalOffset.topRight,
                          end: FractionalOffset.bottomLeft,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.black.withOpacity(0.0),
                          ],
                          stops: [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: PopupMenuButton<int>(
                      icon: Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (int result) {
                        if (result == 1) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DirectorScreen(project),
                            ),
                          );
                        } else if (result == 2) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProjectEdit(project),
                            ),
                          );
                        } else if (result == 3) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GeneratedVideoList(project),
                            ),
                          );
                        } else if (result == 9) {
                          AnimatedDialog.show(
                            context,
                            title: 'Confirm delete',
                            child: Text('Do you want to delete this video?'),
                            button1Text: 'Cancel',
                            onPressedButton1: () {
                              Navigator.of(context).pop();
                            },
                            button2Text: 'OK',
                            onPressedButton2: () {
                              projectService.delete(index);
                              Navigator.of(context).pop();
                            },
                          );
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<int>>[
                            const PopupMenuItem<int>(
                              value: 1,
                              child: Text('Design'),
                            ),
                            const PopupMenuItem<int>(
                              value: 2,
                              child: Text('Edit title and description'),
                            ),
                            const PopupMenuItem<int>(
                              value: 3,
                              child: Text('View generated videos'),
                            ),
                            const PopupMenuDivider(height: 10),
                            const PopupMenuItem<int>(
                              value: 9,
                              child: Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      project.title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Padding(padding: EdgeInsets.symmetric(vertical: 0.0)),
                    Text(
                      DateFormat.yMMMd().format(project.date),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DirectorScreen(project)),
          );
        },
      ),
    );
  }
}

class _CreateProject extends StatelessWidget {
  final projectService = locator.get<ProjectService>();

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        (MediaQuery.of(context).orientation == Orientation.landscape);
    return Card(
      elevation: 5,
      child: InkWell(
        child: DottedBorder(
          options: RectDottedBorderOptions(
            color: Colors.grey,
            strokeWidth: 2,
            dashPattern: [6, 3],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            child: Container(
              height:
                  (MediaQuery.of(context).size.height - 100) *
                      (isLandscape ? 1 : 0.17) -
                  10,
              width:
                  MediaQuery.of(context).size.width *
                      (isLandscape ? 0.20 : 0.95) -
                  10,
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.grey.shade500, size: 38.0),
                  Text(
                    'NEW VIDEO',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProjectEdit(null)),
          );
        },
      ),
    );
  }
}
