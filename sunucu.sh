#!/bin/sh
# Adanmış (ekransız) sunucuyu başlatır. Kullanım: ./sunucu.sh [port]  (varsayılan 7820/UDP)
D="$(dirname "$(readlink -f "$0")")"
exec flatpak run org.godotengine.Godot --headless --path "$D" -- --server --port="${1:-7820}"
