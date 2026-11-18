<!-- autobspwn-atajos v3.4.3 — generado con: ~/.config/bspwm/scripts/keys-help.sh --markdown -->
# AutoBSPWN 3.4.3 — Atajos y comandos

**Super** = tecla Windows. Esta misma lista sale en pantalla con **Super + F1** o **Super + /**
(puedes escribir para filtrar y Enter ejecuta la acción). Se genera leyendo
`~/.config/sxhkd/sxhkdrc`, así que si agregas un atajo con un comentario `# descripción`
encima, aparece solo.

Notas:
- `{a,b,c}` significa “una de estas teclas”, p. ej. `Super + {1-9,0}` = Super+1 … Super+0.
- Las flechas y `h j k l` (estilo vim) hacen lo mismo.
- **Ratón**: Super + arrastre izquierdo mueve una ventana, Super + arrastre derecho la
  redimensiona desde la esquina más cercana y Super + arrastre central desde un lado.
- **Redimensionar con teclado** (flotantes y mosaico): `Super + Alt + ←/→` más estrecha/ancha,
  `Super + Alt + ↑/↓` más baja/alta (en mosaico mueve el borde); `Super + Alt + Shift + flecha` encoge.
- **Dashboard**: `Super + F2` abre el panel eww (perfil, reloj, calendario, CPU/RAM/disco,
  volumen y brillo, accesos, VPN/target y apagado); `Esc` o `Super + F2` lo cierran.
- **Mosaico ↔ flotante**: `Super + s` cambia sólo la ventana activa; `Super + Shift + s` pone
  **todo el escritorio** en modo flotante (las ventanas nuevas abren flotando y las acomodas
  con el ratón) y al volver a pulsarlo regresan al mosaico automático. El modo se ve en la barra.
- **Polybar**: clic en el reloj = calendario · clic en el icono de la izquierda = apps
  (derecho: info del sistema) · rueda sobre el icono de paleta = cambiar tema
  (clic derecho: wallpapers) · clic en target/VPN/IP = copiar/menú.
- **Modo presentación** (`Super + F12`): oculta target, IP de la VPN y de la red en la barra y
  pausa las notificaciones; la barra muestra **OCULTO**. **No graba** (salvo que actives
  «grabar al activar la presentación» en `Super + Alt + F12`). Se recuerda tras reiniciar
  (`~/.config/autobspwn/state`).
- **Grabar la pantalla** (`Super + Shift + F12`, necesita `ffmpeg`): graba el monitor en el que
  estás, sin audio, en `~/Videos/AutoBSPWN/grabacion-AAAAmmdd-HHMMSS.mkv` (nunca sobrescribe) y al
  parar avisa con la ruta exacta; la barra muestra **REC**. Carpeta: `Super + Alt + F12` (menú con
  selector), `record_dir=/ruta` en el state o `AUTOBSPWN_RECORD_DIR`. Audio: `record_audio=1`.
- **Notas rápidas** (`Super + Alt + n`): en el popup, `Alt + d` lista las notas para borrarlas
  (`Shift + Enter` marca varias, confirma antes; «borrar todas» pide escribir `BORRAR`).
- **Varios monitores**: los escritorios I–X se reparten entre los monitores (2 → I–V / VI–X) y
  `Super + 1…0` va al escritorio global; `Super + Alt + 1…0` va al escritorio 1…10 **del otro
  monitor** (el secundario; con 3+ el siguiente al principal; fíjalo con `second_monitor=NOMBRE`)
  y `Super + Alt + Shift + 1…0` manda la ventana ahí. Una barra por monitor y DPI automático.
  `desktops=each` en `~/.config/autobspwn/state` vuelve a I–X en cada monitor. En VMware /
  VirtualBox no se fuerza xrandr (manda el agente de la VM); `monitors.sh --status` diagnostica.

### Terminal y apps

| Atajo | Acción |
|---|---|
| `` Super + Enter `` | Terminal (kitty) |
| `` Super + Shift + Enter `` | Terminal flotante |
| `` Super + u `` | Scratchpad: terminal desplegable con tmux (hasta 4 terminales como pestañas; ver abajo) |
| `` Super + d `` | Lanzador de aplicaciones (rofi) |
| `` Super + r `` | Ejecutar un comando (rofi) |
| `` Super + Tab `` | Lista de ventanas abiertas (rofi) |
| `` Super + e `` | Gestor de archivos |
| `` Super + Shift + f `` | Navegador web |
| `` Super + Shift + b `` | Burp Suite (si está instalado) |

### Pentest

| Atajo | Acción |
|---|---|
| `` Super + i `` | Target HUD: menú del target (nmap, ssh, web, notas…) |
| `` Super + Shift + i `` | Fijar target (setFocus IP nombre) |
| `` Super + Shift + c `` | Quitar target (clearFocus) |
| `` Super + Alt + i `` | Targets guardados (favoritos): elegir uno lo hace el target activo |
| `` Super + Alt + n `` | Nota rápida: una línea a las notas del target (o a ~/notes/inbox.md); Alt+d en el popup = ver / borrar notas |
| `` Super + F12 `` | Modo presentación: oculta IPs, target y VPN de la barra y pausa notificaciones (no graba salvo record_with_present=1) |
| `` Super + Shift + F12 `` | Grabar la pantalla (ffmpeg, monitor actual, sin audio) on/off → ~/Videos/AutoBSPWN |
| `` Super + Alt + F12 `` | Menú de presentación / grabación (carpeta de grabaciones, abrir carpeta, grabar al presentar) |
| `` Super + v `` | VPN / lab switcher |
| `` Super + Shift + v `` | Reconectar la última VPN |
| `` Super + p `` | Launcher de tools de pentest |
| `` Super + c `` | Historial del portapapeles |

### Apariencia

| Atajo | Acción |
|---|---|
| `` Super + w `` | Selector de wallpapers con vista previa |
| `` Super + Shift + w `` | Wallpaper aleatorio |
| `` Super + Shift + t `` | Siguiente tema (amethyst → mocha → macchiato → frappé → tokyonight → nord → gruvbox → dracula → rosé pine → hacker) |
| `` Super + Alt + t `` | Selector de temas |
| `` Super + b `` | Mostrar / ocultar la barra |
| `` Super + Shift + p `` | Reiniciar la barra (polybar) |
| `` Super + Alt + {=,-} `` | Más / menos espacio entre ventanas (gaps) |

### Ventanas

| Atajo | Acción |
|---|---|
| `` Super + q `` | Cerrar ventana |
| `` Super + Shift + q `` | Matar ventana (kill) |
| `` Super + t `` | Modo mosaico (tiled) |
| `` Super + s `` | Ventana actual: flotante ↔ mosaico (alternar) |
| `` Super + Shift + Space `` | Alternar flotante / mosaico (igual que Super+s) |
| `` Super + Shift + s `` | Modo flotante de TODO el escritorio (acomodar libre con el ratón) ↔ mosaico automático |
| `` Super + Alt + s `` | Modo pseudo-tiled |
| `` Super + f `` | Pantalla completa |
| `` Super + m `` | Alternar layout mosaico / monocle |
| `` Super + g `` | Intercambiar con la ventana más grande |
| `` Super + y `` | Llevar la ventana marcada a la preselección |
| `` Super + Ctrl + {m,x,y,z} `` | Marcar / bloquear / fijar en todos los escritorios / privada |
| `` Super + n `` | Ocultar (minimizar) ventana |
| `` Super + Shift + n `` | Recuperar ventanas ocultas (menú) |

### Foco y movimiento

| Atajo | Acción |
|---|---|
| `` Super + {Left,Down,Up,Right} `` | Mover el foco (flechas) |
| `` Super + {h,j,k,l} `` | Mover el foco (vim) |
| `` Super + Shift + {Left,Down,Up,Right} `` | Mover ventana flotante / intercambiar ventana en mosaico (flechas) |
| `` Super + Shift + {h,j,k,l} `` | Mover ventana flotante / intercambiar ventana en mosaico (vim) |
| `` Super + Alt + {Left,Down,Up,Right} `` | Redimensionar (flotante: ←/→ más estrecha/ancha, ↑/↓ más baja/alta; mosaico: mueve el borde) |
| `` Super + Alt + {h,j,k,l} `` | Redimensionar (vim) |
| `` Super + Alt + Shift + {Left,Down,Up,Right} `` | Encoger la ventana (flotante o mosaico) |
| `` Super + Alt + {p,b,coma,punto} `` | Foco al nodo padre / hermano / primer hijo / segundo hijo |
| `` Super + ` `` | Volver a la ventana anterior |
| `` Super + {o,Shift + o} `` | Ventana más antigua / más reciente del historial |

### Escritorios

| Atajo | Acción |
|---|---|
| `` Super + {1-9,0} `` | Ir al escritorio 1-10 |
| `` Super + Shift + {1-9,0} `` | Enviar la ventana al escritorio 1-10 (y seguirla) |
| `` Super + Alt + {1-9,0} `` | Ir al escritorio 1-10 del OTRO monitor (el secundario; con 3+ el siguiente al principal) |
| `` Super + Alt + Shift + {1-9,0} `` | Enviar la ventana al escritorio 1-10 del otro monitor (y seguirla) |
| `` Super + {[,]} `` | Escritorio anterior / siguiente |
| `` Super + Shift + ` `` | Volver al último escritorio |

### Preselección

| Atajo | Acción |
|---|---|
| `` Super + Ctrl + {Left,Down,Up,Right} `` | Preseleccionar dirección para la próxima ventana (flechas) |
| `` Super + Ctrl + {h,j,k,l} `` | Preseleccionar dirección (vim) |
| `` Super + Ctrl + Alt + {Left,Down,Up,Right} `` | Preseleccionar dirección (estilo r1vs3c/yoodreamer) |
| `` Super + Ctrl + {1-9} `` | Proporción de la preselección (10%-90%) |
| `` Super + Ctrl + Space `` | Cancelar la preselección |
| `` Super + Ctrl + Alt + Space `` | Cancelar la preselección (estilo r1vs3c/yoodreamer) |
| `` Super + Ctrl + Shift + Space `` | Cancelar todas las preselecciones del escritorio |

### Capturas

| Atajo | Acción |
|---|---|
| `` Print `` | Captura de una zona (guarda + copia al portapapeles) |
| `` Super + a `` | Captura de una zona |
| `` Super + Print `` | Captura de pantalla completa |
| `` Super + Shift + Print `` | Captura de la ventana activa |
| `` Super + Ctrl + Print `` | Captura completa con 5 s de espera |

### Sistema

| Atajo | Acción |
|---|---|
| `` Super + F1 `` | Hoja de atajos (esta lista) |
| `` Super + / `` | Hoja de atajos |
| `` Super + F2 `` | Dashboard eww: perfil, reloj, sistema, sliders, accesos y apagado (otra vez = cerrar) |
| `` Esc (con el dashboard abierto) `` | Cerrar el dashboard (Esc sigue llegando a la ventana activa) |
| `` Super + Alt + c `` | Calendario |
| `` Super + Shift + m `` | Menú del escritorio (también clic derecho sobre el fondo) |
| `` Click derecho (escritorio) `` | Menú contextual al hacer clic derecho sobre el fondo |
| `` Super + Shift + x `` | Bloquear pantalla (i3lock con el wallpaper desenfocado) |
| `` Ctrl + Alt + l `` | Bloquear pantalla (estilo r1vs3c) |
| `` Super + Shift + e `` | Menú de apagado |
| `` Super + Esc `` | Recargar atajos (sxhkd) |
| `` Super + Shift + r `` | Reiniciar bspwm |
| `` Super + Alt + r `` | Reiniciar bspwm (estilo r1vs3c) |
| `` Super + Alt + q `` | Cerrar sesión (salir de bspwm) |

### Multimedia

| Atajo | Acción |
|---|---|
| `` XF86AudioRaiseVolume `` | Subir volumen |
| `` XF86AudioLowerVolume `` | Bajar volumen |
| `` XF86AudioMute `` | Silenciar |
| `` XF86AudioMicMute `` | Silenciar micrófono |
| `` Super + F11 `` | Subir volumen (VMs sin teclas multimedia) |
| `` Super + F10 `` | Bajar volumen (VMs) |
| `` Super + F9 `` | Silenciar (VMs) |
| `` XF86MonBrightnessUp `` | Subir brillo |
| `` XF86MonBrightnessDown `` | Bajar brillo |

### Ratón

| Acción | Resultado |
|---|---|
| `` Super + clic izquierdo `` (arrastrar) | Mover ventana flotante / intercambiar en mosaico |
| `` Super + clic derecho `` (arrastrar) | Redimensionar desde la esquina más cercana (flotante o mosaico) |
| `` Super + clic central `` (arrastrar) | Redimensionar sólo un lado |
| Clic derecho en ⏻ de la barra | Abrir el dashboard eww |
| Clic en el icono 󰕴/󰖲 de la barra | Alternar modo mosaico / flotante del escritorio (= Super+Shift+s) |
| Clic derecho sobre el fondo | Menú del escritorio (jgmenu) |
| Clic en el reloj | Calendario (yad) |

## Comandos de terminal (zsh)

| Comando | Qué hace |
|---|---|
| `setFocus 10.10.11.25 [nombre]` | Fija el target: aparece en la barra (Target HUD) y en `~/targets/<ip>` |
| `clearFocus` | Quita el target (el historial se conserva en Super+i) |
| `focusip` | Muestra el target actual |
| `tgt` | `cd ~/targets/<ip del target>` (crea `nmap/ loot/ exploits/`) |
| `tgt <nombre\|ip>` | Activa un target guardado o reciente y entra en su carpeta (Tab autocompleta) |
| `targetFav add <ip> [nombre] [etiqueta]` · `rm` · `list` · `use` | Gestiona los targets guardados (`~/.config/bspwm/targets.tsv`) |
| `tscan fast\|full\|udp\|ad [ip]` | Recon del target: resultados en `~/targets/<ip>/nmap/`, actualiza `ports.txt` y avisa de puertos nuevos (respeta el scope; `--force`) |
| `scope-check [-v] <ip\|host\|CIDR\|URL>` | ¿Dentro del scope? (`~/targets/<ip>/scope.conf`: `in:` / `out:`) |
| `nmap …` / `ffuf …` | Pasan por el guardia de scope; `--force` para lanzar fuera de scope |
| `loot <etiqueta> archivo` · `cmd \| loot <etiqueta>` · `loot --list` | Guarda loot en `~/targets/<ip>/loot/` con hora, herramienta, origen y sha256 |
| `autobspwn-update` | `git pull` del repo + `Install.sh --update` (sólo configs; conserva tus ediciones) |
| `autobspwn-update --list-backups` · `--rollback [N]` | Ver los backups · volver al de antes del último update (tus targets no se tocan) |
| `autobspwn-doctor [--quiet]` | Revisa dependencias, versiones y configs: OK / WARN / FAIL (exit 0/1/2) |
| `note <texto>` | Nota rápida al `notes.md` del target (o `~/notes/inbox.md`) = Super+Alt+n |
| `note --list` · `note --rm N` · `note --rm-all` | Ver las notas numeradas · borrar la N (o `2,5`, `3-6`) · borrar todas (pide `BORRAR`) |
| `~/.config/bspwm/scripts/record.sh --dir` · `--set-dir <ruta>` · `--last` | Carpeta de grabaciones · cambiarla (`default` = ~/Videos/AutoBSPWN) · última grabación |
| `mkt <nombre>` | Crea y entra en `~/Machines/<nombre>/{nmap,content,exploits,scripts,loot}` |
| `ports archivo.nmap` | Lista los puertos abiertos separados por coma (para `nmap -p`) |
| `extractHosts [archivo]` | Extrae las IPs únicas de un archivo o de la entrada estándar |
| `theme-sync <tema>` / `theme <tema>` | Cambia el tema: `amethyst`, `mocha`, `macchiato`, `frappe`, `tokyonight`, `nord`, `gruvbox`, `dracula`, `rosepine`, `hacker` |
| `theme-sync --next` · `--menu` · `--list` · `--current` | Ciclar, selector, listar, ver el actual |
| `target` | Menú del Target HUD (= Super+i) |
| `vpnmenu` | Menú de VPN (= Super+v) |
| `tools` | Launcher de tools (= Super+p) |
| `~/.config/bspwm/scripts/wallpaper.sh [--random\|archivo]` | Cambiar wallpaper desde la terminal |
| `~/.config/bspwm/scripts/keys-help.sh --text` | Esta lista en texto plano |
| `ll` · `tree` · `cat` | `lsd` / `bat` con colores |
| `p10k configure` | Personalizar el prompt |

## Scratchpad (Super + u) — hasta 4 terminales

Dentro del scratchpad hay una sesión tmux propia (`~/.config/autobspwn/scratch.tmux.conf`, servidor aparte: no usa ni toca tu `~/.tmux.conf`). Abajo se ven las terminales abiertas como pestañas (número + nombre, la activa resaltada) y el contador `n/4`.

| Atajo | Acción |
|---|---|
| `` Alt + 1 `` … `` Alt + 4 `` | Ir a la terminal 1–4 |
| `` Alt + ← `` / `` Alt + → `` | Terminal anterior / siguiente |
| `` Alt + h `` / `` Alt + l `` | Terminal anterior / siguiente |
| `` Alt + n `` | Nueva terminal (en el mismo directorio); si ya hay 4 muestra «máx 4 terminales» y no crea otra |
| `` Alt + w `` | Cerrar la terminal actual (la última se cierra con `exit`) |
| `` Ctrl + b `` … | tmux normal (`Ctrl+b c` también respeta el máximo de 4) |

## kitty (terminal)

| Atajo | Acción |
|---|---|
| `` Ctrl + Shift + Enter `` | Dividir la terminal (en el directorio actual) |
| `` Ctrl + Alt + \ `` / `` Ctrl + Alt + - `` | Dividir en vertical / en horizontal |
| `` Ctrl + Alt + ← ↓ ↑ → `` | Moverse entre divisiones |
| `` Ctrl + Shift + z `` | Maximizar / restaurar la división actual |
| `` Ctrl + Shift + l `` | Siguiente layout (splits, stack, tall, grid) |
| `` Ctrl + Shift + r `` | Redimensionar divisiones |
| `` Ctrl + Shift + w `` | Cerrar la división actual |
| `` Ctrl + Shift + t `` | Nueva pestaña (mismo directorio) |
| `` Ctrl + Shift + ← / → `` | Pestaña anterior / siguiente |
| `` Ctrl + Shift + Alt + t `` | Renombrar pestaña |
| `` Ctrl + Shift + c `` / `` Ctrl + Shift + v `` | Copiar / pegar |
| `` Ctrl + Shift + = `` / `` Ctrl + Shift + - `` | Zoom + / − |
