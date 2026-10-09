import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:material_ui/material_ui.dart';

/// 手动排序模式下的可拖拽行
class DownloadSortTile extends StatelessWidget {
  const DownloadSortTile({
    super.key,
    required this.season,
    required this.index,
  });

  final DownloadSeasonInfo season;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final page = season.pages.first;
    final title = season.seasonInfo?.title ?? page.title;
    final owner = season.seasonInfo?.uname ?? page.entries.first.ownerName;
    final count = season.pages.fold(0, (a, b) => a + b.entries.length);
    final size = season.pages.fold(
      0,
      (a, b) => a + b.entries.fold(0, (x, y) => x + y.totalBytes),
    );

    return ReorderableDelayedDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Style.safeSpace,
          vertical: 5,
        ),
        child: Row(
          spacing: 10,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                NetworkImgLayer(
                  src: page.cover,
                  width: 104,
                  height: 104 / Style.aspectRatio,
                ),
                PBadge(
                  text: '$count个视频',
                  right: 6.0,
                  bottom: 6.0,
                  isBold: false,
                  type: .gray,
                ),
              ],
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(height: 1.42, letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${size.formatSize}  ${owner ?? ""}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.drag_handle, color: colorScheme.outline),
          ],
        ),
      ),
    );
  }
}
