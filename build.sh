#!/bin/bash

set -e

echo "Derleniyor..."
swift build -c release

echo ""
echo "Uygulama başarıyla derlendi!"
echo ""
echo "Çalıştırmak için:"
echo "  .build/release/ChooseKeyboardForApp"
echo ""
echo "Veya .app bundle oluşturmak için:"
echo "  ./build-app.sh"
