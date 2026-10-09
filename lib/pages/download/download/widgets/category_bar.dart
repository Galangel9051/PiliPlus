import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/models_new/download/download_category.dart';
import 'package:PiliPlus/pages/download/download/controller.dart';
import 'package:PiliPlus/pages/download/download/widgets/category_dialog.dart';
import 'package:PiliPlus/services/download/download_category_store.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 离线缓存页列表上方的常驻筛选栏：分类切换 + 手动排序入口
class DownloadCategoryBar extends StatelessWidget {
  const DownloadCategoryBar({super.key, required this.controller});

  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Obx(() {
      final selected = controller.selectedCategory.value;
      final sorting = controller.sortMode.value;
      final categories = DownloadCategoryStore.categories;

      return Container(
        height: 42,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: categories.length + 2,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _Chip(
                      label: '全部',
                      selected: selected == DownloadController.allCategory,
                      onTap: () => controller.selectCategory(
                        DownloadController.allCategory,
                      ),
                    );
                  }
                  if (index == categories.length + 1) {
                    return _Chip(
                      label: '＋ 新建',
                      selected: false,
                      dashed: true,
                      onTap: () => _onCreateCategory(context),
                    );
                  }
                  final category = categories[index - 1];
                  return _Chip(
                    label: category.name,
                    selected: selected == category.id,
                    onTap: () => controller.selectCategory(category.id),
                    onLongPress: category.id == DownloadCategoryStore.defaultId
                        ? null
                        : () => _onManageCategory(context, category),
                  );
                },
              ),
            ),
            IconButton(
              tooltip: sorting ? '完成排序' : '手动排序',
              visualDensity: VisualDensity.compact,
              onPressed: controller.toggleSortMode,
              icon: Icon(
                sorting ? Icons.check : Icons.swap_vert,
                color: sorting ? colorScheme.primary : colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _onCreateCategory(BuildContext context) async {
    final name = await showCategoryNameDialog(title: '新建分类');
    if (name == null || name.isEmpty) return;
    final category = DownloadCategoryStore.create(name);
    controller.selectCategory(category.id);
    SmartDialog.showToast('已创建分类「${category.name}」');
  }

  Future<void> _onManageCategory(
    BuildContext context,
    DownloadCategory category,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        title: Text(category.name),
        children: [
          DialogOption(
            child: const Text('重命名', style: TextStyle(fontSize: 14)),
            onPressed: () => Get.back(result: 'rename'),
          ),
          DialogOption(
            child: const Text('删除分类', style: TextStyle(fontSize: 14)),
            onPressed: () => Get.back(result: 'delete'),
          ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == 'rename') {
      final name = await showCategoryNameDialog(
        title: '重命名分类',
        initial: category.name,
      );
      if (name == null || name.isEmpty) return;
      DownloadCategoryStore.rename(category.id, name);
      controller.flag.value++;
    } else if (action == 'delete') {
      controller.deleteCategory(category.id);
      SmartDialog.showToast('已删除分类，其中的视频回到默认分类');
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.dashed = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final background = selected
        ? colorScheme.secondaryContainer
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    return Center(
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: dashed
                    ? colorScheme.primary
                    : selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

