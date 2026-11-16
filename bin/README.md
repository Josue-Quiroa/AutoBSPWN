# bin/

| File | What | Why |
|------|------|-----|
| `eww-x86_64` | [eww](https://github.com/elkowar/eww) **v0.6.0** (MIT, © ElKowar), X11-only build, stripped | eww is not packaged by Debian, Kali or Parrot and upstream publishes no binaries |
| `eww-x86_64.sha256` | SHA-256 of the binary | `Install.sh` refuses to install it if it does not match |

The binary prints `eww 0.5.0` with `--version`: that is the crate version upstream left in the
`v0.6.0` tag, not a different release.

How it was built (Debian 12 bookworm chroot → glibc 2.36 baseline, so it runs on Parrot 6,
Parrot 7 and Kali rolling; needs `libgtk-3-0`/`libgtk-3-0t64` and `libdbusmenu-gtk3-4`, which
`Install.sh` installs):

```bash
apt install build-essential pkg-config libgtk-3-dev libdbusmenu-gtk3-dev curl
curl -LO https://github.com/elkowar/eww/archive/refs/tags/v0.6.0.tar.gz
# sha256 cef361946946c566b79f8ddc6208d1a3f16b4ff9961439a3f86935e1cfa174a1
tar xzf v0.6.0.tar.gz && cd eww-0.6.0
cargo build --release --locked --no-default-features --features x11   # toolchain 1.76.0 (rust-toolchain.toml)
strip target/release/eww
```

Without this file (or on another CPU arch) `Install.sh` compiles eww itself when a rustc >= 1.76
is installed, otherwise it skips the dashboard (Super+F2 then shows a notification).
