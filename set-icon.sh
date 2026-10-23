#!/bin/bash
#
# Kullanım:
#   1. ChatGPT / DALL-E ile ikon oluşturun (aşağıdaki prompt'u kullanın)
#   2. İndirdiğiniz PNG dosyasını bu scripte argüman olarak verin:
#      ./set-icon.sh ikon.png
#

set -e

if [ -z "$1" ]; then
    echo "Kullanım: $0 <ikon.png>"
    echo ""
    echo "DALL-E Prompt:"
    echo "  A macOS application icon for a keyboard layout manager app."
    echo "  Minimalist flat design, rounded square shape (Apple style)."
    echo "  Center: a clean keyboard key with a small globe symbol."
    echo "  Gradient background: soft blue (#4A90D9) to cyan (#50C9CE)."
    echo "  White foreground elements, subtle drop shadow, no text."
    echo "  Square 1024x1024, suitable for macOS menu bar app icon."
    exit 1
fi

INPUT_PNG="$1"
APP_NAME="KeyPilot"
APP_BUNDLE="${APP_NAME}.app"
ICONSET_DIR="${APP_BUNDLE}/Contents/Resources/AppIcon.iconset"
ICNS_FILE="${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

if [ ! -f "$INPUT_PNG" ]; then
    echo "❌ Dosya bulunamadı: $INPUT_PNG"
    exit 1
fi

if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ Önce .app bundle oluşturun: ./build-app.sh"
    exit 1
fi

echo "İkon hazırlanıyor: $INPUT_PNG"

# .iconset klasörü oluştur
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# macOS için gerekli tüm boyutlar
# iconutil her boyut için @1x ve @2x ister
sizes=(
    "16x16"
    "32x32"
    "64x64"
    "128x128"
    "256x256"
    "512x512"
    "1024x1024"
)

for size in "${sizes[@]}"; do
    IFS='x' read -r w h <<< "$size"

    # @1x
    out_name="icon_${w}x${h}.png"
    sips -z "$h" "$w" "$INPUT_PNG" --out "${ICONSET_DIR}/${out_name}" > /dev/null 2>&1

    # @2x (2 katı)
    w2=$((w * 2))
    h2=$((h * 2))
    if [ "$w2" -le 1024 ] && [ "$h2" -le 1024 ]; then
        out_name2="icon_${w}x${h}@2x.png"
        sips -z "$h2" "$w2" "$INPUT_PNG" --out "${ICONSET_DIR}/${out_name2}" > /dev/null 2>&1
    fi
done

echo "ICNS oluşturuluyor..."
iconutil --convert icns "$ICONSET_DIR" --output "$ICNS_FILE"

# .iconset klasörünü temizle (artık gerek yok)
rm -rf "$ICONSET_DIR"

# Info.plist'e ikon referansı ekle
PLIST="${APP_BUNDLE}/Contents/Info.plist"
if ! grep -q "CFBundleIconFile" "$PLIST" 2>/dev/null; then
    # </dict> etiketinden önce ekle
    sed -i '' 's|</dict>|    <key>CFBundleIconFile</key>\n    <string>AppIcon</string>\n</dict>|' "$PLIST"
fi

# Finder'a ikonu yenilemesini söyle
touch "$APP_BUNDLE"

echo ""
echo "✅ İkon başarıyla ayarlandı!"
echo ""
echo "Etkili olması için Finder'ı yeniden başlatın:"
echo "  killall Finder"
echo ""
echo "veya uygulamayı kapatıp tekrar açın:"
echo "  pkill -f $APP_NAME; open $APP_BUNDLE"
