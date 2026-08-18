import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/password_field.dart';
import '../../widgets/auth_card.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and conditions')),
      );
      return;
    }
    final auth = ref.read(authProvider);
    auth.setFullName(_nameController.text.trim());
    auth.setEmail(_emailController.text);
    auth.setPassword(_passwordController.text);
    await auth.register();
  }

  double _passwordStrength(String pwd) {
    if (pwd.isEmpty) return 0;
    double score = 0;
    if (pwd.length >= 6) score += 0.25;
    if (pwd.length >= 10) score += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(pwd)) score += 0.2;
    if (RegExp(r'[0-9]').hasMatch(pwd)) score += 0.2;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pwd)) score += 0.2;
    return score.clamp(0, 1);
  }

  Color _strengthColor(double s) {
    if (s == 0) return Colors.transparent;
    if (s < 0.3) return Colors.red;
    if (s < 0.6) return Colors.orange;
    if (s < 0.8) return Colors.amber.shade700;
    return Colors.green;
  }

  String _strengthLabel(double s) {
    if (s == 0) return '';
    if (s < 0.3) return 'Weak';
    if (s < 0.6) return 'Fair';
    if (s < 0.8) return 'Strong';
    return 'Very strong';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final strength = _passwordStrength(_passwordController.text);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => auth.goTo(AuthScreen.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Account', style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('Start your journaling journey',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 28),
                AuthCard(
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _nameController, label: 'Full Name', hint: 'John Doe',
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        validator: auth.validateName,
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _emailController, label: 'Email', hint: 'hello@example.com',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        validator: auth.validateEmail,
                      ),
                      const SizedBox(height: 20),
                      PasswordField(controller: _passwordController, validator: auth.validatePassword),
                      const SizedBox(height: 6),
                      if (_passwordController.text.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: strength, color: _strengthColor(strength),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(_strengthLabel(strength),
                                style: theme.textTheme.labelSmall?.copyWith(color: _strengthColor(strength))),
                          ],
                        ),
                      const SizedBox(height: 14),
                      PasswordField(
                        controller: _confirmController,
                        label: 'Confirm Password',
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm your password';
                          if (v != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(value: _acceptedTerms,
                              onChanged: (v) => setState(() => _acceptedTerms = v ?? false)),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: theme.textTheme.bodySmall,
                                children: [
                                  TextSpan(text: 'I accept the ',
                                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                                  TextSpan(text: 'Terms & Conditions',
                                      style: TextStyle(color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(auth.error!, style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer)),
                  ),
                ],
                const SizedBox(height: 20),
                CustomButton(label: 'Create Account', isLoading: auth.isLoading, onPressed: _register),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    TextButton(
                      onPressed: () => auth.goTo(AuthScreen.login),
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
