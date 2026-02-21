import 'package:flutter/material.dart';

/// Firemní barva pro PIN komponenty.
const Color _accentOrange = Color(0xFFE65100);

/// Vizuální indikátor zadaných číslic – tečky (vyplněné / prázdné).
class PinNumpadIndicator extends StatelessWidget {
  const PinNumpadIndicator({
    super.key,
    required this.filledCount,
    required this.totalCount,
    this.isDisabled = false,
  });

  final int filledCount;
  final int totalCount;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalCount, (index) {
        final isFilled = index < filledCount;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.3)
                : isFilled
                    ? _accentOrange
                    : Colors.white.withValues(alpha: 0.35),
            border: isFilled && !isDisabled
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
          ),
        );
      }),
    );
  }
}

/// Číselník 0–9 + backspace pro zadávání PINu.
class PinNumpad extends StatelessWidget {
  const PinNumpad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    this.isDisabled = false,
  });

  final ValueChanged<int> onDigitPressed;
  final VoidCallback onBackspacePressed;
  final bool isDisabled;

  static const List<List<int?>> _grid = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9],
    [null, 0, -1],
  ];

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1,
      child: IgnorePointer(
        ignoring: isDisabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _grid.map((row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((digitOrAction) {
                if (digitOrAction == null) {
                  return const SizedBox(width: 72 + 16, height: 72 + 16);
                }
                return _KeypadButton(
                  digit: digitOrAction,
                  onPressed: digitOrAction == -1
                      ? onBackspacePressed
                      : () => onDigitPressed(digitOrAction),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.digit, required this.onPressed});

  final int digit;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isBackspace = digit == -1;
    const buttonSize = 72.0;
    const spacing = 16.0;

    return Padding(
      padding: const EdgeInsets.all(spacing / 2),
      child: SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: Material(
          color: isBackspace
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonSize / 2),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(buttonSize / 2),
            splashColor: _accentOrange.withValues(alpha: 0.3),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Center(
              child: isBackspace
                  ? Icon(
                      Icons.backspace_outlined,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 28,
                    )
                  : Text(
                      digit.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
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
