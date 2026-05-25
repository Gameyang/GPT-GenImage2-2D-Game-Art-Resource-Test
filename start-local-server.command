#!/bin/zsh

set -u

REPO_ROOT="${0:A:h}"
START_PORT="${PORT:-8000}"
END_PORT="${MAX_PORT:-8010}"

cd "$REPO_ROOT" || exit 1

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 was not found. Install Python 3, then run this file again."
  echo
  printf "Press Return to close this window..."
  read -r _
  exit 1
fi

is_port_free() {
  python3 - "$1" <<'PY'
import socket
import sys

port = int(sys.argv[1])
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.settimeout(0.2)
    sys.exit(0 if sock.connect_ex(("127.0.0.1", port)) != 0 else 1)
PY
}

PORT_TO_USE=""
port="$START_PORT"
while [ "$port" -le "$END_PORT" ]; do
  if is_port_free "$port"; then
    PORT_TO_USE="$port"
    break
  fi
  port=$((port + 1))
done

if [ -z "$PORT_TO_USE" ]; then
  echo "No free port found from $START_PORT to $END_PORT."
  echo "Close another local server or set PORT before running this file."
  echo
  printf "Press Return to close this window..."
  read -r _
  exit 1
fi

URL="http://localhost:$PORT_TO_USE"

clear
echo "GPT GenImage2 2D Game Art Resource Test"
echo "Serving: $REPO_ROOT/public"
echo "URL: $URL"
echo
echo "Server log will appear below."
echo "Press Ctrl-C to stop the server."
echo

if [ "${OPEN_BROWSER:-1}" != "0" ]; then
  open "$URL" >/dev/null 2>&1 || true
fi
python3 -m http.server "$PORT_TO_USE" --directory public
STATUS=$?

echo
echo "Server stopped. Exit code: $STATUS"
printf "Press Return to close this window..."
read -r _
exit "$STATUS"
