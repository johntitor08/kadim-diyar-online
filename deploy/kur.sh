#!/bin/bash
# Kadim Diyar Online sunucusunu bu bilgisayara systemd kullanıcı servisi olarak kurar ya da günceller.
# Kullanım: ./deploy/kur.sh [port]   (varsayılan 7820/UDP)
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-7820}"
HEDEF="$HOME/.local/share/kadim-diyar-sunucu"
SERVIS="kadim-diyar-sunucu"

echo "== Linux sürümü derleniyor"
mkdir -p "$D/build/linux"
LOG="$(mktemp)"
if ! flatpak run org.godotengine.Godot --headless --path "$D" --export-release "Linux" "$D/build/linux/KadimDiyar.x86_64" > "$LOG" 2>&1; then
	echo "HATA: derleme başarısız. Çıktı:"
	cat "$LOG"
	rm -f "$LOG"
	exit 1
fi
rm -f "$LOG"

if systemctl --user is-active --quiet "$SERVIS"; then
	echo "== Çalışan servis durduruluyor (bağlı oyuncular düşer)"
	systemctl --user stop "$SERVIS"
fi

# Elle ya da sunucu.sh ile açılmış kopya portu tutuyorsa servis başlayamaz.
if pkill -f "^/app/bin/godot-bin.*--server --port=$PORT\$"; then
	echo "== Elle açılmış sunucu kapatıldı"
	sleep 2
fi

mkdir -p "$HEDEF" "$HOME/.config/systemd/user"
cp "$D/build/linux/KadimDiyar.x86_64" "$HEDEF/"
cat > "$HOME/.config/systemd/user/$SERVIS.service" <<UNIT
[Unit]
Description=Kadim Diyar Online oyun sunucusu
After=network-online.target

[Service]
WorkingDirectory=%h/.local/share/kadim-diyar-sunucu
ExecStart=/usr/bin/stdbuf -oL -eL %h/.local/share/kadim-diyar-sunucu/KadimDiyar.x86_64 --headless -- --server --port=$PORT
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now "$SERVIS"
sleep 3
systemctl --user --no-pager status "$SERVIS" | head -5
ss -ulnp | grep ":$PORT " || echo "UYARI: $PORT/UDP dinlenmiyor, logu kontrol et: journalctl --user -u $SERVIS"
echo "== Bitti. Log: journalctl --user -u $SERVIS -f"
