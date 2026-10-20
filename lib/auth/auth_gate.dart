import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../base/base_screen.dart';
import '../data/repositories/onboarding_repo.dart';
import '../data/repositories/session_bootstrap.dart';
import '../onboarding/onboarding_flow.dart';

import 'auth_service.dart';
import 'screens/sign_in_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _repo = OnboardingRepo();

  String? _bootUid;
  Future<void>? _boot;

  Future<void> _bootFor(User user) {
    if (_bootUid != user.uid || _boot == null) {
      _bootUid = user.uid;
      _boot = SessionBootstrap.run(user);
    }
    return _boot!;
  }

  void _retry(User user) => setState(() {
        _bootUid = null;
        _boot = null;
        _bootFor(user);
      });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.I.authState(),
      builder: (context, snap) {
        final user = snap.data;

        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (user == null) {
          _bootUid = null;
          _boot = null;
          return const SignInScreen();
        }

        // Signed in: first sync with the server, then show onboarding or the app.
        return FutureBuilder<void>(
          future: _bootFor(user),
          builder: (context, bootSnap) {
            if (bootSnap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (bootSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 48),
                        const SizedBox(height: 12),
                        Text('${bootSnap.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: () => _retry(user), child: const Text('Try again')),
                        TextButton(onPressed: AuthService.I.signOut, child: const Text('Sign out')),
                      ],
                    ),
                  ),
                ),
              );
            }

            return FutureBuilder(
              future: _repo.load(),
              builder: (context, obSnap) {
                if (!obSnap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                final r = obSnap.data!;
                if (r.onboarded) return BaseScreen(data: r.data);
                return OnboardingFlow(initialData: r.data, initialIndex: r.step);
              },
            );
          },
        );
      },
    );
  }
}
