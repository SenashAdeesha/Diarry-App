import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/auth_service.dart';

enum _LockMode { create, confirm, unlock }

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final bool showBackButton;

  const LockScreen({super.key, required this.onUnlocked, this.showBackButton = false});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  final _auth = AuthService.instance;
  _LockMode _mode = _LockMode.unlock;
  final _pin = <int>[];
  String? _firstPin;
  String? _error;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_auth.isTimedOut() && _auth.status == AuthStatus.locked) {
        _auth.lock();
      }
    }
  }

  Future<void> _initMode() async {
    await _auth.init();
    if (!_auth.hasPin) {
      setState(() => _mode = _LockMode.create);
    } else if (await _auth.isBiometricEnabled() &&
        await _auth.authenticateWithBiometrics()) {
      widget.onUnlocked();
    }
  }

  void _onDigit(int digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      _pin.add(digit);
    });
    if (_pin.length == 4) {
      _submit();
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() => _pin.removeLast());
    }
  }

  Future<void> _submit() async {
    final pin = _pin.join();

    switch (_mode) {
      case _LockMode.create:
        _firstPin = pin;
        setState(() {
          _pin.clear();
          _mode = _LockMode.confirm;
        });

      case _LockMode.confirm:
        if (pin == _firstPin) {
          await _auth.setPin(pin);
          widget.onUnlocked();
        } else {
          setState(() {
            _error = 'PINs don\'t match';
            _pin.clear();
            _mode = _LockMode.create;
            _firstPin = null;
          });
        }

      case _LockMode.unlock:
        final valid = await _auth.verifyPin(pin);
        if (valid) {
          widget.onUnlocked();
        } else {
          _attempts++;
          if (_attempts >= 5) {
            await _auth.resetAll();
            setState(() {
              _error = 'Too many attempts. PIN reset.';
              _mode = _LockMode.create;
              _firstPin = null;
              _attempts = 0;
            });
          } else {
            setState(() {
              _error = 'Wrong PIN (${5 - _attempts} tries left)';
              _pin.clear();
            });
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.showBackButton)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            const Spacer(flex: 2),
            Text(
              _mode == _LockMode.create
                  ? 'Create PIN'
                  : _mode == _LockMode.confirm
                      ? 'Confirm PIN'
                      : AppConstants.appName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _mode == _LockMode.create
                  ? 'Choose a 4-digit PIN'
                  : _mode == _LockMode.confirm
                      ? 'Enter the same PIN again'
                      : 'Enter your PIN',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    border: !filled
                        ? Border.all(color: theme.colorScheme.outlineVariant)
                        : null,
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 32),
            if (_auth.biometricAvailable &&
                _mode == _LockMode.unlock) ...[
              IconButton(
                iconSize: 48,
                icon: Icon(Icons.fingerprint,
                    color: theme.colorScheme.primary),
                onPressed: () async {
                  if (await _auth.authenticateWithBiometrics()) {
                    widget.onUnlocked();
                  }
                },
              ),
              const SizedBox(height: 8),
              Text('Use fingerprint or face ID',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const Spacer(flex: 1),
            ] else ...[
              const Spacer(flex: 1),
            ],
            _buildKeypad(theme),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            children: [
              _KeypadButton('1', () => _onDigit(1)),
              _KeypadButton('2', () => _onDigit(2)),
              _KeypadButton('3', () => _onDigit(3)),
            ],
          ),
          Row(
            children: [
              _KeypadButton('4', () => _onDigit(4)),
              _KeypadButton('5', () => _onDigit(5)),
              _KeypadButton('6', () => _onDigit(6)),
            ],
          ),
          Row(
            children: [
              _KeypadButton('7', () => _onDigit(7)),
              _KeypadButton('8', () => _onDigit(8)),
              _KeypadButton('9', () => _onDigit(9)),
            ],
          ),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              _KeypadButton('0', () => _onDigit(0)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: IconButton(
                    icon: const Icon(Icons.backspace_outlined),
                    onPressed: _pin.isNotEmpty ? _onDelete : null,
                    iconSize: 28,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _KeypadButton(this.label, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Container(
              height: 60,
              alignment: Alignment.center,
              child: Text(
                label,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
