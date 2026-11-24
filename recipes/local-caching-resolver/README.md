# local-caching-resolver

A DNS resolver for one client network, in its own jail: it caches answers, validates DNSSEC, and answers only the clients you name. Zones of your own come from `local-dns-zone`.

Title: Local caching resolver
Summary: A DNS resolver for one client network, in its own jail: it caches, validates DNSSEC and answers only the clients you name.
Category: DNS & Networking
Requires JailOps >= 0.9.5.

## When to use

- The jails of a project should ask one resolver that you run, not each their own, and not a public one.

**It resolves by itself**, from the root servers down (full recursion). Out of the box no query goes to a resolver that you did not choose. If you want an upstream (a resolver of your provider, or a public one), that is a decision of
yours: a file in `/usr/local/etc/unbound/conf.d/` such as

    forward-zone:
        name: "."
        forward-addr: 192.0.2.53

**This recipe owns `/usr/local/etc/unbound/unbound.conf` as a whole.** The file that was there is copied once to `unbound.conf.before-jailops`; anything of your own belongs in `conf.d`, which the new file includes.

## Assumes

- A jail with network access to the root servers (UDP and TCP port 53 out), for recursion and for the DNSSEC root key.
- The clients are in one network, `client_network`; the jail itself may always ask. More networks: add `server:` / `access-control:` lines in a file of your own in `conf.d`.
- IPv4 only (`do-ip6: no`).

## Infrastructure

For a **new jail only** (an `apply -f` of a Jail document replaces the specification of a jail that exists): `infra.yaml` has an address set and a firewall policy that let `client_network` reach port 53 (udp and tcp) and the jail. Copy it,
change the names, the image and the network (it must be the `client_network` of the recipe), then:

    cp recipes/local-caching-resolver/infra.yaml infra.yaml        # change the names, the image and the network
    jailops apply -f infra.yaml
    jailops start dns

On a jail that exists add only the policy.

## Apply

    cp recipes/local-caching-resolver/config.example dns.vars        # client_network=10.20.0.0/24
    jailops jail apply dns -f recipes/local-caching-resolver/ --dry-run --vars dns.vars
    jailops jail apply dns -f recipes/local-caching-resolver/ --vars dns.vars

The first run reports:

```
  package  unbound                                changed  (installed unbound)
  run      sh -c test ! -f "$1" || cp -p "$1" "$1.before-jailops" sh /usr/local/etc/unbound/unbound.conf changed
  dir      /usr/local/etc/unbound/conf.d          changed  (new directory)
  file     /usr/local/etc/unbound/unbound.conf    changed  (content)
  run      sh -c unbound-anchor -a "$1"; test -s "$1" && chown unbound "$1" sh /usr/local/etc/unbound/root.key changed
  run      unbound-checkconf /usr/local/etc/unbound/unbound.conf executed  (no guard)
  service  unbound                                changed  (enabled, started)
  run      service unbound reload                 executed  (no guard)
  8 steps: 6 changed, 2 executed; a run without creates or unless is executed every time
```

## What it does

- installs `unbound`, keeps the old `unbound.conf`, makes `conf.d`, writes `unbound.conf`: access for the jail and `client_network` only (`refuse` for everybody else), qname minimisation, prefetch, no version or identity, DNSSEC validation with the root key (`root.key`, made once by `unbound-anchor`);
- `unbound-checkconf` before the resolver is started or reloaded; enabled and started; reload at every apply (the cache is rebuilt, the process stays).

## A second run

`unchanged` and `skipped` steps, `executed` for the check and the reload.

## Change settings

Change `dns.vars` and apply again: only `unbound.conf` changes. A value unbound cannot read (`client_network=not-a-network`) stops the run at `unbound-checkconf`: the file stays on disk, the running resolver is not reloaded and keeps its old
configuration; apply again with a good value. Do not restart unbound while the file is bad.

## Maintain

Point the clients at the jail's address (their `resolv.conf`, or the DNS setting of the network). `unbound` updates the root key by itself. Package updates: `jailops pkg upgrade dns -- unbound`.

## What was run

FreeBSD 15.2-STABLE (jail made from `infra.yaml`: address set, firewall policy and jail), and again on 16.0-CURRENT: `--validate`; `--dry-run`; apply; apply again; `drill` from a client jail: a name resolved (NOERROR, recursion from the root servers, no upstream configured),
with `-D` the answer carried the `ad` flag, and `dnssec-failed.org` returned SERVFAIL; `client_network` changed to another network (the client was refused) and back; `client_network=not-a-network` (`unbound-checkconf` stopped the run, the next apply with a good value fixed it).

Not run: IPv6, a forward zone in `conf.d`, a client in a network other than the jail's own.
