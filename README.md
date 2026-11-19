# Kadim Diyar Online

Godot 4.6 ile yapılmış, 2D yukarıdan bakışlı çok oyunculu aksiyon RPG.

- **İndir (Windows, Linux):** https://johntitortheprog.itch.io/kadim-diyar-online
- **Tarayıcıda oyna:** https://johntitortheprog.itch.io/kadim-diyar-online-web

## Nasıl oynanır
- **WASD / Ok tuşları** ya da **sağ fare tuşu basılı**: hareket (sağ tıkla imlece doğru yürünür)
- **Fare**: nişan, **Sol tık / Boşluk**: kılıç saldırısı
- **E / Shift / R**: yetenekler (Kasırga, Atılma, Şifa)
- **Q**: iksir iç (azami canın %40'ı, 6 sn bekleme), **B**: kamptaki tüccardan iksir al (30 altın, en çok 5)
- **I**: çanta, **F**: Kâhin'den görev al / teslim et, **N**: dünya haritası
- **Enter**: sohbet (Esc: iptal), **M**: sesi aç/kapat

Kamptan uzaklaştıkça canavarlar güçlenir: Balçık → Kurt → Ork.
Bir canavar öldüğünde 600 px yakınındaki herkes XP ve altın kazanır, yani grup halinde oynamak avantajlıdır.
Her seviyede +20 maks. can ve +4 hasar kazanılır. 5 saniye hasar almazsan canın yavaşça dolar.

- **Bölgeler:** Kadim Çayır'daki yol uçlarında portallar var: doğuda **Unutulmuş Mezarlık** (Sv 5+: zombi,
  iskelet okçu, hayalet), kuzeyde **Ebedi Buzul** (Sv 9+: kar kurdu, yeti, buz golemi), güneyde **Kızıl Volkan**
  (Sv 13+: lav balçığı, ateş iblisi, lav gölleri can yakar, boss **Ejderha** ateş püskürür), batıdaki iskeleden
  **Engin Okyanus** (Sv 7+: suda tekneyle gidilir, beş ada; dev yengeç, korsan, açık denizde boss **Kraken**).
  Bölgede oyuncu yoksa canavarlar kaldırılır; bölge boss'ları oyuncu varken 3 dakikada bir uyanır.
- **Harita:** sağ üstte bulunduğun bölgenin mini haritası (engeller, portallar, canavarlar, oyuncular),
  **N** ile tüm bölgeleri gösteren dünya haritası.
- **Market (B):** tüccar iksirin yanında seviyene göre silah ve zırh satar; vitrin 10 dakikada bir yenilenir.
- **Karakter:** menüde ten, saç stili, saç rengi ve kıyafet seçilir; önizleme canlı güncellenir.
  Kuşanılan zırh ve kılıç karakterin üzerinde görünür (nadirliğe göre renk ve parıltı).
- **Ekipman:** canavarlar kılıç ve zırh düşürür (Sıradan / Nadir / Efsanevi). Kılıç hasarı, zırh azami canı
  artırır. Çanta 12 eşya alır; dolarken düşen eşya kendiliğinden satılır. Eşyalar kamptaki tüccara satılır.
- **Görevler:** kampın batısındaki Kâhin seviyene göre görev verir ("6 Kurt avla", "Kadim Dev'i yen" gibi).
  Bitince altın, XP ve bir eşya ödülü.
- **Yetenekler:** Kasırga (Sv 3, çevredeki her canavara vurur), Atılma (Sv 5, kısa süre hasar almaz),
  Şifa (Sv 8, yakındaki herkesi iyileştirir).
- **Altın:** canavarlar altın verir (Balçık 5, Kurt 10, Ork 25); yeni karakter 30 altınla başlar.
- **Kadim Dev (boss):** her 4 dakikada bir haritanın bir köşesinde uyanır ve sohbette duyurulur.
  1200 can, vuruşu çevresindeki herkese işler; yenince yakındaki herkes 400 XP, ~300 altın ve kesin bir
  Nadir/Efsanevi eşya alır.
- **Kayıt:** seviye, XP, altın, iksir, çanta, kuşanılan eşyalar ve görev sunucuda saklanır; aynı bilgisayardan
  (ya da aynı tarayıcıdan) aynı sunucuya döndüğünde kaldığın yerden devam edersin. Kimlik `user://kimlik.cfg`
  içindeki rastgele anahtardır (isim değiştirmek kaydı etkilemez). Sunucu kaydı `user://kayit.json`
  dosyasına, oyuncu ayrılınca ve 20 saniyede bir yazar.
- **Ses:** tüm efektler kodla sentezlenir (`scripts/sfx.gd`).
- **Tuşlar** hem fiziksel konumla hem harfle tanımlıdır (farklı klavye düzenlerinde ve tuş kodunu gizleyen
  tarayıcılarda da çalışsın diye). Tarayıcıda oyuna her tıklamada klavye odağı oyun alanına alınır.

## Çok oyunculu
- Bir oyuncu **Sunucu Kur (Host)** der, diğerleri onun IP adresini yazıp **Katıl (Join)** der.
- **Resmi sunucu:** `scooter-regs.tun.ply.gg:37826` (menüde hazır yazılı, **Katıl** demek yeter).
  Adres kutusuna `adres:port` yazılabilir; port yazılmazsa yandaki port kutusu kullanılır.
- Sunucunun çalıştığı bilgisayardan oynarken `127.0.0.1` adresine bağlan (tünel üzerinden dolaşma).
- Portlar: **7820/UDP** (ENet, masaüstü) ve **7821/TCP** (WebSocket, tarayıcı). İnternet üzerinden oynamak için
  bu portları modemden yönlendirmek ya da Tailscale/ZeroTier/Radmin VPN gibi bir sanal LAN kullanmak gerekir.
- **Tarayıcı sürümü:** tarayıcılar UDP kullanamadığı için sunucu aynı oyunu WebSocket'ten de açar
  (`scripts/dual_peer.gd`). Resmi sunucuda bu port bir Cloudflare tüneliyle `wss://` adresine açılır; adres her
  yeniden başlatmada değiştiğinden bir gist dosyasına yazılır ve tarayıcı sürümü ("Otomatik") oradan okur
  (`scripts/web_address.gd`). Adres kutusuna `ws://` ya da `wss://` adresi yazılırsa doğrudan ona bağlanılır.

### Komut satırı
```bash
godot --path . -- --host --name=Ali              # sunucu kur ve oyna
godot --path . -- --join=192.168.1.20            # sunucuya katıl
godot --path . -- --join=ws://127.0.0.1:7821     # WebSocket ile katıl (tarayıcının yolu)
godot --headless --path . -- --server            # ekransız (dedicated) sunucu
godot --path . -- --join=127.0.0.1 --bot         # kendi kendine oynayan test botu
godot --path . -- --foto                         # görsel kontrol: user://foto_*.png yazar ve kapanır
```
Sunucu için ek bayraklar: `--kayit=user://baska.json` (kayıt dosyası), `--boss-sure=60` (boss aralığı, sn),
`--bolge-boss-sure=60` (Ejderha/Kraken aralığı, sn),
`--test-modu` (ganimet şansı 6 kat, görevler 2 canavarlık). İstemci için: `--key=abc12345` (kayıt anahtarını
elle ver; diske yazılmaz).

### Betikler
```bash
./oyna.sh                 # oyunu aç
./sunucu.sh [port]        # ekransız sunucu (varsayılan 7820/UDP + 7821/TCP), Ctrl+C ile kapanır
./test.sh                 # sunucu + iki ENet botu + bir WebSocket botu ile ağ testi (~80 sn)
./deploy/kur.sh           # kalıcı sunucu: systemd kullanıcı servisi "kadim-diyar-sunucu" + tarayıcı tüneli
./tools/fragman.sh        # fragman: oyun içinden 30 fps kayıt + kodla üretilen müzik → build/fragman/*.mp4
```

## Mimari
| Dosya | Görev |
|---|---|
| `scripts/network.gd` (autoload `Network`) | ENet + WebSocket host/join, oyuncu kaydı, kimlik ve görünüm, sürüm denetimi (`VERSION`), sohbet |
| `scripts/dual_peer.gd` | Sunucuda ENet ve WebSocket eşlerini tek `MultiplayerPeer` olarak birleştirir |
| `scripts/web_address.gd` | Tarayıcı sürümü için güncel wss adresini gist'ten okur |
| `scripts/save.gd` | Sunucu tarafı kalıcı kayıt (JSON) |
| `scripts/world.gd` | Zemin çizimi, seed ile engel üretimi, `MultiplayerSpawner` ile oyuncu/canavar spawn, kayıt yükleme |
| `scripts/player.gd` | Hareket sahipte (`PosSync`); can/XP/altın/ekipman/görev sunucuda (`StatsSync`); yetenekler ve istekler |
| `scripts/look.gd` | Karakter görünümü tabloları ve çizimi (oyun ve menü önizlemesi aynı kodu kullanır) |
| `scripts/items.gd`, `scripts/quests.gd` | Eşya üretimi, değerleri ve görev tabloları |
| `scripts/zones.gd`, `scripts/zone_ground.gd`, `scripts/portal.gd`, `scripts/lava_pool.gd` | Bölgeler, adalar, zemin çizimi, portallar, lav gölleri |
| `scripts/minimap.gd`, `scripts/market_ui.gd`, `scripts/projectile.gd` | Mini harita / dünya haritası, market penceresi, mermi görüntüsü |
| `scripts/enemy.gd` | Sunucu otoriteli yapay zeka; istemciler sadece interpolasyon yapıp çizer |
| `scripts/hud.gd`, `scripts/inventory_ui.gd`, `scripts/skillbar.gd` | Oyun içi arayüz, çanta, yetenek çubuğu |
| `scripts/menu.gd`, `scripts/character_creator.gd` | Ana menü ve karakter oluşturma |
| `scripts/fx.gd` (autoload `FX`), `scripts/sfx.gd` (autoload `SFX`) | Görsel efektler ve sentezlenen sesler |

Tüm grafikler `_draw()` ile kodla çizilir, harici asset gerekmez.
