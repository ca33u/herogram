#!/bin/zsh
# Herogram was called Herald. Its settings live in Herald.lua; this puts
# them where Herogram loads them (Herogram.lua, as HeraldDB, which the
# addon moves into HerogramDB on the next login). Run with the game closed.
set -e
WTF="/Applications/World of Warcraft/_forever_/WTF/Account"
if pgrep -f "MacOS/World of Warcraft( |$)" >/dev/null; then
  echo "Close the game first: it rewrites these files when it exits."
  exit 1
fi
for dir in "$WTF"/*/SavedVariables; do
  old="$dir/Herald.lua"
  new="$dir/Herogram.lua"
  [ -f "$old" ] || continue
  if [ -f "$new" ] && grep -q "HeraldDB" "$new"; then
    echo "already moved: $new"
    continue
  fi
  { [ -f "$new" ] && cat "$new"; echo; cat "$old"; } > "$new.tmp"
  mv "$new.tmp" "$new"
  echo "moved Herald settings into $new"
done
