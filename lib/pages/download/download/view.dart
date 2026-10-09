import 'dart:async';

import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/pages/download/detail/widgets/item.dart';
import 'package:PiliPlus/pages/download/download/controller.dart';
import 'package:PiliPlus/pages/download/download/widgets/category_bar.dart';
import 'package:PiliPlus/pages/download/download/widgets/category_dialog.dart';
import 'package:PiliPlus/pages/download/download/widgets/page.dart';
import 'package:PiliPlus/pages/download/download/widgets/season.dart';
import 'package:PiliPlus/pages/download/download/widgets/sort_tile.dart';
import 'package:PiliPlus/pages/download/download_action_mixin.dart';
import 'package:PiliPlus/pages/download/search/view.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/download_data_utils.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with GridMixin, BaseDownloadActionMixin<DownloadPage, DownloadSeasonInfo> {
  final _progress = ChangeNotifier();
  final _controller = Get.put(DownloadController());

  @override
  final downloadService = Get.find<DownloadService>();

  @override
  BaseMultiSelectMixin<DownloadSeasonInfo> get multiSelectCtr => _controller;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Future<void> onUpdate(
    Future<bool> Function(BiliDownloadEntryInfo e) toElement,
  ) async {
    if (checkUpdateCount(_controller.checkedCount)) return;

    bool dismiss = false;
    SmartDialog.showLoading(
      onDismiss: () {
        dismiss = true;
        _controller.handleSelect();
      },
    );

    bool isSuccess = true;
    for (final chunk in _controller.allChecked.mapChunked(
      kUpdateConcurrency,
      (season) async {
        bool isSuccess = true;
        for (final chunk in season.pages.mapChunked(
          kUpdateConcurrency,
          (page) async {
            bool isSuccess = true;
            for (final chunk in page.entries.mapChunked(
              kUpdateConcurrency,
              toElement,
            )) {
              final res = await Future.wait(chunk);
              if (res.any((e) => !e)) isSuccess = false;
              if (dismiss) break;
            }
            return isSuccess;
          },
        )) {
          final res = await Future.wait(chunk);
          if (res.any((e) => !e)) isSuccess = false;
          if (dismiss) break;
        }
        return isSuccess;
      },
    )) {
      final res = await Future.wait(chunk);
      if (res.any((e) => !e)) isSuccess = false;
      if (dismiss) break;
    }

    toastUpdateResult(dismiss, isSuccess);
  }

  Widget _categoryBtn() => TextButton(
    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
    onPressed: () {
      showPickCategoryDialog(
        title: '移动到分类',
        pageIds: _controller.allChecked.map((e) => e.pageId).toSet(),
        onPick: _controller.moveCheckedToCategory,
      );
    },
    child: Text('分类', style: TextStyle(color: colorScheme.onSurface)),
  );

  Future<void> _updateSeasonDm(DownloadSeasonInfo seasonInfo) async {
    if (checkUpdateCount(
      seasonInfo.pages.fold(0, (a, b) => a + b.entries.length),
    )) {
      return;
    }

    bool dismiss = false;
    SmartDialog.showLoading(onDismiss: () => dismiss = true);

    bool isSuccess = true;

    for (final page in seasonInfo.pages) {
      for (final chunk in page.entries.mapChunked(
        kUpdateConcurrency,
        (e) => downloadService.downloadDanmaku(
          entry: e,
          isUpdate: true,
        ),
      )) {
        final res = await Future.wait(chunk);
        if (res.any((e) => !e)) isSuccess = false;
        if (dismiss) break;
      }
    }

    toastUpdateResult(dismiss, isSuccess);
  }

  Widget _sectionTitle(String text, {double top = 0}) => SliverPadding(
    padding: EdgeInsets.only(left: 12, bottom: 7, top: top),
    sliver: SliverToBoxAdapter(child: Text(text)),
  );

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    return Obx(() {
      final enableMultiSelect = _controller.enableMultiSelect.value;
      final sorting = _controller.sortMode.value;
      return popScope(
        canPop: !enableMultiSelect && !sorting,
        onPopInvokedWithResult: (didPop, result) {
          if (enableMultiSelect) {
            _controller.handleSelect();
          } else if (sorting) {
            _controller.sortMode.value = false;
          }
        },
        child: SimpleScaffold(
          appBar: MultiSelectAppBarWidget(
            ctr: _controller,
            actions: [updateBtn(), _categoryBtn()],
            child: AppBar(
              title: const Text('离线缓存'),
              actions: [
                IconButton(
                  tooltip: '导入/导出',
                  onPressed: () => DownloadDataUtils.showMenu(context),
                  icon: const Icon(Icons.import_export),
                ),
                IconButton(
                  tooltip: '搜索',
                  onPressed: () async {
                    await downloadService.waitForInitialization;
                    if (!mounted) return;
                    Get.to(DownloadSearchPage(progress: _progress));
                  },
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: '多选',
                  onPressed: () {
                    if (enableMultiSelect) {
                      _controller.handleSelect();
                    } else {
                      _controller.sortMode.value = false;
                      _controller.enableMultiSelect.value = true;
                    }
                  },
                  icon: const Icon(Icons.edit_note),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          body: Column(
            children: [
              DownloadCategoryBar(controller: _controller),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: padding.left,
                    right: padding.right,
                  ),
                  child: CustomScrollView(
                    slivers: [
                      Obx(() {
                        final entry =
                            downloadService.waitDownloadQueue.firstWhereOrNull(
                              (e) => e.cid == downloadService.curCid,
                            ) ??
                            downloadService.waitDownloadQueue.firstOrNull;
                        if (entry != null) {
                          return SliverMainAxisGroup(
                            slivers: [
                              _sectionTitle(
                                '正在缓存 (${downloadService.waitDownloadQueue.length})',
                              ),
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 110,
                                  child: DetailItem(
                                    entry: entry,
                                    progress: _progress,
                                    downloadService: downloadService,
                                    showTitle: true,
                                    isCurr: true,
                                    controller: _controller,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return const SliverToBoxAdapter();
                      }),
                      Obx(() {
                        final sliver = _buildCachedSliver(
                          enableMultiSelect,
                          sorting,
                        );
                        if (sliver != null) {
                          return sliver;
                        }
                        if (downloadService.waitDownloadQueue.isNotEmpty &&
                            _controller.seasons.isEmpty) {
                          return const SliverToBoxAdapter();
                        }
                        return const HttpError();
                      }),
                      SliverToBoxAdapter(
                        child: SizedBox(height: padding.bottom + 100),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  SliverMainAxisGroup? _buildCachedSliver(
    bool enableMultiSelect,
    bool sorting,
  ) {
    final list = _controller.displaySeasons;
    if (list.isEmpty) {
      if (_controller.seasons.isEmpty) {
        return null;
      }
      return SliverMainAxisGroup(
        slivers: [
          _sectionTitle(
            '已缓存视频',
            top: downloadService.waitDownloadQueue.isEmpty ? 0 : 7,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text(
                  '该分类下暂无缓存视频',
                  style: TextStyle(
                    color: ColorScheme.of(context).outline,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        _sectionTitle(
          sorting ? '拖拽调整顺序（${list.length}）' : '已缓存视频（${list.length}）',
          top: downloadService.waitDownloadQueue.isEmpty ? 0 : 7,
        ),
        if (sorting)
          SliverReorderableList(
            itemCount: list.length,
            onReorderItem: _controller.onReorder,
            itemBuilder: (context, index) {
              final season = list[index];
              return DownloadSortTile(
                key: ValueKey(season.pageId),
                season: season,
                index: index,
              );
            },
          )
        else
          SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemBuilder: (context, index) {
              final season = list[index];
              final seasonInfo = season.seasonInfo;
              final pages = season.pages;

              if (seasonInfo != null && pages.length > 1) {
                return SeasonInfoItem(
                  controller: _controller,
                  downloadService: downloadService,
                  seasonInfo: seasonInfo,
                  season: season,
                  enableMultiSelect: enableMultiSelect,
                  progress: _progress,
                  updateSeasonDm: _updateSeasonDm,
                );
              }

              final page = pages.first;
              if (pages.length == 1 && page.entries.length == 1) {
                final entry = page.entries.first;
                return DetailItem(
                  entry: entry,
                  progress: _progress,
                  downloadService: downloadService,
                  showTitle: true,
                  onDelete: () {
                    downloadService.deleteDownload(
                      entry: entry,
                      removeList: true,
                    );
                    GStorage.watchProgress.delete(entry.cid.toString());
                  },
                  checked: season.checked,
                  onSelect: (_) => _controller.onSelect(season),
                  controller: _controller,
                );
              }

              return PageInfoItem(
                controller: _controller,
                downloadService: downloadService,
                seasonInfo: season,
                pageInfo: page,
                enableMultiSelect: enableMultiSelect,
                progress: _progress,
                updatePageDm: updatePageDm,
              );
            },
            itemCount: list.length,
          ),
      ],
    );
  }
}
