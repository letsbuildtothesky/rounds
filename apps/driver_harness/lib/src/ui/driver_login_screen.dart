import 'package:flutter/material.dart';

import '../app/harness_app_controller.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({required this.controller, super.key});

  final HarnessAppController controller;

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF17453B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'R',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Team driver sign in',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF15382F),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open the Round assigned by your Operations team.',
              style: TextStyle(color: Color(0xFF68766F)),
            ),
            const SizedBox(height: 28),
            TextField(
              key: const Key('driver-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Work email',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('driver-password'),
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Password',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.controller.driverError != null) ...[
              const SizedBox(height: 14),
              Text(
                widget.controller.driverError!,
                style: const TextStyle(color: Color(0xFF9C3B27)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('driver-sign-in'),
              onPressed: widget.controller.driverLoading
                  ? null
                  : () => widget.controller.signInDriver(
                      _email.text,
                      _password.text,
                    ),
              child: Text(
                widget.controller.driverLoading ? 'Signing in…' : 'Sign in',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pilot authentication uses a protected Team account. Phone OTP can replace this entry method without changing Round data.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7B8781), fontSize: 12),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    ),
  );
}
