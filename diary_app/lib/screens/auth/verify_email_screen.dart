import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/auth_card.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _emailSent = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _sendVerification());
  }

  Future<void> _sendVerification() async {
    final success = await ref.read(authProvider).resendVerification();
    if (mounted) setState(() => _emailSent = success);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Hero(
                tag: 'app_logo',
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(Icons.mark_email_unread, size: 40,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 32),
              Text('Verify Your Email', style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 28),
              AuthCard(
                child: Column(
                  children: [
                    Icon(Icons.email_outlined, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 20),
                    Text('We sent a verification email to',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(auth.user?.email ?? '',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(
                      'Please check your inbox and click the verification link.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Didn\'t receive it? Check your spam folder.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: auth.isLoading ? 'Checking...' : "I've Verified",
                isLoading: auth.isLoading,
                onPressed: () => auth.checkEmailVerified(),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final s = await auth.resendVerification();
                  if (mounted) setState(() => _emailSent = s);
                },
                child: Text(_emailSent ? '✓ Verification Sent' : 'Resend Email'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => auth.logout(),
                child: Text('Use a different email',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
