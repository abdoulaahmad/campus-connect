import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';

/// Login screen for CampusConnect AUS.
///
/// Provides email + password authentication and biometric login.
/// Connects to [AuthNotifier] via Riverpod. On [AuthAuthenticated],
/// [RouterNotifier] automatically redirects to the correct shell —
/// this screen never navigates manually.
///
/// **Credentials for DEV/TEST:**
/// - `student@university.edu` / `student123` → Student shell
/// - `admin@university.edu` / `admin123` → Admin shell
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Form ──────────────────────────────────────────────────────────────────

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Animation ─────────────────────────────────────────────────────────────

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Normalize email: mobile keyboards often insert spaces after a period
    // (e.g. "student@university. edu") and capitalize the first letter.
    // Repositories do an exact string match, so strip all whitespace and
    // lowercase before authenticating.
    final String email =
        _emailController.text.replaceAll(RegExp(r'\s'), '').toLowerCase();

    final String? error = await ref.read(authProvider.notifier).login(
          email: email,
          password: _passwordController.text,
        );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = error;
    });
    // On success: RouterNotifier fires automatically — no context.go() needed.
  }

  Future<void> _biometricLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String? error =
        await ref.read(authProvider.notifier).biometricLogin();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = error;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch auth state to reflect loading changes from external triggers.
    final AuthState authState = ref.watch(authProvider);
    final bool authLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: AppTheme.spaceXXL),

                  // ── Logo ────────────────────────────────────────────────────
                  _buildLogoSection(),

                  const SizedBox(height: AppTheme.spaceXL),

                  // ── Heading ─────────────────────────────────────────────────
                  Text(
                    'Welcome Back',
                    style:
                        Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(
                    'Sign in to CampusConnect AUS',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),

                  const SizedBox(height: AppTheme.spaceXL),

                  // ── Error Banner ─────────────────────────────────────────────
                  if (_errorMessage != null) ...<Widget>[
                    _ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: AppTheme.spaceMD),
                  ],

                  // ── Form ─────────────────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        // Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Institutional Email',
                            hintText: 'student@university.edu',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (String? value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppTheme.spaceMD),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Forgot Password (out of scope) ────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: null, // Out of scope for MVP
                      child: Text(
                        'Forgot Password?',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textDisabled,
                            ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spaceSM),

                  // ── Sign In Button ────────────────────────────────────────────
                  ElevatedButton(
                    onPressed:
                        (_isLoading || authLoading) ? null : _login,
                    child: (_isLoading || authLoading)
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.onPrimary,
                            ),
                          )
                        : const Text('Sign In'),
                  ),

                  const SizedBox(height: AppTheme.spaceLG),

                  // ── Divider ───────────────────────────────────────────────────
                  _buildDivider(context),

                  const SizedBox(height: AppTheme.spaceLG),

                  // ── Biometric Button ──────────────────────────────────────────
                  OutlinedButton.icon(
                    onPressed:
                        (_isLoading || authLoading) ? null : _biometricLogin,
                    icon: const Icon(Icons.fingerprint, size: 22),
                    label: const Text('Sign in with Biometrics'),
                  ),

                  const SizedBox(height: AppTheme.spaceXL),

                  // ── Register Link ─────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        "Don't have an account?",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.register),
                        child: const Text('Register'),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spaceMD),

                  // ── Campus Code Footer ────────────────────────────────────────
                  _buildFooter(context),

                  const SizedBox(height: AppTheme.spaceLG),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Private Widgets ───────────────────────────────────────────────────────

  Widget _buildLogoSection() {
    return Row(
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withAlpha(30),
            border: Border.all(color: AppTheme.primary.withAlpha(100)),
          ),
          child: const Icon(
            Icons.school_rounded,
            color: AppTheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: AppTheme.spaceMD),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'CampusConnect',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              'CAM-AUS-11 · Group 11',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.secondary,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
          child: Text(
            'or',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Text(
      'CampusConnect AUS v1.0.0 · /api/v2/aus/ · FCP/CIT/22/1000',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textDisabled,
            fontSize: 10,
          ),
    );
  }
}

// ── Error Banner ──────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.error.withAlpha(20),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppTheme.error.withAlpha(80)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
