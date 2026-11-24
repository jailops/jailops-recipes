# admin-user-with-ssh-key

Gives a person a login on a jail: a user account with no password, and the public keys that may log in as that user. It is the first
step of a jail that is reached over ssh; `ssh-key-only-access` then closes the password logins.

Title: Admin user with SSH key
Summary: A user account with no password, and the public keys that may log in as that user.
Category: Users & Access
Requires JailOps >= 0.9.5.

## When to use

- A new jail needs an administrator, or an existing jail needs one more person.
- You want the keys of a user in one place that is owned by root and that you can see in a recipe run, not in the user's own home.

One run is one user. Apply it again with another `user` and other keys for the next person; each user has a file of their own, so a run never
touches the files of other users.

## Assumes

- The jail has the ssh programs: `jailops jail base add web FreeBSD-ssh` (the recipe uses `ssh-keygen` to check the keys, and sshd comes with it).
- sshd reads the keys from `/usr/local/etc/ssh/authorized_keys/USER` only when its `AuthorizedKeysFile` says so. `ssh-key-only-access` sets that;
  if you do not use it, put `AuthorizedKeysFile /usr/local/etc/ssh/authorized_keys/%u` in `/etc/ssh/sshd_config` yourself.

## Infrastructure

None. The jail must be running, and the firewall policy of the jail must let your address reach port 22.

## Apply

Give the user and the keys (one public key per line; the file is yours, not in this repository):

    cp recipes/admin-user-with-ssh-key/config.example alice.vars        # set user (and the other values if you want)
    jailops jail apply web -f recipes/admin-user-with-ssh-key/ --dry-run --vars alice.vars --set-file ssh_keys=alice.pub
    jailops jail apply web -f recipes/admin-user-with-ssh-key/ --vars alice.vars --set-file ssh_keys=alice.pub

`alice.vars` holds `user=alice` and the other values of `config.example` that you change; `ssh_keys` is multi-line, so it is always given with
`--set-file`. Public keys are not secret: they appear in the report of the run.

The first run reports:

```
  run      pw useradd alice -m -s /bin/sh -G wheel -c Administrator changed
  run      sh -c good=0 all=0 ...                 executed  (no guard)
  file     /usr/local/etc/ssh/authorized_keys/alice changed  (new file)
  3 steps: 2 changed, 1 executed; a run without creates or unless is executed every time
```

## What it does

| Step | What |
|---|---|
| `pw useradd` | creates the user with a home directory, the shell and groups of the variables, and **no password** (`*` in the password field: no password login). Skipped when the user exists: an existing user's shell and groups are not changed |
| the check of the keys | every non-empty, non-comment line of `ssh_keys` must be a public key that `ssh-keygen` reads; otherwise the run stops **before** the key file is written |
| the key file | `/usr/local/etc/ssh/authorized_keys/USER`, `root:wheel`, `0644`, written whole |

Things to know:

- **The key file is replaced whole at each run.** List every key the user needs. A line that is not a key stops the run before the file is touched, so a typo cannot
  empty it; a valid list of one key does replace a list of three, because that is what you asked for.
- `groups` defaults to `wheel`. A jail's root has no password, so a member of `wheel` can become root with `su`. Give another group if that is not what you want.
- The directory is made `root:wheel` `0755` by the engine and the file belongs to root, so the user cannot add keys of their own and a restored home directory
  does not bring old keys back.

## A second run

The user is `skipped` and the key file is `unchanged`. The check of the keys is an unguarded `run`: it is reported `executed` every time, and
changes nothing.

## Change settings

Change a value in `alice.vars` and apply again; only the file that depends on it changes. To add or remove a key, change the file of keys. A different
`authorized_keys_dir` must be the same in `ssh-key-only-access`. To take a user's access away, remove their key file
(`jailops exec web -- rm /usr/local/etc/ssh/authorized_keys/USER`); the account stays.

## Maintain

Nothing runs by itself. Keys live in one directory, so `ls /usr/local/etc/ssh/authorized_keys` is the list of who can log in by key.

## What was run

FreeBSD 15.2-STABLE (jails of the minimal image, `FreeBSD-ssh` added), and again on 16.0-CURRENT: `--validate`; `--dry-run`; apply (user and key file created); apply again (user `skipped`, key file `unchanged`); a second user with other keys;
a list of two keys for the first user (only the key file changed); a line that is not a key (the run stopped at the check, the key file was not touched); key logins as these users by ssh from the host (with `ssh-key-only-access`).

Not run: an existing user with another home directory or shell, a `groups` value other than `wheel`, a jail without `FreeBSD-ssh`.
