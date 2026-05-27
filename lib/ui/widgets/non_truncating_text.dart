import 'package:flutter/material.dart';

class ScaleDownText extends StatelessWidget {
  const ScaleDownText(
    this.data, {
    this.style,
    this.textAlign,
    this.alignment = Alignment.center,
    super.key,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          data,
          maxLines: 1,
          softWrap: false,
          textAlign: textAlign,
          style: style,
        ),
      ),
    );
  }
}

class FixedSlotText extends StatelessWidget {
  const FixedSlotText(
    this.data, {
    this.maxLines = 1,
    this.style,
    this.textAlign,
    this.alignment = Alignment.center,
    super.key,
  });

  final String data;
  final int maxLines;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Text(
          data,
          maxLines: maxLines,
          textAlign: textAlign,
          style: style,
          overflow: TextOverflow.clip,
        );
        if (!constraints.hasBoundedWidth) {
          return text;
        }
        return Align(
          alignment: alignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: SizedBox(width: constraints.maxWidth, child: text),
          ),
        );
      },
    );
  }
}
