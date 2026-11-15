#!/bin/sh
# Ağ testi: ekransız sunucu + kendi kendine savaşan iki bot, gerçek ENet üzerinden.
# Ardından BotBir aynı kayıt anahtarıyla yeniden bağlanır; ilerlemenin kayıttan geldiği doğrulanır.
D="$(dirname "$(readlink -f "$0")")"
G="flatpak run org.godotengine.Godot --headless --path $D"
PORT=7826
RUN="t$(date +%s)"   # her çalıştırmada yeni kayıt anahtarları
KAYIT_DOSYA="$HOME/.var/app/org.godotengine.Godot/data/godot/app_userdata/Kadim Diyar Online/test_kayit_$PORT.json"
TMP="$(mktemp -d)"
trap 'pkill -f "^/app/bin/godot-bin.*--port=$PORT"; rm -rf "$TMP"; rm -f "$KAYIT_DOSYA"' EXIT

timeout 100 $G -- --server --port=$PORT --kayit=user://test_kayit_$PORT.json --boss-sure=8 --sure=62 > "$TMP/sunucu.log" 2>&1 &
PS=$!
sleep 3
timeout 50 $G -- --join=127.0.0.1 --port=$PORT --bot --name=BotBir --key=${RUN}bir --sure=30 > "$TMP/bot1.log" 2>&1 &
P1=$!
timeout 50 $G -- --join=127.0.0.1 --port=$PORT --bot --name=BotIki --key=${RUN}iki --sure=30 > "$TMP/bot2.log" 2>&1 &
P2=$!
wait $P1 $P2
sleep 2
timeout 40 $G -- --join=127.0.0.1 --port=$PORT --bot --name=BotBir --key=${RUN}bir --sure=12 > "$TMP/bot1b.log" 2>&1
wait $PS

FAIL=0
kontrol() { # kontrol <açıklama> <desen> <dosya>
	if grep -q "$2" "$3"; then echo "OK    $1"; else echo "HATA  $1"; FAIL=1; fi
}
kontrol "sunucu açıldı"              "Sunucu $PORT portunda" "$TMP/sunucu.log"
kontrol "BotBir sunucuya kaydoldu"   "BotBir oyuna katıldı"  "$TMP/sunucu.log"
kontrol "BotIki sunucuya kaydoldu"   "BotIki oyuna katıldı"  "$TMP/sunucu.log"
kontrol "bot1 bağlandı"              "Sunucuya bağlanıldı"   "$TMP/bot1.log"
kontrol "bot2 bağlandı"              "Sunucuya bağlanıldı"   "$TMP/bot2.log"
kontrol "sohbet istemciye ulaştı"    "BotIki oyuna katıldı"  "$TMP/bot1.log"
kontrol "savaş sunucuda işliyor (seviye/ölüm)" "seviye [0-9]* oldu\|yenik düştü" "$TMP/sunucu.log"
kontrol "tüccardan iksir alındı"     "\[Tüccar\] Bot"        "$TMP/sunucu.log"
kontrol "boss duyurusu istemciye ulaştı" "Kadim Dev .* uyandı" "$TMP/bot1.log"
kontrol "ayrılma sunucuda görüldü"   "oyundan ayrıldı"       "$TMP/sunucu.log"
kontrol "ilerleme kayıttan geri yüklendi" "\[Kayıt\] BotBir yüklendi: seviye" "$TMP/sunucu.log"
grep -h "\[Kayıt\] BotBir yüklendi" "$TMP/sunucu.log" | sed 's/^/      /'
if grep -hE "SCRIPT ERROR|Parse Error|^ERROR" "$TMP"/*.log; then
	echo "HATA  betik hatası var"
	FAIL=1
else
	echo "OK    betik hatası yok"
fi
if [ "$FAIL" -ne 0 ]; then
	echo "SONUÇ: ağ testi başarısız"
	exit 1
fi
echo "SONUÇ: ağ testi geçti"
