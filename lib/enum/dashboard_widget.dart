import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/views/dashboard/widgets/announce_widget.dart';
import 'package:flclashx/views/dashboard/widgets/metainfo_widget.dart';
import 'package:flclashx/views/dashboard/widgets/widgets.dart';
import 'package:flclashx/widgets/widgets.dart';
import 'package:flutter/foundation.dart';

enum DashboardWidget {
  networkSpeed(
    GridItem(
      crossAxisCellCount: 8,
      child: NetworkSpeed(),
    ),
  ),
  outboundModeV2(
    GridItem(
      crossAxisCellCount: 8,
      child: OutboundModeV2(),
    ),
  ),
  outboundMode(
    GridItem(
      crossAxisCellCount: 4,
      child: OutboundMode(),
    ),
  ),
  trafficUsage(
    GridItem(
      crossAxisCellCount: 4,
      child: TrafficUsage(),
    ),
  ),
  announce(
    GridItem(
      crossAxisCellCount: 8,
      child: AnnounceWidget(),
    ),
  ),
  metainfo(
    GridItem(
      crossAxisCellCount: 8,
      child: MetainfoWidget(),
    ),
  ),
  networkDetection(
    GridItem(
      crossAxisCellCount: 4,
      child: NetworkDetection(),
    ),
  ),
  tunButton(
    GridItem(
      crossAxisCellCount: 4,
      child: TUNButton(),
    ),
    platforms: desktopPlatforms,
  ),
  vpnButton(
    GridItem(
      crossAxisCellCount: 4,
      child: VpnButton(),
    ),
    platforms: [
      SupportPlatform.Android,
    ],
  ),
  systemProxyButton(
    GridItem(
      crossAxisCellCount: 4,
      child: SystemProxyButton(),
    ),
    platforms: desktopPlatforms,
  ),
  intranetIp(
    GridItem(
      crossAxisCellCount: 4,
      child: IntranetIP(),
    ),
  ),
  memoryInfo(
    GridItem(
      crossAxisCellCount: 4,
      child: MemoryInfo(),
    ),
  ),
  changeServerButton(
    GridItem(
      crossAxisCellCount: 8,
      child: ChangeServerButton(),
    ),
  ),
  serviceInfo(
    GridItem(
      crossAxisCellCount: 8,
      child: ServiceInfoWidget(),
    ),
  );

  final GridItem widget;
  final List<SupportPlatform> platforms;

  const DashboardWidget(
    this.widget, {
    this.platforms = SupportPlatform.values,
  });

  static DashboardWidget getDashboardWidget(GridItem gridItem) {
    const dashboardWidgets = DashboardWidget.values;
    final index = dashboardWidgets.indexWhere(
      (item) => item.widget == gridItem,
    );
    return dashboardWidgets[index];
  }
}

extension DashboardWidgetParser on DashboardWidget {
  static List<DashboardWidget> parseLayout(String? layoutString) {
    if (layoutString == null || layoutString.isEmpty) {
      return [];
    }

    final widgetNames =
        layoutString.split(',').map((e) => e.trim().toLowerCase()).toList();
    final result = <DashboardWidget>[];

    for (final name in widgetNames) {
      try {
        final widget = DashboardWidget.values.firstWhere(
          (e) => e.name.toLowerCase() == name,
        );
        result.add(widget);
      } catch (e) {
        debugPrint('[FlClashR] no data widget "$name"');
      }
    }
    return result;
  }
}
