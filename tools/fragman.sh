#!/bin/bash
# Fragmanı kaydeder: oyun --fragman kipinde Godot'nun film kaydıyla (sabit 30 fps, 1920x1080) çalışır,
# ardından üretilen müzik oyun sesleriyle karıştırılıp MP4'e (H.264 + AAC) dönüştürülür.
# Çıktı: build/fragman/kadim-diyar-fragman.mp4
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$D/build/fragman"
mkdir -p "$OUT"
rm -f "$OUT/ham.avi" "$OUT/ham.wav"
echo "== Oyun içi kayıt (birkaç dakika sürebilir)"
flatpak run org.godotengine.Godot --path "$D" --write-movie "$OUT/ham.avi" --fixed-fps 30 --resolution 1920x1080 -- --fragman \
	> "$OUT/kayit.log" 2>&1 || true
grep -E "SCRIPT ERROR|Parse Error" "$OUT/kayit.log" && { echo "HATA: kayıtta betik hatası"; exit 1; }
SURE="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/ham.avi")"
echo "== Ham kayıt: $SURE sn"
echo "== Müzik"
python3 "$D/tools/make_music.py" "$OUT/muzik.wav" "$SURE"
echo "== Kurgu (müzik + oyun sesi, H.264)"
ffmpeg -y -loglevel error -i "$OUT/ham.avi" -i "$OUT/muzik.wav" \
	-filter_complex "[0:a]volume=0.55[oyun];[1:a]volume=0.9[muzik];[oyun][muzik]amix=inputs=2:duration=first:normalize=0[ses]" \
	-map 0:v -map "[ses]" -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart \
	"$OUT/kadim-diyar-fragman.mp4"
ls -la "$OUT/kadim-diyar-fragman.mp4"
