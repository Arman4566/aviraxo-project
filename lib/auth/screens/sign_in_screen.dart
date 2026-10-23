import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../../widgets/gp_buttons.dart';
import '../auth_service.dart';
import 'email_auth_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool loading = false;
  String? err;

  Future<void> _google() async {
    if (loading) return;
    setState(() {
      loading = true;
      err = null;
    });
    try {
      await AuthService.I.signInWithGoogle();
    } catch (e) {
      setState(() => err = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _openEmail() {
    if (loading) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
          child: Column(
            children: [
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: GPColors.line.withOpacity(0.6)),
                ),
                child: Image.asset(
                  'assets/images/galla_pro.png',
                  height: 88,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "Welcome to Galla Pro",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Sign in to keep your invoices, parties and stock safely on the server and use them on any device.",
                textAlign: TextAlign.center,
                style: TextStyle(color: GPColors.ink2, height: 1.35),
              ),
              const SizedBox(height: 22),

              if (err != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GPColors.tint.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GPColors.line),
                  ),
                  child: Text(err!, style: TextStyle(color: GPColors.ink2)),
                ),
                const SizedBox(height: 12),
              ],

              GPPrimaryButton(
                text: loading ? "Signing in..." : "Continue with Google",
                onPressed: () {
                  _google(); // ✅ always non-null callback
                },
              ),
              const SizedBox(height: 12),

              GPSecondaryButton(
                text: "Continue with Email",
                onPressed: () {
                  _openEmail(); // ✅ always non-null callback
                },
              ),

              const Spacer(),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
