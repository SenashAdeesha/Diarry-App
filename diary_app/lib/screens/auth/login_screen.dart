import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/password_field.dart';
import '../../widgets/auth_card.dart';
import '../../widgets/social_login_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
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
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authProvider);
    auth.setEmail(_emailController.text);
    auth.setPassword(_passwordController.text);
    await auth.login();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, size.height * 0.06, 24, 24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 24, offset: const Offset(0, 10),
                          )],
                        ),
                        child: const Icon(Icons.menu_book_rounded, size: 40, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text('Welcome back', style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text('Sign in to your account',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 36),
                    AuthCard(
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email', hint: 'Enter your email',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.email_outlined, size: 20),
                            validator: auth.validateEmail,
                          ),
                          const SizedBox(height: 18),
                          PasswordField(
                            controller: _passwordController,
                            validator: auth.validatePassword,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(
                                height: 40,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      Text('Remember me', style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => auth.goTo(AuthScreen.forgotPassword),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Forgot password?'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(child: Text(auth.error!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer))),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    CustomButton(label: 'Sign In', isLoading: auth.isLoading, onPressed: _login),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('or continue with',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ),
                        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SocialLoginButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata,
                      iconColor: Colors.red,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?",
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        TextButton(
                          onPressed: () => auth.goTo(AuthScreen.register),
                          child: const Text('Register'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
