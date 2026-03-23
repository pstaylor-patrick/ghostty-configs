# Ghostty Curated Theme Cycler
# Cycles deterministically through 5 WCAG AA-compliant themes, one per new tab.
# Uses an index file to track position in the rotation.
# Source this file from ~/.zshrc.

# Curated theme rotation: 1 light, 4 dark — all WCAG AA compliant
GHOSTTY_THEMES=(
  "Loom PowerShell"
  "Loom Amber CRT"
  "Loom Solarized Light"
  "Loom Dracula"
  "Loom Homebrew"
)

# Apply a theme by name via OSC escape sequences
ghostty_apply_theme() {
  [ "$TERM_PROGRAM" = "ghostty" ] || return 0

  local theme_name="$1"
  local theme_file="$HOME/.config/ghostty/themes/$theme_name"

  if [[ ! -f "$theme_file" ]]; then
    printf '\e[2m░ theme not found: %s\e[0m\n' "$theme_name"
    return 1
  fi

  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    local key="${line%%=*}"
    local val="${line#*=}"
    key="${key// /}"
    val="${val// /}"

    case "$key" in
      background)       printf '\e]11;%s\e\\' "$val" ;;
      foreground)       printf '\e]10;%s\e\\' "$val" ;;
      cursor-color)     printf '\e]12;%s\e\\' "$val" ;;
      palette)
        local n="${val%%#*}"
        n="${n//=/}"
        local hex="#${val#*#}"
        printf '\e]4;%s;%s\e\\' "$n" "$hex"
        ;;
    esac
  done < "$theme_file"

  printf '\e[2m░ %s\e[0m\n' "$theme_name"
}

# Cycle through themes on new tab
ghostty_theme_cycle() {
  [ "$TERM_PROGRAM" = "ghostty" ] || return 0

  local index_file="$HOME/.config/ghostty/.theme-index"
  local count=${#GHOSTTY_THEMES[@]}

  local idx=0
  if [[ -f "$index_file" ]]; then
    idx=$(cat "$index_file" 2>/dev/null)
    if ! [[ "$idx" =~ ^[0-9]+$ ]] || [[ $idx -ge $count ]]; then
      idx=0
    fi
  fi

  local theme_name="${GHOSTTY_THEMES[$((idx + 1))]}"  # zsh arrays are 1-based

  # Write next index atomically
  local next_idx=$(( (idx + 1) % count ))
  echo "$next_idx" > "$index_file"

  ghostty_apply_theme "$theme_name"
}

# T1–T5: quick-switch aliases for each preset theme
T1() { ghostty_apply_theme "${GHOSTTY_THEMES[1]}"; }
T2() { ghostty_apply_theme "${GHOSTTY_THEMES[2]}"; }
T3() { ghostty_apply_theme "${GHOSTTY_THEMES[3]}"; }
T4() { ghostty_apply_theme "${GHOSTTY_THEMES[4]}"; }
T5() { ghostty_apply_theme "${GHOSTTY_THEMES[5]}"; }

ghostty_theme_cycle
