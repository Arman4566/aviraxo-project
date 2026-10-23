import 'package:flutter/material.dart' hide Text;
import '../../l10n/auto_translate.dart';
import '../../l10n/gtext.dart';
import '../../theme/gp_colors.dart';
import '../../widgets/gp_buttons.dart';
import '../auth_service.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final emailC = TextEditingController();
  final passC = TextEditingController();

  bool isLogin = true;
  bool loading = false;
  String? err;

  Future<void> _submit() async {
    if (loading) return;

    setState(() {
      loading = true;
      err = null;
    });

    try {
      final email = emailC.text.trim();
      final pass = passC.text;

      if (email.isEmpty || !email.contains("@")) {
        throw Exception("Enter a valid email.");
      }
      if (pass.length < 6) {
        throw Exception("Password should be at least 6 characters.");
      }

      if (isLogin) {
        await AuthService.I.signInWithEmail(email: email, password: pass);
      } else {
        await AuthService.I.signUpWithEmail(email: email, password: pass);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => err = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toggleMode() {
    if (loading) return;
    setState(() {
      isLogin = !isLogin;
      err = null;
    });
  }

  @override
  void dispose() {
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? "Sign in with Email" : "Create Account"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          children: [
            TextField(
              controller: emailC,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: trs("Email")),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passC,
              obscureText: true,
              decoration: InputDecoration(labelText: trs("Password")),
            ),
            const SizedBox(height: 14),

            if (err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(err!, style: TextStyle(color: GPColors.ink2)),
              ),

            GPPrimaryButton(
              text: loading ? "Please wait..." : (isLogin ? "Sign In" : "Sign Up"),
              onPressed: () {
                _submit(); // ✅ always non-null callback
              },
            ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: _toggleMode, // ✅ always non-null callback
              child: Text(
                isLogin ? "New here? Create account" : "Already have account? Sign in",
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
