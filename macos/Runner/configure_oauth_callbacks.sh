#!/bin/sh
set -eu

# GoogleSignIn requires the reversed client ID to be registered as a macOS URL
# scheme. Flutter carries dart-defines as base64 values in DART_DEFINES, so add
# the selected scheme to the built Info.plist before Xcode signs the app.
redirect_uri=""
old_ifs="$IFS"
IFS=','
for encoded in ${DART_DEFINES:-}; do
  decoded="$(printf '%s' "$encoded" | /usr/bin/base64 -D 2>/dev/null || true)"
  case "$decoded" in
    GOOGLE_DRIVE_MACOS_REDIRECT_URI=*)
      redirect_uri="${decoded#*=}"
      ;;
  esac
done
IFS="$old_ifs"

[ -n "$redirect_uri" ] || exit 0
scheme="${redirect_uri%%:*}"
case "$scheme" in
  com.googleusercontent.apps.*) ;;
  *)
    echo "error: GOOGLE_DRIVE_MACOS_REDIRECT_URI must use the reversed Google client ID scheme" >&2
    exit 1
    ;;
esac

plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
plist_buddy=/usr/libexec/PlistBuddy
"$plist_buddy" -c "Add :CFBundleURLTypes:1 dict" "$plist"
"$plist_buddy" -c "Add :CFBundleURLTypes:1:CFBundleTypeRole string Editor" "$plist"
"$plist_buddy" -c "Add :CFBundleURLTypes:1:CFBundleURLName string Google Drive OAuth" "$plist"
"$plist_buddy" -c "Add :CFBundleURLTypes:1:CFBundleURLSchemes array" "$plist"
"$plist_buddy" -c "Add :CFBundleURLTypes:1:CFBundleURLSchemes:0 string $scheme" "$plist"
