import 'dart:async';

import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show BaseMultiSelectMixin;
import 'package:PiliPlus/services/download/download_category_store.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' show Text;

class DownloadController extends GetxController
    with BaseMultiSelectMixin<DownloadSeasonInfo> {
  /// 筛选栏里「全部」的伪分类
  static const String allCategory = 'all';

  final _downloadService = Get.find<DownloadService>();
  final seasons = RxList<DownloadSeasonInfo>();
  final flag = RxInt(0);

  /// 当前选中的分类
  final selectedCategory = allCategory.obs;

  /// 手动排序模式
  final sortMode = false.obs;

  @override
  List<DownloadSeasonInfo> get list => seasons;
  @override
  RxList<DownloadSeasonInfo> get state => seasons;

  @override
  void onInit() {
    super.onInit();
    DownloadCategoryStore.ensureLoaded();
    _loadList();
    _downloadService.flagNotifier.add(_loadList);
  }

  @override
  void onClose() {
    _downloadService.flagNotifier.remove(_loadList);
    super.onClose();
  }

  /// 按当前分类筛选 + 手动顺序排好序的列表
  ///
  /// 未登记手动顺序的条目（例如刚缓存完的）按缓存时间倒序排在已登记的前面。
  List<DownloadSeasonInfo> get displaySeasons {
    final category = selectedCategory.value;
    final list = category == allCategory
        ? List<DownloadSeasonInfo>.from(seasons)
        : seasons
              .where(
                (e) => DownloadCategoryStore.categoryOf(e.pageId) == category,
              )
              .toList();
    return _applyOrder(list);
  }

  List<DownloadSeasonInfo> _applyOrder(List<DownloadSeasonInfo> list) {
    final order = DownloadCategoryStore.order;
    final orderIndex = <String, int>{};
    for (var i = 0; i < order.length; i++) {
      orderIndex[order[i]] = i;
    }
    list.sort((a, b) {
      final ia = orderIndex[a.pageId];
      final ib = orderIndex[b.pageId];
      if (ia == null && ib == null) {
        return _timeOf(b).compareTo(_timeOf(a));
      }
      if (ia == null) return -1;
      if (ib == null) return 1;
      return ia.compareTo(ib);
    });
    return list;
  }

  static int _timeOf(DownloadSeasonInfo season) {
    var timestamp = 0;
    for (final page in season.pages) {
      for (final entry in page.entries) {
        if (entry.timeUpdateStamp > timestamp) {
          timestamp = entry.timeUpdateStamp;
        }
      }
    }
    return timestamp;
  }

  Future<void> _loadList() async {
    await _downloadService.waitForInitialization;
    if (isClosed) return;
    if (_downloadService.downloadList.isEmpty) {
      seasons.clear();
      flag.value++;
      return;
    }
    final list = <DownloadSeasonInfo>[];
    for (final entry in _downloadService.downloadList) {
      final pageId = entry.pageId;
      final seasonInfo = entry.seasonInfo;
      final season = seasonInfo != null
          ? list.firstWhereOrNull((e) => e.seasonInfo == seasonInfo)
          : list.firstWhereOrNull((e) => e.pageId == pageId);
      if (season != null) {
        final page = season.pages.firstWhereOrNull((e) => e.pageId == pageId);
        if (page != null) {
          final aSortKey = entry.sortKey;
          final bSortKey = page.sortKey;
          if (aSortKey < bSortKey) {
            page
              ..cover = entry.cover
              ..sortKey = aSortKey;
          }
          page.entries.add(entry);
        } else {
          season.pages.add(
            entry.toDownloadPageInfo(pageId, sortKey: seasonInfo!.index),
          );
        }
      } else {
        list.add(
          DownloadSeasonInfo(
            pageId: pageId,
            seasonInfo: seasonInfo,
            pages: [
              entry.toDownloadPageInfo(pageId, sortKey: seasonInfo?.index),
            ],
          ),
        );
      }
    }
    seasons.value = list;
    flag.value++;
  }

  /// 全选只作用于当前分类下可见的条目，避免把被筛掉的缓存一起删掉
  @override
  void handleSelect({bool checked = false, bool disableSelect = true}) {
    if (!checked) {
      super.handleSelect(checked: false, disableSelect: disableSelect);
      return;
    }
    final visible = displaySeasons.map((e) => e.pageId).toSet();
    var count = 0;
    for (final season in seasons) {
      season.checked = visible.contains(season.pageId);
      if (season.checked) count++;
    }
    state.refresh();
    rxCount.value = count;
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  /// 进入/退出手动排序模式；进入时用当前整体顺序做一次初始化
  void toggleSortMode() {
    if (sortMode.value) {
      sortMode.value = false;
      return;
    }
    DownloadCategoryStore.seedOrder(
      _applyOrder(List<DownloadSeasonInfo>.from(seasons))
          .map((e) => e.pageId)
          .toList(),
    );
    sortMode.value = true;
  }

  /// 拖拽排序：只重排当前可见子集，其它条目的相对位置不变
  ///
  /// [newIndex] 来自 [SliverReorderableList.onReorderItem]，已经处理过下移时的偏移
  void onReorder(int oldIndex, int newIndex) {
    final visible = displaySeasons;
    final previous = visible.map((e) => e.pageId).toList();
    final reordered = List<String>.from(previous);
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    DownloadCategoryStore.applyReorder(previous, reordered);
    flag.value++;
  }

  void moveCheckedToCategory(String categoryId) {
    final pageIds = allChecked.map((e) => e.pageId).toList();
    if (pageIds.isEmpty) return;
    DownloadCategoryStore.moveToCategory(pageIds, categoryId);
    if (enableMultiSelect.value) {
      rxCount.value = 0;
      enableMultiSelect.value = false;
    }
    flag.value++;
  }

  void deleteCategory(String id) {
    DownloadCategoryStore.remove(id);
    if (selectedCategory.value == id) {
      selectedCategory.value = allCategory;
    }
    flag.value++;
  }

  @override
  void onRemove() {
    showConfirmDialog(
      context: Get.context!,
      title: const Text('确定删除选中视频？'),
      onConfirm: () async {
        SmartDialog.showLoading();
        final watchProgress = GStorage.watchProgress;
        for (final season in allChecked) {
          for (final page in season.pages) {
            await watchProgress.deleteAll(
              page.entries.map((e) => e.cid.toString()),
            );
            await _downloadService.deletePage(
              pageDirPath: page.dirPath,
              refresh: false,
            );
          }
        }
        _downloadService.flagNotifier.refresh();
        if (enableMultiSelect.value) {
          rxCount.value = 0;
          enableMultiSelect.value = false;
        }
        SmartDialog.dismiss();
      },
    );
  }
}
