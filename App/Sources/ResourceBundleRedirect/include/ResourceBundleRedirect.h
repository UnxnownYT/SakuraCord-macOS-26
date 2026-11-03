// Redirects SwiftPM resource bundle lookups from the .app root to
// Contents/Resources. Needed on Swift 6.3, whose generated accessor only
// checks Bundle.main.bundleURL.
void SakuraCordResourceBundleRedirectAnchor(void);
