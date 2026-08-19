import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../injector_container.dart';
import '../../../../generated/l10n.dart';
import '../../../../router/app_navigator.dart';
import '../bloc/login_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;
    context.read<LoginBloc>().add(
      LoginSubmitted(username: username, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return BlocProvider(
      create: (_) => sl<LoginBloc>(),
      child: Scaffold(
        backgroundColor: NocturneColors.bg,
        body: Stack(
          children: [
            const Positioned(top: 20, right: 20, child: LanguageSwitcher()),
            Center(
              child: BlocConsumer<LoginBloc, LoginState>(
                listener: (context, state) {
                  if (state.session != null) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil(Routes.shell, (route) => false);
                  }
                },
                builder: (context, state) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: NocturneColors.accent.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.storefront,
                              color: NocturneColors.accent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.appTitle, style: AppTextStyles.h3),
                          const SizedBox(height: 4),
                          Text(
                            l10n.loginSubtitle,
                            style: AppTextStyles.body.copyWith(
                              color: NocturneColors.text.withValues(
                                alpha: 0.55,
                              ),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          TextField(
                            controller: _usernameController,
                            style: AppTextStyles.body,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.loginUsername,
                              prefixIcon: const Icon(
                                PhosphorIconsRegular.at,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            style: AppTextStyles.body,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(context),
                            decoration: InputDecoration(
                              labelText: l10n.loginPassword,
                              prefixIcon: const Icon(
                                PhosphorIconsRegular.lock,
                                size: 18,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? PhosphorIconsRegular.eye
                                      : PhosphorIconsRegular.eyeSlash,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              state.errorMessage!,
                              style: const TextStyle(
                                color: NocturneColors.danger,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: state.isLoading
                                  ? null
                                  : () => _submit(context),
                              child: state.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: NocturneColors.accent,
                                      ),
                                    )
                                  : Text(l10n.loginButton),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
