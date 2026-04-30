# TestFlight Setup Guide

## Prerequisites

1. Apple Developer Program membership ($99/year)
2. App created in App Store Connect
3. App-specific password or API key

## Setup

1. **Create App in App Store Connect**
   - Go to https://appstoreconnect.apple.com
   - Create new macOS app with bundle ID `com.danfarr.Clipd`

2. **Install dependencies**
   ```bash
   brew install fastlane
   brew install gifsicle
   ```

3. **Configure fastlane**
   - Copy `.env.default` to `.env`
   - Fill in your Apple ID, Team ID, and ITC Team ID

4. **Upload manually**
   ```bash
   bundle exec fastlane beta
   ```

5. **Upload via CI**
   - Set GitHub secrets: APPLE_ID, TEAM_ID, ITC_TEAM_ID
   - Push a tag: `git tag v1.0.0 && git push origin v1.0.0`
