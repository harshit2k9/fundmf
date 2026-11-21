/// Values shared across the app. Keep environment-specific settings here so
/// the rest of the code never hard-codes an address or endpoint.
abstract final class AppConstants {
  /// The only account allowed to provision clients and trigger CAMS syncs.
  static const String adminEmail = 'fundmfservices@gmail.com';

  /// Support inbox shown on pending-approval and profile-request screens.
  static const String supportEmail = 'fundmfservices@gmail.com';

  /// Gmail sender that CAMS uses for statement emails (kept in sync with the
  /// backend search query).
  static const String camsSender = 'donotreply@camsonline.com';

  /// Gmail sender that KFintech uses for statement emails.
  static const String kfintechSender = 'distributorcare@kfintech.com';

  /// Public AMFI NAV provider.
  static const String mfApiBaseUrl = 'https://api.mfapi.in/mf';

  /// Base URL of the Fundmf backend (Express on Render).
  ///
  /// Defaults to the deployed Render service. Override for local work, e.g.
  ///   flutter run --dart-define=FUNDMF_API_BASE_URL=http://localhost:8080
  ///
  /// Android emulators reach the host machine on 10.0.2.2 instead of localhost.
  static const String apiBaseUrl = String.fromEnvironment(
    'FUNDMF_API_BASE_URL',
    defaultValue: 'https://fundmf.onrender.com',
  );

  /// Admin-only endpoint that runs the CAMS sync on demand.
  /// Must match `server/src/routes/sync.ts`.
  static const String syncPath = '/api/cams/sync';

  /// How long a live NAV quote is reused before hitting MFAPI again.
  static const Duration navCacheTtl = Duration(minutes: 30);

  /// Page titles used by the shell app bars.
  static const String appName = 'FUNDMF';
  static const String tagline = '— Powered by Compounding —';
}
