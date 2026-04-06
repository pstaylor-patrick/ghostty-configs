# Ghostty Theme Switcher
# Applies Loom Homebrew as the default theme on every new tab.
# T1–T4 aliases allow explicit switching to other preset themes.
# Source this file from ~/.zshrc.

# Preset themes: T1 is the default, T2–T4 available on demand
GHOSTTY_THEMES=(
  "Loom Homebrew"
  "Loom PowerShell"
  "Loom Charcoal Light"
  "Loom Solarized Light"
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

# Apply default theme (T1) on every new tab
ghostty_apply_default() {
  ghostty_apply_theme "${GHOSTTY_THEMES[1]}"
}

# T1–T4: quick-switch aliases for each preset theme
T1() { ghostty_apply_theme "${GHOSTTY_THEMES[1]}"; }
T2() { ghostty_apply_theme "${GHOSTTY_THEMES[2]}"; }
T3() { ghostty_apply_theme "${GHOSTTY_THEMES[3]}"; }
T4() { ghostty_apply_theme "${GHOSTTY_THEMES[4]}"; }

ghostty_apply_default
