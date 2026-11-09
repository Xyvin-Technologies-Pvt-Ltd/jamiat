import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/interfaces/components/loading_indicator.dart';

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    required this.asyncValue,
    required this.builder,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> asyncValue;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      // Keep previous content visible while a background refresh runs
      // (pull-to-refresh, app resume, invalidate).
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: LoadingAnimation()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: kBodyTitleR.copyWith(color: kSecondaryTextColor),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
      data: builder,
    );
  }
}
