import 'dart:convert';

import 'package:PiliPlus/models_new/download/download_category.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get/get.dart';
import 'package:uuid/v4.dart';

/// 离线缓存的「分类 / 排序」
///
/// 这里只维护软件内的逻辑标签，**不会改动磁盘上的缓存目录结构**，
/// 删掉分类也不会删除任何视频文件（条目只是回到默认分类）。
abstract final class DownloadCategoryStore {
  /// 未指定分类时归入的默认分类：id 固定、不可删除
  static const String defaultId = 'default';
  static const String defaultName = '默认分类';

  static final categories = <DownloadCategory>[].obs;

  /// pageId -> categoryId
  static final entryCategory = <String, String>{}.obs;

  /// pageId 的手动顺序；未登记的条目按缓存时间倒序排在已登记的之前
  static final order = <String>[].obs;

  static bool _loaded = false;

  static void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;

    categories.value = _decodeList(SettingBoxKey.downloadCategories);
    if (!categories.any((e) => e.id == defaultId)) {
      categories.insert(
        0,
        DownloadCategory(id: defaultId, name: defaultName),
      );
    }

    final categoryMap = _decodeMap(SettingBoxKey.downloadEntryCategory);
    final ids = categories.map((e) => e.id).toSet();
    categoryMap.removeWhere((_, v) => !ids.contains(v));
    entryCategory.value = categoryMap;

    order.value = _decodeStringList(SettingBoxKey.downloadEntryOrder);
  }

  static String categoryOf(String pageId) =>
      entryCategory[pageId] ?? defaultId;

  static DownloadCategory? categoryById(String id) =>
      categories.firstWhereOrNull((e) => e.id == id);

  static List<String> get _categoryIds =>
      categories.map((e) => e.id).toList(growable: false);

  static DownloadCategory create(String name) {
    final category = DownloadCategory(
      id: const UuidV4().generate(),
      name: name,
    );
    categories.add(category);
    _saveCategories();
    return category;
  }

  static void rename(String id, String name) {
    final category = categoryById(id);
    if (category == null || category.name == name) return;
    category.name = name;
    _saveCategories();
  }

  /// 删除分类，其下条目回到默认分类（不删除任何文件）
  static void remove(String id) {
    if (id == defaultId) return;
    categories.removeWhere((e) => e.id == id);
    entryCategory.removeWhere((_, v) => v == id);
    _saveCategories();
    _saveEntryCategory();
  }

  static void moveToCategory(Iterable<String> pageIds, String categoryId) {
    final valid = categoryId == defaultId || _categoryIds.contains(categoryId);
    if (!valid) return;
    for (final pageId in pageIds) {
      if (categoryId == defaultId) {
        entryCategory.remove(pageId);
      } else {
        entryCategory[pageId] = categoryId;
      }
    }
    _saveEntryCategory();
  }

  /// 把 [visible]（当前分类下可见的 pageId，已按显示顺序）的新排列写回全局顺序：
  /// 只替换这些 id 原来占据的位置，其它条目相对顺序不变
  static void applyReorder(
    List<String> previousVisible,
    List<String> reorderedVisible,
  ) {
    if (previousVisible.length != reorderedVisible.length) return;
    final current = order.toList();
    final visible = previousVisible.toSet();
    var index = 0;
    final next = [
      for (final id in current)
        if (visible.contains(id)) reorderedVisible[index++] else id,
    ];
    // 未登记的条目按显示顺序补到末尾
    if (index < reorderedVisible.length) {
      next.addAll(reorderedVisible.sublist(index));
    }
    order.assignAll(next);
    _saveOrder();
  }

  /// 用当前显示顺序初始化整体顺序（进入排序模式时调用）
  static void seedOrder(List<String> pageIds) {
    order.assignAll(pageIds);
    _saveOrder();
  }

  static void clearOrder() {
    order.clear();
    _saveOrder();
  }

  static List<dynamic> _rawList(String key) {
    final raw = GStorage.setting.get(key);
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } catch (e) {
      debugPrint('decode $key error: $e');
      return const [];
    }
  }

  static List<DownloadCategory> _decodeList(String key) {
    final result = <DownloadCategory>[];
    for (final item in _rawList(key)) {
      try {
        result.add(DownloadCategory.fromJson(item as Map<String, dynamic>));
      } catch (e) {
        debugPrint('decode category error: $e');
      }
    }
    return result;
  }

  static List<String> _decodeStringList(String key) => [
    for (final item in _rawList(key))
      if (item is String) item,
  ];

  static Map<String, String> _decodeMap(String key) {
    final raw = GStorage.setting.get(key);
    if (raw is! String || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k as String, v as String));
      }
    } catch (e) {
      debugPrint('decode $key error: $e');
    }
    return {};
  }

  static void _saveCategories() => GStorage.setting.put(
    SettingBoxKey.downloadCategories,
    jsonEncode(categories.map((e) => e.toJson()).toList()),
  );

  static void _saveEntryCategory() => GStorage.setting.put(
    SettingBoxKey.downloadEntryCategory,
    jsonEncode(entryCategory),
  );

  static void _saveOrder() => GStorage.setting.put(
    SettingBoxKey.downloadEntryOrder,
    jsonEncode(order.toList()),
  );
}
