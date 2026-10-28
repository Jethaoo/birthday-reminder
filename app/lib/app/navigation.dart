import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Returns to the previous route, or to [fallback] when there is no history.
void popOrGo(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}
