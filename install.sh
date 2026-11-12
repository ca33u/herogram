#!/bin/zsh
# Copies Herogram into the WoW Forever AddOns folder. A new addon needs a
# full game restart; after that /reload is enough.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="/Applications/World of Warcraft/_forever_/Interface/AddOns/Herogram"
mkdir -p "$DST/Media"
cp "$SRC/Herogram.toc" "$SRC/Crop.html" "$SRC/LICENSE" "$SRC/README.md" "$SRC/README.ru.md" "$DST/"
cp "$SRC"/Media/*.blp "$DST/Media/"
grep -v '^##' "$SRC/Herogram.toc" | tr -d '\r' | while read -r file; do
  [ -z "$file" ] && continue
  cp "$SRC/$file" "$DST/$file"
done
echo "Herogram installed to $DST. Restart the game (new addon), then /herogram."
