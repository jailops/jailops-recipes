# local-dns-zone

Names that the resolver answers itself, for one zone: the addresses of your own hosts, an internal domain, a name that must point somewhere else inside than outside.

Title: Local DNS zone
Summary: Names the resolver answers itself, for one zone: your own hosts, an internal domain, a name that points somewhere else inside.
Category: DNS & Networking
Requires JailOps >= 0.9.5.

## When to use

- After `local-caching-resolver`. One run is one zone; apply it again with another `zone` and its records for the next one. Each zone is a file of its own in `conf.d`, so zones never touch each other and `unbound.conf` is never touched.

## Assumes

An unbound that includes `/usr/local/etc/unbound/conf.d/*.conf` in its main file (`local-caching-resolver` sets that up). `records` has one `local-data:` line per record, in unbound's syntax, for example

    local-data: "www.example.test. 300 IN A 192.0.2.10"
    local-data: "example.test. 300 IN MX 10 mail.example.test."

Names are given with the final dot. The records are a file on the machine where you run `jailops`, given with `--set-file`.

## Infrastructure

None.

## Apply

    cp recipes/local-dns-zone/config.example example.test.vars            # zone=example.test
    jailops jail apply dns -f recipes/local-dns-zone/ --dry-run --vars example.test.vars --set-file records=example.test.records
    jailops jail apply dns -f recipes/local-dns-zone/ --vars example.test.vars --set-file records=example.test.records

The first run reports:

```
  file     /usr/local/etc/unbound/conf.d/zone-example.test.conf changed  (new file)
  run      unbound-checkconf /usr/local/etc/unbound/unbound.conf executed  (no guard)
  run      service unbound reload                 executed  (no guard)
  3 steps: 1 changed, 2 executed; a run without creates or unless is executed every time
```

## What it does

`conf.d/zone-ZONE.conf` holds `local-zone: "ZONE." static` and your records. With `static`, a name in the zone that is not listed is `NXDOMAIN`; set `zone_type=transparent` to let unlisted names resolve as usual.
Then `unbound-checkconf` on the whole configuration, then a reload.

## A second run

The zone file is `unchanged`; the check and the reload are `executed`.

## Change settings

Edit the records and apply again: only that zone's file changes. A record unbound cannot parse stops the run at `unbound-checkconf`: the file stays on disk, the running resolver is not reloaded and keeps answering with the old
records; correct the file and apply again. To remove a zone: delete its file and reload (`jailops exec dns -- sh -c 'rm /usr/local/etc/unbound/conf.d/zone-ZONE.conf; service unbound reload'`).

## Maintain

Records are changed in the file you keep with your configuration, never in the jail. Check with `drill @RESOLVER name`.

## What was run

FreeBSD 15.2-STABLE (jail of `local-caching-resolver`), and again on 16.0-CURRENT: `--validate`; `--dry-run`; apply; apply again; `drill` from a client jail: an `A` record and an `MX` record of the zone, `NXDOMAIN` for a name of the static zone that is not listed;
a second zone by applying again (both answer); a record added (only that zone's file changed); a record with an unknown type (`unbound-checkconf` stopped the run, the resolver kept answering with the old records, the next apply fixed it).

Not run: `zone_type=transparent`, reverse zones, more than a few records.
