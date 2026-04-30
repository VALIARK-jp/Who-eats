import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

enum AppStateType {
  loading,
  empty,
  error,
  permissionDenied,
  offline,
}

/// Simple unified UI for common app states.
class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.onRetry,
  });

  final AppStateType type;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (type == AppStateType.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final defaultTitle = switch (type) {
      AppStateType.empty => 'データがありません',
      AppStateType.error => '読み込みに失敗しました',
      AppStateType.permissionDenied => '権限が必要です',
      AppStateType.offline => '通信状況が不安定です',
      _ => null,
    };

    final defaultMessage = switch (type) {
      AppStateType.empty => '次に進むための導線を用意します。',
      AppStateType.error => 'もう一度お試しください。',
      AppStateType.permissionDenied => '位置情報/カメラ権限を許可してください。',
      AppStateType.offline => 'しばらくしてから再度お試しください。',
      _ => null,
    };

    final t = title ?? defaultTitle;
    final m = message ?? defaultMessage;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.blackElevated.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == AppStateType.permissionDenied) ...[
              const Icon(Icons.location_off_outlined, size: 38),
              const SizedBox(height: 10),
            ] else if (type == AppStateType.offline) ...[
              const Icon(Icons.wifi_off_outlined, size: 38),
              const SizedBox(height: 10),
            ] else if (type == AppStateType.error) ...[
              const Icon(Icons.error_outline, size: 38),
              const SizedBox(height: 10),
            ] else if (type == AppStateType.empty) ...[
              const Icon(Icons.hourglass_bottom_outlined, size: 38),
              const SizedBox(height: 10),
            ],
            Text(
              t ?? '',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (m != null)
              Text(
                m,
                style: TextStyle(
                  color: AppColors.textSubtle.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.black,
                ),
                child: const Text('再試行'),
              )
            ],
          ],
        ),
      ),
    );
  }
}

