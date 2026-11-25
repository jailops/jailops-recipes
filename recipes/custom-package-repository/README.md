# custom-package-repository

An extra pkg repository for one jail: its public key is fetched from an https URL and checked, and a repository file points pkg at it. Applied again with another name it adds the next repository.

Title: Custom package repository
Summary: Make a jail use an additional pkg repository, with its public key fetched from an https URL and optionally pinned by its sha256.
Category: System Administration
Requires JailOps >= 0.9.6.

## When to use

- Packages of your own (built with poudriere, or published by a vendor) are served from a pkg repository, and a jail must install and update from it next to the FreeBSD ones.
- You want the key to come from a URL instead of being copied into the jail by hand, and, when you know its fingerprint, to be refused when it differs.

## Assumes

- The jail has `fetch` and `pkg`: `jailops jail base add NAME FreeBSD-fetch` for `fetch`, `jailops pkg install NAME -- pkg` for `pkg`. The recipe checks both before any step runs. It also needs `sha256` (part of the runtime of the base).
- The jail can verify https certificates (a trust store), or `fetch` of the key fails and says so.
- The repository is signed with a key pair (`signature_type: pubkey`) and you have the URL of the public key. Never put a private key anywhere in this recipe.

## Infrastructure

None. The jail must reach the host of the repository and of the key.

## Apply

    cp recipes/custom-package-repository/config.example acme.vars     # repo_name, repo_url, key_url and the optional key_sha256
    jailops jail apply web -f recipes/custom-package-repository/ --dry-run --vars acme.vars
    jailops jail apply web -f recipes/custom-package-repository/ --vars acme.vars

| Variable | Meaning |
|---|---|
| `repo_name` | required; a lower-case word (a to z, digits and `-` after the first letter). It names the repository, `/usr/local/etc/pkg/repos/NAME.conf` and `/usr/local/etc/pkg/keys/NAME.pub` |
| `repo_url` | required; the repository as pkg writes it, for example `pkg+https://pkg.example.org/${ABI}/latest` |
| `key_url` | required; https URL of the public key (PEM) |
| `key_sha256` | optional; `sha256 -q` of the key. When set, a key with another sha256 is refused before it is installed |

**`${ABI}` in `repo_url`.** pkg expands `${ABI}` (and `${OSNAME}`, `${RELEASE}`) itself, so it must reach the file as written. Write it exactly like that, in the vars file, in `--set` or in a default: JailOps replaces `${name}` once in the text of the recipe and never searches a value again, so a `${ABI}` inside a value arrives in the file untouched. Do not double it: `$${ABI}` is only for text of the recipe itself, and in a value it would reach pkg as `$${ABI}`, which pkg does not expand. On a command line, keep the shell from expanding it: `--set 'repo_url=pkg+https://pkg.example.org/${ABI}/latest'` in single quotes.

The first run reports:

```
  dir      /usr/local/etc/pkg/keys                changed  (new directory)
  dir      /usr/local/etc/pkg/repos               unchanged
  run      sh -c set -eu url=$1; dest=$2; want=$3 ... changed
  file     /usr/local/etc/pkg/repos/acme.conf     changed  (new file)
  run      pkg update -r acme                     executed  (no guard)
```

## What it does

| In the jail | What |
|---|---|
| `/usr/local/etc/pkg/keys/NAME.pub` | the public key (`0644`, root), fetched with `fetch` next to its place as `NAME.pub.new`, checked, then moved over; a failed check leaves no `.new` file and keeps the old key |
| `/usr/local/etc/pkg/repos/NAME.conf` | `NAME: { url, signature_type: "pubkey", pubkey, enabled: yes }` |
| `pkg update -r NAME` | refreshes the catalogue of this repository and so proves that the URL answers and the signature matches the key |

The key is checked for a non-empty PEM public key (`BEGIN PUBLIC KEY`) and, with `key_sha256`, for the exact fingerprint. Without `key_sha256` the key is trusted on first use over https: the connection protects it, nothing pins it. Give the fingerprint whenever you know it.

**Names that are taken.** The image of a jail seeds `/usr/local/etc/pkg/repos/FreeBSD.conf` (it disables `FreeBSD-ports-kmods`) and `FreeBSD-base.conf` (it keeps `FreeBSD-base` disabled), and `/etc/pkg/FreeBSD.conf` defines `FreeBSD-ports`. `repo_name` is lower-case, so it never meets them, and the recipe never writes a file that JailOps seeds or manages (`FreeBSD.conf`, `FreeBSD-base.conf`). Avoid `jailops` as well: that is the name of JailOps's own package repository on the host.

**Packages.** The recipe does not install any. A step cannot be left out, and a `package` step needs at least one name, so an optional list of packages cannot be part of it. Install from the new repository with `jailops pkg install web -- PACKAGE`, or apply a recipe with a `package:` step afterwards (pkg takes a package from any repository the jail has; `pkg install -r NAME PACKAGE` in the jail picks this one).

## A second run

The key step is `skipped` (the key is there, and has the right sha256 when `key_sha256` is set), the file `unchanged`, `pkg update -r NAME` `executed`.

## Change settings

- `repo_url` or `repo_name`: the file `NAME.conf` changes; a new `repo_name` adds a second repository, the old files stay (remove them with `jailops exec web -- rm /usr/local/etc/pkg/repos/OLD.conf /usr/local/etc/pkg/keys/OLD.pub`).
- **Key rotation.** With `key_sha256` set: put the new fingerprint in the vars file and apply again; the installed key no longer matches, so the key is fetched again, checked against the new fingerprint and replaced. With a wrong fingerprint nothing is replaced and the run stops with the sha256 that was served. Without `key_sha256`: an installed key is never replaced, so remove it (`jailops exec web -- rm /usr/local/etc/pkg/keys/NAME.pub`) and apply again, or better, set `key_sha256`.
- `key_url`: takes effect when the key is fetched again (after a rotation as above).

## Maintain

pkg checks the signature of the catalogue with the file at `pubkey`, so a replaced key must belong to the repository you serve. To stop using the repository, set `enabled: no` in `NAME.conf` (or remove both files).

## What was run

`jailops jail apply --validate` with `config.example` (offline, `check.sh`), the render of the repository file with `${ABI}` in a value (it stays `${ABI}`), the logic of the key script with stand-ins for `fetch` and `sha256` on a Linux machine (a wrong sha256 installs nothing, the right one installs, `unless` skips only when the installed key matches), and the shell checks of the requirements for names and fingerprints.

Not run on FreeBSD: nothing here was applied to a jail. Not verified: that `FreeBSD-fetch` is the package that holds `fetch` on 15.x, that a jail of the minimal image has `fetch`, `sha256` and a trust store, the apply, the second run, a rotation, and `pkg update -r NAME` against a real repository.
