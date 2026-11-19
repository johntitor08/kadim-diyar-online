#!/bin/sh
# Ağ testi: ekransız sunucu (test modu) + kendi kendine savaşan iki ENet botu ve bir WebSocket botu.
# Botlar görev alır, ganimet toplar, eşya kuşanır, yetenek kullanır. Ardından BotBir aynı kayıt
# anahtarıyla yeniden bağlanır; ilerlemenin ve çantanın kayıttan geldiği doğrulanır.
D="$(dirname "$(readlink -f "$0")")"
G="flatpak run org.godotengine.Godot --headless --path $D"
PORT=7826
WS_PORT=$((PORT + 1))
RUN="t$(date +%s)"   # her çalıştırmada yeni kayıt anahtarları
KAYIT_DOSYA="$HOME/.var/app/org.godotengine.Godot/data/godot/app_userdata/Kadim Diyar Online/test_kayit_$PORT.json"
TMP="$(mktemp -d)"
trap 'pkill -f "^/app/bin/godot-bin.*--port=$PORT"; pkill -f "^/app/bin/godot-bin.*127.0.0.1:$WS_PORT"; rm -rf "$TMP"; rm -f "$KAYIT_DOSYA"' EXIT

timeout 110 $G -- --server --port=$PORT --kayit=user://test_kayit_$PORT.json --test-modu --boss-sure=8 --sure=72 > "$TMP/sunucu.log" 2>&1 &
PS=$!
sleep 3
timeout 55 $G -- --join=127.0.0.1 --port=$PORT --bot --name=BotBir --key=${RUN}bir --sure=38 > "$TMP/bot1.log" 2>&1 &
P1=$!
timeout 55 $G -- --join=127.0.0.1 --port=$PORT --bot --name=BotIki --key=${RUN}iki --sure=38 > "$TMP/bot2.log" 2>&1 &
P2=$!
timeout 55 $G -- --join=ws://127.0.0.1:$WS_PORT --bot --name=BotWeb --key=${RUN}web --sure=38 > "$TMP/bot3.log" 2>&1 &
P3=$!
wait $P1 $P2 $P3
sleep 2
timeout 40 $G -- --join=127.0.0.1 --port=$PORT --bot --name=BotBir --key=${RUN}bir --sure=12 > "$TMP/bot1b.log" 2>&1
wait $PS

FAIL=0
kontrol() { # kontrol <açıklama> <desen> <dosya>
	if grep -q "$2" "$3"; then echo "OK    $1"; else echo "HATA  $1"; FAIL=1; fi
}
kontrol "sunucu açıldı (UDP)"          "Sunucu $PORT portunda" "$TMP/sunucu.log"
kontrol "sunucu açıldı (WebSocket)"    "WebSocket $WS_PORT portunda" "$TMP/sunucu.log"
kontrol "BotBir sunucuya kaydoldu"     "BotBir oyuna katıldı"  "$TMP/sunucu.log"
kontrol "BotIki sunucuya kaydoldu"     "BotIki oyuna katıldı"  "$TMP/sunucu.log"
kontrol "BotWeb WebSocket ile kaydoldu" "BotWeb kaydoldu (tarayıcı)" "$TMP/sunucu.log"
kontrol "bot1 bağlandı"                "Sunucuya bağlanıldı"   "$TMP/bot1.log"
kontrol "WebSocket botu bağlandı"      "Sunucuya bağlanıldı"   "$TMP/bot3.log"
kontrol "başka oyuncunun mesajı istemciye ulaştı" "BotIki \(oyuna katıldı\|seviye\)\|BotWeb \(oyuna katıldı\|seviye\)" "$TMP/bot1.log"
kontrol "başka oyuncunun mesajı WebSocket istemcisine ulaştı" "BotBir \(oyuna katıldı\|seviye\)\|BotIki \(oyuna katıldı\|seviye\)" "$TMP/bot3.log"
kontrol "savaş sunucuda işliyor (seviye/ölüm)" "seviye [0-9]* oldu\|yenik düştü" "$TMP/sunucu.log"
kontrol "tüccardan iksir alındı"       "\[Tüccar\] Bot.* iksir aldı" "$TMP/sunucu.log"
kontrol "görev alındı"                 "\[Görev\] Bot.* aldı"  "$TMP/sunucu.log"
kontrol "görev tamamlandı"             "\[Görev\] Bot.* tamamladı" "$TMP/sunucu.log"
kontrol "ganimet düştü"                "\[Ganimet\] Bot"       "$TMP/sunucu.log"
kontrol "eşya kuşanıldı"               "\[Kuşan\] Bot"         "$TMP/sunucu.log"
kontrol "yetenek kullanıldı (Kasırga)" "\[Yetenek\] Bot.*Kasırga" "$TMP/sunucu.log"
kontrol "boss duyurusu istemciye ulaştı" "Kadim Dev .* uyandı" "$TMP/bot1.log"
kontrol "ayrılma sunucuda görüldü"     "oyundan ayrıldı"       "$TMP/sunucu.log"
kontrol "ilerleme ve çanta kayıttan geri yüklendi" "\[Kayıt\] BotBir yüklendi: seviye .* eşya" "$TMP/sunucu.log"
grep -h "\[Kayıt\] BotBir yüklendi" "$TMP/sunucu.log" | sed 's/^/      /'
grep -hc "\[Ganimet\]" "$TMP/sunucu.log" | sed 's/^/      ganimet sayısı: /'
grep -h "\[Yetenek\]" "$TMP/sunucu.log" | sed 's/^\[Yetenek\] [^:]*: //' | sort | uniq -c | sed 's/^/      yetenek /'
if grep -hE "SCRIPT ERROR|Parse Error|^ERROR" "$TMP"/*.log; then
	echo "HATA  betik hatası var"
	FAIL=1
else
	echo "OK    betik hatası yok"
fi
if [ "$FAIL" -ne 0 ]; then
	cp "$TMP"/*.log "$D/build/" 2>/dev/null
	echo "SONUÇ: ağ testi başarısız (loglar build/ içine kopyalandı)"
	exit 1
fi
echo "SONUÇ: ağ testi geçti"
