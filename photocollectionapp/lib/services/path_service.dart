import 'dart:io';
import 'package:path_provider/path_provider.dart' as pp;
//import 'package:path/path.dart' as p;
//import '../models/photo_local.dart';
//import '../utils/datetime_utils.dart';
//import '../utils/logger.dart';

class PathService {
  // We need the ApplicationDocumentsDirectory but the getter is async,
  // which infects averything with async/await. This is a workaround and
  // we rely on init() to be called from main().

  // --- Singleton pattern (alternative to D.I.) ----------
  /*
  // Singleton instance.
  static PathService? _instance;
  // Public factory ctor.
  factory PathService(/* optional deps */) {
    _instance ??= PathService._internal(/* optional deps */);
    return _instance!;
  }
  // Private ctor
  PathService._internal(/* optional deps */);
 
  // Ensure init runs exactly once. Avoid singleton race condition.
  Future<void>? _initFuture;
  
  Future<void> init() {
    _initFuture ??= initialize();
    return _initFuture!;
  }
  */
  // ------------------------------------------------------

  Directory? _appDocDir; // cached value after init.

  // Call once during app startup.
  Future<void> initialize() async {
    if (null != _appDocDir) return; // already initialized
    _appDocDir = await pp.getApplicationDocumentsDirectory();
  }

  // Get ApplicationDocumentsDirectory without async.
  Directory get applicationDocumentsDirectory {
    if (null == _appDocDir) {
      throw Exception('PathService not initialized');
    }
    return _appDocDir!;
  }

  /* TODO: This however depends on user id.
  Future<Directory> getUserDirectory() async {
    final Directory root = await getApplicationDocumentsDirectory();
    final Directory dir =
        (userId == null)
            ? Directory(p.join(root.path, "anon"))
            : Directory(p.join(root.path, userId));
    return dir;
  }
  */
}
