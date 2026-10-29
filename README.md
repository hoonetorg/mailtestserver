# mailtestserver

A local mail and groupware server with **fake accounts only**, for testing mail clients (Evolution, Thunderbird) and
their automated configuration (e.g. ansible-role-mailclient) without any real account, address or server.

- IMAP (Dovecot 2.4), SMTP submission (Postfix, delivers only to the test domains, everything else is rejected),
  CalDAV/CardDAV (Radicale), all from the official openSUSE Leap 16.1 packages, in one rootless podman container.
- Fake accounts: `files/users` (RFC 2606 domains, throwaway passwords). Never put real accounts there.
- Seeded content per account: nested folders (`Projects/Alpha/Deep`, `Projects/Beta`, `Old`), a few mails, one
  calendar with an event (tomorrow) and a server-side colour (alice magenta, bob cyan - a client showing them took
  the colour from the server), one address book with a contact; special folders Drafts/Sent/Trash/Junk/Archive.
- TLS everywhere with a self-signed certificate for `localhost` (made at image build): accept it once in the client,
  `./run.sh info` shows its SHA-256 fingerprint.

## Use

```bash
./run.sh start     # builds the image if missing, starts the container, prints server data + accounts;
                   # a container that is still there (e.g. after a reboot) is started again with its data
./run.sh check     # IMAP folder list, a mail, CalDAV/CardDAV collections, an event, SMTP send
./run.sh status | logs | info
./run.sh stop      # removes the container - all test mails/events/changes are gone (fake data only);
                   # the next start begins from the seeded state again
./run.sh build     # rebuild the image (new certificate → the clients ask again)
```

| service | address (published on 127.0.0.1 only) | login |
|---|---|---|
| IMAP | `localhost:10993`, SSL/TLS | full address + password |
| SMTP | `localhost:10587`, STARTTLS, normal password | full address + password |
| CalDAV | `https://localhost:15232/<address>/calendar/` | full address + password |
| CardDAV | `https://localhost:15232/<address>/contacts/` | full address + password |

Ports can be changed with `MAILTEST_IMAPS`, `MAILTEST_SUBMISSION`, `MAILTEST_DAV`, the container name with
`MAILTEST_NAME`.

## Client test with ansible-role-mailclient (Evolution + Thunderbird)

The fake accounts as `mailclient` users/accounts with a provider for this server, e.g. in the test VM's
host_vars:

```yaml
mailclient:
  providers:
    mailtestserver:
      imap: {host: localhost, port: 10993, security: ssl}
      smtp: {host: localhost, port: 10587, security: starttls}
      calendar_url: "https://localhost:15232/{address}/calendar/"
      contacts_url: "https://localhost:15232/{address}/contacts/"
  users:
    - user: john                      # test user, its desktop session on the same host as this server
      accounts:
        - {id: alice, label: "Alice (test)", address: alice@example.org, provider: mailtestserver}
        - {id: bob, label: "Bob (test)", address: bob@example.net, provider: mailtestserver}
```

Then run the role (`--tags mailclient`), log in as the test user and start Evolution and Thunderbird: accounts,
calendars, task lists, address books of alice + bob; passwords from `files/users`. Certificate: accept it for
IMAP, add exceptions for `localhost:10587` and `https://localhost:15232` in Thunderbird (Settings →
Certificates).

## Limits

This is Dovecot/Postfix/Radicale, not the real hosters: provider-specific behaviour (e.g. how a hoster handles a
folder deleted into Trash) has to be checked against the real server by the user.

## License

Apache-2.0

Created with the help of AI
