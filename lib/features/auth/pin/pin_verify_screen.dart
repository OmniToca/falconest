import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/pin_storage.dart';
import 'package:falconest/core/auth/pin_unlock_provider.dart';
import 'package:falconest/core/services/supabase_service.dart';

/// Firemní barvy – konzistentní s login obrazovkou.
const _primaryBlue = Color(0xFF1565C0);
const _accentOrange = Color(0xFFE65100);

/// Obrazovka pro odemknutí aplikace pomocí 6místného PINu.
///
/// Zobrazuje se na mobilu, když je session platná, ale uživatel ještě nezadal PIN.
/// Po správném zadání nastaví pinUnlocked a router přesměruje na dashboard.
/// "Zapomněl jsem PIN" odhlásí uživatele a smaže PIN.
class PinVerifyScreen extends ConsumerStatefulWidget {
  const PinVerifyScreen({super.key});

  @override
  ConsumerState<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends ConsumerState<PinVerifyScreen>
    with SingleTickerProviderStateMixin {
  final _pinputController = TextEditingController();
  bool _isVerifying = false;
  bool _showError = false;
  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(12, 0)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(12, 0), end: const Offset(-12, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(-12, 0), end: const Offset(8, 0)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(8, 0), end: const Offset(-4, 0)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-4, 0), end: Offset.zero), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pinputController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin(String pin) async {
    if (_isVerifying || pin.length != 6) return;

    setState(() {
      _isVerifying = true;
      _showError = false;
    });

    final stored = await PinStorage.getPin();

    if (!mounted) return;

    if (stored == pin) {
      ref.read(pinUnlockedProvider.notifier).state = true;
      _navigateToApp();
    } else {
      setState(() {
        _isVerifying = false;
        _showError = true;
      });
      _pinputController.clear();
      _shakeController.forward(from: 0).then((_) {
        if (mounted) _shakeController.reset();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pin.error_wrong'.tr()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _navigateToApp() {
    final authNotifier = ref.read(authNotifierProvider);
    final state = authNotifier.state;

    if (state.isSuperAdmin) {
      context.go('/super-admin');
    } else if (state.isAdminOrManager) {
      context.go('/admin');
    } else if (state.isPropertyOwner) {
      context.go('/owner/apartments');
    } else {
      context.go('/worker');
    }
  }

  /// Odhlásí uživatele, smaže PIN a přesměruje na přihlášení.
  Future<void> _onForgotPin() async {
    await SupabaseService.client.auth.signOut();
    await PinStorage.deletePin();
    ref.read(pinUnlockedProvider.notifier).state = false;
    if (!mounted) return;
    context.go('/');
  }

  PinTheme _buildPinTheme(Color borderColor) {
    return PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = _buildPinTheme(
      _showError ? Colors.red.shade400 : Colors.white.withValues(alpha: 0.5),
    );
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: _accentOrange, width: 2),
      ),
    );

    return Scaffold(
      backgroundColor: _primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Text(
                'pin.verify_title'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'pin.verify_subtitle'.tr(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: _shakeAnimation.value,
                    child: child,
                  );
                },
                child: Pinput(
                  controller: _pinputController,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: _accentOrange, width: 2),
                    ),
                  ),
                  pinputAutovalidateMode: PinputAutovalidateMode.disabled,
                  enabled: !_isVerifying,
                  onCompleted: _verifyPin,
                ),
              ),
              if (_isVerifying)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              const Spacer(flex: 3),
              TextButton(
                onPressed: _isVerifying ? null : _onForgotPin,
                child: Text(
                  'pin.forgot_pin'.tr(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
