import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import '../../../core/widgets/gradient_background.dart';
import '../data/auth_repository_impl.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.isModal = false});

  final bool isModal;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _repo = AuthRepositoryImpl();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required.');
      }

      if (_isRegister) {
        await _repo.register(email: email, password: password);
      }
      final token = await _repo.login(email: email, password: password);
      await AuthSession.instance.setTokens(
        token.accessToken,
        refreshToken: token.refreshToken,
      );

      // Check for existing interests to skip onboarding if possible
      try {
        final api = ApiClient();
        final resp = await api.get('/v1/interests/me', auth: true);
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final selectedNames = (data['selected'] as List)
              .map((e) => e['name'] as String)
              .toList();

          if (selectedNames.isNotEmpty) {
            // Returning user with interests
            await AppState.instance.completeOnboarding(selectedNames);
            if (mounted) {
              if (widget.isModal) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/');
              }
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Failed to sync interests: $e');
        // Continue to manual selection if sync fails
      }

      if (mounted) {
        if (widget.isModal) {
          Navigator.pop(context);
        } else {
          // If we are not in modal (e.g. from Profile), force interest selection
          AppState.instance.onboardingComplete.value = false;
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegister ? 'Create account' : 'Sign in')),
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 16.0),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8.0),
              ],
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(
                        _loading
                            ? 'Please wait...'
                            : _isRegister
                            ? 'Create and sign in'
                            : 'Sign in',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() => _isRegister = !_isRegister);
                      },
                child: Text(
                  _isRegister
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
