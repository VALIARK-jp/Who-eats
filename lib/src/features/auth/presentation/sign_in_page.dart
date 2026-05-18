import 'package:flutter/material.dart';

import 'login_page.dart';

/// 後方互換。新規画面は [LoginPage] / [SignupPage] を使う。
@Deprecated('Use LoginPage instead')
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) => const LoginPage();
}
