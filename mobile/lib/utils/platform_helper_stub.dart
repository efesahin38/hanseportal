import 'dart:typed_data';

class PlatformHelperImpl {
  static Future<void> saveAndOpenFile({
    required Uint8List bytes,
    required String fileName,
    required String title,
    bool isShare = false,
  }) async {
    throw UnimplementedError('Platform not supported');
  }
}
