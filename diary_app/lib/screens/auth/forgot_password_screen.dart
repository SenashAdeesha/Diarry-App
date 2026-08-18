import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/auth_card.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authProvider);
    auth.setEmail(_emailController.text);
    final success = await auth.sendPasswordReset();
    if (success && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.lock_reset, size: 28,
                    color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 24),
              Text('Reset Password', style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text('Enter your email and we\'ll send you a reset link',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 28),
              if (!_sent) ...[
                AuthCard(
                  child: CustomTextField(
                    controller: _emailController, label: 'Email', hint: 'hello@example.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    validator: auth.validateEmail,
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
                CustomButton(label: 'Send Reset Link', isLoading: auth.isLoading, onPressed: _reset),
              ] else ...[
                AuthCard(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 48,
                          color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Email Sent!', style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        'We\'ve sent a password reset link to ${_emailController.text}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                CustomButton(label: 'Back to Sign In',
                    onPressed: () => auth.goTo(AuthScreen.login)),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
