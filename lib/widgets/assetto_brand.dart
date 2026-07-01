import 'package:flutter/material.dart';

const String assettoAppIconAsset = 'assets/images/assetto_app_icon.png';

class AssettoAppIcon extends StatelessWidget {
  final double size;

  const AssettoAppIcon({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assettoAppIconAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Assetto',
    );
  }
}

class AssettoBrandTitle extends StatelessWidget {
  final double iconSize;
  final TextStyle? textStyle;
  final MainAxisAlignment alignment;

  const AssettoBrandTitle({
    super.key,
    this.iconSize = 28,
    this.textStyle,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = textStyle ??
        Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        AssettoAppIcon(size: iconSize),
        const SizedBox(width: 10),
        Text('Assetto', style: titleStyle),
      ],
    );
  }
}
