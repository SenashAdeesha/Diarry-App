import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  static final ImageService instance = ImageService._();
  ImageService._();

  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  static const String _imageDirName = 'diary_images';
  static const double maxDimension = 1920;
  static const int quality = 85;
  static const int maxImagesPerEntry = 9;

  String? _cachedDir;

  Future<String> get imageDirectory async {
    if (_cachedDir != null) return _cachedDir!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_imageDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedDir = dir.path;
    return dir.path;
  }

  String _generateName(String extension) => '${_uuid.v4()}.$extension';

  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<String?> captureFromCamera() => _pick(ImageSource.camera);

  Future<String?> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: maxDimension,
        maxHeight: maxDimension,
        imageQuality: quality,
      );
      if (file == null) return null;
      return _saveToAppDir(file);
    } catch (e) {
      throw ImagePickException('Failed to pick image: $e');
    }
  }

  Future<String> _saveToAppDir(XFile picked) async {
    final dir = await imageDirectory;
    final ext = picked.path.split('.').last;
    final dest = '$dir/${_generateName(ext)}';
    await File(picked.path).copy(dest);
    return dest;
  }

  Future<void> deleteImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> deleteImages(List<String> paths) async {
    for (final p in paths) {
      await deleteImage(p);
    }
  }

  Future<int> totalStorageBytes() async {
    final dir = await imageDirectory;
    final dirEntity = Directory(dir);
    if (!await dirEntity.exists()) return 0;
    int total = 0;
    await for (final entity in dirEntity.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> cleanOrphans(Set<String> activePaths) async {
    final dir = await imageDirectory;
    final dirEntity = Directory(dir);
    if (!await dirEntity.exists()) return;
    await for (final entity in dirEntity.list()) {
      if (entity is File && !activePaths.contains(entity.path)) {
        await entity.delete();
      }
    }
  }
}

class ImagePickException implements Exception {
  final String message;
  const ImagePickException(this.message);
  @override
  String toString() => message;
}
