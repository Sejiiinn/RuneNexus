import '../../domain/enemy/enemy_type.dart';
import '../../domain/wave/wave_definition.dart';

part 'game_stage_wave_helpers.dart';
part 'game_stage_wave_previews.dart';
part 'game_stage_wave_spawn_groups.dart';

final gameWaves = List<WaveDefinition>.unmodifiable(_buildGameWaves());
final gameStage2Waves = List<WaveDefinition>.unmodifiable(
  _buildStage2ArmoredWaves(),
);
final gameChapter2Waves = List<WaveDefinition>.unmodifiable(
  _buildStage2Waves(),
);
final gameChapter2Stage7Waves = List<WaveDefinition>.unmodifiable(
  _buildChapter2Stage7Waves(),
);
final gameChapter2Stage8Waves = List<WaveDefinition>.unmodifiable(
  _buildChapter2Stage8Waves(),
);
final gameChapter2Stage9Waves = List<WaveDefinition>.unmodifiable(
  _buildChapter2Stage9Waves(),
);
final gameChapter2Stage10Waves = List<WaveDefinition>.unmodifiable(
  _buildChapter2Stage10Waves(),
);

List<WaveDefinition> _buildGameWaves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _previewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _groupsFor(round),
    );
  });
}

List<WaveDefinition> _buildStage2Waves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _stage2PreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _stage2GroupsFor(round),
    );
  });
}

List<WaveDefinition> _buildChapter2Stage7Waves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _chapter2Stage7PreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _chapter2Stage7GroupsFor(round),
    );
  });
}

List<WaveDefinition> _buildChapter2Stage8Waves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _chapter2Stage8PreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _chapter2Stage8GroupsFor(round),
    );
  });
}

List<WaveDefinition> _buildChapter2Stage9Waves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _chapter2Stage9PreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _chapter2Stage9GroupsFor(round),
    );
  });
}

List<WaveDefinition> _buildChapter2Stage10Waves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _chapter2Stage10PreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _chapter2Stage10GroupsFor(round),
    );
  });
}

List<WaveDefinition> _buildStage2ArmoredWaves() {
  return List<WaveDefinition>.generate(50, (index) {
    final round = index + 1;
    return WaveDefinition(
      round: round,
      previewText: _stage2ArmoredPreviewTextFor(round),
      clearRewardGold: _clearRewardGoldFor(round),
      groups: _stage2ArmoredGroupsFor(round),
    );
  });
}
