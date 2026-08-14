import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Back-button behavior that survives `context.go` navigation: pops when
/// there's a page underneath, otherwise goes to [fallback]. `go` replaces the
/// whole stack, so a bare `context.pop()` on such a screen throws "nothing to
/// pop" and the arrow becomes a dead tap — this keeps it working from any
/// entry path (deep link, dev stepper, go vs push).
void backOr(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
