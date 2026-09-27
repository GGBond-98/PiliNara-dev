import 'package:flutter/widgets.dart' show ScrollController, Curves;

extension ScrollControllerExt on ScrollController {
  void animToTop() => animTo(0);

  void animTo(
    double offset, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final positions = this.positions;
    if (positions.length != 1) return;

    final position = positions.single;
    final maxOffset = position.viewportDimension * 2;
    if ((offset - position.pixels).abs() >= maxOffset) {
      position.jumpTo(maxOffset);
    }
    position.animateTo(
      offset,
      duration: duration,
      curve: Curves.easeInOut,
    );
  }

  void jumpToTop() {
    final positions = this.positions;
    if (positions.length != 1) return;
    positions.single.jumpTo(0);
  }
}
