#!/bin/bash
# fake content per account: nested folders + a few mails (IMAP), one calendar with an event, one address book with a
# contact (CalDAV/CardDAV). Runs at the first start of a container; a new container always starts from this state
set -euo pipefail
src=/opt/mailtest
accounts() { grep -v -e '^#' -e '^\s*$' "$src/users" | awk '{print $1}'; }
dav=/var/lib/radicale/collections/collection-root
tomorrow=$(date -u -d tomorrow +%Y%m%d)
# server-side calendar colour per account (CalDAV calendar-color): unusual colours, so a client showing them took
# them from the server and didn't pick its own
colors=("#ff00ff" "#00c0c0" "#c0c000")
n=0

mail() {   # mail <user> <folder> <from> <subject>
  printf 'From: %s\nTo: %s\nSubject: %s\nDate: %s\nMessage-ID: <%s@mailtestserver>\n\nFake test mail "%s".\n' \
    "$3" "$1" "$4" "$(date -R)" "$(cat /proc/sys/kernel/random/uuid)" "$4" | doveadm save -u "$1" -m "$2"
}

for u in $(accounts); do
  for f in Projects Projects/Alpha Projects/Alpha/Deep Projects/Beta Old; do
    doveadm mailbox create -u "$u" -s "$f"
  done
  mail "$u" INBOX test@example.com "Welcome $u"
  mail "$u" INBOX test@example.com "Second mail"
  mail "$u" Projects/Alpha test@example.com "Alpha status"
  mail "$u" Projects/Alpha/Deep test@example.com "Deep folder mail"
  mail "$u" Old test@example.com "Old mail"

  install -d -o radicale -g radicale "$dav/$u/calendar" "$dav/$u/contacts"
  printf '{"tag": "VCALENDAR", "D:displayname": "Calendar", "ICAL:calendar-color": "%s"}\n' \
    "${colors[n % ${#colors[@]}]}" > "$dav/$u/calendar/.Radicale.props"
  n=$((n + 1))
  echo '{"tag": "VADDRESSBOOK", "D:displayname": "Contacts"}' > "$dav/$u/contacts/.Radicale.props"
  printf 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//mailtestserver//EN\r\nBEGIN:VEVENT\r\nUID:%s\r\nDTSTAMP:%sT000000Z\r\nDTSTART:%sT090000Z\r\nDTEND:%sT100000Z\r\nSUMMARY:Fake test event\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n' \
    "event1-$u" "$tomorrow" "$tomorrow" "$tomorrow" > "$dav/$u/calendar/event1.ics"
  printf 'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:%s\r\nFN:Test Contact\r\nN:Contact;Test;;;\r\nEMAIL:test@example.com\r\nEND:VCARD\r\n' \
    "contact1-$u" > "$dav/$u/contacts/contact1.vcf"
  chown -R radicale:radicale "$dav/$u"
done
