#!/usr/bin/env bash

if pgrep -i helium >/dev/null; then
  echo "Helium seems to be running:"
  pgrep -a -i helium
  echo
  echo "Close Helium normally, or run:"
  echo
  echo "  pkill -TERM -i helium"
  echo
  echo "If it still does not close, run:"
  echo
  echo "  pkill -KILL -i helium"
  echo
  echo "Then run this script again:"
  echo
  echo "  unlock-helium"
  exit 1
fi

find ~/.config ~/.var/app -maxdepth 5 \
  \( -name 'SingletonLock' -o -name 'SingletonSocket' -o -name 'SingletonCookie' \) \
  -delete 2>/dev/null

echo "Removed Helium lock files. Try starting Helium again."