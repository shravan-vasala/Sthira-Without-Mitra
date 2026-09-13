import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/progress_photo.dart';

class MediaRepository {
  late Isar _isar;
  late String _baseDir;

  Isar get isar => _isar;

  Future<void> init(Isar isar) async {
    _isar = isar;
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      _baseDir = '${appDir.path}/trufit_media';
      await Directory(_baseDir).create(recursive: true);
      await Directory('$_baseDir/progress_photos').create(recursive: true);
    } else {
      _baseDir = 'trufit_media';
    }
  }

  // Save any media file to a given category subdirectory
  Future<String> saveMediaFile(String sourcePath, String category) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuidStr = const Uuid().v4();
    final extension = sourcePath.split('.').last.toLowerCase();
    final ext = ['jpg', 'jpeg', 'png', 'webp'].contains(extension) ? extension : 'jpg';
    final relPath = '$category/${category}_${timestamp}_$uuidStr.$ext';
    final destPath = kIsWeb ? sourcePath : '$_baseDir/$relPath';

    if (!kIsWeb) {
      final dir = Directory('$_baseDir/$category');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await File(sourcePath).copy(destPath);
    }

    return kIsWeb ? destPath : relPath;
  }

  // Save a progress photo from raw bytes (works on both web and mobile)
  Future<String> saveProgressPhoto(
    String date,
    Uint8List imageBytes, {
    String poseTag = 'none',
    double? weight,
    String? note,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuidStr = const Uuid().v4();
    final relPath = 'progress_photos/${date}_${timestamp}_$uuidStr.jpg';
    final destPath = kIsWeb ? 'web_photo_${date}_${timestamp}_$uuidStr.jpg' : '$_baseDir/$relPath';

    File? copiedFile;
    if (!kIsWeb) {
      copiedFile = File(destPath);
      await copiedFile.writeAsBytes(imageBytes);
    }

    final storedPath = kIsWeb ? destPath : relPath;
    final meta = ProgressPhoto(
      path: storedPath,
      date: date,
      pose: poseTag,
      weight: weight,
      note: note,
    );
    try {
      await _isar.writeTxn(() async {
        await _isar.progressPhotos.put(meta);
      });
    } catch (e) {
      if (copiedFile != null && await copiedFile.exists()) {
        try { await copiedFile.delete(); } catch(_) {}
      }
      rethrow;
    }

    return storedPath;
  }

  // Save a progress photo from a file path (legacy, mobile-only)
  Future<String> saveProgressPhotoFromPath(
    String date,
    String sourcePath, {
    String poseTag = 'none',
    double? weight,
    String? note,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uuidStr = const Uuid().v4();
    final relPath = 'progress_photos/${date}_${timestamp}_$uuidStr.jpg';
    final destPath = kIsWeb ? sourcePath : '$_baseDir/$relPath';

    File? copiedFile;
    if (!kIsWeb) {
      copiedFile = await File(sourcePath).copy(destPath);
    }

    final storedPath = kIsWeb ? destPath : relPath;
    final meta = ProgressPhoto(
      path: storedPath,
      date: date,
      pose: poseTag,
      weight: weight,
      note: note,
    );
    
    try {
      await _isar.writeTxn(() async {
        await _isar.progressPhotos.put(meta);
      });
    } catch (e) {
      if (copiedFile != null && await copiedFile.exists()) {
        try { await copiedFile.delete(); } catch (_) {}
      }
      rethrow;
    }

    return storedPath;
  }

  String getAbsolutePath(String storedPath) {
    if (storedPath.contains('..')) {
      throw ArgumentError('Path traversal detected');
    }
    if (kIsWeb) return storedPath;
    if (storedPath.startsWith('/')) { // legacy absolute path
      if (storedPath.contains('trufit_media/')) {
        final rel = storedPath.split('trufit_media/').last;
        return '$_baseDir/$rel';
      }
      return storedPath;
    }
    return '$_baseDir/$storedPath';
  }

  ProgressPhoto getProgressPhotoMeta(String date, String photoPath) {
    return _isar.progressPhotos
            .where()
            .pathEqualTo(photoPath)
            .findFirstSync() ??
        ProgressPhoto(path: photoPath, date: date, pose: 'none');
  }

  String getPoseTag(String photoPath) {
    return _isar.progressPhotos
            .where()
            .pathEqualTo(photoPath)
            .findFirstSync()
            ?.pose ??
        'none';
  }

  List<String> getProgressPhotos(String date) {
    return _isar.progressPhotos
        .filter()
        .dateEqualTo(date)
        .findAllSync()
        .map((p) => p.path)
        .toList();
  }

  List<MapEntry<String, List<String>>> getAllProgressPhotos() {
    final grouped = <String, List<String>>{};
    final allPhotos = _isar.progressPhotos.where().findAllSync();
    for (final photo in allPhotos) {
      grouped.putIfAbsent(photo.date, () => []).add(photo.path);
    }
    final result = grouped.entries.toList();
    result.sort((a, b) => b.key.compareTo(a.key));
    return result;
  }

  List<ProgressPhoto> getAllProgressPhotosDetailed() {
    return _isar.progressPhotos.where().sortByDateDesc().findAllSync();
  }

  int getAllPhotoCount() {
    return _isar.progressPhotos.where().countSync();
  }

  Future<void> deletePhoto(String date, String photoPath) async {
    final photo = _isar.progressPhotos
        .where()
        .pathEqualTo(photoPath)
        .findFirstSync();
    if (photo != null) {
      await _isar.writeTxn(() async {
        await _isar.progressPhotos.delete(photo.id);
      });
    }

    // 3. Delete physical file (if not web)
    if (!kIsWeb) {
      final file = File(getAbsolutePath(photoPath));
      if (await file.exists()) {
        try { await file.delete(); } catch (_) {}
      }
    }
  }

  Future<void> deletePhotos(Map<String, List<String>> photosByDate) async {
    for (final entry in photosByDate.entries) {
      final date = entry.key;
      for (final path in entry.value) {
        await deletePhoto(date, path);
      }
    }
  }
}
