import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports its child's height, now and whenever it changes.
///
/// For a full-bleed map layer that has to keep its own controls out from under
/// the sheet drawn over it: the sheet sizes itself to its content, so only the
/// screen that owns both can know how much of the map is covered. Wrap the sheet
/// in this, keep the height in state, and hand it to the map.
///
/// [onHeight] is called after layout (never during it), so it is safe to
/// `setState` from. It fires only when the height actually changes.
class MeasureHeight extends SingleChildRenderObjectWidget {
  const MeasureHeight({super.key, required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMeasureHeight).onHeight = onHeight;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _last) return;
    _last = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
