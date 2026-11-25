# Contributing a recipe

A recipe is a way to get a job done on a FreeBSD jail, kept as a directory under `recipes/`. Send a pull request with one.

**Name it after what it accomplishes, not what it installs.** `small-postgresql-server`, `nginx-tls-site`, `ssh-key-only-access`, `local-caching-resolver`: yes. `postgresql18`, `install-nginx`: no. A package name or a version
belongs inside the recipe, and `check.sh` refuses a name with a digit.

**Few and good beat many.** Every recipe is applied on real FreeBSD (15.x) before it is merged.

What a good recipe has:

1. **A job.** One recipe does one thing. A *setup* recipe owns the main configuration file once and adds an include directory (`conf.d`, `pg_hba.d`); a *task* recipe owns one file per object, so it can be applied again with other
   values and never overwrites another recipe's files. A recipe that replaces a whole file that exists says so in the first lines of its README and keeps the old file once (`NAME.before-...`).
2. **A README** (`recipes/NAME/README.md`) that starts with `# NAME`, has a line `Title: Small PostgreSQL server` (the name a person would say), a line `Summary: ...` (one sentence of at most 150 characters that ends with a full stop: it is the text on the entry's card), a line `Category: Databases` (one of: Users & Access, System Administration, Web & Reverse Proxy, Databases, DNS & Networking, Backup & Recovery,
   Security & Hardening, Monitoring & Logging), a line `Requires JailOps >= 0.9.5`, and the sections `When to use`, `Assumes` (prerequisites: for example a jail with `FreeBSD-ssh`, added with `jailops jail base add NAME FreeBSD-ssh`, never by a recipe),
   `Infrastructure`, `Apply`, `A second run`, `Change settings`, `Maintain` and, last, `What was run`: what you ran, on which FreeBSD release, and one plain line about what was not.
3. **`recipe.yaml`**, the files it copies in `files/`, and a **`config.example`** in the `--vars` format that gives every variable (`NAME=value`, no secrets). Where a second user would change a value, it is a variable.
4. **`infra.yaml`** when the recipe needs a volume, a firewall policy or the jail itself: a file for `jailops apply -f`, marked `FOR A NEW JAIL ONLY` (a Jail document replaces the specification of a jail that exists).
5. **A test on real FreeBSD**, on the release family the Book targets (15.x). Run it on a jail made from the minimal image: `--validate`, `--dry-run`, apply, apply again (nothing changes but the unguarded checks and reloads), change a
   variable and apply again (only what depends on it changes), break a step on purpose (the error is clear and says what stayed), and use the result (log in, fetch the page, ask the resolver). Run it on a jail that was not made for it
   when the recipe says it works there.
6. **No secrets.** A secret is a variable declared `secret: true` that the user gives with `--set-file` and that is used only as the content of a `template: true` file. Nothing secret is in the repository, in an argument, in a log or in
   a file on the host. What a service writes into its own log is for the recipe to prevent (give a database password to `psql` as a variable, not as SQL text) and to show.
7. **FreeBSD conventions.** Local configuration in `/usr/local/etc` and `/usr/local/etc/ssh/authorized_keys/%u` for sshd keys. The only files in `/etc` a recipe may write are `sysctl.conf`, `periodic.conf`, `ssh/sshd_config` and
   `newsyslog.conf`. Base packages are added with `jailops jail base add`, never by a recipe.

Rules of the steps:

- A recipe works on a running jail. It **reloads** and does not restart. A recipe may restart a service only when the change cannot take effect otherwise, behind a guard that makes it happen once, and only when its README says so
  (`syslog-forwarding` is the one example).
- Every `run` has a guard (`creates` or `unless`) unless it is a check or a reload; the check or the reload is an unguarded `run` with a comment that says so. Nothing is deleted that the recipe did not make; a step never
  empties or replaces data without a guard.
- A recipe must not be able to lock people out or lose data: check before you close (`ssh-key-only-access` checks the keys first), keep the old file when you replace a whole one, scope what you delete (`postgresql-nightly-backup`).
- Values reach a shell as arguments (`sh -c 'script' sh "${value}"`), never inside the text of the script. `$${` writes a literal `${`.
- Names in everything: `example.test`, `192.0.2.0/24`, `10.20.0.0/24`, `2001:db8::`. No customer or host names, no names of other tools, no names of tools that wrote it.

## Check

`sh check.sh` checks every entry offline, with `jailops jail apply --validate` and no daemon, jail or network (the client must be 0.9.5 or later: `JAILOPS=/path/to/jailops sh check.sh`). It checks the files, the README, the variables against
`config.example`, that there is no key or password-looking value, that every action of the workflow is pinned to a commit SHA, and that `recipes/index.json` is up to date. That file is what the website reads to list the recipes; after you add or change an entry, run `sh check.sh --write-index` and commit the result. It runs on every push and pull request (`.github/workflows/check.yml`).
