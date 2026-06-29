import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';

/// Registration screen for new student accounts.
///
/// Collects name, institutional email, matriculation number, and password.
/// Validates institutional email domain client-side before submission.
/// Connects to [AuthNotifier] — on [AuthAuthenticated], [RouterNotifier]
/// automatically redirects to the student shell.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ── Form ──────────────────────────────────────────────────────────────────

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _matricController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
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
      duration: const Duration(milliseconds: 600),
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
    _nameController.dispose();
    _emailController.dispose();
    _matricController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Validation Helpers ────────────────────────────────────────────────────

  static const List<String> _acceptedDomains = <String>[
    '.edu',
    '.edu.ng',
    '.ac.uk',
    '.ac.ng',
  ];

  bool _isInstitutionalEmail(String email) {
    if (!email.contains('@')) return false;
    return _acceptedDomains.any(
      (String domain) => email.toLowerCase().endsWith(domain),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Normalize email: strip all whitespace (mobile keyboards insert spaces
    // after a period) and lowercase, matching the login screen behaviour.
    final String email =
        _emailController.text.replaceAll(RegExp(r'\s'), '').toLowerCase();

    final String? error = await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          email: email,
          matricNumber: _matricController.text.trim(),
          password: _passwordController.text,
          confirmPassword: _confirmController.text,
        );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = error;
    });
    // On success: RouterNotifier fires — no context.go() needed.
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authProvider);
    final bool authLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go(AppRoutes.login),
        ),
        title: const Text('Create Account'),
      ),
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
                  const SizedBox(height: AppTheme.spaceMD),

                  // ── Heading ──────────────────────────────────────────────────
                  Text(
                    'Join CampusConnect AUS',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(
                    'Create your student account to get started.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),

                  const SizedBox(height: AppTheme.spaceLG),

                  // ── Error Banner ─────────────────────────────────────────────
                  if (_errorMessage != null) ...<Widget>[
                    _ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: AppTheme.spaceMD),
                  ],

                  // ── Form ─────────────────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Full Name
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Abdullahi Abba Ahmad',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (String? value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Full name is required';
                            }
                            if (value.trim().split(' ').length < 2) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppTheme.spaceMD),

                        // Institutional Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Institutional Email',
                            hintText: 'student@university.edu',
                            prefixIcon: Icon(Icons.alternate_email),
                            helperText:
                                'Must be an institutional email (.edu, .ac.ng, etc.)',
                          ),
                          validator: (String? value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!_isInstitutionalEmail(value.trim())) {
                              return 'Please use your institutional email address';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppTheme.spaceMD),

                        // Matriculation Number
                        TextFormField(
                          controller: _matricController,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Matriculation Number',
                            hintText: 'FCP/CIT/22/1000',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (String? value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Matriculation number is required';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppTheme.spaceMD),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Minimum 8 characters',
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
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppTheme.spaceMD),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _register(),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            hintText: 'Repeat your password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                          validator: (String? value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spaceLG),

                  // ── Create Account Button ─────────────────────────────────────
                  ElevatedButton(
                    onPressed:
                        (_isLoading || authLoading) ? null : _register,
                    child: (_isLoading || authLoading)
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.onPrimary,
                            ),
                          )
                        : const Text('Create Account'),
                  ),

                  const SizedBox(height: AppTheme.spaceLG),

                  // ── Login Link ────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Already have an account?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.login),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spaceMD),
                ],
              ),
            ),
          ),
        ),
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
