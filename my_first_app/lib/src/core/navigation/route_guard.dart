// Route guard and session consent manager
// Responsibility: Provide interfaces for guarding routes (e.g., requiring consent for Explore Discussion)
// and a lightweight in-memory consent store for the current app session.

// This file intentionally keeps logic simple and testable. Consent is stored
// in-memory only (no persistence) to respect the requirement that consent is
// session-scoped. When implementing a real app, consider adding an interface
// to abstract storage and to integrate telemetry and audits.

class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  bool _consentGiven = false;

  /// Returns whether the user has provided consent for the current session.
  bool get consentGiven => _consentGiven;

  /// Set the consent flag for the current session.
  void setConsent(bool value) => _consentGiven = value;

  /// Clear consent (useful for testing or session end).
  void clearConsent() => _consentGiven = false;
}

// Route guarding helpers (non-UI):
// - `ConsentService.instance.consentGiven` can be checked by pages or router
//   implementations to determine whether an opt-in flow should be presented.
// - UI code should present a consent dialog before allowing navigation into
//   any `optIn` route (e.g., Explore Discussion). Keep routing and UI separate
//   to allow testable guard logic.