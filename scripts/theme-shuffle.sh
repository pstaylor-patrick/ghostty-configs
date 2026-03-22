# Ghostty Curated Theme Cycler
# Cycles deterministically through 5 WCAG AA-compliant themes, one per new tab.
# Uses an index file to track position in the rotation.
# Source this file from ~/.zshrc.

ghostty_theme_cycle() {
  [ "$TERM_PROGRAM" = "ghostty" ] || return 0

  # Curated theme rotation: 4 light, 1 dark
  local -a theme_names=(
    "Loom Light Blue"
    "Loom Warm Cream"
    "Loom Sage"
    "Loom Lavender"
    "Loom Dark"
  )

  local index_file="$HOME/.config/ghostty/.theme-index"
  local custom_dir="$HOME/.config/ghostty/themes"
  local count=${#theme_names[@]}

  # Read current index (0-based), default to 0
  local idx=0
  if [[ -f "$index_file" ]]; then
    idx=$(cat "$index_file" 2>/dev/null)
    # Validate it's a number in range
    if ! [[ "$idx" =~ ^[0-9]+$ ]] || [[ $idx -ge $count ]]; then
      idx=0
    fi
  fi

  local theme_name="${theme_names[$((idx + 1))]}"  # zsh arrays are 1-based
  local theme_file="$custom_dir/$theme_name"

  # Write next index atomically
  local next_idx=$(( (idx + 1) % count ))
  echo "$next_idx" > "$index_file"

  # Bail if theme file is missing
  if [[ ! -f "$theme_file" ]]; then
    printf '\e[2m░ theme not found: %s\e[0m\n' "$theme_name"
    return 1
  fi

  # Parse and apply via OSC escape sequences
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

  # Subtle theme name display
  printf '\e[2m░ %s\e[0m\n' "$theme_name"
}

ghostty_theme_cycle
