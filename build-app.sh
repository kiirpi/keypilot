#!/bin/bash

set -e

APP_NAME="KeyPilot"
BUNDLE_ID="com.kulucka.keypilot"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

echo "Derleniyor..."
swift build -c release

echo ""
echo ".app bundle oluşturuluyor..."

# Bundle dizinini oluştur
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Binary'yi kopyala
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Info.plist oluştur
# Not: macOS 26 (Tahoe) menü bar hatası nedeniyle bundle ID'nin
# daha önce kullanılmamış (temiz) bir ID olması önemli. Control Center
# eski bundle ID'leri "gizli" olarak önbelleğe alıp ikonu ekran dışına atabiliyor.
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>KeyPilot</string>
    <key>CFBundleDisplayName</key>
    <string>KeyPilot</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>KeyPilot</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# PkgInfo (bazı macOS servisleri tarafından beklenir)
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Bundle ID ile ad-hoc imzala (menü bar kaydı için gerekli)
echo "İmzalanıyor..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "✅ Uygulama başarıyla oluşturuldu: ${APP_BUNDLE}"
echo ""
echo "Çalıştırmak için:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "Login Items'a eklemek için:"
echo "  1. Sistem Tercihleri > Kullanıcılar ve Gruplar > Giriş Öğeleri"
echo "  2. ${APP_BUNDLE} dosyasını sürükleyip bırakın"
