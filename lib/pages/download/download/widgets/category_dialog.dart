import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/services/download/download_category_store.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 输入分类名称（新建 / 重命名）
Future<String?> showCategoryNameDialog({
  required String title,
  String? initial,
}) async {
  final textController = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: Get.context!,
    builder: (context) {
      final colorScheme = ColorScheme.of(context);
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '分类名称',
            counterText: '',
          ),
          onSubmitted: (value) => Get.back(result: value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text('取消', style: TextStyle(color: colorScheme.outline)),
          ),
          TextButton(
            onPressed: () => Get.back(result: textController.text.trim()),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  textController.dispose();
  return result;
}

/// 选择要移动到的分类（单选时会给当前归属打勾）
Future<void> showPickCategoryDialog({
  required String title,
  required Set<String> pageIds,
  required ValueChanged<String> onPick,
}) async {
  if (pageIds.isEmpty) {
    SmartDialog.showToast('请先选择视频');
    return;
  }
  final selected = pageIds.length == 1
      ? DownloadCategoryStore.categoryOf(pageIds.first)
      : null;

  final categoryId = await showDialog<String>(
    context: Get.context!,
    builder: (context) {
      final colorScheme = ColorScheme.of(context);
      return SimpleDialog(
        clipBehavior: Clip.hardEdge,
        title: Text(title),
        children: [
          for (final category in DownloadCategoryStore.categories)
            DialogOption(
              onPressed: () => Get.back(result: category.id),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (selected == category.id)
                    Icon(Icons.check, size: 18, color: colorScheme.primary),
                ],
              ),
            ),
        ],
      );
    },
  );
  if (categoryId == null) return;
  onPick(categoryId);
  SmartDialog.showToast(
    '已移动到「${DownloadCategoryStore.categoryById(categoryId)?.name ?? ''}」',
  );
}
