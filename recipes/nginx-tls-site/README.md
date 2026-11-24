# nginx-tls-site

One https site on nginx with its certificate and private key, a web root, and plain http redirecting to https. Applied again with another name it adds the next site.

Title: Nginx TLS site
Summary: One https site on nginx with its certificate and key, and http redirecting to https; apply again with another name for the next site.
Category: Web & Reverse Proxy
Requires JailOps >= 0.9.5.

## When to use

- A site that has a certificate (from your own authority, from an ACME client, or self-signed for a test) and that nginx serves from a directory.

## Assumes

- nginx runs in the jail with a main file that includes `conf.d/*.conf`: that is what `nginx-web-server` sets up. The recipe never touches `nginx.conf`.
- You have the certificate chain and the private key as files on the machine where you run `jailops`. The key is a secret variable: it is only written to the file in the jail
  (`0600`, root), and never to the command line, a log, the report or a file on the host. If a step fails, JailOps withholds the output of every step of the run, so run the check
  yourself to read the reason: `jailops exec web -- nginx -t`.

## Infrastructure

None. Ports 80 and 443 must reach the jail.

## Apply

    cp recipes/nginx-tls-site/config.example example.test.vars          # site=example.test and the other values
    jailops jail apply web -f recipes/nginx-tls-site/ --dry-run --vars example.test.vars --set-file tls_cert=example.test.crt --set-file tls_key=example.test.secret
    jailops jail apply web -f recipes/nginx-tls-site/ --vars example.test.vars --set-file tls_cert=example.test.crt --set-file tls_key=example.test.secret

`tls_cert` and `tls_key` have several lines and are given with `--set-file`; `tls_key` is the only secret and has no place in `example.test.vars`.

The first run reports:

```
  file     /usr/local/etc/ssl/shop.example.test.crt changed  (new file)
  file     /usr/local/etc/ssl/shop.example.test.key changed  (new file)
  dir      /usr/local/www/shop.example.test       changed  (new directory)
  run      sh -c printf "<!doctype html><title>%s</title><p>%s is served by nginx.\n" "$1" "$1" > "$2/index.html" sh shop.example.t... changed
  file     /usr/local/etc/nginx/conf.d/shop.example.test.conf changed  (new file)
  run      nginx -t                               executed  (no guard)
  run      service nginx reload                   executed  (no guard)
  7 steps: 5 changed, 2 executed; a run without creates or unless is executed every time
```

## What it does

| In the jail | What |
|---|---|
| `/usr/local/etc/ssl/SITE.crt`, `SITE.key` | the certificate (`0644`) and the key (`0600`) |
| `/usr/local/www/SITE` | the web root, made if missing; a one-line page `index.html` is written **only while there is none**, so your content is never replaced |
| `/usr/local/etc/nginx/conf.d/SITE.conf` | port 80 redirects to `https://SITE`, port 443 serves the web root with TLS 1.2 and 1.3 for `site` and its `server_aliases` |
| `nginx -t`, reload | the whole configuration is tested, then nginx reloads |

The site listens on `listen_address` (`0.0.0.0`; `[::]` for IPv6, if the jail has an IPv6 address).

## A second run

All files `unchanged`, the page `skipped`, `nginx -t` and the reload `executed`.

## Change settings

Change `example.test.vars` and apply again; only the files that depend on the value change. A key that does not belong to the certificate (or any other broken file) stops the run at `nginx -t`: the
new files **stay on disk**, the running nginx is not reloaded and keeps serving every site with the configuration it has, and the next reload or start of nginx fails until you apply again with
good files. To renew a certificate, give the new files and apply again.

To remove a site: `jailops exec web -- rm /usr/local/etc/nginx/conf.d/SITE.conf`, then reload.

## Maintain

Certificates expire: renew them and apply again, from your own schedule. The recipe does not fetch certificates.

## What was run

FreeBSD 15.2-STABLE (jails of the minimal image, with `nginx-web-server`), and again on 16.0-CURRENT, with a self-signed certificate made for the test: `--validate`; `--dry-run`; apply; apply again; `curl` with the certificate as the authority:
`https://SITE/` (200), the alias (200), `http://SITE/page` (301 to https), an unknown name (TLS handshake refused on 443, empty reply on 80); a page edited in the jail was not replaced by the next apply;
a second site applied with other values (both answer); `web_root` changed; a key that does not belong to the certificate (`nginx -t` failed, the running nginx kept serving, the next apply with the right key fixed it).
On 15.2 only, on the hand-made nginx jail of `nginx-web-server` after its site was moved to `conf.d`: the new site was served next to the old one.

Not run: `listen_address=[::]`, a certificate chain with intermediates, renewal of a certificate.
