import 'package:flutter_video_editor/model/generated_video.dart';
import 'package:flutter_video_editor/model/project.dart';
import 'package:sqflite/sqflite.dart';

class ProjectDao {
  late Database db;
  bool _isInitialized = false;

  final migrationScripts = [
    '''
create table project (
  _id integer primary key autoincrement
  , title text not null
  , description text
  , date integer not null
  , duration integer not null
  , layersJson text
  , imagePath text
)
''',
    '''
create table generatedVideo (
  _id integer primary key autoincrement
  , projectId integer not null
  , path text not null
  , date integer not null
  , resolution text
  , thumbnail text
)
  ''',
  ];

  Future<void> open() async {
    if (_isInitialized) return;

    db = await openDatabase(
      'project',
      version: migrationScripts.length,
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        for (var i = oldVersion; i < newVersion; i++) {
          await db.execute(migrationScripts[i]);
        }
      },
    );
    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await open();
    }
  }

  Future<Project> insert(Project project) async {
    await _ensureInitialized();
    project.id = await db.insert('project', project.toMap());
    return project;
  }

  Future<GeneratedVideo> insertGeneratedVideo(
    GeneratedVideo generatedVideo,
  ) async {
    await _ensureInitialized();
    generatedVideo.id = await db.insert(
      'generatedVideo',
      generatedVideo.toMap(),
    );
    return generatedVideo;
  }

  Future<Project?> get(int id) async {
    await _ensureInitialized();
    List<Map<String, Object?>> maps = await db.query(
      'project',
      columns: [
        '_id',
        'title',
        'description',
        'date',
        'duration',
        'layersJson',
        'imagePath',
      ],
      where: '_id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Project.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Project>> findAll() async {
    await _ensureInitialized();
    List<Map<String, Object?>> maps = await db.query(
      'project',
      columns: [
        '_id',
        'title',
        'description',
        'date',
        'duration',
        'layersJson',
        'imagePath',
      ],
    );
    return maps.map((m) => Project.fromMap(m)).toList();
  }

  Future<List<GeneratedVideo>> findAllGeneratedVideo(int projectId) async {
    await _ensureInitialized();
    List<Map<String, Object?>> maps = await db.query(
      'generatedVideo',
      columns: ['_id', 'projectId', 'path', 'date', 'resolution', 'thumbnail'],
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: '_id desc',
    );
    return maps.map((m) => GeneratedVideo.fromMap(m)).toList();
  }

  Future<int> delete(int id) async {
    await _ensureInitialized();
    return await db.delete('project', where: '_id = ?', whereArgs: [id]);
  }

  Future<int> deleteGeneratedVideo(int id) async {
    await _ensureInitialized();
    return await db.delete('generatedVideo', where: '_id = ?', whereArgs: [id]);
  }

  Future<int> deleteAll() async {
    await _ensureInitialized();
    return await db.delete('project');
  }

  Future<int> update(Project project) async {
    await _ensureInitialized();
    return await db.update(
      'project',
      project.toMap(),
      where: '_id = ?',
      whereArgs: [project.id],
    );
  }

  Future<void> close() async {
    if (_isInitialized) {
      await db.close();
      _isInitialized = false;
    }
  }
}
