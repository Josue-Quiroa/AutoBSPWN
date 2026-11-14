<div align="center">

# 🪻 AutoBSPWN

**Entorno [BSPWM](https://github.com/baskerville/bspwm) listo para pentesting, pensado para Parrot OS Home.**
Barra estilo píldoras · esquinas redondeadas · temas sincronizados · Target HUD · VPN switcher · calendario.

<br>

![Parrot](https://img.shields.io/badge/Parrot_OS-Home_%7C_Security-16B1C6?style=for-the-badge&logo=parrotsecurity&logoColor=white)
![Kali](https://img.shields.io/badge/Kali-compatible-557C94?style=for-the-badge&logo=kalilinux&logoColor=white)
![BSPWM](https://img.shields.io/badge/WM-bspwm-8A5CF6?style=for-the-badge)
![Shell](https://img.shields.io/badge/Bash-shellcheck_clean-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-A8C957?style=for-the-badge)

<br>

![Escritorio AutoBSPWN](assets/preview-desktop.png)

</div>

---

## Contenido

- [Instalación](#instalación)
- [Qué incluye](#qué-incluye)
- [Atajos esenciales](#atajos-esenciales)
- [Flujo de pentest](#flujo-de-pentest)
- [Herramientas de Parrot Security](#herramientas-de-parrot-security-opcional)
- [Temas y wallpapers](#temas-y-wallpapers)
- [Compatibilidad](#compatibilidad)
- [Créditos](#créditos)

---

## Instalación

```bash
git clone https://github.com/Josue-Quiroa/AutoBSPWN.git
cd AutoBSPWN
./Install.sh
```

Cierra sesión y, en el login (LightDM / SDDM), elige la sesión **`bspwm`**.
Tu escritorio MATE o KDE sigue intacto. Dentro, pulsa **`Super`+`F1`** para ver todos los atajos.

| Comando | Qué hace |
|---|---|
| `./Install.sh` | Interactivo: pregunta si instalar tools de pentest |
| `./Install.sh -y` | Sin preguntas, sin tools |
| `./Install.sh -y --tools basic` | Sin preguntas, con tools básicas |
| `./Install.sh --list-tools` | Lista categorías de tools y sale |

> **Requisitos:** usuario con `sudo` (no root), sesión **X11**, ~1 GB libre. Parrot 6/7 Home, Parrot Security o Kali rolling.

<details>
<summary>Todas las flags del instalador</summary>

```
-y, --yes              sin preguntas (tools = none salvo --tools)
--tools MODO           none | basic | pentest | full | custom:cat1,cat2
--list-tools           ver categorías/metapaquetes de tu distro y salir
--skip-upgrade         no hacer full-upgrade / parrot-upgrade
--skip-fonts           no descargar Nerd Fonts
--disable-backports    comentar repos *-backports de Parrot (opt-in)
-n, --nickname NAME    obsoleta (se ignora; los fondos ya no llevan texto)
```
</details>

---

## Qué incluye

| Pieza | Detalle |
|---|---|
| 🧩 **Polybar** | Barra de píldoras: launcher, IP, VPN, tools, portapapeles, tema, updates, CPU/RAM, batería, Target HUD, volumen, reloj con calendario y power |
| 🎨 **Temas** | `amethyst` (defecto), `mocha`, `macchiato`, `hacker` — sincronizan polybar, bspwm, kitty, rofi, dunst, lock y wallpaper |
| 🖼️ **Wallpapers** | 9 fondos anime/paisaje + selector con miniaturas |
| 🐱 **Kitty** | JetBrainsMono NF, opacidad, pestañas redondeadas, divisiones |
| ✨ **Picom** | Esquinas redondeadas (radio 10) en VM y en metal |
| 🔎 **Rofi** | Menús compactos con iconos y esquinas redondeadas |
| 🎯 **Pentest** | Target HUD, VPN/lab switcher, portapapeles, launcher de tools |
| ⚡ **Extras** | Calendario, hoja de atajos, capturas, menú de escritorio, scratchpad |

---

## Atajos esenciales

La lista completa (≈80 atajos + comandos) está en **[`ATAJOS.md`](ATAJOS.md)** y en pantalla con **`Super`+`F1`**.

| Teclas | Acción |
|---|---|
| `Super`+`Enter` | Terminal (kitty) |
| `Super`+`d` · `Super`+`Tab` | Lanzar apps · cambiar de ventana |
| `Super`+`i` | 🎯 Target HUD |
| `Super`+`v` · `Super`+`Shift`+`v` | 🔐 VPN · reconectar |
| `Super`+`c` · `Super`+`p` | 📋 Portapapeles · 🧰 tools |
| `Super`+`w` · `Super`+`Shift`+`w` | 🖼️ Wallpapers · aleatorio |
| `Super`+`Shift`+`t` · `Super`+`Alt`+`t` | Ciclar tema · selector |
| `Super`+`Alt`+`c` | 📅 Calendario |
| `Print` · `Super`+`Print` | Captura de zona · pantalla |
| `Super`+`flechas` / `h j k l` | Mover el foco (`Shift` mueve, `Alt` redimensiona) |
| `Super`+`1`…`0` | Cambiar de escritorio |
| `Super`+`q` · `Super`+`Shift`+`x` | Cerrar ventana · bloquear |

<p align="center">
  <img src="assets/wallpapers.png" alt="Wallpapers incluidos" width="48%">
  <img src="assets/preview-keys.png" alt="Hoja de atajos (Super+F1)" width="48%">
</p>

---

## Flujo de pentest

### 🎯 Target HUD
La barra muestra el objetivo actual (**nombre · IP · puertos**). Con `Super`+`i` abres el menú para copiar la IP, abrir `http/https`, entrar por **SSH**, lanzar **Nmap** (rápido o full `-sC -sV`) o añadirlo a `/etc/hosts`. Todo se guarda en `~/targets/<ip>/` (`nmap/`, `loot/`, `notes.md`…). En zsh, `tgt` te lleva a la carpeta del target.

### 🔐 VPN / lab switcher
`Super`+`v` lista tus perfiles de `~/vpn/*.ovpn`, WireGuard y las conexiones de NetworkManager. Conectar uno desconecta los demás (modo lab); la barra muestra el perfil, la IP y la interfaz del túnel. Pide la contraseña **una sola vez** por acción (sudo cacheado → pkexec → terminal).

### 📋 Portapapeles · 🧰 Tools
`Super`+`c` abre el historial del portapapeles (greenclip, con copyq de respaldo; ignora gestores de contraseñas). `Super`+`p` abre un menú con solo las herramientas instaladas (Burp, Wireshark, BloodHound, Ghidra…); las apps Java arrancan sin ventanas grises.

---

## Herramientas de Parrot Security (opcional)

Parrot Home no trae las tools de pentest. El instalador las ofrece y nunca aborta si algo falla (reintenta por metapaquete y lo deja en el log). Se instalan al final, así el entorno queda listo aunque una falle.

| Flag | Parrot | Kali | Tamaño aprox. (Parrot 6 / 7) |
|---|---|---|---|
| `--tools none` | — | — | 0 |
| `--tools basic` | recon · web · passwords · post-exploit | `kali-tools-top10` | ~5 GB / ~9 GB |
| `--tools pentest` | basic + explotación + sniffing | `kali-linux-default` | ~7 GB / ~11 GB |
| `--tools full` | `parrot-tools-full` | `kali-linux-large` | ~10 GB / ~15 GB |
| `--tools custom:web,password,…` | `parrot-tools-<cat>` | `kali-tools-<cat>` | depende |

> Los tamaños son estimaciones sobre el índice oficial de Parrot (nov 2026, con *Recommends*); varían según el mirror. Instálalas después con `./Install.sh -y --skip-upgrade --tools pentest`.

---

## Temas y wallpapers

Un solo cambio de tema (`Super`+`Shift`+`t`) reaplica colores en **polybar, bordes, kitty, rofi, dunst, lock y wallpaper** a la vez. Cada tema trae su fondo; con `Super`+`w` eliges entre los 9 incluidos (con miniaturas) y `Super`+`Shift`+`w` pone uno al azar.

Para que cambiar de tema **no** te cambie el fondo: `touch ~/.config/bspwm/.no-theme-wall`.
Fuentes de cada imagen en [`wallpapers/CREDITS.md`](wallpapers/CREDITS.md).

---

## Compatibilidad

Detecta automáticamente **Parrot Home / Security / Kali** y adapta nombres de paquetes, versión de polybar (3.6 y 3.7) y de picom (10 y 12+). Convive con MATE y KDE sin romperlos:

<details>
<summary>Detalles de convivencia con MATE / KDE</summary>

- La sesión bspwm no arranca marco, mate-panel, caja-desktop ni el compositor de MATE.
- Notificaciones: dunst solo dentro de bspwm; el daemon nativo (MATE/KDE/XFCE) en sus sesiones, vía un router en `~/.local/share/dbus-1/services/`.
- El autostart global de `picom` se desactiva para tu usuario; bspwm lo lanza por su cuenta.
- nm-applet, agente polkit y portapapeles se arrancan una sola vez.
- Caja se abre con `--no-desktop` para no tapar el wallpaper.
- `nmap`, `openvpn` y `wireguard-tools` se instalan siempre (los usan el HUD y la VPN).
</details>

<details>
<summary>Notas y resolución de problemas</summary>

- No ejecutar como root. Log completo en `~/.cache/autobspwn-install-*.log`; backup en `~/.config/autobspwn-backup-*`.
- apt espera hasta 10 min por el lock y reintenta `apt update`; si falla, sigue con la caché.
- Polybar sin iconos → `fc-cache -fv` y reinstala sin `--skip-fonts`.
- `wg-quick` con `DNS =` puede necesitar `openresolv`/`resolvconf`.
- Actualizar desde v2.x: `./Install.sh --skip-upgrade -y` (mueve los fondos viejos con texto al backup).
- Nada requiere GPU: en VMs picom usa `xrender` y las esquinas redondeadas siguen funcionando.
</details>

---

## Créditos

Inspirado en el trabajo de la comunidad; **todo el código y las configs están escritos desde cero** para AutoBSPWN (ninguno de los dos repos publica licencia, así que no se copió nada de ellos):

- **[r1vs3c/auto-bspwm](https://github.com/r1vs3c/auto-bspwm)** — inspiración visual: barra de píldoras moradas, bordes finos, gaps, estilo de rofi y kitty.
- **[yoodreamer/AutoBSPWM](https://github.com/yoodreamer/AutoBSPWM)** — inspiración funcional: calendario en el reloj, menú de escritorio, ocultar/recuperar ventanas, foco por nodos, capturas.
- **Colores:** [Catppuccin](https://github.com/catppuccin/catppuccin) (MIT) y la paleta Material Design.
- **Wallpapers:** de sus respectivos autores — ver [`wallpapers/CREDITS.md`](wallpapers/CREDITS.md).

<div align="center">
<br>

Código bajo licencia **MIT** · hecho para la comunidad de Parrot y Kali 🦜

</div>
