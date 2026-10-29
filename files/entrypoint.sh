#!/bin/bash
set -euo pipefail
dovecot
postfix start
# seed once per container; a restarted container keeps its (test) changes
if [ ! -e /srv/mail/.seeded ]; then
  /opt/mailtest/seed.sh
  touch /srv/mail/.seeded
fi
# Postfix logs to a file (postlogd can't reach the container's stdout); pass it on to podman logs
touch /var/log/postfix.log
tail -F -n 0 /var/log/postfix.log &
echo "mailtestserver ready"
exec runuser -u radicale -- radicale --config /etc/radicale/config
