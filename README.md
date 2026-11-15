# Kadim Diyar Online

Godot 4.6 ile yapılmış, 2D yukarıdan bakışlı çok oyunculu aksiyon RPG.

**İndir (Windows, Linux):** https://johntitortheprog.itch.io/kadim-diyar-online

## Nasıl oynanır
- **WASD / Ok tuşları**: hareket
- **Fare**: nişan, **Sol tık / Boşluk**: kılıç saldırısı
- **Q**: iksir iç (azami canın %40'ı, 6 sn bekleme), **B**: kamptaki tüccardan iksir al (30 altın, en çok 5)
- **Enter**: sohbet (Esc: iptal), **M**: sesi aç/kapat

Kamptan uzaklaştıkça canavarlar güçlenir: Balçık → Kurt → Ork.
Bir canavar öldüğünde 600 px yakınındaki herkes XP kazanır, yani grup halinde oynamak avantajlıdır.
Her seviyede +20 maks. can ve +4 hasar kazanılır. 5 saniye hasar almazsan canın yavaşça dolar.

- **Altın:** canavarlar XP ile birlikte altın da verir (Balçık 5, Kurt 10, Ork 25); yeni karakter 30 altınla başlar.
- **Kadim Dev (boss):** her 4 dakikada bir haritanın bir köşesinde uyanır ve sohbette duyurulur.
  1200 can, vuruşu çevresindeki herkese işler; yenince yakındaki herkes 400 XP ve ~300 altın alır.
- **Kayıt:** seviye, XP, altın ve iksirler sunucuda saklanır; aynı bilgisayardan aynı sunucuya
  döndüğünde kaldığın yerden devam edersin. Kimlik `user://kimlik.cfg` içindeki rastgele anahtardır
  (isim değiştirmek kaydı etkilemez). Sunucu kaydı `user://kayit.json` dosyasına, oyuncu ayrılınca ve
  20 saniyede bir yazar.
- **Ses:** tüm efektler kodla sentezlenir (`scripts/sfx.gd`).

## Çok oyunculu
- Bir oyuncu **Sunucu Kur (Host)** der, diğerleri onun IP adresini yazıp **Katıl (Join)** der.
- **Resmi sunucu:** `scooter-regs.tun.ply.gg:37826` (menüde hazır yazılı, **Katıl** demek yeter).
  Adres kutusuna `adres:port` yazılabilir; port yazılmazsa yandaki port kutusu kullanılır.
- Sunucunun çalıştığı bilgisayardan oynarken `127.0.0.1` adresine bağlan (tünel üzerinden dolaşma).
- Varsayılan port: **7820 (UDP)**. İnternet üzerinden oynamak için bu portu modemden yönlendirmek
  ya da Tailscale/ZeroTier/Radmin VPN gibi bir sanal LAN kullanmak gerekir.

### Komut satırı
```bash
godot --path . -- --host --name=Ali         # sunucu kur ve oyna
godot --path . -- --join=192.168.1.20       # sunucuya katıl
godot --headless --path . -- --server       # ekransız (dedicated) sunucu
godot --path . -- --join=127.0.0.1 --bot    # kendi kendine savaşan test botu
godot --path . -- --foto                    # görsel kontrol: user://foto_*.png yazar ve kapanır
```
Sunucu için ek bayraklar: `--kayit=user://baska.json` (kayıt dosyası), `--boss-sure=60` (boss aralığı, sn).
İstemci için: `--key=abc12345` (kayıt anahtarını elle ver; diske yazılmaz).

### Betikler
```bash
./oyna.sh            # oyunu aç
./sunucu.sh [port]   # ekransız sunucu (varsayılan 7820/UDP), Ctrl+C ile kapanır
./test.sh            # sunucu + iki bot ile ağ testi (~40 sn)
./deploy/kur.sh      # kalıcı sunucu: systemd kullanıcı servisi "kadim-diyar-sunucu"
```

## Mimari
| Dosya | Görev |
|---|---|
| `scripts/network.gd` (autoload `Network`) | ENet host/join, oyuncu kaydı, kimlik anahtarı, sürüm denetimi (`VERSION`), sohbet |
| `scripts/save.gd` | Sunucu tarafı kalıcı kayıt (JSON) |
| `scripts/sfx.gd` (autoload `SFX`) | Kodla sentezlenen ses efektleri |
| `scripts/world.gd` | Zemin çizimi, seed ile engel üretimi, `MultiplayerSpawner` ile oyuncu/canavar spawn |
| `scripts/player.gd` | Hareket sahipte (`PosSync`), can/XP/seviye sunucuda (`StatsSync`) |
| `scripts/enemy.gd` | Sunucu otoriteli yapay zeka; istemciler sadece interpolasyon yapıp çizer |
| `scripts/fx.gd` (autoload `FX`) | Hasar yazıları ve patlama efektleri |
| `scripts/hud.gd`, `scripts/menu.gd` | Arayüz |

Tüm grafikler `_draw()` ile kodla çizilir, harici asset gerekmez.
