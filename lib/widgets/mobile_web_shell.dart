import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double _mobileMaxWidth = 480;

class MobileWebShell extends StatelessWidget {
  final Widget child;

  const MobileWebShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWideLayout = screenWidth > _mobileMaxWidth;

    return ColoredBox(
      color: isWideLayout ? const Color(0xFFECEFF1) : Colors.white,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _mobileMaxWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: isWideLayout
                    ? const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
