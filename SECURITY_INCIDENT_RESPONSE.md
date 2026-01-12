# Security Incident Response - Exposed API Keys

## Date: December 28, 2025

## Incident
API keys and sensitive credentials were exposed in the GitHub repository.

## Exposed Credentials

### 1. Android Keystore Passwords (CRITICAL)
- **File**: `android/key.properties`
- **Exposed**: Store password and key password
- **Action Required**: Generate new keystore and update Play Store signing

### 2. Firebase API Keys
- **Files**: `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
- **Action Required**: Restrict API keys in Firebase Console

## Immediate Actions

### Step 1: Restrict Firebase API Keys
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: `rosterup-ce0e1`
3. Navigate to: APIs & Services > Credentials
4. For each API key found:
   - Click on the API key
   - Under "Application restrictions", select appropriate platform (Android/iOS)
   - Under "API restrictions", restrict to only needed APIs
   - Add package name restrictions: `com.addydevs.rosterup.app`
   - Add SHA-1 fingerprints for Android

### Step 2: Generate New Android Signing Key
```bash
keytool -genkey -v -keystore ~/rosterup-new-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias rosterup
```

Then update Play Store with new signing key using Play App Signing.

### Step 3: Remove Secrets from Git History
```bash
# Install BFG Repo-Cleaner or use git filter-repo
brew install bfg

# Clone a fresh copy of the repo
git clone --mirror https://github.com/YOUR_USERNAME/YOUR_REPO.git

# Remove the sensitive files from all history
bfg --delete-files key.properties YOUR_REPO.git
bfg --delete-files google-services.json YOUR_REPO.git
bfg --delete-files GoogleService-Info.plist YOUR_REPO.git

# Clean up and push
cd YOUR_REPO.git
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push --force
```

### Step 4: Update Local Files
1. Keep `key.properties` locally but NEVER commit it
2. Use environment variables or secure secrets management
3. Update `.gitignore` (already done)

## Prevention

### For Team Members
1. Copy `key.properties.template` to `key.properties`
2. Fill in with your local credentials (get from team lead securely)
3. Never commit the actual `key.properties` file

### CI/CD
Store secrets in:
- GitHub Secrets (for GitHub Actions)
- Environment variables in your CI system
- Secret management service (AWS Secrets Manager, etc.)

## Notes

**Firebase API Keys**: While Firebase API keys are meant to be included in client apps, they should still be restricted by:
- Platform (Android/iOS)
- Package name/Bundle ID
- API restrictions

**Keystore Passwords**: These are CRITICAL. If compromised, malicious actors could sign fake versions of your app.

## References
- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Removing Sensitive Data from Git](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
