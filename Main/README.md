# CS2 Weapon Battle Game

Bu Ruby konsol oyunu, Counter-Strike 2 silahlarının "balanced score" hesaplamasına dayalı bir savaş simülasyonudur.

## 🎮 Oyun Hakkında

Oyuncu, 5 raund boyunca bilgisayara karşı savaşır. Her raundda:

- Belirli bir bütçe ile silah satın alır
- Bilgisayar rastgele bir silah seçer
- Balanced score'lar karşılaştırılır ve yüksek olan kazanır

## 📊 Balanced Score Formülü

```
Balanced Score = ((Damage × Fire Rate) + (Magazine × Range)) / (Falloff + Recoil)
```

Bu formül, silahın etkinliğini değerlendirmek için kullanılır.

## 🚀 Kurulum ve Çalıştırma

### Gereksinimler

- Ruby 3.0 veya üzeri
- Windows için RubyInstaller (önerilen)

### Kurulum

1. Ruby'yi yükleyin: https://rubyinstaller.org/
2. Projeyi indirin
3. Terminal'de proje klasörüne gidin

### Çalıştırma

```bash
ruby ammo.rb
```

## 📁 Dosya Yapısı

- `ammo.rb` - Ana oyun dosyası
- `Cs2.csv` - Silah veritabanı (CSV formatında)
- `test_demo.rb` - Test ve demo scripti
- `README.md` - Bu dosya

## 🎯 Oyun Özellikleri

### Ana Menü

1. **Play** - Oyunu başlat
2. **Options** - Ayarlar (henüz uygulanmadı)
3. **Help** - Yardım (henüz uygulanmadı)
4. **About** - Tüm silahları tablo halinde göster
5. **Exit** - Oyundan çık

### Oyun Akışı

- **Round 1**: $900 bütçe, ilk 10 silah
- **Round 2**: +$1700 bonus, sonraki 7 silah
- **Round 3**: +$2000 bonus, sonraki 6 silah
- **Round 4**: +$2600 bonus, sonraki 7 silah
- **Round 5**: +$3500 bonus, son 4 silah

### Silah Seçimi

- Her raundda belirli bir grup silah sunulur
- Oyuncu bütçesi dahilinde silah seçebilir
- Bilgisayar aynı gruptan rastgele seçim yapar

## 📊 CSV Dosya Formatı

CSV dosyası şu sütunları içermelidir:

```csv
name,price,damage,firerate,magazine,falloff,range,recoil
AK47,2700,36,600.0,30,7,31.5,2.0
```

## 🧪 Test

Demo scriptini çalıştırarak oyunun çalışmasını test edebilirsiniz:

```bash
ruby test_demo.rb
```

## 🎮 Oyun Kuralları

1. Her raundda bütçeniz artar
2. Sadece bütçeniz dahilinde silah satın alabilirsiniz
3. Balanced score yüksek olan silah kazanır
4. 5 raund sonunda toplam skor belirlenir

## 🔧 Teknik Detaylar

- **Dil**: Ruby 3.4+
- **Kütüphaneler**: CSV (standart kütüphane)
- **Platform**: Windows, macOS, Linux
- **Giriş**: Klavye (sayısal seçimler)
- **Çıkış**: Konsol tablosu

## 🐛 Hata Ayıklama

Oyun şu durumları otomatik olarak yönetir:

- Geçersiz kullanıcı girişi
- Yetersiz bütçe
- CSV dosya hataları
- Division by zero (balanced score hesaplamasında)

## 📝 Lisans

Bu proje eğitim amaçlı oluşturulmuştur.

## 🤝 Katkıda Bulunma

1. Projeyi fork edin
2. Feature branch oluşturun
3. Değişikliklerinizi commit edin
4. Pull request gönderin

---

# Normal oyun

ruby ammo.rb

# Türkçe, zor seviye

ruby ammo.rb --lang tr --diff hard

# Simülasyon modu

ruby ammo.rb --sim 100

# Yardım

ruby ammo.rb --help

**İyi oyunlar! 🎮**
