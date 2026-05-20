import 'dart:ui';

enum MapTileThemeKind { chapterOne, chapterTwoRift }

class MapTileTheme {
  const MapTileTheme({
    required this.kind,
    required this.pathTopColor,
    required this.pathMidColor,
    required this.pathBottomColor,
    required this.pathRimColor,
    required this.pathStainColor,
    required this.pathChipColor,
    required this.pathLightChipColor,
    required this.pathInsetStrokeColor,
    required this.buildTopColor,
    required this.buildMidColor,
    required this.buildBottomColor,
    required this.buildRimColor,
    required this.buildMossColor,
    required this.buildDarkScuffColor,
    required this.buildMutedLeafColor,
    required this.gridStrokeColor,
    required this.spawnTileColor,
    required this.coreTileColor,
    required this.stoneMortarColor,
    required this.stoneHighlightColor,
    required this.portalOuterColor,
    required this.portalOuterAlertColor,
    required this.portalInnerColor,
    required this.portalInnerAlertColor,
    required this.portalBaseColor,
    required this.portalGlowColor,
    required this.portalSpiralColor,
    required this.portalCoreColor,
    required this.portalPulseColor,
    required this.nexusBaseColor,
    required this.nexusShadowColor,
    required this.nexusGemColor,
    required this.nexusGemHitColor,
    required this.nexusGemStrokeColor,
    required this.energyPrimaryColor,
    required this.energySecondaryColor,
    required this.energySoftColor,
  });

  final MapTileThemeKind kind;
  final Color pathTopColor;
  final Color pathMidColor;
  final Color pathBottomColor;
  final Color pathRimColor;
  final Color pathStainColor;
  final Color pathChipColor;
  final Color pathLightChipColor;
  final Color pathInsetStrokeColor;
  final Color buildTopColor;
  final Color buildMidColor;
  final Color buildBottomColor;
  final Color buildRimColor;
  final Color buildMossColor;
  final Color buildDarkScuffColor;
  final Color buildMutedLeafColor;
  final Color gridStrokeColor;
  final Color spawnTileColor;
  final Color coreTileColor;
  final Color stoneMortarColor;
  final Color stoneHighlightColor;
  final Color portalOuterColor;
  final Color portalOuterAlertColor;
  final Color portalInnerColor;
  final Color portalInnerAlertColor;
  final Color portalBaseColor;
  final Color portalGlowColor;
  final Color portalSpiralColor;
  final Color portalCoreColor;
  final Color portalPulseColor;
  final Color nexusBaseColor;
  final Color nexusShadowColor;
  final Color nexusGemColor;
  final Color nexusGemHitColor;
  final Color nexusGemStrokeColor;
  final Color energyPrimaryColor;
  final Color energySecondaryColor;
  final Color energySoftColor;

  bool get usesRiftEnergy => kind == MapTileThemeKind.chapterTwoRift;
}

const chapterOneTileTheme = MapTileTheme(
  kind: MapTileThemeKind.chapterOne,
  pathTopColor: Color(0xFF968875),
  pathMidColor: Color(0xFF796F60),
  pathBottomColor: Color(0xFF5C554B),
  pathRimColor: Color(0xFF193E3F),
  pathStainColor: Color(0x223E3329),
  pathChipColor: Color(0x66473F35),
  pathLightChipColor: Color(0x338F8575),
  pathInsetStrokeColor: Color(0x333F352B),
  buildTopColor: Color(0xFF3D6048),
  buildMidColor: Color(0xFF2E5040),
  buildBottomColor: Color(0xFF203B34),
  buildRimColor: Color(0xFF183F3D),
  buildMossColor: Color(0x55304335),
  buildDarkScuffColor: Color(0x7720322A),
  buildMutedLeafColor: Color(0x665C7F50),
  gridStrokeColor: Color(0x44083A42),
  spawnTileColor: Color(0xFF4B245F),
  coreTileColor: Color(0xFF0B86B8),
  stoneMortarColor: Color(0x33271618),
  stoneHighlightColor: Color(0x227FF3FF),
  portalOuterColor: Color(0xFFB16DFF),
  portalOuterAlertColor: Color(0xFFE3B7FF),
  portalInnerColor: Color(0xFF2B0D44),
  portalInnerAlertColor: Color(0xFF4A1478),
  portalBaseColor: Color(0xFF190826),
  portalGlowColor: Color(0xFF50E6FF),
  portalSpiralColor: Color(0xFFB16DFF),
  portalCoreColor: Color(0xFFE3B7FF),
  portalPulseColor: Color(0xFF8E46FF),
  nexusBaseColor: Color(0xFF26384A),
  nexusShadowColor: Color(0xFF07111D),
  nexusGemColor: Color(0xFFB9F7FF),
  nexusGemHitColor: Color(0xFFFFD0C6),
  nexusGemStrokeColor: Color(0xFF70DFFF),
  energyPrimaryColor: Color(0xFF50E6FF),
  energySecondaryColor: Color(0xFFB16DFF),
  energySoftColor: Color(0x6650E6FF),
);

const chapterTwoRiftTileTheme = MapTileTheme(
  kind: MapTileThemeKind.chapterTwoRift,
  pathTopColor: Color(0xFF473C63),
  pathMidColor: Color(0xFF332B4D),
  pathBottomColor: Color(0xFF221B35),
  pathRimColor: Color(0xFF0B4F55),
  pathStainColor: Color(0x44301852),
  pathChipColor: Color(0x775D4F84),
  pathLightChipColor: Color(0x557E6FD0),
  pathInsetStrokeColor: Color(0x665B3D91),
  buildTopColor: Color(0xFF284C54),
  buildMidColor: Color(0xFF1D3B46),
  buildBottomColor: Color(0xFF132931),
  buildRimColor: Color(0xFF3B2362),
  buildMossColor: Color(0x553B2D5E),
  buildDarkScuffColor: Color(0x8821434A),
  buildMutedLeafColor: Color(0x777AE7D7),
  gridStrokeColor: Color(0x66384C70),
  spawnTileColor: Color(0xFF2A1748),
  coreTileColor: Color(0xFF0B5A67),
  stoneMortarColor: Color(0x5521173D),
  stoneHighlightColor: Color(0x556CF7FF),
  portalOuterColor: Color(0xFF8F62FF),
  portalOuterAlertColor: Color(0xFFBFFAFF),
  portalInnerColor: Color(0xFF201135),
  portalInnerAlertColor: Color(0xFF3A236F),
  portalBaseColor: Color(0xFF120820),
  portalGlowColor: Color(0xFF5CF9E9),
  portalSpiralColor: Color(0xFFD5B6FF),
  portalCoreColor: Color(0xFF9FFFF4),
  portalPulseColor: Color(0xFF24E7D8),
  nexusBaseColor: Color(0xFF1C3045),
  nexusShadowColor: Color(0xFF080A18),
  nexusGemColor: Color(0xFF8BFFF1),
  nexusGemHitColor: Color(0xFFE3C7FF),
  nexusGemStrokeColor: Color(0xFFB68BFF),
  energyPrimaryColor: Color(0xFF5CF9E9),
  energySecondaryColor: Color(0xFFB68BFF),
  energySoftColor: Color(0x665CF9E9),
);
