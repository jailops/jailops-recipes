# ssh-key-only-access

sshd of a jail accepts logins by public key for the users you name, and nothing else: no passwords, no root login, no other users. Before it changes
anything it checks that every named user already has a valid public key, so closing the passwords cannot lock everybody out.

Title: SSH key-only access
Summary: sshd accepts key logins for the users you name and nothing else, after checking that every one of them has a key.
Category: Security & Hardening
Requires JailOps >= 0.9.6.

## When to use

- A jail is reached over ssh and you want key logins only.
- After `admin-user-with-ssh-key`, which makes the users and their keys.

**This recipe owns `/etc/ssh/sshd_config` as a whole.** The file that was there is copied once to `/etc/ssh/sshd_config.before-key-only-access`; every later run replaces
the file again, so keep your own settings in the variables of the recipe or in a copy of its `files/sshd_config`.

## Assumes

- `jailops jail base add web FreeBSD-ssh` was done: that is where sshd and `ssh-keygen` come from. The recipe checks that sshd is there before it changes anything.
- Every user in `allowed_users` has a key file in `keys_dir` (`/usr/local/etc/ssh/authorized_keys/USER`), made by `admin-user-with-ssh-key`. The recipe checks it and stops
  with the name of the user that has none; nothing is changed in that case.
- Keys in a user's own `~/.ssh/authorized_keys` are **not** read any more: `AuthorizedKeysFile` points to `keys_dir` only. Move them there first.

## Infrastructure

None. The firewall policy of the jail must let your address reach the port you choose (22 by default).

## Apply

    cp recipes/ssh-key-only-access/config.example sshd.vars        # allowed_users=alice bob
    jailops jail apply web -f recipes/ssh-key-only-access/ --dry-run --vars sshd.vars
    jailops jail apply web -f recipes/ssh-key-only-access/ --vars sshd.vars

The first run reports:

```
  run      sh -c k=$1; shift ...                  executed  (no guard)
  run      cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.before-key-only-access changed
  run      ssh-keygen -A                          changed
  file     /etc/ssh/sshd_config                   changed  (content)
  run      /usr/sbin/sshd -t                      executed  (no guard)
  service  sshd                                   changed  (enabled, started)
  run      service sshd reload                    executed  (no guard)
  7 steps: 4 changed, 3 executed; a run without creates or unless is executed every time
```

## What it does

| Step | What |
|---|---|
| the check | for every user of `allowed_users`: `keys_dir/USER` holds at least one public key `ssh-keygen` accepts, or the run stops |
| copy of the old file | `/etc/ssh/sshd_config.before-key-only-access`, once |
| host keys | `ssh-keygen -A` only when no ed25519 host key exists; existing host keys are kept, so clients that know the jail do not see a changed key |
| `/etc/ssh/sshd_config` | `AllowUsers`, `PermitRootLogin`, `AuthenticationMethods publickey`, `PasswordAuthentication no`, `AuthorizedKeysFile keys_dir/%u`, no forwarding, three tries |
| `sshd -t`, service, reload | the file is tested before sshd sees it; sshd is enabled and started if it is not; a running sshd reloads (open sessions stay) |

**Root.** `permit_root_login` is `no`, and root is not in `allowed_users`, so logins as root stop, **including the key logins of automation that uses root**. If you
need them, give root a key with `admin-user-with-ssh-key` (`user=root`), put `root` in `allowed_users` and set `permit_root_login=prohibit-password`.

**A reload closes the listening socket for a moment** (observed: a connection in the first instant after the reload is refused, one a second later is accepted).
Open sessions are not touched.

## A second run

The check, `sshd -t` and the reload are unguarded `run` steps: reported `executed`, and harmless. The copy and the host keys are `skipped`, the file is `unchanged`.

## Change settings

Change `sshd.vars` and apply again. A bad value (for example `permit_root_login=bogus`) makes `sshd -t` fail: the run stops, the new file **stays on disk** and the running sshd
is not reloaded, so it keeps the old rules until you apply again with a good value. Do not restart sshd or the jail while the file is bad. To go back, copy
`/etc/ssh/sshd_config.before-key-only-access` over it. Changing `port` moves sshd to the new port on the reload: open the port in the firewall policy first.

## Maintain

Add a person with `admin-user-with-ssh-key`, then apply this recipe again with the person added to `allowed_users`. FreeBSD updates of the `FreeBSD-ssh` base package can bring a new default `sshd_config`;
the next run of this recipe puts yours back.

## What was run

FreeBSD 15.2-STABLE (jails of the minimal image, `FreeBSD-ssh` added), and again on 16.0-CURRENT: `--validate`; `--dry-run`; a user without a key in `allowed_users` (stopped at the check, `sshd_config` untouched); apply; apply again; real ssh logins from the host:
the named user with a key (accepted), the same user by password (refused), a user not in `allowed_users` (refused), root (refused); then `allowed_users` with a second user (accepted) and with root and `permit_root_login=prohibit-password` (root key accepted);
`permit_root_login=bogus` (`sshd -t` failed, the file stayed, the next apply with a good value fixed it); the previous `sshd_config` was kept as `sshd_config.before-key-only-access`.

Not run: a `port` other than 22, a jail whose sshd was already running with its own configuration, IPv6.
