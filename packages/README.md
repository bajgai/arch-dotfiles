# Package manifests

Plain lists, one package per line. `#` comments and blank lines are ignored.

- `common.txt` — installed on both Arch boxes
- `vm.txt`     — Omarchy VM only
- `vps.txt`    — VPS only

To capture what a machine currently has explicitly installed:

```sh
pacman -Qqe > /tmp/current.txt
```

On the Omarchy VM, diff that against Omarchy's own base set before adding
anything here — Omarchy manages its own packages and you do not want to
duplicate or pin them.
