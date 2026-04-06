# Release Checklist — FitnessAI v1.0

## Pre-Submission

### Code
- [ ] All tests passing (backend + mobile + E2E)
- [ ] No critical/high security vulnerabilities
- [ ] Linters clean on all services
- [ ] Version bumped in pubspec.yaml, package.json, all service configs
- [ ] CHANGELOG.md updated

### App Build
- [ ] Flutter build iOS: `flutter build ipa --release`
- [ ] Flutter build Android: `flutter build appbundle --release`
- [ ] App icon generated (all sizes): 1024x1024 source
- [ ] Splash screen configured
- [ ] ProGuard/R8 rules verified for Android
- [ ] Bitcode enabled for iOS

### Backend
- [ ] Production .env configured on EC2
- [ ] Database migrations applied
- [ ] HTTPS working with valid Let's Encrypt certificate
- [ ] Health checks passing for all services
- [ ] Backup script running (cron.daily)
- [ ] CloudWatch monitoring active

### Store Listings
- [ ] App Store Connect: app record created
- [ ] Google Play Console: app record created
- [ ] Screenshots captured for all required sizes
- [ ] App description (IT + EN) uploaded
- [ ] Privacy policy URL live and accessible
- [ ] Terms of service URL live and accessible
- [ ] Support URL configured
- [ ] App review credentials created (reviewer account)

## Apple App Store

### Submission
1. Upload IPA via Xcode or Transporter
2. Select build in App Store Connect
3. Fill in app information (version, what's new)
4. Add screenshots for all device sizes
5. Submit for review
6. Respond to any reviewer questions within 24h

### Common Rejection Reasons to Avoid
- Login required without guest mode: add "skip login" or demo mode
- Camera usage not explained: NSCameraUsageDescription in Info.plist
- Photo library access: NSPhotoLibraryUsageDescription in Info.plist
- In-app purchase not working: test credits purchase flow
- Incomplete functionality: ensure all screens are functional

## Google Play Store

### Submission
1. Upload AAB via Play Console
2. Create release in Internal Testing track first
3. Promote to Open Testing after validation
4. Fill in store listing (description, screenshots, category)
5. Complete Data Safety section
6. Submit for review

### Data Safety Declaration
- Personal info collected: email, name, age (optional)
- Health and fitness data: workout logs, body measurements
- Photos: accessed but not stored on servers
- Data encrypted in transit: yes (TLS)
- Data encrypted at rest: yes
- Users can request data deletion: yes (in-app)

## Post-Launch
- [ ] Monitor crash reports (Firebase Crashlytics / Sentry)
- [ ] Monitor app reviews and respond
- [ ] Monitor server metrics (CPU, memory, response times)
- [ ] Plan v1.1 based on user feedback
