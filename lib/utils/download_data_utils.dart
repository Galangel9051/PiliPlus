import 'dart:convert' show jsonDecode;
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, debugPrint;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;

/// 离线缓存（本地视频数据）的导入/导出
abstract final class DownloadDataUtils {
  static const _zipExt = 'zip';
  static const _zipMime = 'application/zip';
  static const _entryFile = 'entry.json';

  static String get _timestamp =>
      DateFormatUtils.only0_9.format(DateTime.now());

  /// 弹出「导入/导出」选择框
  static Future<void> showMenu(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) {
      const style = TextStyle(fontSize: 15);
      return SimpleDialog(
        clipBehavior: Clip.hardEdge,
        title: const Text('导入/导出本地视频数据'),
        children: [
          DialogOption(
            child: const Text('导出至本地文件', style: style),
            onPressed: () {
              Get.back();
              exportData();
            },
          ),
          DialogOption(
            child: const Text('从本地文件导入', style: style),
            onPressed: () {
              Get.back();
              importData();
            },
          ),
        ],
      );
    },
  );

  /// 将整个离线缓存目录打包为 zip 并导出
  static Future<void> exportData() async {
    final sourceDir = Directory(downloadPath);
    if (!sourceDir.existsSync() || !_hasDownloadData(sourceDir)) {
      SmartDialog.showToast('暂无可导出的缓存视频');
      return;
    }

    final progress = ValueNotifier<double>(0);
    SmartDialog.showLoading(
      builder: (context) => _ExportProgress(progress: progress),
    );

    File? zipFile;
    var packed = false;
    try {
      zipFile = File(
        path.join(Directory.systemTemp.path, 'piliplus_download_$_timestamp.$_zipExt'),
      );
      if (zipFile.existsSync()) {
        await zipFile.delete();
      }
      await ZipFileEncoder().zipDirectory(
        sourceDir,
        filename: zipFile.path,
        onProgress: (value) => progress.value = value,
      );
      packed = true;
    } catch (e) {
      debugPrint('export download data error: $e');
      SmartDialog.showToast('导出失败：$e');
    } finally {
      SmartDialog.dismiss();
      progress.dispose();
    }

    if (!packed || zipFile == null) {
      return;
    }

    try {
      await _saveZipToLocal(zipFile, path.basename(zipFile.path));
    } catch (e) {
      debugPrint('save download data error: $e');
      SmartDialog.showToast('导出失败：$e');
    } finally {
      if (zipFile.existsSync()) {
        try {
          await zipFile.delete();
        } catch (_) {}
      }
    }
  }

  /// 从本地 zip 压缩包导入视频数据至离线缓存目录
  static Future<void> importData() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: '选择要导入的本地视频数据',
      type: FileType.custom,
      allowedExtensions: const [_zipExt],
    );
    if (picked == null) {
      return;
    }

    final ctx = Get.context;
    if (ctx != null && ctx.mounted) {
      final confirmed = await showConfirmDialog(
        context: ctx,
        title: const Text('确定导入本地视频数据？'),
        content: Text('将把「${picked.name}」解压到缓存目录，同名的缓存文件会被覆盖。'),
      );
      if (!confirmed) {
        return;
      }
    }

    File? cacheFile;
    try {
      final pickedPath = picked.path;
      final String inputPath;
      if (pickedPath != null && pickedPath.isNotEmpty) {
        inputPath = pickedPath;
      } else {
        cacheFile = File(
          path.join(
            Directory.systemTemp.path,
            'piliplus_import_$_timestamp.$_zipExt',
          ),
        );
        await cacheFile.writeAsBytes(await picked.readAsBytes(), flush: true);
        inputPath = cacheFile.path;
      }

      SmartDialog.showLoading(msg: '正在解压导入…');
      final root = Directory(downloadPath);
      await root.create(recursive: true);

      final depth = await _detectEntryDepth(inputPath);
      if (depth < 0) {
        SmartDialog.dismiss();
        SmartDialog.showToast('压缩包内没有找到缓存数据（缺少 entry.json）');
        return;
      }
      // 正常结构是 <pageId>/<pageDir>/entry.json，entry.json 前面有两层；
      // 把整个 download 文件夹压缩后会多出若干层，这里按探测结果自动剥离
      await _extractZip(inputPath, root, strip: depth > 2 ? depth - 2 : 0);
      // 兼容只压缩了单个分P目录的情况
      await _wrapBareEntries(root);

      final downloadService = Get.find<DownloadService>()..initDownloadList();
      await downloadService.waitForInitialization;
      // 重新读取时未完成的缓存会被重复加入队列，这里去重保留原条目
      final seenCids = <int>{};
      downloadService.waitDownloadQueue.removeWhere(
        (entry) => !seenCids.add(entry.cid),
      );
      downloadService.flagNotifier.refresh();
      SmartDialog.dismiss();
      SmartDialog.showToast(
        '导入成功，已缓存视频共 ${downloadService.downloadList.length} 个',
      );
    } catch (e) {
      SmartDialog.dismiss();
      debugPrint('import download data error: $e');
      SmartDialog.showToast('导入失败：$e');
    } finally {
      if (cacheFile != null && cacheFile.existsSync()) {
        try {
          await cacheFile.delete();
        } catch (_) {}
      }
    }
  }

  /// 拆路径：统一分隔符，剔除空段与 `.`，出现 `..` 视为非法
  static List<String> _splitName(String name) {
    final segments = <String>[];
    for (final segment in name.replaceAll(r'\', '/').split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') return const [];
      segments.add(segment);
    }
    return segments;
  }

  /// 探测压缩包内 `entry.json` 前面的目录层数，找不到返回 -1
  static Future<int> _detectEntryDepth(String zipPath) async {
    final input = InputFileStream(zipPath);
    var depth = -1;
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final entry in archive) {
        if (!entry.isFile || entry.symbolicLink != null) continue;
        final segments = _splitName(entry.name);
        if (segments.isEmpty || segments.last != _entryFile) continue;
        final current = segments.length - 1;
        if (depth == -1 || current < depth) {
          depth = current;
        }
      }
    } finally {
      await input.close();
    }
    return depth;
  }

  /// 把 [zipPath] 解压到 [root]，[strip] 为需要剥离的顶层目录层数
  static Future<int> _extractZip(
    String zipPath,
    Directory root, {
    int strip = 0,
  }) async {
    final input = InputFileStream(zipPath);
    var count = 0;
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final entry in archive) {
        if (entry.symbolicLink != null) continue;
        final segments = _splitName(entry.name);
        if (segments.length <= strip) continue;
        final target = path.join(root.path, segments.skip(strip).join('/'));
        if (!path.isWithin(root.path, target)) continue;

        if (entry.isDirectory) {
          await Directory(target).create(recursive: true);
          continue;
        }
        await Directory(path.dirname(target)).create(recursive: true);
        final output = OutputFileStream(target);
        try {
          entry.writeContent(output);
        } finally {
          await output.close();
        }
        count++;
      }
    } finally {
      await input.close();
    }
    return count;
  }

  /// 兼容「把单个分P目录直接压缩」的包：
  /// 此时结构是 `<pageDir>/entry.json`，少了一层 pageId，按 entry.json 补上
  static Future<void> _wrapBareEntries(Directory root) async {
    for (final child in root.listSync()) {
      if (child is! Directory) continue;
      final entryFile = File(path.join(child.path, _entryFile));
      if (!entryFile.existsSync()) continue;

      var pageId = '';
      try {
        final json = jsonDecode(await entryFile.readAsString());
        pageId = BiliDownloadEntryInfo.fromJson(
          json as Map<String, dynamic>,
        ).pageId;
      } catch (e) {
        debugPrint('read bare entry error: $e');
      }
      if (pageId.isEmpty) continue;

      try {
        final target = path.join(root.path, pageId, path.basename(child.path));
        await Directory(path.dirname(target)).create(recursive: true);
        await child.rename(target);
      } catch (e) {
        debugPrint('wrap bare entry error: $e');
      }
    }
  }

  static bool _hasDownloadData(Directory dir) {
    try {
      for (final entity in dir.listSync()) {
        if (entity is Directory && entity.listSync().isNotEmpty) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('read download dir error: $e');
    }
    return false;
  }

  static Future<void> _saveZipToLocal(File zip, String fileName) async {
    final isDesktop = PlatformUtils.isDesktop;
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: isDesktop ? Uint8List(0) : await zip.readAsBytes(),
      mimeType: _zipMime,
      dialogTitle: '导出本地视频数据',
      type: FileType.custom,
      allowedExtensions: const [_zipExt],
    );
    if (uri == null) {
      SmartDialog.showToast('已取消导出');
      return;
    }
    if (isDesktop) {
      await zip.copy(uri.toFilePath());
    }
    SmartDialog.showToast('导出成功');
  }
}

class _ExportProgress extends StatelessWidget {
  const _ExportProgress({required this.progress});

  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: value <= 0 ? null : value),
              const SizedBox(height: 12),
              Text(
                value <= 0
                    ? '正在打包离线缓存…'
                    : '正在打包离线缓存 ${(value * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
