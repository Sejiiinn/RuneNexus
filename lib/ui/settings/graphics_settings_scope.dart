import 'package:flutter/widgets.dart';

import '../../data/settings/graphics_settings.dart';

class GraphicsSettingsScope
    extends InheritedNotifier<GraphicsSettingsController> {
  const GraphicsSettingsScope({
    required GraphicsSettingsController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static GraphicsSettingsController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GraphicsSettingsScope>()
      ?.notifier;
}
