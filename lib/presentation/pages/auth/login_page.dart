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
      showAppSnackBar(context, '璇疯緭鍏ラ偖绠卞拰瀵嗙爜');
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
            showAppSnackBar(context, '瀵嗙爜閿欒');
          }
        }
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, '鐧诲綍澶辫触: $e');
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

  String _normalizedPhone() {
    final raw = _phoneController.text.trim().replaceAll(' ', '');
    if (raw.startsWith('+')) return raw;
    if (raw.length == 11 && raw.startsWith('1')) return '+86$raw';
    return raw;
  }

  Future<void> _requestPhoneOtp() async {
    if (AppConstants.supabaseUrl == 'YOUR_SUPABASE_URL') {
      showAppSnackBar(context, '鏈湴妯″紡涓嶆敮鎸佹墜鏈洪獙璇佺爜鐧诲綍');
      return;
    }
    final phone = _normalizedPhone();
    if (phone.isEmpty || !phone.startsWith('+')) {
      showAppSnackBar(context, '璇疯緭鍏ュ甫鍥藉鍖哄彿鐨勬墜鏈哄彿锛屼緥濡?+8613812345678');
      return;
    }
    _otpPhone = phone;
    context.read<AuthBloc>().add(PhoneOtpRequested(phone: phone));
  }

  Future<void> _verifyPhoneOtp() async {
    final phone = _otpPhone ?? _normalizedPhone();
    final token = _otpController.text.trim();
    if (phone.isEmpty || token.isEmpty) {
      showAppSnackBar(context, '璇疯緭鍏ユ墜鏈哄彿鍜岄獙璇佺爜');
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
                            '浣犵殑 AI 鏃ョ▼绠″',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 40),
                          SegmentedButton<_LoginMode>(
                            segments: const [
                              ButtonSegment(
                                value: _LoginMode.email,
                                icon: Icon(Icons.email_outlined, size: 18),
                                label: Text('閭'),
                              ),
                              ButtonSegment(
                                value: _LoginMode.phone,
                                icon: Icon(Icons.sms_outlined, size: 18),
                                label: Text('手机验证码'),
                              ),
                            ],
                            selected: {_loginMode},
                            onSelectionChanged: isSubmitting
                                ? null
                                : (value) => setState(() {
                                      _loginMode = value.first;
                                      _otpSent = false;
                                      _otpController.clear();
                                    }),
                          ),
                          const SizedBox(height: 16),
                          if (_loginMode == _LoginMode.email) ...[
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '閭',
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
                              labelText: '瀵嗙爜',
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
                          ] else ...[
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: _otpSent
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: '手机号',
                                hintText: '+8613812345678',
                                prefixIcon: Icon(Icons.phone_iphone, size: 20),
                              ),
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
                              onSubmitted: (_) => _login(),
                            ),
                            if (_otpSent) ...[
                              const SizedBox(height: 14),
                              TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: '短信验证码',
                                  prefixIcon: Icon(Icons.password, size: 20),
                                ),
                                onTapOutside: (_) =>
                                    FocusScope.of(context).unfocus(),
                                onSubmitted: (_) => _verifyPhoneOtp(),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : () {
                                          setState(() {
                                            _otpSent = false;
                                            _otpController.clear();
                                          });
                                          _requestPhoneOtp();
                                        },
                                  child: const Text('重新获取验证码'),
                                ),
                              ),
                            ],
                          ],
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
                                  : Text(
                                      _loginMode == _LoginMode.phone
                                          ? (_otpSent ? '验证码登录' : '获取验证码')
                                          : '登录',
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
                                '杩樻病鏈夎处鍙凤紵',
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
                                child: const Text('绔嬪嵆娉ㄥ唽'),
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
