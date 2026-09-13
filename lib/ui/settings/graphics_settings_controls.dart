import 'package:flutter/material.dart';

import '../../data/settings/graphics_settings.dart';
import '../game/game_palette.dart';
import '../game/game_text_styles.dart';

class GraphicsSettingsControls extends StatelessWidget {
  const GraphicsSettingsControls({required this.controller, super.key});

  final GraphicsSettingsController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final settings = controller.value;
      final enabled = controller.loaded && !controller.saving;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('3D 그래픽', style: GameTextStyles.sectionTitle),
          const SizedBox(height: 6),
          const Text(
            '낮추면 기기의 그래픽 부담을 줄일 수 있습니다.\n이 기기에 자동 저장됩니다.\n앱을 다시 켜고 저장된 전투를 이어서 해도 적용됩니다.',
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 16),
          _choices(
            title: 'MSAA · 테두리 부드럽게',
            description: '끄면 물체의 가장자리가 거칠어질 수 있습니다.',
            value: settings.msaaSamples,
            options: const {0: '끄기', 2: '2배'},
            keyPrefix: 'graphics-msaa',
            onChanged: enabled
                ? (value) =>
                      controller.update(settings.copyWith(msaaSamples: value))
                : null,
          ),
          const SizedBox(height: 12),
          const Divider(color: GamePalette.stoneDark),
          const SizedBox(height: 12),
          _choices(
            title: '그림자 품질',
            description: '낮추면 그림자가 흐릿해지고, 끄면 사라집니다.',
            value: settings.shadowMapSize,
            options: const {0: '끄기', 512: '낮음', 1024: '중간', 2048: '높음'},
            keyPrefix: 'graphics-shadow',
            onChanged: enabled
                ? (value) =>
                      controller.update(settings.copyWith(shadowMapSize: value))
                : null,
          ),
          if (controller.error case final error?) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: GameTextStyles.body.copyWith(color: GamePalette.danger),
            ),
          ],
        ],
      );
    },
  );

  Widget _choices({
    required String title,
    required String description,
    required int value,
    required Map<int, String> options,
    required String keyPrefix,
    required ValueChanged<int>? onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: GameTextStyles.button),
      const SizedBox(height: 4),
      Text(description, style: GameTextStyles.body),
      RadioGroup<int>(
        groupValue: value,
        onChanged: (value) {
          if (value != null) onChanged?.call(value);
        },
        child: Wrap(
          spacing: 8,
          children: [
            for (final entry in options.entries)
              IntrinsicWidth(
                child: RadioListTile<int>(
                  key: ValueKey('$keyPrefix-${entry.key}'),
                  value: entry.key,
                  enabled: onChanged != null,
                  title: Text(entry.value, style: GameTextStyles.body),
                  activeColor: GamePalette.cyan,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
