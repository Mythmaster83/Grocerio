import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../sync/presentation/providers/sync_di.dart';
import '../../data/auth_service.dart';
import '../../data/device_auth_store.dart';
import '../providers/account_di.dart';

/// Visual phase after Sign in: spinner → check → signed-in body.
enum _SignInPhase { idle, loading, success }

/// Account: optional sign-in for sharing and community prices.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
  bool _linkSent = false;
  bool _showMagicLink = false;
  String? _inlineError;
  _SignInPhase _signInPhase = _SignInPhase.idle;

  @override
  void initState() {
    super.initState();
    _prefillEmail();
  }

  Future<void> _prefillEmail() async {
    final saved = await DeviceAuthStore.signedInEmail();
    if (!mounted || saved == null || saved.isEmpty) return;
    if (_emailController.text.isEmpty) {
      _emailController.text = saved;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _inlineError = null;
      _signInPhase = _SignInPhase.loading;
    });

    final result = await ref.read(authServiceProvider).signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;

    await result.when(
      ok: (_) async {
        _passwordController.clear();
        setState(() => _signInPhase = _SignInPhase.success);
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        ref.invalidate(currentUserProvider);
        ref.invalidate(deviceLoggedInProvider);
        setState(() {
          _busy = false;
          _signInPhase = _SignInPhase.idle;
        });
      },
      err: (failure) async {
        setState(() {
          _busy = false;
          _signInPhase = _SignInPhase.idle;
          _inlineError = failure.message;
        });
      },
    );
  }

  Future<void> _openCreateAccountDialog() async {
    FocusScope.of(context).unfocus();
    var signedInFromDialog = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateAccountDialog(
        initialEmail: _emailController.text.trim(),
        onSignedIn: () {
          signedInFromDialog = true;
          ref.invalidate(currentUserProvider);
          ref.invalidate(deviceLoggedInProvider);
        },
      ),
    );
    if (!mounted || !signedInFromDialog) return;
    // Same loading → check transition as password sign-in.
    setState(() => _signInPhase = _SignInPhase.success);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _signInPhase = _SignInPhase.idle);
  }

  Future<void> _forgotPassword() async {
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    final result = await ref
        .read(authServiceProvider)
        .sendPasswordResetEmail(_emailController.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      ok: (_) => _showInfoDialog(
        title: 'Check your email',
        message:
            'We sent a password reset link to ${_emailController.text.trim()}.',
      ),
      err: (failure) => setState(() => _inlineError = failure.message),
    );
  }

  Future<void> _sendLink() async {
    setState(() {
      _busy = true;
      _inlineError = null;
    });
    final result = await ref
        .read(authServiceProvider)
        .sendSignInLink(_emailController.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      ok: (_) => setState(() => _linkSent = true),
      err: (failure) => setState(() => _inlineError = failure.message),
    );
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    final result = await ref.read(authServiceProvider).signOut();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _linkSent = false;
      _signInPhase = _SignInPhase.idle;
      _inlineError = null;
    });
    result.when(
      ok: (_) {},
      err: (failure) => setState(() => _inlineError = failure.message),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete account?',
      message:
          'Your account, shared lists you own, and the prices you reported are '
          'permanently deleted. Lists stay on this device.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final result = await ref.read(authServiceProvider).deleteAccount();
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      ok: (_) => _showInfoDialog(
        title: 'Account deleted',
        message: 'Your account was removed. Lists on this device are unchanged.',
      ),
      err: (failure) => setState(() => _inlineError = failure.message),
    );
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backendOk = ref.watch(backendAvailableProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final syncState = ref.watch(syncStatusProvider);
    final deviceLoggedIn = ref.watch(deviceLoggedInProvider);

    final showSignedIn = user != null && _signInPhase == _SignInPhase.idle;
    final showTransition = _signInPhase == _SignInPhase.loading ||
        _signInPhase == _SignInPhase.success;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surfaceElevated,
                child: Icon(
                  showSignedIn ? Icons.person : Icons.person_outline,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showSignedIn
                          ? (user.email ?? 'Signed in')
                          : (_signInPhase == _SignInPhase.success
                              ? 'Signed in'
                              : 'Not signed in'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showSignedIn
                          ? 'Signed in on this device'
                          : deviceLoggedIn.valueOrNull == true &&
                                  _signInPhase == _SignInPhase.idle
                              ? 'Restoring session…'
                              : 'Lists are stored on this device',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: !backendOk
                ? KeyedSubtree(
                    key: const ValueKey('no-backend'),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'This build has no backend configured, so accounts, '
                          'sharing and shared prices are unavailable. '
                          'Everything else works normally and stays on this '
                          'device.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  )
                : showTransition
                    ? KeyedSubtree(
                        key: ValueKey(_signInPhase),
                        child: _SignInTransition(phase: _signInPhase),
                      )
                    : showSignedIn
                        ? KeyedSubtree(
                            key: const ValueKey('signed-in'),
                            child: _SignedInBlock(
                              busy: _busy,
                              syncDescription: syncState.description,
                              isSyncing: syncState.isSyncing,
                              inlineError: _inlineError,
                              onSync: () => ref
                                  .read(syncStatusProvider.notifier)
                                  .requestSync(),
                              onSignOut: _signOut,
                              onDeleteAccount: _deleteAccount,
                            ),
                          )
                        : KeyedSubtree(
                            key: const ValueKey('signed-out'),
                            child: _SignInBlock(
                              emailController: _emailController,
                              passwordController: _passwordController,
                              busy: _busy,
                              obscurePassword: _obscurePassword,
                              linkSent: _linkSent,
                              showMagicLink: _showMagicLink,
                              inlineError: _inlineError,
                              onToggleObscure: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              onToggleMagicLink: () => setState(() {
                                _showMagicLink = !_showMagicLink;
                                _linkSent = false;
                                _inlineError = null;
                              }),
                              onSignIn: _signIn,
                              onCreateAccount: _openCreateAccountDialog,
                              onForgotPassword: _forgotPassword,
                              onSendLink: _sendLink,
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _SignInTransition extends StatelessWidget {
  final _SignInPhase phase;

  const _SignInTransition({required this.phase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuccess = phase == _SignInPhase.success;

    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: isSuccess
                  ? Container(
                      key: const ValueKey('check'),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.accentTint,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 40,
                        color: AppColors.accent,
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('spinner'),
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isSuccess ? 'Signed in' : 'Signing in…',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInBlock extends StatelessWidget {
  final bool busy;
  final String syncDescription;
  final bool isSyncing;
  final String? inlineError;
  final VoidCallback onSync;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  const _SignedInBlock({
    required this.busy,
    required this.syncDescription,
    required this.isSyncing,
    required this.inlineError,
    required this.onSync,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inlineError != null) ...[
          Text(
            inlineError!,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Card(
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync now'),
            subtitle: Text(
              syncDescription,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
            trailing: isSyncing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: isSyncing ? null : onSync,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: busy ? null : onSignOut,
          child: const Text('Sign out'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: busy ? null : onDeleteAccount,
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}

class _SignInBlock extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool busy;
  final bool obscurePassword;
  final bool linkSent;
  final bool showMagicLink;
  final String? inlineError;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleMagicLink;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onForgotPassword;
  final VoidCallback onSendLink;

  const _SignInBlock({
    required this.emailController,
    required this.passwordController,
    required this.busy,
    required this.obscurePassword,
    required this.linkSent,
    required this.showMagicLink,
    required this.inlineError,
    required this.onToggleObscure,
    required this.onToggleMagicLink,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onForgotPassword,
    required this.onSendLink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (showMagicLink && linkSent) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Check your email', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'We sent a sign-in link to ${emailController.text.trim()}. '
                'Open it on this phone to finish signing in.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: onSendLink,
                child: const Text('Resend link'),
              ),
              TextButton(
                onPressed: onToggleMagicLink,
                child: const Text('Use password instead'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sign in to share lists', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          showMagicLink
              ? 'We will email a one-time link. Prefer a password? Switch below.'
              : 'Use email and password. Your session stays on this device until '
                  'you sign out.',
          style:
              theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'you@example.com',
          ),
        ),
        if (!showMagicLink) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSignIn(),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'At least 6 characters',
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy ? null : onForgotPassword,
              child: const Text('Forgot password?'),
            ),
          ),
          if (inlineError != null) ...[
            Text(
              inlineError!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          FilledButton(
            onPressed: busy ? null : onSignIn,
            child: const Text('Sign in'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: busy ? null : onCreateAccount,
            child: const Text('Create account'),
          ),
        ] else ...[
          if (inlineError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              inlineError!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: busy ? null : onSendLink,
            child: busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Email me a link'),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: busy ? null : onToggleMagicLink,
          child: Text(
            showMagicLink
                ? 'Use email and password'
                : 'Use email link instead',
          ),
        ),
      ],
    );
  }
}

/// Create-account dialog: credentials → check-email (or closes if signed in).
class _CreateAccountDialog extends ConsumerStatefulWidget {
  final String initialEmail;
  final VoidCallback onSignedIn;

  const _CreateAccountDialog({
    required this.initialEmail,
    required this.onSignedIn,
  });

  @override
  ConsumerState<_CreateAccountDialog> createState() =>
      _CreateAccountDialogState();
}

class _CreateAccountDialogState extends ConsumerState<_CreateAccountDialog> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _confirm;
  bool _obscure = true;
  bool _busy = false;
  bool _checkEmail = false;
  String? _error;
  String _createdEmail = '';

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
    _password = TextEditingController();
    _confirm = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;

    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref.read(authServiceProvider).signUpWithPassword(
          email: email,
          password: password,
        );
    if (!mounted) return;

    result.when(
      ok: (outcome) {
        _password.clear();
        _confirm.clear();
        switch (outcome) {
          case SignUpResult.needsEmailConfirmation:
            setState(() {
              _busy = false;
              _checkEmail = true;
              _createdEmail = email;
            });
          case SignUpResult.signedIn:
            widget.onSignedIn();
            Navigator.of(context).pop();
        }
      },
      err: (failure) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_checkEmail ? 'Check your email' : 'Create account'),
      content: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: _checkEmail
              ? KeyedSubtree(
                  key: const ValueKey('check-email'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 48,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'We sent a confirmation link to $_createdEmail. '
                        'Open it, then return here and sign in.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('form'),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@example.com',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'At least 6 characters',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _confirm,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_busy) _submit();
                          },
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
      actions: _checkEmail
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ]
          : [
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create account'),
              ),
            ],
    );
  }
}
