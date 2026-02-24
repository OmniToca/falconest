import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import 'package:falconest/core/auth/auth_provider.dart';
import 'package:falconest/core/auth/pin_storage.dart';
import 'package:falconest/core/auth/pin_unlock_provider.dart';

/// Firemní barvy – konzistentní s login obrazovkou.
const _primaryBlue = Color(0xFF1565C0);
const _accentOrange = Color(0xFFE65100);

/// Krok nastavení PINu – zadání nebo potvrzení.
enum _PinSetupStep { enter, confirm }

/// Obrazovka pro vytvoření 6místného PINu po prvním přihlášení na mobilu.
///
/// Uživatel zadá PIN dvakrát (vstup + potvrzení). Pokud se shodují, uloží se
/// do secure storage a přesměruje na dashboard podle role.
class PinSetupScreen extends ConsumerStatefulWidget {
  /// Voláno při změně PINu (z nastavení) – po uložení zavře dialog/pop.
  const PinSetupScreen({super.key, this.isChangeFlow = false});

  final bool isChangeFlow;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _firstPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  _PinSetupStep _step = _PinSetupStep.enter;
  String _firstPin = '';
  bool _isSaving = false;

  @override
  void dispose() {
    _firstPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
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

  Future<void> _onFirstPinCompleted(String pin) async {
    if (pin.length != 6) return;
    setState(() {
      _firstPin = pin;
      _step = _PinSetupStep.confirm;
      _confirmPinController.clear();
    });
  }

  Future<void> _onConfirmPinCompleted(String pin) async {
    if (pin.length != 6 || _isSaving) return;

    if (pin != _firstPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('pin.error_mismatch'.tr()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _confirmPinController.clear();
      return;
    }

    setState(() => _isSaving = true);

    try {
      await PinStorage.setPin(pin);
      if (!mounted) return;

      ref.read(pinUnlockedProvider.notifier).state = true;

      if (widget.isChangeFlow) {
        Navigator.of(context).pop(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('pin.change_success'.tr()),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _navigateToApp();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isSaving = false;
          _confirmPinController.clear();
        });
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
      context.go('/owner');
    } else {
      context.go('/worker');
    }
  }

  void _onBack() {
    if (_step == _PinSetupStep.confirm) {
      setState(() {
        _step = _PinSetupStep.enter;
        _firstPin = '';
        _firstPinController.clear();
        _confirmPinController.clear();
      });
    } else if (widget.isChangeFlow) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = _buildPinTheme(Colors.white.withValues(alpha: 0.5));
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: _accentOrange, width: 2),
      ),
    );

    final isConfirmStep = _step == _PinSetupStep.confirm;
    final title = isConfirmStep ? 'pin.setup_confirm_title'.tr() : 'pin.setup_title'.tr();
    final subtitle = isConfirmStep ? 'pin.setup_confirm_subtitle'.tr() : 'pin.setup_subtitle'.tr();

    return Scaffold(
      backgroundColor: _primaryBlue,
      appBar: widget.isChangeFlow || _step == _PinSetupStep.confirm
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _isSaving ? null : _onBack,
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              else if (isConfirmStep)
                Pinput(
                  controller: _confirmPinController,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: _accentOrange, width: 2),
                    ),
                  ),
                  pinputAutovalidateMode: PinputAutovalidateMode.disabled,
                  enabled: !_isSaving,
                  onCompleted: _onConfirmPinCompleted,
                )
              else
                Pinput(
                  controller: _firstPinController,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: _accentOrange, width: 2),
                    ),
                  ),
                  pinputAutovalidateMode: PinputAutovalidateMode.disabled,
                  enabled: !_isSaving,
                  onCompleted: _onFirstPinCompleted,
                ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
