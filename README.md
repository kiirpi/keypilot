# Choose Keyboard For App

macOS'ta her uygulama için farklı klavye düzeni otomatik seçimi yapan menü bar uygulaması.

## Özellikler

- 🎯 Her uygulama için farklı klavye düzeni ataması
- 🔄 Uygulama geçişlerinde otomatik klavye değişimi
- 💾 Atamalar JSON dosyasında saklanır
- ⌨️ Menü bar'dan kolay yönetim
- 🚀 Açılışta otomatik başlatma desteği

## Derleme

### Sadece binary derle

```bash
./build.sh
```

### .app bundle oluştur (önerilen)

```bash
./build-app.sh
```

Bu komut:
- Swift paketini derler
- `.app` bundle oluşturur
- `Info.plist` ile menü bar uygulaması olarak yapılandırır

## Kullanım

1. Uygulamayı başlat:
   ```bash
   open ChooseKeyboardForApp.app
   ```

2. Menü bar'da klavye ikonunu göreceksiniz

3. Bir uygulamaya geçiş yaptığınızda:
   - Menü bar ikonuna tıklayın
   - "Klavye Ata" menüsünden istediğiniz klavye düzenini seçin
   - Bundan sonra o uygulamaya her geçtiğinizde otomatik olarak seçili klavye aktif olacak

4. Menüden şunları yapabilirsiniz:
   - Mevcut uygulama için klavye ata
   - Atamayı kaldır
   - Tüm atamaları görüntüle
   - Config dosyasını düzenle

## Yapılandırma

Atamalar şu dosyada saklanır:
```
~/Library/Application Support/ChooseKeyboardForApp/config.json
```

Örnek:
```json
{
  "com.apple.Terminal": "com.apple.keylayout.US",
  "com.microsoft.VSCode": "com.apple.keylayout.Turkish",
  "com.apple.Safari": "com.apple.keylayout.US"
}
```

### Klavye düzeni ID'lerini bulma

Mevcut klavye düzenlerinin ID'lerini görmek için:

```bash
# Sistem tercihlerinden Klavye > Input Sources bölümüne bakın
# veya uygulamayı açtığınızda menüden görebilirsiniz
```

## Otomatik Başlatma

### Menü bar'dan (önerilen)

1. Menü bar ikonuna tıklayın
2. **"Açılışta Başlat"** seçeneğini işaretleyin ✓

Bu tek adımda uygulamayı macOS Login Items'a kaydeder. Kaldırmak için aynı menüyü tekrar tıklayın.

### Manuel (Sistem Tercihleri)

1. **Sistem Tercihleri** > **Kullanıcılar ve Gruplar** > **Giriş Öğeleri**
2. `ChooseKeyboardForApp.app` dosyasını sürükleyip bırakın

### launchd ile

```bash
# ~/Library/LaunchAgents/com.kulucka.ChooseKeyboardForApp.plist oluştur
cat > ~/Library/LaunchAgents/com.kulucka.ChooseKeyboardForApp.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.kulucka.ChooseKeyboardForApp</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/ChooseKeyboardForApp.app/Contents/MacOS/ChooseKeyboardForApp</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Yükle
launchctl load ~/Library/LaunchAgents/com.kulucka.ChooseKeyboardForApp.plist
```

## Gereksinimler

- macOS 13.0 veya üzeri
- Swift 5.9+

## Teknik Detaylar

- **NSWorkspace**: Uygulama aktivasyonlarını izler
- **TISInputSource API**: Klavye düzenlerini yönetir (Carbon framework)
- **NSStatusItem**: Menü bar öğesi
- **JSON**: Konfigürasyon saklama

## Uygulama İkonu

### DALL-E / ChatGPT için prompt

```
A macOS application icon for a keyboard layout manager app.
Minimalist flat design, rounded square shape (Apple style).
Center: a clean keyboard key with a small globe symbol on it.
Gradient background: soft blue (#4A90D9) to cyan (#50C9CE).
White foreground elements, subtle drop shadow, no text.
Square 1024x1024, suitable for macOS menu bar app icon.
```

### İkonu kurma

DALL-E'den indirdiğiniz PNG dosyasını şu komutla uygulamaya ekleyin:

```bash
./set-icon.sh ~/Downloads/ikon.png
```

Script otomatik olarak:
- Tüm macOS boyutlarını (16x16 → 1024x1024) oluşturur
- ICNS dosyasına çevirir
- `.app` bundle'a ekler
- Info.plist'i günceller

Sonra:
```bash
killall Finder
open ChooseKeyboardForApp.app
```

## Sorun Giderme

### Klavye değişmiyor

1. Uygulamanın çalıştığından emin olun (menü bar'da ikon var mı?)
2. Klavye düzeninin Sistem Tercihleri'nde eklenmiş olduğundan emin olun
3. Config dosyasını kontrol edin: `~/Library/Application Support/ChooseKeyboardForApp/config.json`

### Menü bar'da görünmüyor

- Uygulama menü bar uygulaması olarak yapılandırılmış, dock'ta görünmez
- Activity Monitor'de çalışıp çalışmadığını kontrol edin

## Lisans

MIT
