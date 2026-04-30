# App Store Connect API Key

## Create Key

1. Go to https://appstoreconnect.apple.com/access/integrations/api
2. Create new key with "App Manager" role
3. Download the `.p8` file

## Base64 encode

```bash
base64 -i YourKey.p8 | tr -d '\n'
```

## Set as GitHub Secret

```bash
gh secret set APP_STORE_CONNECT_API_KEY_KEY --body "$(base64 -i YourKey.p8 | tr -d '\n')"
```
