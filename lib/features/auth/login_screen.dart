import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  String _role = 'admin';
  bool _signup = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_pass.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_signup) {
        final cred = await auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _pass.text);
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': _name.text.trim().isEmpty ? (_role == 'admin' ? 'Manager' : 'Worker') : _name.text.trim(),
          'role': _role,
          'email': _email.text.trim(),
        });
      } else {
        await auth.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.route_rounded, size: 72, color: cs.primary),
                const SizedBox(height: 12),
                Text('FieldRoute',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text('Your route. Your visits. Your hours.',
                    textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 32),
                if (_signup) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          selected: _role == 'admin',
                          avatar: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                          label: const Center(child: Text('Manager / Admin')),
                          onSelected: (selected) {
                            if (selected) setState(() => _role = 'admin');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          selected: _role == 'worker',
                          avatar: const Icon(Icons.badge_outlined, size: 18),
                          label: const Center(child: Text('Field Worker')),
                          onSelected: (selected) {
                            if (selected) setState(() => _role = 'worker');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Full name')),
                  const SizedBox(height: 12),
                ],
                TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password (6+ characters)')),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: cs.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(_signup ? 'Create account' : 'Sign in'),
                ),
                TextButton(
                  onPressed: () => setState(() => _signup = !_signup),
                  child: Text(_signup ? 'I already have an account' : 'New here? Create account'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
