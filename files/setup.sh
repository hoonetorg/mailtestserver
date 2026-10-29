#!/bin/bash
# image build: configure Dovecot, Postfix, Radicale for the fake accounts in users; TLS certificate (self-signed)
set -euo pipefail
src=/opt/mailtest
accounts() { grep -v -e '^#' -e '^\s*$' "$src/users"; }

# TLS: self-signed, valid for localhost (the clients connect to 127.0.0.1 via the published ports)
install -d -m 0755 /etc/mailtest/tls
openssl req -x509 -newkey rsa:3072 -nodes -days 3650 -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
  -keyout /etc/mailtest/tls/server.key -out /etc/mailtest/tls/server.crt 2>/dev/null
chown root:radicale /etc/mailtest/tls/server.key
chmod 0640 /etc/mailtest/tls/server.key

# Dovecot
install -m 0644 "$src/dovecot.conf" /etc/dovecot/dovecot.conf
: > /etc/dovecot/users
while read -r addr pw; do
  echo "$addr:{PLAIN}$pw:5000:5000::/srv/mail/$addr::" >> /etc/dovecot/users
done < <(accounts)
chown root:dovecot /etc/dovecot/users
chmod 0640 /etc/dovecot/users

# Radicale
install -m 0644 "$src/radicale.conf" /etc/radicale/config
accounts | awk '{print $1 ":" $2}' > /etc/radicale/users
chown root:radicale /etc/radicale/users
chmod 0640 /etc/radicale/users

# Postfix: the test domains are delivered to Dovecot (LMTP); nothing ever leaves the container
accounts | awk '{print $1 " ok"}' > /etc/postfix/vmailbox
domains=$(accounts | awk '{sub(/.*@/, "", $1); print $1}' | sort -u | tr '\n' ' ')
postconf -e \
  "myhostname = mail.example.org" \
  "mydestination = localhost" \
  "inet_interfaces = all" \
  "inet_protocols = ipv4" \
  "alias_maps =" \
  "alias_database =" \
  "virtual_mailbox_domains = $domains" \
  "virtual_mailbox_maps = texthash:/etc/postfix/vmailbox" \
  "virtual_transport = lmtp:unix:private/dovecot-lmtp" \
  "default_transport = error:mailtestserver delivers to the test domains only" \
  "relay_transport = error:mailtestserver delivers to the test domains only" \
  "smtpd_tls_cert_file = /etc/mailtest/tls/server.crt" \
  "smtpd_tls_key_file = /etc/mailtest/tls/server.key" \
  "smtpd_tls_security_level = may" \
  "maillog_file = /var/log/postfix.log"
cat >> /etc/postfix/master.cf <<'EOF'
submission inet n       -       n       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_tls_auth_only=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
EOF

# mail storage
groupadd -g 5000 vmail
useradd -u 5000 -g vmail -d /srv/mail -M -s /usr/sbin/nologin vmail
install -d -o vmail -g vmail -m 0750 /srv/mail
install -d -o radicale -g radicale -m 0750 /var/lib/radicale/collections

# Postfix queue directories (incl. private/ for Dovecot's LMTP and auth sockets)
install -d -m 0755 /var/spool/postfix
postfix post-install create-missing

doveconf -n > /dev/null
postfix check
