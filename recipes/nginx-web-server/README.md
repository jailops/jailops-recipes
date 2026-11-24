# nginx-web-server

nginx installed and running, with a main configuration that includes every `conf.d/*.conf` and answers nothing for a name that no site claims. It is the setup;
the sites come from `nginx-tls-site`, or from files you drop in `conf.d`.

Title: Nginx web server
Summary: nginx installed and running, with a main configuration that includes conf.d/*.conf and answers nothing for a name no site claims.
Category: Web & Reverse Proxy
Requires JailOps >= 0.9.5.

## When to use

- The first thing on a jail that serves web pages or proxies requests.

**This recipe owns `/usr/local/etc/nginx/nginx.conf` as a whole.** The file that was there (the one the package installs, or yours) is copied once to
`/usr/local/etc/nginx/nginx.conf.before-jailops`. On a jail that already serves sites, those sites keep working only if they are files that the new `nginx.conf` includes:
move them to `conf.d` first, or merge `include /usr/local/etc/nginx/conf.d/*.conf;` into your own file and do not use this recipe.

## Assumes

A running FreeBSD jail with network access to its package repository. A flavour of nginx other than the `nginx` package: set `package`.

## Infrastructure

None to run it. To serve the Internet the jail needs ports 80 and 443 reachable (a firewall policy, or `jailops expose web 80,443`, which opens them to everybody: say so before you do it).

## Apply

    cp recipes/nginx-web-server/config.example web.vars
    jailops jail apply web -f recipes/nginx-web-server/ --dry-run --vars web.vars
    jailops jail apply web -f recipes/nginx-web-server/ --vars web.vars

The first run reports:

```
  package  nginx                                  changed  (installed nginx)
  run      sh -c test ! -f "$1" || cp -p "$1" "$1.before-jailops" sh /usr/local/etc/nginx/nginx.conf changed
  dir      /usr/local/etc/nginx/conf.d            changed  (new directory)
  file     /usr/local/etc/nginx/nginx.conf        changed  (content)
  run      nginx -t                               executed  (no guard)
  service  nginx                                  changed  (enabled, started)
  run      service nginx reload                   executed  (no guard)
  7 steps: 5 changed, 2 executed; a run without creates or unless is executed every time
```

## What it does

- installs the package, keeps the old `nginx.conf`, makes `conf.d`, writes `nginx.conf` (from the variables `worker_processes`, `worker_connections`, `max_body_size`);
- the main file has two default servers: port 80 answers nothing (`return 444`) and port 443 refuses the TLS handshake of an unknown name. They listen on IPv4 only;
- `nginx -t` before nginx is started or reloaded; the service is enabled and started; a reload at every apply (it keeps connections).

## A second run

Everything `unchanged` or `skipped`; `nginx -t` and the reload are `executed`.

## Change settings

Change `web.vars` and apply again: only `nginx.conf` changes and nginx reloads. A value nginx refuses (`worker_processes=many`) stops the run at `nginx -t`: the file stays on disk, the running nginx
is not reloaded and keeps its old configuration; fix the value and apply again. Do not restart nginx while the file is bad.

## Maintain

Package updates come with `jailops pkg upgrade web -- nginx`. Logs are `/var/log/nginx/access.log` and `error.log`; `syslog-forwarding` does not cover them (they are files, not syslog).

## What was run

FreeBSD 15.2-STABLE (jails of the minimal image), and again on 16.0-CURRENT: `--validate`; `--dry-run`; apply; apply again; `worker_processes` changed (only `nginx.conf` changed); `worker_processes=many` (`nginx -t` failed, the file stayed, the next apply fixed it).
On 15.2 only, on a jail with a hand-made nginx and its own `nginx.conf` with a site on port 8080: the file was kept as `nginx.conf.before-jailops`, the site stopped being served, and it was served again after its server block was moved into `conf.d`.
Observed: `service nginx reload` is a signal, so a request in the first instant after the apply can still meet the old configuration.

Not run: a `package` other than `nginx`, IPv6.
