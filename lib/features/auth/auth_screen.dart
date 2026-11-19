import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../providers/auth.dart';
import '../../widgets/common.dart';
import '../../widgets/branding.dart';

/// Client login / sign up with the segmented [Log in | Sign up] control.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.signup = false});
  final bool signup;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late int _tab = widget.signup ? 1 : 0;
  final _loginForm = GlobalKey<FormState>();
  final _signupForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _tab == 0 ? _loginForm : _signupForm;
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final auth = ref.read(authProvider.notifier);
    try {
      if (_tab == 0) {
        await auth.login(_email.text, _password.text);
      } else {
        await auth.register(name: _name.text, email: _email.text, password: _password.text, phone: _phone.text);
      }
      // Router redirect takes over once the auth state changes.
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const Center(child: BuildoraLogo(size: 26)),
            const SizedBox(height: 28),
            PillTabs(tabs: const ['Log in', 'Sign up'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 32),
            Text(_tab == 0 ? 'Good to see you again' : 'Follow your build from anywhere', style: AppText.label),
            const SizedBox(height: 4),
            Text(_tab == 0 ? 'Welcome back' : 'Create your account', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -0.6)),
            const SizedBox(height: 28),
            if (_tab == 0) _loginFields() else _signupFields(),
            const SizedBox(height: 36),
            AppButton(label: _tab == 0 ? 'Login' : 'Create account', loading: _busy, onPressed: _submit),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _tab = _tab == 0 ? 1 : 0),
                child: Text(
                  _tab == 0 ? "New here? Create an account" : 'Already have an account? Log in',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loginFields() => Form(
        key: _loginForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, validator: Validators.email),
            const SizedBox(height: 20),
            AppTextField(label: 'Password', controller: _password, obscure: true, validator: (v) => Validators.required(v, 'Password')),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Forgot password?', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            ),
          ],
        ),
      );

  Widget _signupFields() => Form(
        key: _signupForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(label: 'Full name', controller: _name, keyboardType: TextInputType.name, textCapitalization: TextCapitalization.words, validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your full name' : null),
            const SizedBox(height: 20),
            AppTextField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, validator: Validators.email),
            const SizedBox(height: 20),
            AppTextField(label: 'Phone (optional)', controller: _phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            AppTextField(label: 'Password', controller: _password, obscure: true, validator: Validators.password),
            const SizedBox(height: 20),
            AppTextField(label: 'Confirm password', controller: _confirm, obscure: true, validator: (v) => v != _password.text ? 'Passwords do not match' : null),
          ],
        ),
      );
}
