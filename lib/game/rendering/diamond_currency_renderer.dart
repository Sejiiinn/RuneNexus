import 'dart:ui';

const String diamondCurrencyImageFile = 'diamond_currency.png';
const String diamondCurrencyImageAsset = 'assets/images/$diamondCurrencyImageFile';

void drawDiamondCurrencyGlyph(Canvas canvas, Size size, Image? image) {
  if (image == null) {
    return;
  }
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Offset.zero & size,
    Paint()..filterQuality = FilterQuality.medium,
  );
}
