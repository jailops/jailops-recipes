# quiet-periodic-and-cron

A jail whose periodic(8) jobs say only what is wrong, write it to log files instead of mail that nobody reads, and skip the checks that mean nothing in a jail; and whose cron
starts its jobs spread over a few seconds so that many jails do not wake up in the same moment.

Title: Quiet periodic and cron
Summary: Periodic jobs that log instead of mailing, and cron jobs spread over a few seconds so that many jails do not wake together.
Category: System Administration
Requires JailOps >= 0.9.5.

## When to use

- On every jail you keep, hand-made jails included. A JailOps image already sends the reports to log files; this recipe adds the quiet settings and works the same on a jail that
  was made some other way.

## Assumes

Nothing besides a running FreeBSD jail with cron.

## Infrastructure

None.

## Apply

    cp recipes/quiet-periodic-and-cron/config.example quiet.vars
    jailops jail apply web -f recipes/quiet-periodic-and-cron/ --dry-run --vars quiet.vars
    jailops jail apply web -f recipes/quiet-periodic-and-cron/ --vars quiet.vars

The first run reports:

```
  sysrc    periodic.conf                          changed  (daily_clean_tmps_enable=YES daily_show_info=NO daily_show_success=NO daily_status_disks_enable=NO daily_status_mfi_enable=NO daily_status_network_enable=NO monthly_show_info=NO monthly_show_success=NO weekly_locate_enable=NO weekly_show_info=NO weekly_show_success=NO weekly_whatis_enable=NO)
  sysrc    rc.conf                                changed  (cron_flags=-j 30 -J 30)
  service  cron                                   changed  (enabled)
  3 steps: 3 changed
```

## What it does

`/etc/periodic.conf` is changed variable by variable (the rest of the file stays):

- `daily_output`, `weekly_output`, `monthly_output`: log files in `/var/log`, which the stock `newsyslog.conf` rotates.
- `*_show_success=NO` and `*_show_info=NO`: only warnings and errors are reported.
- the checks of disks, the network statistics of the host, hardware (mfi) and the world/kernel version are off; `locate` and `whatis` databases are not rebuilt; `/tmp` is cleaned.

`cron_flags` in `/etc/rc.conf` becomes `-j N -J N`: `-j` spreads the jobs of users, `-J` the jobs of root (the system crontab). N is `cron_jitter`, 0 to 60 seconds.

## A second run

Everything `unchanged`.

## Change settings

Change `cron_jitter` in `quiet.vars` and apply again: only `cron_flags` changes. **cron reads its flags when it starts**, and a recipe never restarts a service: the new value is used after
`jailops exec web -- service cron restart` or the next start of the jail.

## Maintain

The reports are in `/var/log/daily.log`, `weekly.log` and `monthly.log`. A quiet report is an empty file.

## What was run

FreeBSD 15.2-STABLE (jail of the minimal image), and again on 16.0-CURRENT: `--validate`; `--dry-run`; apply; apply again (all `unchanged`); `cron_jitter` changed (only `cron_flags` changed); cron restarted by hand and seen running with `-j 45 -J 45`;
`periodic daily` before the recipe wrote 1377 bytes into `/var/log/daily.log` of the stock jail and, after it, 0 bytes.

Not run: a start of the jail with the new flags, the weekly and monthly jobs, a jail that was not made by JailOps.
