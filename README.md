# FireSync

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/Ruby-3.0+-red.svg)](https://www.ruby-lang.org/)
[![C](https://img.shields.io/badge/C-Standard-blue.svg)](<https://en.wikipedia.org/wiki/C_(programming_language)>)

Bu proje, Counter-Strike 2 silahlarının "balanced score" hesaplamasına dayalı bir savaş simülasyonudur. Hem Ruby hem de C programlama dillerinde geliştirilmiştir.

## 🎮 Proje Hakkında

Bu oyun, CS2 silahlarının etkinliğini değerlendirmek için özel bir formül kullanır. Oyuncu 5 raund boyunca bilgisayara karşı savaşır ve her raundda belirli bir bütçe ile silah satın alır.

### 📊 Balanced Score Formülü

```
Balanced Score = ((Damage × Fire Rate) + (Magazine × Range)) / (Falloff + Recoil)
```

## 📁 Proje Yapısı

```
FireSync/
├── Main/                    # Ana Ruby versiyonu
│   ├── ammo.rb             # Ana oyun dosyası
│   ├── config.yml          # Oyun konfigürasyonu
│   ├── Cs2.csv             # Silah veritabanı
│   ├── profile.json        # Oyuncu profili
│   ├── lang/               # Dil dosyaları
│   │   ├── en.yml          # İngilizce
│   │   └── tr.yml          # Türkçe
│   └── README.md           # Detaylı dokümantasyon
├── OldVersion/             # Eski C versiyonu
│   ├── ammo.c              # C kaynak kodu
│   ├── ammo.exe            # Derlenmiş C programı
│   └── case.txt            # Test dosyası
├── LICENSE                 # MIT Lisansı
└── README.md               # Bu dosya
```

## 🚀 Kurulum ve Çalıştırma

### Ruby Versiyonu (Önerilen)

#### Gereksinimler

- Ruby 3.0 veya üzeri
- Windows için RubyInstaller (önerilen)

#### Kurulum

1. Ruby'yi yükleyin: https://rubyinstaller.org/
2. Projeyi indirin
3. Terminal'de `Main` klasörüne gidin

#### Çalıştırma

```bash
# Normal oyun
ruby ammo.rb

# Türkçe, zor seviye
ruby ammo.rb --lang tr --diff hard

# Simülasyon modu (100 oyun)
ruby ammo.rb --sim 100

# Yardım
ruby ammo.rb --help
```

### C Versiyonu (Eski)

#### Gereksinimler

- GCC veya başka bir C derleyicisi

#### Derleme

```bash
cd OldVersion/OldVersion
gcc -o ammo ammo.c
```

#### Çalıştırma

```bash
./ammo
```

## 🎯 Oyun Özellikleri

### Ana Menü

1. **Play** - Oyunu başlat
2. **Options** - Ayarlar
3. **Help** - Yardım
4. **About** - Tüm silahları tablo halinde göster
5. **Exit** - Oyundan çık

### Oyun Akışı

- **Round 1**: $900 bütçe, ilk 10 silah
- **Round 2**: +$1700 bonus, sonraki 7 silah
- **Round 3**: +$2000 bonus, sonraki 6 silah
- **Round 4**: +$2600 bonus, sonraki 7 silah
- **Round 5**: +$3500 bonus, son 4 silah

### Gelişmiş Özellikler (Ruby Versiyonu)

- **Çoklu Dil Desteği**: İngilizce ve Türkçe
- **Zorluk Seviyeleri**: Kolay, Normal, Zor
- **Oyuncu Profili**: İstatistikler ve başarılar
- **Perk Sistemi**: Özel yetenekler
- **Ekipman Sistemi**: Silah eklentileri
- **Olay Sistemi**: Hava durumu ve özel durumlar
- **Simülasyon Modu**: Otomatik oyun testi

## 📊 CSV Dosya Formatı

Silah veritabanı şu sütunları içermelidir:

```csv
name,price,damage,firerate,magazine,falloff,range,recoil
AK47,2700,36,600.0,30,7,31.5,2.0
```

## 🔧 Teknik Detaylar

### Ruby Versiyonu

- **Dil**: Ruby 3.4+
- **Kütüphaneler**: CSV, JSON, YAML, OptionParser, SecureRandom
- **Platform**: Windows, macOS, Linux
- **Özellikler**: ANSI renk kodları, çoklu dil desteği, konfigürasyon sistemi

### C Versiyonu

- **Dil**: C (ANSI)
- **Platform**: Windows (derlenmiş .exe)
- **Özellikler**: Basit konsol arayüzü

## 🧪 Test

### Ruby Versiyonu

```bash
# Demo scriptini çalıştır
ruby test_demo.rb

# Simülasyon modu ile test
ruby ammo.rb --sim 50
```

### C Versiyonu

```bash
# Test dosyası ile çalıştır
./ammo < case.txt
```

## 🐛 Hata Ayıklama

Oyun şu durumları otomatik olarak yönetir:

- Geçersiz kullanıcı girişi
- Yetersiz bütçe
- CSV dosya hataları
- Division by zero (balanced score hesaplamasında)
- Profil dosyası hataları

## 📝 Lisans

Bu proje [MIT Lisansı](LICENSE) altında lisanslanmıştır.

## 🤝 Katkıda Bulunma

1. Projeyi fork edin
2. Feature branch oluşturun (`git checkout -b feature/AmazingFeature`)
3. Değişikliklerinizi commit edin (`git commit -m 'Add some AmazingFeature'`)
4. Branch'inizi push edin (`git push origin feature/AmazingFeature`)
5. Pull request gönderin

## 📞 İletişim

Proje ile ilgili sorularınız için issue açabilirsiniz.

## 🙏 Teşekkürler

- Counter-Strike 2 oyunu ve silah verileri için Valve Corporation'a
- Ruby topluluğuna
- C programlama dili geliştiricilerine

---

**İyi oyunlar! 🎮**
