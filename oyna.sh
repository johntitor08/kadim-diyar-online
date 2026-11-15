#!/bin/sh
# Oyunu açar. Örnek: ./oyna.sh -- --join=127.0.0.1 --name=Ali
D="$(dirname "$(readlink -f "$0")")"
exec flatpak run org.godotengine.Godot --path "$D" "$@"
