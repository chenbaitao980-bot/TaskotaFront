import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/local_storage_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../privacy/privacy_consent_page.dart';
import 'package:smart_assistant/core/utils/snackbar_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _LoginMode { email, phone }

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  _LoginMode _loginMode = _LoginMode.email;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _otpSent = false;
  bool _acceptTerms = false;
  String? _otpPhone;
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
    _phoneController.dispose();
    _otpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_acceptTerms) {
      showAppSnackBar(context, '请先同意用户协议和隐私政策');
      return;
    }
    if (_loginMode == _LoginMode.phone) {
      if (_otpSent) {
        _verifyPhoneOtp();
      } else {
        _requestPhoneOtp();
      }
      return;
    }

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
      context.read<AuthBloc>().add(LoggedIn(email: email, password: password));
    }
  }

  bool get _isDesktop => isDesktop;

  Future<void> _useLocalOnly() async {
    if (!_acceptTerms) {
      showAppSnackBar(context, '请先同意用户协议和隐私政策');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final storage = LocalStorageService();
      await storage.init();
      if (mounted) {
        context.read<AuthBloc>().add(const LocalLogin(email: 'local_desktop'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _normalizedPhone() {
    final raw = _phoneController.text.trim().replaceAll(' ', '');
    if (raw.startsWith('+')) return raw;
    if (raw.length == 11 && raw.startsWith('1')) return '+86$raw';
    return raw;
  }

  Future<void> _requestPhoneOtp() async {
    if (AppConstants.supabaseUrl == 'YOUR_SUPABASE_URL') {
      showAppSnackBar(context, '本地模式不支持手机验证码登录');
      return;
    }
    final phone = _normalizedPhone();
    if (phone.isEmpty || !phone.startsWith('+')) {
      showAppSnackBar(context, '请输入带国家区号的手机号，例如 +8613812345678');
      return;
    }
    _otpPhone = phone;
    context.read<AuthBloc>().add(PhoneOtpRequested(phone: phone));
  }

  Future<void> _verifyPhoneOtp() async {
    final phone = _otpPhone ?? _normalizedPhone();
    final token = _otpController.text.trim();
    if (phone.isEmpty || token.isEmpty) {
      showAppSnackBar(context, '请输入手机号和验证码');
      return;
    }
    context.read<AuthBloc>().add(PhoneOtpVerified(phone: phone, token: token));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated || state is LocalAuthenticated) {
          AppRouter.navigateToAndReplace(context, AppRouter.home);
        } else if (state is PhoneOtpSent) {
          setState(() {
            _otpSent = true;
            _otpPhone = state.phone;
          });
          showAppSnackBar(context, '验证码已发送');
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
                            'Taskora',
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
                            '智能任务管理',
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
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                size: 20,
                              ),
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
                          if (_isDesktop) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: OutlinedButton.icon(
                                onPressed: isSubmitting ? null : _useLocalOnly,
                                icon: const Icon(Icons.storage_outlined),
                                label: const Text('不登录，本地使用'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                child: Checkbox(
                                  value: _acceptTerms,
                                  onChanged: (value) =>
                                      setState(() => _acceptTerms = value ?? false),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    text: '我已阅读并同意 ',
                                    style: TextStyle(
                                      color: AppTheme.textHint,
                                      fontSize: 13,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '用户协议',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _showTerms(context),
                                      ),
                                      const TextSpan(text: ' 和 '),
                                      TextSpan(
                                        text: '隐私政策',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _showPolicy(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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

  void _showPolicy(BuildContext context) => _showDocSheet(context, '隐私政策');
  void _showTerms(BuildContext context) => _showDocSheet(context, '用户协议');

  void _showDocSheet(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  title == '隐私政策' ? privacyPolicyText : termsOfServiceText,
                  style: const TextStyle(fontSize: 14, height: 1.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
