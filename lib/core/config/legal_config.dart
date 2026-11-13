/// Configuration for the legal surfaces (privacy policy + terms) the app must
/// link to and gate startup behind.
///
/// The hosted page lives in `netlify-privacy/` and is deployed separately, so
/// its URL is supplied at build time via `--dart-define=PRIVACY_POLICY_URL=…`.
/// The default is the placeholder documented in `PRIVACY.md`; ship builds must
/// override it with the real deployed URL.
class LegalConfig {
  LegalConfig._();

  /// Bumped whenever the privacy policy / terms change in a way that requires
  /// users to re-accept. A device that accepted an older version is re-prompted
  /// on next launch (see [ConsentStore]). This mirrors the "Changes" clause of
  /// the policy: continued use after a material change is fresh acceptance.
  static const int privacyPolicyVersion = 1;

  /// Public privacy-policy + terms page. Override at build time:
  /// `--dart-define=PRIVACY_POLICY_URL=https://your-site.netlify.app/`.
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://YOUR_SITE.netlify.app/',
  );
}
