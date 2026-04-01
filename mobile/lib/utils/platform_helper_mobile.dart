import 'dart:io';
import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PlatformHelperImpl {
  static Future<void> saveAndOpenFile({
    required Uint8List bytes,
    required String fileName,
    required String title,
    bool isShare = false,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes);

    if (isShare) {
      await Share.shareXFiles([XFile(tempFile.path)], text: title);
    } else {
      await OpenFilex.open(tempFile.path);
    }
  }
}
