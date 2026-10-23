#!/bin/bash

set -e

APP_NAME="KeyPilot"
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
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>KeyPilot</string>
    <key>CFBundleDisplayName</key>
    <string>KeyPilot</string>
    <key>CFBundleIdentifier</key>
    <string>com.kulucka.KeyPilot</string>
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
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo ""
echo "✅ Uygulama başarıyla oluşturuldu: ${APP_BUNDLE}"
echo ""
echo "Çalıştırmak için:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "Login Items'a eklemek için:"
echo "  1. Sistem Tercihleri > Kullanıcılar ve Gruplar > Giriş Öğeleri"
echo "  2. ${APP_BUNDLE} dosyasını sürükleyip bırakın"
