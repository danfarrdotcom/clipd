# Sparkle Auto-Updater Setup

## Generate Keys

```bash
generate_appcast --generate-keypair
```

## Configure

1. Add `SUPublicEDKey` to Info.plist
2. Host `appcast.xml` on a public URL
3. Set `SUFeedURL` in Info.plist to point to your appcast
