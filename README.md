# JailOps Recipe Book

Recipes for FreeBSD jails: set up a service, give someone access, harden, log, back up, restore. Each entry is a directory with a `recipe.yaml`, its files and a README, and is applied with
`jailops jail apply NAME -f recipes/ENTRY/` to any running jail, however that jail was made, as often as you like. Nothing runs by itself and there is no agent: you run it, and a second run changes nothing that is already right.
The Book does not follow the release cycle of JailOps: each entry says which version it needs (0.9.5 or later). Every entry is applied twice on FreeBSD 15 before it is merged; its README says what was run.

The Book is organised by the question **what do I need to do?** A *setup* recipe owns the main configuration file once and adds an include directory; a *task* recipe owns one file per object and is applied again for the next one
(another site, another database, another user). Things outside the jail (volumes, firewall policies, the jail itself) are in an `infra.yaml` for `jailops apply -f`, for a new jail only.

## Entries

### Users & Access

| Entry | What |
|---|---|
| [admin-user-with-ssh-key](recipes/admin-user-with-ssh-key/) | a user with no password and the public keys that may log in as that user, one file per user |

### System Administration

| Entry | What |
|---|---|
| [quiet-periodic-and-cron](recipes/quiet-periodic-and-cron/) | periodic reports only what is wrong and writes it to logs, cron spreads its jobs |

### Web & Reverse Proxy

| Entry | What |
|---|---|
| [nginx-web-server](recipes/nginx-web-server/) | nginx with a main file that includes `conf.d/*.conf` and answers nothing for unknown names |
| [nginx-tls-site](recipes/nginx-tls-site/) | one https site with its certificate and key, http redirects to it; apply again for the next site |

### Databases

| Entry | What |
|---|---|
| [small-postgresql-server](recipes/small-postgresql-server/) | PostgreSQL with its data in a volume, scram-sha-256 on the network, `conf.d` and `pg_hba.d` |
| [postgresql-database-and-role](recipes/postgresql-database-and-role/) | one database, one role, one network that may connect; the password never reaches a log |

### DNS & Networking

| Entry | What |
|---|---|
| [local-caching-resolver](recipes/local-caching-resolver/) | a caching, validating resolver for one client network, full recursion, no upstream you did not choose |
| [local-dns-zone](recipes/local-dns-zone/) | names the resolver answers itself, one file per zone |

### Backup & Recovery

| Entry | What |
|---|---|
| [postgresql-nightly-backup](recipes/postgresql-nightly-backup/) | nightly dump of every database and the roles, retention, a failed night is a syslog line |
| [postgresql-restore-dump](recipes/postgresql-restore-dump/) | restore a dump into a new database; never over one that exists |

### Security & Hardening

| Entry | What |
|---|---|
| [ssh-key-only-access](recipes/ssh-key-only-access/) | sshd takes public keys of the named users and nothing else, after it has checked that they have keys |

### Monitoring & Logging

| Entry | What |
|---|---|
| [syslog-forwarding](recipes/syslog-forwarding/) | the jail sends its log messages to a log host |

## Use an entry

    git clone https://github.com/jailops/jailops-recipes.git
    cd jailops-recipes
    cp recipes/nginx-web-server/config.example web.vars                 # change the values
    jailops jail apply web -f recipes/nginx-web-server/ --vars web.vars --dry-run
    jailops jail apply web -f recipes/nginx-web-server/ --vars web.vars

Read the README of the entry first: it says what it assumes, whether it needs an `infra.yaml`, and which of its files it replaces whole. `config.example` lists every variable in the format `--vars` reads. A secret is a variable that is given
with `--set-file` and never written in a file of the Book. `--validate` checks a recipe without a daemon or a jail, and `--dry-run` shows what would change in a running jail.

## Layout of an entry

    recipes/NAME/README.md          the job, when to use it, what it assumes, infrastructure, apply, a second run, changes, maintenance, what was run
    recipes/NAME/recipe.yaml        the steps and the variables
    recipes/NAME/config.example     every variable, in the --vars format; no secrets
    recipes/NAME/files/             the files the steps copy into the jail
    recipes/NAME/infra.yaml         volume, policy, jail for `jailops apply -f`: only when needed, for a new jail only

## Check

`sh check.sh` checks every entry offline (see the file); see [CONTRIBUTING.md](CONTRIBUTING.md) for how to add one.

## Naming

**Name recipes after what they accomplish, not what they install.** A package is an ingredient, a recipe is the dish: `small-postgresql-server`, `postgresql-nightly-backup`, `nginx-tls-site`, `local-caching-resolver`, `ssh-key-only-access`. The software may appear in a name when it is what the job is done to (`postgresql-database-and-role`), but a name is never a package, never a version (no `postgresql18`), and never only "install X". Package names and versions live inside the recipe, where a reader changes them for the host at hand, and a recipe keeps its purpose when the software moves on to a new release.

## Layout

    jailops-recipes/
    ├── LICENSE.md
    ├── README.md
    ├── CONTRIBUTING.md
    ├── check.sh
    ├── .github/workflows/check.yml    check.sh on every push and pull request
    └── recipes/
        └── NAME/                      one directory per recipe, named by what it accomplishes

`recipes/` is flat on purpose: the path of a recipe stays the same when the way recipes are grouped changes. The grouping (Users & Access, System Administration, Web & Reverse Proxy, Databases, DNS & Networking, Backup & Recovery, Security & Hardening, Monitoring & Logging) is the `Category:` line of each README, and the website builds its pages from it.
