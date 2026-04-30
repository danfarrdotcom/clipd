# Notarization Guide

## Create DMG

```bash
hdiutil create -volname "Clipd" -srcfolder "build/Release/Clipd.app" -ov -format UDZO build/Clipd.dmg
```

## Submit for Notarization

```bash
xcrun notarytool submit build/Clipd.dmg \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "YOUR_TEAM_ID" \
  --wait
```

## Staple Ticket

```bash
xcrun stapler staple build/Clipd.dmg
```
