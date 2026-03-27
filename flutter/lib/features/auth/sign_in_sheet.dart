import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/auth_provider.dart';

enum _AuthMode { signIn, forgotPassword, register }

/// Bottom sheet for Supabase email/password auth.
/// Handles sign in, forgot password, and registration in one surface.
class SignInSheet extends ConsumerStatefulWidget {
  const SignInSheet({super.key});

  @override
  ConsumerState<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends ConsumerState<SignInSheet> {
  _AuthMode _mode = _AuthMode.signIn;
  bool _loading = false;
  bool _registrationSent = false;
  String? _errorMessage;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;

      switch (_mode) {
        case _AuthMode.signIn:
          await ref.read(authNotifierProvider.notifier).signIn(email, password);
          if (mounted) Navigator.of(context).pop(true);

        case _AuthMode.forgotPassword:
          await ref
              .read(authNotifierProvider.notifier)
              .resetPassword(email);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Password reset email sent. Check your inbox.'),
              ),
            );
            Navigator.of(context).pop();
          }

        case _AuthMode.register:
          if (password != _confirmCtrl.text) {
            setState(() {
              _errorMessage = 'Passwords do not match';
              _loading = false;
            });
            return;
          }
          await ref
              .read(authNotifierProvider.notifier)
              .register(email, password);
          if (mounted) setState(() => _registrationSent = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (raw.contains('User already registered')) {
      return 'An account with this email already exists.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: _registrationSent
            ? _buildConfirmation()
            : _buildForm(),
      ),
    );
  }

  Widget _buildConfirmation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_outlined,
            size: 48, color: Colors.green),
        const SizedBox(height: 12),
        const Text(
          'Check your email',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a confirmation link to ${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _registrationSent = false;
              _mode = _AuthMode.signIn;
            }),
            child: const Text('Back to sign in'),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title
        Text(
          switch (_mode) {
            _AuthMode.signIn => 'Sign in',
            _AuthMode.forgotPassword => 'Reset password',
            _AuthMode.register => 'Create account',
          },
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        // Email
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: _mode == _AuthMode.forgotPassword
              ? TextInputAction.done
              : TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          onSubmitted: _mode == _AuthMode.forgotPassword
              ? (_) => _submit()
              : null,
        ),
        const SizedBox(height: 12),

        // Password (not shown for forgot password)
        if (_mode != _AuthMode.forgotPassword) ...[
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            textInputAction: _mode == _AuthMode.register
                ? TextInputAction.next
                : TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _mode == _AuthMode.signIn ? (_) => _submit() : null,
          ),
          const SizedBox(height: 12),
        ],

        // Confirm password (register only)
        if (_mode == _AuthMode.register) ...[
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
        ],

        // Error message
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],

        // Submit button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(switch (_mode) {
                    _AuthMode.signIn => 'Sign in',
                    _AuthMode.forgotPassword => 'Send reset email',
                    _AuthMode.register => 'Create account',
                  }),
          ),
        ),
        const SizedBox(height: 12),

        // Mode switcher links
        if (_mode == _AuthMode.signIn) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _mode = _AuthMode.forgotPassword;
                  _errorMessage = null;
                }),
                child: const Text('Forgot password'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _mode = _AuthMode.register;
                  _errorMessage = null;
                }),
                child: const Text('Register'),
              ),
            ],
          ),
        ] else ...[
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _mode = _AuthMode.signIn;
                _errorMessage = null;
              }),
              child: const Text('Back to sign in'),
            ),
          ),
        ],
      ],
    );
  }
}
