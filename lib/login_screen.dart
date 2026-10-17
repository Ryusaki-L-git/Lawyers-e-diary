import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'ld_logo.dart';
import 'templates/animations/staggered_entry.dart';
import 'templates/transactions/auth_transactions.dart';
import 'templates/utils/app_snackbar.dart';
import 'templates/widgets/app_button.dart';
import 'templates/widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
  with SingleTickerProviderStateMixin {
  bool isEmailLoading = false;
  bool isGoogleLoading = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _authTransactions = AuthTransactions();
  late final StaggeredEntryController _entryController;

  bool get isLoading => isEmailLoading || isGoogleLoading;

  Widget _entry(int index, Widget child) {
    return StaggeredEntry(
      animation: _entryController.animations[index],
      child: child,
    );
  }

  @override
  void initState() {
    super.initState();
    _entryController = StaggeredEntryController(
      vsync: this,
      itemCount: 7,
    );
    _entryController.controller.forward();
  }

  Future<void> signInWithGoogle() async {
    setState(() => isGoogleLoading = true);

    try {
      final userCredential = await _authTransactions.signInWithGoogle();
      if (userCredential == null) {
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint(
        'Google Sign-In Firebase error: code=${e.code}, '
        'message=${e.message}\n$stackTrace',
      );

      if (!mounted) return;

      _showSnackBar('Google Sign-In failed: ${e.message ?? e.code}');
    } on PlatformException catch (e, stackTrace) {
      debugPrint(
        'Google Sign-In platform error: code=${e.code}, '
        'message=${e.message}\n$stackTrace',
      );

      if (!mounted) return;

      _showSnackBar('Google Sign-In failed: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('Google Sign-In error: $e');

      if (!mounted) return;

      _showSnackBar('Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final emailFormat = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill all fields');
      return;
    }

    if (!emailFormat.hasMatch(email)) {
      _showSnackBar('Invalid email format');
      return;
    }

    if (password.length < 8) {
      _showSnackBar('Password must be at least 8 characters');
      return;
    }

    setState(() => isEmailLoading = true);

    try {
      await _authTransactions.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint(
        'Email login Firebase error: code=${e.code}, '
        'message=${e.message}\n$stackTrace',
      );

      if (!mounted) return;

      final String message;

      switch (e.code) {
        // Firebase Email Enumeration Protection merges 'user-not-found' and
        // 'wrong-password' into the generic 'invalid-credential' code.
        // Handle it explicitly so the user receives a clear, actionable message.
        case 'invalid-credential':
          message = 'Incorrect email or password. Please try again';
          break;
        case 'user-not-found':
          message = 'No account found. Please sign up';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Invalid email format';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection';
          break;
        default:
          message = 'Login failed. Try again';
      }

      _showSnackBar(message);
    } catch (_) {
      if (mounted) _showSnackBar('Login failed. Try again');
    } finally {
      if (mounted) setState(() => isEmailLoading = false);
    }
  }

  Future<void> _sendWindowsPasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Enter your account email first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        _showSnackBar('If an account exists for that email, password-reset instructions have been sent.');
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showSnackBar(error.code == 'invalid-email'
            ? 'Enter a valid email address.'
            : 'Unable to send reset instructions right now. Please try again.');
      }
    } catch (_) {
      if (mounted) _showSnackBar('Unable to send reset instructions right now. Please try again.');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) AppSnackbar.show(context, message);
  }

  void showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Login Help',
            style: TextStyle(color: Colors.black87),
          ),
          content: const Text(
            'Use the email address and password linked to your account. '
            'If you do not have an account yet, select Sign Up or continue '
            'with your Google account.',
            style: TextStyle(color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFFD4AF37)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return _buildWindowsLogin();
    }
    return _buildMobileLogin();
  }

  Widget _buildWindowsLogin() {
    const forest = Color(0xFF1F3D2B);
    const gold = Color(0xFFCCA046);
    const ivory = Color(0xFFF7F5F2);
    const muted = Color(0xFF6B665E);
    return Scaffold(
      backgroundColor: ivory,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 18 : 34),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 640),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5DFD7)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x12000000), blurRadius: 34, offset: Offset(0, 18)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: compact
                      ? Column(children: [
                          _windowsBrandPanel(compact: true),
                          Padding(padding: const EdgeInsets.all(28), child: _windowsLoginForm()),
                        ])
                      : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(flex: 5, child: _windowsBrandPanel(compact: false)),
                          Expanded(flex: 6, child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 44), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 390), child: _windowsLoginForm())))),
                        ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _windowsBrandPanel({required bool compact}) {
    const forest = Color(0xFF1F3D2B);
    const gold = Color(0xFFCCA046);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 25 : 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1F3D2B), Color(0xFF13291C)]),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x66CCA046))), child: const Icon(Icons.balance_rounded, color: gold, size: 27)),
            const SizedBox(width: 13),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("LAWYER'S", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
              SizedBox(height: 4),
              Text('E-DIARY', style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.7)),
            ]),
          ]),
          SizedBox(height: compact ? 24 : 62),
          const Text('A clearer view of your practice.', style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontSize: 30, height: 1.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          const Text('Your cases, hearing dates and daily legal work — organized in one focused workspace.', style: TextStyle(color: Color(0xFFD8E1D9), fontSize: 14, height: 1.65)),
          const SizedBox(height: 30),
          for (final feature in const [
            (Icons.folder_open_outlined, 'A docket built around your cases'),
            (Icons.calendar_month_outlined, 'Hearings and dates in clear view'),
            (Icons.shield_outlined, 'Sign in to your own workspace'),
          ]) Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(10)), child: Icon(feature.$1, color: gold, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(feature.$2, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ),
          if (!compact) const SizedBox(height: 38),
          const Row(children: [
            Icon(Icons.lock_outline_rounded, size: 15, color: gold),
            SizedBox(width: 8),
            Expanded(child: Text('Private workspace · Built for legal practice', style: TextStyle(color: Color(0xFFB9C7BD), fontSize: 10))),
          ]),
        ],
      ),
    );
  }

  Widget _windowsLoginForm() {
    const forest = Color(0xFF1F3D2B);
    const muted = Color(0xFF6B665E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _entry(0, const Center(child: LawFirmMark(width: 82))),
        const SizedBox(height: 22),
        _entry(1, const Text('Welcome back', textAlign: TextAlign.center, style: TextStyle(color: forest, fontFamily: 'Georgia', fontSize: 29, fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        const Text('Sign in to continue to your legal workspace.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13, height: 1.5)),
        const SizedBox(height: 30),
        _entry(2, AppTextField(controller: emailController, label: 'Email address', hint: 'name@lawfirm.com', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress)),
        const SizedBox(height: 18),
        _entry(3, AppTextField(controller: passwordController, label: 'Password', hint: 'Enter your password', icon: Icons.lock_outline_rounded, obscureText: true)),
        const SizedBox(height: 24),
        _entry(4, AppButton(label: 'Sign in securely', onPressed: login, isLoading: isEmailLoading, loadingColor: Colors.white)),
        const SizedBox(height: 18),
        const Row(children: [
          Icon(Icons.info_outline_rounded, size: 15, color: muted),
          SizedBox(width: 7),
          Expanded(child: Text('Use the email and password linked to your LED account.', style: TextStyle(color: muted, fontSize: 10, height: 1.4))),
        ]),
        const SizedBox(height: 20),
        _entry(6, Column(children: [
          TextButton(onPressed: isLoading ? null : () => Navigator.pushNamed(context, '/signup'), child: const Text("Don't have an account? Create one", style: TextStyle(color: forest, fontWeight: FontWeight.w700))),
          TextButton(onPressed: isLoading ? null : _sendWindowsPasswordReset, child: const Text('Forgot password?', style: TextStyle(color: forest, fontWeight: FontWeight.w700))),
          TextButton(onPressed: isLoading ? null : showHelpDialog, child: const Text('Need help signing in?', style: TextStyle(color: muted))),
        ])),
      ],
    );
  }

  Widget _buildMobileLogin() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  _entry(0, const Center(child: LawFirmMark(width: 120))),
                  const SizedBox(height: 24),
                  _entry(
                    1,
                    const Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to manage your cases and diary.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _entry(
                    2,
                    AppTextField(
                      controller: emailController,
                      label: 'Email',
                      hint: 'Enter your email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _entry(
                    3,
                    AppTextField(
                      controller: passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _entry(
                    4,
                    AppButton(
                      label: 'Login',
                      onPressed: login,
                      isLoading: isEmailLoading,
                      loadingColor: Colors.black87,
                    ),
                  ),
                  if (defaultTargetPlatform != TargetPlatform.windows) ...[
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.black12)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.black12)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _entry(
                    5,
                    AppButton(
                      label: 'Continue with Google',
                      onPressed: signInWithGoogle,
                      isLoading: isGoogleLoading,
                      outlined: true,
                      loadingColor: const Color(0xFFD4AF37),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GoogleLogo(size: 28),
                          const SizedBox(width: 8),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ],
                  _entry(
                    6,
                    Column(
                      children: [
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  Navigator.pushNamed(context, '/signup');
                                },
                          child: Text(
                            'Don\'t have an account? Sign Up',
                            style: TextStyle(
                              color: isLoading
                                  ? Colors.black54.withValues(alpha: 0.45)
                                  : Colors.black54,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: isLoading ? null : showHelpDialog,
                          child: Text(
                            'Need help?',
                            style: TextStyle(
                              color: isLoading
                                  ? Colors.black54.withValues(alpha: 0.45)
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}