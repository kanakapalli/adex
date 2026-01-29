import 'package:adex_client/adex_client.dart';
import 'package:flutter/material.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../main.dart';

class SignInScreen extends StatefulWidget {
  final Widget child;
  const SignInScreen({super.key, required this.child});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    client.auth.authInfoListenable.addListener(_updateSignedInState);
    _isSignedIn = client.auth.isAuthenticated;
  }

  @override
  void dispose() {
    client.auth.authInfoListenable.removeListener(_updateSignedInState);
    super.dispose();
  }

  void _updateSignedInState() {
    setState(() {
      _isSignedIn = client.auth.isAuthenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSignedIn) return widget.child;

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      body: isDesktop
          ? _DesktopSignIn(client: client)
          : _MobileSignIn(client: client),
    );
  }
}

// ---------------------------------------------------------------------------
// Stateful wrapper that manages the EmailAuthController, shows errors via
// SnackBar, and resets the controller state so the button re-enables.
// ---------------------------------------------------------------------------
class _EmailSignInForm extends StatefulWidget {
  final Client client;
  const _EmailSignInForm({required this.client});

  @override
  State<_EmailSignInForm> createState() => _EmailSignInFormState();
}

class _EmailSignInFormState extends State<_EmailSignInForm> {
  late final EmailAuthController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EmailAuthController(
      client: widget.client,
      startScreen: EmailFlowScreen.login,
      onError: _handleError,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleError(Object error) {
    if (!mounted) return;

    // Show a SnackBar with the error message.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
        showCloseIcon: true,
        closeIconColor: Colors.white,
      ),
    );

    // Reset the controller state to idle so the button re-enables.
    // navigateTo the current screen resets state without changing screens.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _controller.navigateTo(_controller.currentScreen);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SignInWidget(
      client: widget.client,
      onAuthenticated: () {},
      emailSignInWidget: EmailSignInWidget(
        controller: _controller,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop: split layout — branded left panel + sign-in form on the right
// ---------------------------------------------------------------------------
class _DesktopSignIn extends StatelessWidget {
  final Client client;
  const _DesktopSignIn({required this.client});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        // ---- Left branding panel ----
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7B1FA2),
                  Color(0xFF9C27B0),
                  Color(0xFFE65100),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Subtle pattern overlay
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.06,
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 64,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo with glow effect
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          child: Image.asset(
                            'assets/logo/adex_logo.png',
                            width: 100,
                            height: 100,
                          ),
                        ),
                        const SizedBox(height: 36),
                        const Text(
                          'ADEX',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Adaptive Data Extraction System',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 56),
                        // Feature highlights
                        ...(_features.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    item.$1,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  item.$2,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ---- Right sign-in panel ----
        Expanded(
          flex: 4,
          child: Container(
            color: isDark
                ? theme.colorScheme.surface
                : theme.colorScheme.surfaceContainerLowest,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 64,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Small logo for context
                      Row(
                        children: [
                          Image.asset(
                            'assets/logo/adex_logo.png',
                            width: 32,
                            height: 32,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'ADEX',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      Text(
                        'Welcome',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your account to continue',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _EmailSignInForm(client: client),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile: single-column layout with branding header and form below
// ---------------------------------------------------------------------------
class _MobileSignIn extends StatelessWidget {
  final Client client;
  const _MobileSignIn({required this.client});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ---- Gradient header ----
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF7B1FA2),
                Color(0xFF9C27B0),
                Color(0xFFE65100),
              ],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: Image.asset(
                      'assets/logo/adex_logo.png',
                      width: 56,
                      height: 56,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ADEX',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adaptive Data Extraction System',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ---- Sign-in form ----
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to your account to continue',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _EmailSignInForm(client: client),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Feature items shown on the desktop branding panel
const _features = [
  (Icons.video_library_outlined, 'Process and analyze video content'),
  (Icons.auto_awesome_outlined, 'AI-powered data extraction'),
  (Icons.speed_outlined, 'Fast and accurate results'),
];

// ---------------------------------------------------------------------------
// Subtle grid pattern for the desktop branding panel background
// ---------------------------------------------------------------------------
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    const spacing = 30.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
