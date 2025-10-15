import 'package:flutter_video_editor/dao/project_dao.dart';
import 'package:flutter_video_editor/service/director/generator.dart';
import 'package:flutter_video_editor/service/director_service.dart';
import 'package:flutter_video_editor/service/generated_video_service.dart';
import 'package:flutter_video_editor/service/project_service.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerSingleton<Logger>(createLog());
  locator.registerSingleton<ProjectDao>(ProjectDao());
  locator.registerSingleton<ProjectService>(ProjectService());
  locator.registerSingleton<Generator>(Generator());
  locator.registerSingleton<DirectorService>(DirectorService());
  locator.registerSingleton<GeneratedVideoService>(GeneratedVideoService());
}

Logger createLog() {
  Logger.level = Level.debug;
  return Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: false,
    ),
    output: null,
  );
}
