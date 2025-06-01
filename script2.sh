#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO"' ERR

# Define required env vars
export CERT_PASSWORD="User@54321"
export KEYCHAIN_PASSWORD="buildKey@123"
export KEYCHAIN_NAME="ios-build.keychain-db"
export CERT_CER_PATH="./distribution.cer"
export PRIVATE_KEY_PATH="./private.key"
export CERT_PATH="./certificate.p12"
export PROFILE_PATH="./profile.mobileprovision"
export CM_BUILD_DIR="./build"
export BUNDLE_ID="com.garbcode.garbcodeapp"
export APPLE_TEAM_ID="9H2AD7NQ49"
export XCODE_WORKSPACE="ios/Runner.xcworkspace"
export XCODE_SCHEME="Runner"
export CM_ENV=".env_build"

# Clean up and prepare
mkdir -p "$CM_BUILD_DIR"

# Download files
CERT_CER_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/distribution_pixa.cer"
CERT_KEY_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/privatekey.key"
PROFILE_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/GarbcodeApp_StoreProfile.mobileprovision"

#!/usr/bin/env bash

set -euo pipefail
trap 'echo "❌ Error on line $LINENO"' ERR

# ✅ Required environment variables
REQUIRED_VARS=(CERT_CER_URL CERT_KEY_URL CERT_PASSWORD PROFILE_URL KEYCHAIN_PASSWORD)
echo "🔍 Validating environment variables..."
for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR:-}" ]]; then
    echo "❌ Environment variable '$VAR' is not set!"
    exit 1
  else
    echo "✅ $VAR is set"
  fi
done

# 🔧 Paths
KEYCHAIN_NAME="ios-build.keychain"
BUILD_DIR="$CM_BUILD_DIR"
CERT_CER_PATH="$BUILD_DIR/certificate.cer"
PRIVATE_KEY_PATH="$BUILD_DIR/private.key"
P12_PATH="$BUILD_DIR/generated_certificate.p12"
PROFILE_PATH="$BUILD_DIR/profile.mobileprovision"

mkdir -p "$BUILD_DIR"

echo "📥 Downloading cert, key, and mobileprovision..."
curl -fsSL -o "$CERT_CER_PATH" "$CERT_CER_URL"
curl -fsSL -o "$PRIVATE_KEY_PATH" "$CERT_KEY_URL"
curl -fsSL -o "$PROFILE_PATH" "$PROFILE_URL"

echo "🔐 Generating .p12 from cert + key..."
openssl pkcs12 -export \
  -inkey "$PRIVATE_KEY_PATH" \
  -in "$CERT_CER_PATH" \
  -out "$P12_PATH" \
  -name "Apple Distribution" \
  -certfile "$CERT_CER_PATH" \
  -passout pass:"$CERT_PASSWORD" \
  -legacy

echo "🔐 Setting up keychain..."
security delete-keychain "$KEYCHAIN_NAME" || true
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

echo "🔑 Importing .p12..."
security import "$P12_PATH" -k "$KEYCHAIN_NAME" -P "$CERT_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security list-keychains -s "$KEYCHAIN_NAME"
security default-keychain -s "$KEYCHAIN_NAME"

echo "📲 Installing provisioning profile..."
PROFILE_UUID=$(security cms -D -i "$PROFILE_PATH" | plutil -extract UUID xml1 -o - - | plutil -p - | sed -E 's/.*"([^"]+)".*/\1/')
PROFILE_NAME=$(security cms -D -i "$PROFILE_PATH" | plutil -extract Name xml1 -o - - | plutil -p - | sed -E 's/.*"([^"]+)".*/\1/')
CODE_SIGN_IDENTITY="Apple Distribution"

mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
cp "$PROFILE_PATH" ~/Library/MobileDevice/Provisioning\ Profiles/"$PROFILE_UUID".mobileprovision

echo "✅ PROFILE_UUID=$PROFILE_UUID"
echo "✅ PROFILE_NAME=$PROFILE_NAME"
echo "✅ CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY"

echo "PROFILE_UUID=$PROFILE_UUID" >> "$CM_ENV"
echo "PROFILE_NAME=$PROFILE_NAME" >> "$CM_ENV"
echo "CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY" >> "$CM_ENV"

# ✅ CERTIFICATE MATCH VALIDATION
echo "🔍 Validating that provisioning profile matches signing cert..."

PROFILE_PLIST="$BUILD_DIR/profile.plist"
CERT_DER_PATH="$BUILD_DIR/dev_cert.der"

# Decode .mobileprovision into plist
security cms -D -i "$PROFILE_PATH" > "$PROFILE_PLIST"

# Extract base64 and decode into DER file using awk (safe for multiline)
CERT_BASE64=$(plutil -extract DeveloperCertificates.0 xml1 -o - "$PROFILE_PLIST" \
  | awk '/<data>/,/<\/data>/' \
  | sed -e 's/<[^>]*>//g' -e 's/^[ \t]*//' \
  | tr -d '\n')

if [[ -z "$CERT_BASE64" ]]; then
  echo "❌ Failed to extract base64 certificate data"
  exit 1
fi

echo "$CERT_BASE64" | base64 -d > "$CERT_DER_PATH"

# Validate extracted certificate
if ! openssl x509 -inform der -in "$CERT_DER_PATH" -noout > /dev/null 2>&1; then
  echo "❌ Extracted certificate is invalid or unreadable"
  exit 1
fi

echo "✅ Provisioning profile contains a valid Developer Certificate."

DER_HASH=$(openssl x509 -in "$CERT_DER_PATH" -inform der -noout -sha1 -fingerprint)
CER_HASH=$(openssl x509 -in "$CERT_CER_PATH" -noout -sha1 -fingerprint)

if [[ "$DER_HASH" != "$CER_HASH" ]]; then
  echo "❌ Certificate in profile does NOT match imported .cer"
  echo "DER: $DER_HASH"
  echo "CER: $CER_HASH"
  exit 1
else
  echo "✅ Certificate matches the .cer used to generate the .p12"
fi

cd ios
rm -rf Pods Podfile.lock
pod deintegrate
pod cache clean --all
pod install --repo-update