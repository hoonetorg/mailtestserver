#!/bin/bash
# mailtestserver: IMAP/SMTP/CalDAV/CardDAV with FAKE accounts for client tests (Evolution, Thunderbird)
#   ./run.sh build | start | stop | status | logs | info | check
# Ports are published on 127.0.0.1 only. stop removes the container and with it all test mails/events (fake data);
# the next start begins from the seeded state again.
set -euo pipefail
cd "$(dirname "$0")"
name=${MAILTEST_NAME:-mailtestserver}
image=localhost/mailtestserver:latest
imaps=${MAILTEST_IMAPS:-10993}
submission=${MAILTEST_SUBMISSION:-10587}
dav=${MAILTEST_DAV:-15232}
accounts() { grep -v -e '^#' -e '^\s*$' files/users; }

case ${1:-} in
  build)
    podman build -t "$image" .
    ;;
  start)
    podman image exists "$image" || podman build -t "$image" .
    if podman container exists "$name"; then
      # still there (e.g. stopped by a reboot): start it again, its test data stays
      [ "$(podman inspect -f '{{.State.Running}}' "$name")" = true ] || podman start "$name" > /dev/null
    else
      podman run -d --name "$name" \
        -p "127.0.0.1:$imaps:993" -p "127.0.0.1:$submission:587" -p "127.0.0.1:$dav:5232" "$image" > /dev/null
    fi
    for _ in $(seq 30); do
      podman logs "$name" 2>&1 | grep -q 'mailtestserver ready' && break
      sleep 1
    done
    "$0" info
    ;;
  stop)
    podman rm -f "$name" > /dev/null && echo "removed container $name (test mails/events gone)"
    ;;
  status)
    podman ps -a --filter "name=^$name\$" --format '{{.Names}} {{.Status}} {{.Ports}}'
    ;;
  logs)
    podman logs "$name"
    ;;
  info)
    cat <<EOF
Server (self-signed certificate for localhost - accept it once in the client):
  IMAP     localhost:$imaps   SSL/TLS                     user = full address
  SMTP     localhost:$submission   STARTTLS, password auth  user = full address
  CalDAV   https://localhost:$dav/<address>/calendar/
  CardDAV  https://localhost:$dav/<address>/contacts/
Accounts (fake):
$(accounts | sed 's/^/  /')
Certificate SHA-256:
  $(podman exec "$name" openssl x509 -in /etc/mailtest/tls/server.crt -noout -fingerprint -sha256 | cut -d= -f2)
EOF
    ;;
  check)
    # the protocols answer with the fake accounts (curl with -k: the certificate is self-signed)
    read -r user pw < <(accounts | head -1)
    curl -sk --user "$user:$pw" "imaps://localhost:$imaps/" -X 'LIST "" "*"'
    curl -sk --user "$user:$pw" "imaps://localhost:$imaps/Projects/Alpha/Deep" -X 'EXAMINE "Projects/Alpha/Deep"' | grep EXISTS
    curl -sk --user "$user:$pw" -X PROPFIND -H 'Depth: 1' "https://localhost:$dav/$user/" | grep -o '<displayname>[^<]*' || true
    curl -sk --user "$user:$pw" "https://localhost:$dav/$user/calendar/event1.ics" | grep SUMMARY
    curl -sk --ssl-reqd --user "$user:$pw" "smtp://localhost:$submission" \
      --mail-from "$user" --mail-rcpt "$user" -T <(printf 'Subject: check\n\ncheck\n') && echo "SMTP ok"
    ;;
  *)
    sed -n '2,5p' "$0"; exit 1
    ;;
esac
