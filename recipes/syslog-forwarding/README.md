# syslog-forwarding

The jail sends its log messages to a central log host over UDP, so that what a jail logs is kept somewhere else than the jail.

Title: Syslog forwarding
Summary: The jail sends its log messages to a central log host over UDP, so they are kept somewhere other than the jail.
Category: Monitoring & Logging
Requires JailOps >= 0.9.5.

## When to use

- A fleet of jails whose logs you read in one place, or one jail whose logs must survive the jail.
- PostgreSQL, nginx and most FreeBSD services log through syslog here, so one rule covers them.

## Assumes

- A log host that receives syslog over UDP (`syslogd` started with `-a` for the sender's network, or another collector) and that the jail can reach on the port.
- The messages are not encrypted and UDP can lose them: keep the log host on a network you trust.

## Infrastructure

None. The firewall policy of the log host must let the jail's address reach its UDP port; the jail's own policy must allow it to send.

## Apply

    cp recipes/syslog-forwarding/config.example syslog.vars         # loghost=192.0.2.50
    jailops jail apply web -f recipes/syslog-forwarding/ --dry-run --vars syslog.vars
    jailops jail apply web -f recipes/syslog-forwarding/ --vars syslog.vars

The first run reports:

```
  run      sh -c case "$1" in '*'|kern|user|mail|daemon|auth|security|syslog|lpr|news|uucp|cron|authpriv|ftp|ntp|audit|console|loca... executed  (no guard)
  file     /usr/local/etc/syslog.d/forward.conf   changed  (new file)
  sysrc    rc.conf                                changed  (syslogd_flags=-s)
  service  syslogd                                changed  (enabled)
  run      service syslogd restart                changed
  run      service syslogd reload                 executed  (no guard)
  6 steps: 4 changed, 2 executed; a run without creates or unless is executed every time
```

## What it does

- `/usr/local/etc/syslog.d/forward.conf`: one line, `FACILITY.LEVEL @loghost:port`. syslogd reads that directory after `/etc/syslog.conf`, so nothing else of the logging of the jail changes.
- The recipe refuses a facility or a level that syslogd does not know before it writes anything.
- `syslogd_flags="-s"` in `rc.conf`. **A JailOps jail starts syslogd with `-ss`, which opens no network socket and so forwards nothing**; `-s` still refuses remote messages and can send.
  Flags are read when syslogd starts, so the recipe **restarts syslogd once**, only while the running process does not have the flags (a guarded `run`), and reloads it at every apply.
  The restart takes a moment; messages logged in it are not forwarded.

## A second run

The file, the rc variable and the service are `unchanged`, the restart is `skipped`, the reload is `executed`.

## Change settings

`facility` (default `*`) and `level` (default `notice`: that level and everything above it). A selector with several rules or a program filter is a file of your own in `/usr/local/etc/syslog.d/`.
One destination per jail: the recipe owns `forward.conf`.

## Maintain

What arrives is decided by the log host's own `syslog.conf`: a message below the level that it writes to a file is received and not kept. Test the path with
`jailops exec web -- logger -p daemon.notice "test"` and look on the log host.

## What was run

FreeBSD 15.2-STABLE (jails of the minimal image: one that logs, one that receives with `syslogd -a`), and again on 16.0-CURRENT: `--validate`; `--dry-run`; apply on a jail whose syslogd ran with `-ss` (the recipe restarted syslogd once);
apply again (restart `skipped`); a `notice` message arrived at the log host and an `info` message did not; `facility=daemon level=info` (an `info` message of `daemon` arrived, a `debug` one did not); `level=loud` (refused before anything was written).

Not run: a log host that is not a JailOps jail, a host name instead of an address, IPv6.
