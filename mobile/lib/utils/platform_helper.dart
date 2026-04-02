import 'dart:typed_data';

/// Platform-specific file handling abstraction.
/// Standard implementation for mobile.
import 'platform_helper_stub.dart'
    if (dart.library.html) 'platform_helper_web.dart'
    if (dart.library.io) 'platform_helper_mobile.dart';

abstract class PlatformHelper {
  static Future<void> saveAndOpenFile({
    required Uint8List bytes,
    required String fileName,
    required String title,
    bool isShare = false,
  }) {
    return PlatformHelperImpl.saveAndOpenFile(
      bytes: bytes,
      fileName: fileName,
      title: title,
      isShare: isShare,
    );
  }
}
