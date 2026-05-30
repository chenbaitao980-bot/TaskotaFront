import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/local_storage_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showAppSnackBar(context, '请输入邮箱和密码');
      return;
    }

    if (AppConstants.supabaseUrl == 'YOUR_SUPABASE_URL') {
      setState(() => _isLoading = true);
      try {
        final storage = LocalStorageService();
        await storage.init();
        final ok = await storage.login(email, password);
        if (ok) {
          await storage.ensureDemoData(email);
          if (mounted) {
            context.read<AuthBloc>().add(LocalLogin(email: email));
          }
        } else {
          if (mounted) {
            showAppSnackBar(context, '密码错误');
          }
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, '登录失败: $e');
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      context.read<AuthBloc>().add(
        LoggedIn(email: email, password: password),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated || state is LocalAuthenticated) {
          AppRouter.navigateToAndReplace(context, AppRouter.home);
        } else if (state is AuthError) {
          showAppSnackBar(context, state.message);
        }
      },
      builder: (context, state) {
        final isSubmitting = _isLoading || state is AuthLoading;

        return Scaffold(
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.smart_toy_rounded,
                                size: 44,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '智能小助手',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.instrumentSerifTextTheme()
                                .displayMedium
                                ?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontSize: 32,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '你的 AI 日程管家',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 40),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '邮箱',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            onSubmitted: (_) =>
                                FocusScope.of(context).nextFocus(),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: '密码',
                              prefixIcon: const Icon(
                                Icons.lock_outlined,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('忘记密码？'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isSubmitting ? null : _login,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: AppTheme.primaryColor,
                                disabledBackgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '登录',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '还没有账号？',
                                style: TextStyle(
                                  color: AppTheme.textHint,
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: () => AppRouter.navigateTo(
                                  context,
                                  AppRouter.register,
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                child: const Text('立即注册'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
