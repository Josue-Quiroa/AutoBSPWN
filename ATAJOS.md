<!-- autobspwn-atajos v3.0.0 — generado con: ~/.config/bspwm/scripts/keys-help.sh --markdown -->
# AutoBSPWN 3.0.0 — Atajos y comandos

**Super** = tecla Windows. Esta misma lista sale en pantalla con **Super + F1** o **Super + /**
(puedes escribir para filtrar y Enter ejecuta la acción). Se genera leyendo
`~/.config/sxhkd/sxhkdrc`, así que si agregas un atajo con un comentario `# descripción`
encima, aparece solo.

Notas:
- `{a,b,c}` significa “una de estas teclas”, p. ej. `Super + {1-9,0}` = Super+1 … Super+0.
- Las flechas y `h j k l` (estilo vim) hacen lo mismo.
- **Ratón**: Super + clic izquierdo arrastra una ventana, Super + clic derecho la redimensiona.
- **Polybar**: clic en el reloj = calendario · clic en el icono de la izquierda = apps
  (derecho: info del sistema) · rueda sobre el icono de paleta = cambiar tema
  (clic derecho: wallpapers) · clic en target/VPN/IP = copiar/menú.

### Terminal y apps

| Atajo | Acción |
|---|---|
| `` Super + Enter `` | Terminal (kitty) |
| `` Super + Shift + Enter `` | Terminal flotante |
| `` Super + u `` | Scratchpad: terminal desplegable con tmux |
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
| `` Super + v `` | VPN / lab switcher |
| `` Super + Shift + v `` | Reconectar la última VPN |
| `` Super + p `` | Launcher de tools de pentest |
| `` Super + c `` | Historial del portapapeles |

### Apariencia

| Atajo | Acción |
|---|---|
| `` Super + w `` | Selector de wallpapers con vista previa |
| `` Super + Shift + w `` | Wallpaper aleatorio |
| `` Super + Shift + t `` | Siguiente tema (amethyst → mocha → macchiato → hacker) |
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
| `` Super + s `` | Modo flotante |
| `` Super + Shift + Space `` | Alternar flotante / mosaico |
| `` Super + Shift + s `` | Modo pseudo-tiled |
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
| `` Super + Alt + {Left,Down,Up,Right} `` | Redimensionar inteligente (crece hacia la flecha o encoge) |
| `` Super + Alt + {h,j,k,l} `` | Redimensionar inteligente (vim) |
| `` Super + Alt + {p,b,coma,punto} `` | Foco al nodo padre / hermano / primer hijo / segundo hijo |
| `` Super + ` `` | Volver a la ventana anterior |
| `` Super + {o,Shift + o} `` | Ventana más antigua / más reciente del historial |

### Escritorios

| Atajo | Acción |
|---|---|
| `` Super + {1-9,0} `` | Ir al escritorio 1-10 |
| `` Super + Shift + {1-9,0} `` | Enviar la ventana al escritorio 1-10 (y seguirla) |
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
| `` Super + Alt + c `` | Calendario |
| `` Super + Shift + m `` | Menú del escritorio (también clic derecho sobre el fondo) |
| `` Click derecho (escritorio) `` | Menú contextual al hacer clic derecho sobre el fondo |
| `` Super + Shift + x `` | Bloquear pantalla |
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
| `` Super + clic izquierdo `` (arrastrar) | Mover ventana (la vuelve flotante) |
| `` Super + clic derecho `` (arrastrar) | Redimensionar ventana |
| Clic derecho sobre el fondo | Menú del escritorio (jgmenu) |
| Clic en el reloj | Calendario (yad) |

## Comandos de terminal (zsh)

| Comando | Qué hace |
|---|---|
| `setFocus 10.10.11.25 [nombre]` | Fija el target: aparece en la barra (Target HUD) y en `~/targets/<ip>` |
| `clearFocus` | Quita el target (el historial se conserva en Super+i) |
| `focusip` | Muestra el target actual |
| `tgt` | `cd ~/targets/<ip del target>` (crea `nmap/ loot/ exploits/`) |
| `mkt <nombre>` | Crea y entra en `~/Machines/<nombre>/{nmap,content,exploits,scripts,loot}` |
| `ports archivo.nmap` | Lista los puertos abiertos separados por coma (para `nmap -p`) |
| `extractHosts [archivo]` | Extrae las IPs únicas de un archivo o de la entrada estándar |
| `theme-sync <tema>` / `theme <tema>` | Cambia el tema: `amethyst`, `mocha`, `macchiato`, `hacker` |
| `theme-sync --next` · `--menu` · `--list` · `--current` | Ciclar, selector, listar, ver el actual |
| `target` | Menú del Target HUD (= Super+i) |
| `vpnmenu` | Menú de VPN (= Super+v) |
| `tools` | Launcher de tools (= Super+p) |
| `~/.config/bspwm/scripts/wallpaper.sh [--random\|archivo]` | Cambiar wallpaper desde la terminal |
| `~/.config/bspwm/scripts/keys-help.sh --text` | Esta lista en texto plano |
| `ll` · `tree` · `cat` | `lsd` / `bat` con colores |
| `p10k configure` | Personalizar el prompt |

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
