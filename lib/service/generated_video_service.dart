import 'dart:io';
import 'package:flutter_video_editor/dao/project_dao.dart';
import 'package:flutter_video_editor/model/generated_video.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:rxdart/rxdart.dart';

class GeneratedVideoService {
  final ProjectDao projectDao = locator.get<ProjectDao>();

  List<GeneratedVideo> generatedVideoList = [];
  int? projectId;

  final BehaviorSubject<bool> _generatedVideoListChanged =
      BehaviorSubject.seeded(false);
  Stream<bool> get generatedVideoListChanged$ =>
      _generatedVideoListChanged.stream;
  bool get generatedVideoListChanged => _generatedVideoListChanged.value;

  GeneratedVideoService() {
    open();
  }

  void dispose() {
    _generatedVideoListChanged.close();
  }

  void open() async {
    await projectDao.open();
  }

  void refresh(int _projectId) async {
    projectId = _projectId;
    generatedVideoList = [];
    _generatedVideoListChanged.add(true);
    generatedVideoList = await projectDao.findAllGeneratedVideo(projectId!);
    _generatedVideoListChanged.add(true);
  }

  bool fileExists(int index) {
    return File(generatedVideoList[index].path).existsSync();
  }

  Future<void> delete(int index) async {
    if (generatedVideoList[index].id == null) {
      print("Generated video id is null. Deletion failed...");
      return;
    }
    if (fileExists(index)) File(generatedVideoList[index].path).deleteSync();
    await projectDao.deleteGeneratedVideo(generatedVideoList[index].id!);
    if (projectId != null) {
      refresh(projectId!);
    } else {
      print("projectId is null. Cannot refresh generated videos.");
    }
  }
}
