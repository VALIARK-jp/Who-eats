import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/sign_in_page.dart';

/// 未ログイン時にホーム以外のタブ上へ重ねる、グレーアウト＋ログイン誘導。
class SignedInGateOverlay extends StatelessWidget {
  const SignedInGateOverlay({
    super.key,
    required this.bottomInset,
    required this.tabIndex,
  });

  final double bottomInset;

  /// [FloatingBottomNav] の index（0=ホームは呼び出し側で除外）。
  final int tabIndex;

  String get _title {
    switch (tabIndex) {
      case 1:
        return '友達機能を使うにはログインが必要です';
      case 2:
        return '投稿するにはログインが必要です';
      case 3:
        return '記録を見るにはログインが必要です';
      case 4:
        return 'プロフィールを使うにはログインが必要です';
      default:
        return 'ログインが必要です';
    }
  }

  void _openSignIn(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SignInPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: bottomInset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Material(
                color: AppColors.cardElevated,
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 40,
                        color: AppColors.orange.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'ログインまたは新規登録すると、すべての機能が使えます。',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSubtle,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _openSignIn(context),
                          child: const Text('ログイン'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _openSignIn(context),
                          child: const Text('新規登録'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
