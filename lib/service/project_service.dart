import 'dart:io';
import 'package:flutter_video_editor/dao/project_dao.dart';
import 'package:flutter_video_editor/model/project.dart';
import 'package:flutter_video_editor/service_locator.dart';
import 'package:rxdart/rxdart.dart';

class ProjectService {
  final ProjectDao projectDao = locator.get<ProjectDao>();

  List<Project> projectList = [];
  Project? project;

  final BehaviorSubject<bool> _projectListChanged = BehaviorSubject.seeded(
    false,
  );
  Stream<bool> get projectListChanged$ => _projectListChanged.stream;
  bool get projectListChanged => _projectListChanged.value;

  ProjectService() {
    load();
  }

  void dispose() {
    _projectListChanged.close();
  }

  void load() async {
    await projectDao.open();
    refresh();
  }

  void refresh() async {
    projectList = await projectDao.findAll();
    _projectListChanged.add(true);
    checkSomeFileNotExists();
  }

  void checkSomeFileNotExists() {
    for (int i = 0; i < projectList.length; i++) {
      if (projectList[i].imagePath != null &&
          !File(projectList[i].imagePath!).existsSync()) {
        print('${projectList[i].imagePath} does not exist');
        projectList[i].imagePath = null;
      }
    }
  }

  Project createNew() {
    return Project(title: '', duration: 0, date: DateTime.now());
  }

  Future<void> insert(Project _project) async {
    _project.date = DateTime.now();
    await projectDao.insert(_project);
    refresh();
  }

  Future<void> update(Project _project) async {
    await projectDao.update(_project);
    refresh();
  }

  Future<void> delete(int index) async {
    if (projectList[index].id == null) {
      print("Project id is null. Cannot delete project.");
      return;
    }
    await projectDao.delete(projectList[index].id!);
    refresh();
  }
}
