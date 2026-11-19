#!/bin/bash
# Tarayıcı sürümü tünelini kullanıcı servisi olarak kurar (ya da günceller) ve başlatır.
# Kaldırmak için: systemctl --user disable --now kadim-diyar-web-tunel
set -euo pipefail
cd "$(dirname "$0")"
SERVIS="kadim-diyar-web-tunel"
if [ ! -x "$HOME/.local/bin/cloudflared" ] || [ ! -s "$HOME/.config/oyun-web-gist-id" ]; then
	echo "UYARI: cloudflared ya da ~/.config/oyun-web-gist-id yok; tarayıcı tüneli kurulmadı."
	exit 0
fi
install -Dm755 web-tunel.sh "$HOME/.local/bin/$SERVIS.sh"
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/$SERVIS.service" <<UNIT
[Unit]
Description=Kadim Diyar tarayici tuneli
After=network-online.target kadim-diyar-sunucu.service

[Service]
ExecStart=%h/.local/bin/$SERVIS.sh
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable "$SERVIS.service"
systemctl --user restart "$SERVIS.service"
echo "== Tünel adresi bekleniyor"
sleep 20
systemctl --user is-active "$SERVIS"
grep -E "adres yayınlandı|UYARI" "$HOME/.local/state/$SERVIS.log" | tail -2
