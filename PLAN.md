# PLAN — claude-statusline

Statusline para Claude Code que cualquier dev pueda instalar **en un comando**,
usar **sin configurar**, y personalizar **editando un archivo**.

---

## 1. Objetivo y diferenciación

Apuntamos al hueco que dejan los 4 proyectos analizados (ver tabla en
`README.md` / mensaje del autor):

- Más configurable que `nilbuild/claude-statusline` (que es "personal use").
- Más liviano y simple que `sirmalloc/ccstatusline` en el render path (sin Node en cada render; la TUI futura corre solo para configurar).
- Más fácil de instalar que `felipeelias/claude-statusline` (sin compilar Go ni brew obligatorio).
- Con valores por defecto y presets, a diferencia del approach DIY de los docs oficiales.

**Slogan interno:** *"git clone → un comando → ya tenés statusline. Editá un JSON si querés más."*

---

## 2. Principios de diseño

1. **Zero-config first.** Después de instalar, funciona con datos útiles sin tocar nada.
2. **Un solo comando para instalar.** `curl | bash` (o `npx`) y listo.
3. **Sin runtime pesado.** El script de render es Bash + `jq`. Nada de levantar Node/Go en cada update (el statusline corre potencialmente cada pocos segundos).
4. **TUI por defecto, archivo siempre editable.** Cuando exista la TUI, será el flujo recomendado para configurar presets, módulos y colores. Aun así, siempre debe crear y persistir `~/.config/claude-statusline/config.json` como fuente de verdad versionable, copiable entre máquinas y editable manualmente después.
5. **Multi-línea de fábrica.** Es una de las features más útiles de Claude Code y la mitad de los competidores no la soportan.
6. **Instalación segura e idempotente.** Backup de `settings.json`, merge con `jq`, uninstall que restaura.
7. **Progresivo:** preset → tweaks de módulos → módulos custom (comando shell).

---

## 3. Stack técnico

| Decisión | Elección | Razón |
|---|---|---|
| Lenguaje del script | **Bash** (POSIX donde se pueda) | Sin runtime extra, ubicuo, arranque inmediato. |
| Parser de input JSON | **`jq`** | Único dep externo, ya estándar entre devs. |
| Formato de config | **JSON** | `jq` ya está como dep → cero parsers nuevos. Familiar para devs. |
| Distribución | **`curl \| bash` + Homebrew tap + npx wrapper opcional** | Cubre macOS, Linux y Windows (WSL). |
| Modificación de `settings.json` | **`jq` con `--argjson` + escritura atómica** | Merge seguro sin pisar otras keys. |
| Detección de capacidades de color | `$COLORTERM`, `$TERM`, `$NO_COLOR` | Estándar. |

**Dependencias del usuario:** `bash`, `jq`. El instalador detecta y ofrece instalarlas (`brew`, `apt`, `dnf`, `pacman`).

### 3.1 Soporte por plataforma

| Plataforma | Estado | Notas |
|---|---|---|
| macOS | Soportado actualmente | Instalación principal vía `curl | bash`; Homebrew tap en roadmap. |
| Linux | Soportado actualmente | Instalación principal vía `curl | bash`; `jq` vía `apt`, `dnf` o `pacman`. |
| Windows (WSL) | Planeado | Documentar WSL como el camino recomendado para usuarios Windows antes del soporte nativo. |
| Windows nativo | Planeado | Wrapper `npx` cross-platform y port a PowerShell en v0.4+. |

---

## 4. Distribución e instalación

### Comando principal

```bash
curl -fsSL https://raw.githubusercontent.com/tenondecrpc/claude-statusline/main/install.sh | bash
```

Equivalentes:
- `brew install <tap>/claude-statusline` (futuro)
- `npx @<scope>/claude-statusline install` (wrapper liviano)

### Flujo del instalador (`install.sh`)

1. Detectar `jq`. Si falta → ofrecer instalarlo (`brew`/`apt`/`dnf`) o abortar con instrucciones claras.
2. Crear `~/.local/share/claude-statusline/` y copiar `statusline.sh` + `lib/`.
3. Crear `~/.config/claude-statusline/config.json` **solo si no existe** (default preset).
4. **Detectar statusline pre-existente** en `~/.claude/settings.json` (ver §4.1).
5. Backup de `~/.claude/settings.json` → `~/.claude/settings.json.bak.<timestamp>`.
6. Merge con `jq` solo si el usuario lo confirma (o ya estaba seteado por nosotros):
   ```bash
   jq '.statusLine = {
     "type": "command",
     "command": "~/.local/share/claude-statusline/statusline.sh",
     "padding": 1
   }' settings.json > settings.json.tmp && mv settings.json.tmp settings.json
   ```
7. Imprimir resumen: dónde quedó la config, cómo cambiar de preset, cómo desinstalar.

### 4.1 Manejo de un `statusLine` ya configurado

Antes de tocar `~/.claude/settings.json`, el instalador clasifica el estado actual y actúa distinto según el caso:

| Caso | Cómo se detecta | Acción por defecto |
|---|---|---|
| **A. No hay `statusLine`** | `jq -e '.statusLine' settings.json` falla | Instalación limpia, sin prompts. |
| **B. Es nuestro** (reinstalación / upgrade) | El `command` apunta a `~/.local/share/claude-statusline/statusline.sh` **o** el script tiene el marker `# claude-statusline:vX.Y.Z` | Idempotente: actualiza el script, deja `config.json` intacto, no muta `settings.json` salvo cambio de path. Sin prompts. |
| **C. Es de otro proyecto conocido** | Match por path/comando: `npx ccstatusline*`, `claude-statusline prompt` (felipeelias), `~/.claude/statusline.sh` con header de nilbuild | Prompt interactivo: **Replace / Keep / Cancel**. Mostrar de qué herramienta viene (`"Detected: ccstatusline"`). |
| **D. Es un script custom del usuario** | Cualquier otro `command` | Prompt interactivo más cauto: imprime el `command` actual y los primeros 3 lines del script si es un archivo. **Replace / Keep / Cancel**, default = `Cancel`. |
| **E. `settings.json` no existe o está vacío** | archivo ausente | Crear `~/.claude/settings.json` mínimo con solo `statusLine`. |

**Prompt unificado (casos C y D):**

```
Detected an existing statusLine in ~/.claude/settings.json:
  command: <comando actual>
  source : <ccstatusline | felipeelias | nilbuild | custom script | inline>

What do you want to do?
  [r] Replace it with claude-statusline (your current setup will be backed up)
  [k] Keep your current statusline and exit  (we'll still drop our script for manual use)
  [c] Cancel (no changes)

> 
```

**Backup en todos los casos C/D:**

- `~/.claude/settings.json` → `~/.claude/settings.json.bak.<timestamp>`
- Si el `command` apunta a un script local (ej. `~/.claude/statusline.sh`), también copiamos ese archivo a `~/.claude/statusline.sh.bak.<timestamp>` antes de cualquier cambio. Si el `command` es inline, lo guardamos como `~/.claude/statusline.previous.<timestamp>.txt` para poder mostrarlo en el uninstall.

**Marker de identificación.** Nuestro `statusline.sh` lleva siempre como segunda línea:

```bash
#!/usr/bin/env bash
# claude-statusline:vX.Y.Z https://github.com/tenondecrpc/claude-statusline
```

Esto hace que la detección del caso B sea robusta incluso si el usuario movió el script a otra ruta.

**Project-level override.** Si existe `<cwd>/.claude/settings.json` con un `statusLine` distinto, **no lo tocamos** y avisamos: *"Project-level statusLine in `./.claude/settings.json` will override the user-level one. Edit that file if you want claude-statusline to apply here."*

**Flags no interactivos** (para CI / dotfiles):

| Flag | Efecto |
|---|---|
| `--force` | Reemplaza siempre, sin prompt. Sigue haciendo backup. |
| `--keep-existing` | Si ya hay un `statusLine`, instala los archivos pero no toca `settings.json`. Sale con código 0. |
| `--abort-if-exists` | Si ya hay un `statusLine` (caso C o D), sale con código no-cero sin tocar nada. |
| `--dry-run` | Imprime el plan (qué iría a `settings.json`, qué backup haría) sin escribir. |

Default sin flags: prompt interactivo en C/D, idempotente en B, limpio en A/E.

### Flujo del desinstalador (`uninstall.sh`)

1. Si hay `.bak` de `settings.json` → restaurar el más reciente (preserva el statusline previo, sea de quien sea).
2. Si no, quitar la key `statusLine` con `jq 'del(.statusLine)'`.
3. Si existe `~/.claude/statusline.sh.bak.<timestamp>` → ofrecer restaurarlo a `~/.claude/statusline.sh`.
4. Borrar `~/.local/share/claude-statusline/` (preguntar antes de borrar `~/.config/claude-statusline/config.json`).
5. Flags: `--purge` (borra config sin preguntar), `--keep-backups` (no borra los `.bak`).

---

## 5. Modelo de configuración

`~/.config/claude-statusline/config.json`:

```json
{
  "preset": "developer",
  "separator": " | ",
  "lines": [
    ["model", "directory", "git"],
    ["context_bar", "cost", "rate_limit"]
  ],
  "modules": {
    "directory": { "truncate": 30, "tilde": true },
    "git":       { "show_status": true, "show_ahead_behind": true },
    "context_bar": { "width": 20, "thresholds_pct": [50, 80] },
    "cost":      { "format": "$%.2f", "hide_below": 0.01 },
    "rate_limit":{ "show": ["five_hour", "seven_day"] }
  },
  "colors": {
    "model": "cyan",
    "git_clean": "green",
    "git_dirty": "yellow",
    "context_warn": "yellow",
    "context_crit": "red"
  }
}
```

**Reglas:**
- Si `preset` está seteado, los campos siguientes lo sobrescriben módulo a módulo (estilo Starship/felipeelias).
- `lines` es una array de arrays → cada subarray es una línea. Una sola línea = `[[...]]`.
- Si una key no existe, se usa el default del preset cargado.

---

## 6. Módulos (MVP)

| Módulo | Datos del JSON de Claude Code | Notas |
|---|---|---|
| `model` | `model.display_name` | Acepta `short` para acortar. |
| `directory` | `workspace.current_dir` | Tilde-collapse + trunc. |
| `git` | (ejecuta `git`) | Branch + counts (staged/unstaged/untracked) + ahead/behind. |
| `context_bar` | `context_window.used_percentage` | Barra default de N chars + %. |
| `context_pct` | idem | Solo el %. |
| `cost` | `cost.total_cost_usd` | Hide-when-zero opcional. |
| `rate_limit` | `rate_limits.five_hour.*`, `seven_day.*` | Skip si ausente (no-Pro). |
| `session_timer` | `cost.total_duration_ms` | Formato `1h23m`. |
| `lines_changed` | `cost.total_lines_added/removed` | `+12 -3`. |
| `vim_mode` | `vim.mode` | Solo si presente. |
| `worktree` | `worktree.name`/`branch` | Solo si presente. |
| `agent` | `agent.name` | Solo si presente. |
| `custom` | shell command | Ejecuta y mete stdout (con timeout). |

Todos los módulos respetan **hide-when-empty** y **timeout** para no colgar el statusline.

---

## 7. Presets (MVP)

| Preset | Layout | Para quién |
|---|---|---|
| `minimal` | una línea: `model · dir · branch` | quien quiere lo mínimo |
| `default` | una línea: `model | dir | git | context% | cost` | uso general |
| `developer` | dos líneas: `[model, dir, git]` / `[context_bar, cost, rate_limit]` | trabajo serio |
| `powerline` | una línea con flechas Powerline (Nerd Font) | con terminal copada |

Todos guardados como JSON en `presets/` y embedded en el script.

---

## 8. Estructura del repo

```
claude-statusline/
├── README.md                  # quickstart + screenshot + tabla de presets
├── PLAN.md                    # este archivo
├── LICENSE                    # MIT
├── install.sh                 # instalador one-liner
├── uninstall.sh               # desinstalador
├── statusline.sh              # entrypoint: lee stdin, dispatcher
├── lib/
│   ├── modules.sh             # implementación de cada módulo
│   ├── git.sh                 # helpers de git
│   ├── colors.sh              # ANSI + detección de capacidades
│   ├── render.sh              # ensamblado de líneas, separadores
│   └── config.sh              # carga y merge de config + preset
├── presets/
│   ├── minimal.json
│   ├── default.json
│   ├── developer.json
│   └── powerline.json
├── tests/
│   ├── fixtures/              # JSONs de muestra (con/sin worktree, sin rate_limits, etc.)
│   ├── snapshots/             # output esperado (sin ANSI)
│   └── test.bats              # bats-core
├── docs/
│   ├── modules.md
│   ├── customizing.md
│   └── troubleshooting.md
└── .github/workflows/
    └── ci.yml                 # macOS + Ubuntu, varias versiones de jq
```

---

## 9. Testing

- **Fixtures**: 1 JSON por escenario (`min.json`, `with_worktree.json`, `no_rate_limits.json`, `vim.json`, `cost_high.json`, etc.).
- **Snapshots**: correr `statusline.sh < fixture.json | strip-ansi > out.txt` y comparar con `expected.txt`.
- **`bats`** para tests unitarios de funciones de `lib/`.
- **CI** en macOS y Ubuntu con `jq` 1.6 y 1.7.
- Test del instalador: copia `settings.json` falso, corre `install.sh` y verifica el merge con `jq`.

---

## 10. Roadmap

### v0.1 — MVP
- [ ] `statusline.sh` + módulos: `model`, `directory`, `git`, `context_bar`, `cost`, `rate_limit`.
- [ ] Multi-línea.
- [ ] Presets `minimal`, `default`, `developer`.
- [ ] `install.sh` con backup y merge con `jq`.
- [ ] `uninstall.sh` con restore.
- [ ] README con screenshot + tabla de presets.
- [ ] CI con tests de snapshot.

### v0.2 — UX y polish
- [ ] Preset `powerline` con detección de Nerd Font + fallback.
- [ ] OSC 8 (branches y dirs clickeables).
- [ ] Módulos `worktree`, `vim_mode`, `session_timer`, `lines_changed`.
- [ ] Subcomandos: `claude-statusline test` (mock data) y `claude-statusline themes`.
- [ ] Homebrew tap.

### v0.3 — Extensibilidad
- [ ] Módulo `custom` con timeout y caching.
- [ ] Plugin folder: `~/.config/claude-statusline/modules/<name>.sh`.
- [ ] Truncado inteligente cuando la terminal es angosta.

### v0.4+
- [ ] Wrapper `npx @<scope>/claude-statusline` para Windows/cross-platform.
- [ ] Port a PowerShell para Windows nativo.
- [ ] Theme builder: comando que genera un preset interactivo.
- [ ] TUI tipo `ccstatusline` como flujo de configuración por defecto para presets, módulos, colores y preview; la decisión UX para usuarios no técnicos es **editar archivo < clicar menúes**, pero la TUI debe crear y guardar todo en `config.json` para permitir edición manual posterior.

---

## 11. No-objetivos (lo que **no** vamos a hacer)

- TUI en el path de render, daemon residente, o configuración opaca que no pueda editarse a mano. La TUI puede ser el flujo por defecto, pero debe correr fuera del render y persistir todo en `config.json`.
- Reimplementar tracking de tokens (usamos lo que Claude Code mete en stdin).
- Soportar features que requieran levantar un daemon o servidor.
- Telemetría / analytics de cualquier tipo.
- Soporte oficial pre-1.0 para terminales sin ANSI (Windows cmd.exe sin ANSI).

---

## 12. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| `jq` no instalado | Detección + instrucciones por SO en el instalador. |
| `settings.json` ya tiene un `statusLine` distinto | Backup con timestamp antes de tocar. |
| Render lento por `git status` en repos grandes | Cache por proceso + flags livianas (`git status --porcelain=v1 -uno` por defecto). |
| Cambia el JSON de Claude Code | Tests con fixtures fijos + manejo de campos ausentes con `// empty`. |
| Devs en Windows | Documentar WSL como path principal; PowerShell port en roadmap. |

---

## 13. Métricas de éxito

- Instalar desde cero a statusline visible en **< 30 segundos**.
- Cambiar a otro preset en **< 10 segundos** (editar un campo).
- Tiempo de render del statusline **< 50 ms** en repos típicos.
- README leído de arriba a abajo por un dev nuevo en **< 3 minutos** y que ya sepa cómo personalizar.
