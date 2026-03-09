# Ghostty Contrast-Aware Theme Shuffler
# Applies a random color theme via OSC escape sequences per terminal session.
# Uses a shared history file + RGB distance check to avoid visually similar
# consecutive themes across tabs.
# Source this file from ~/.zshrc — it defines and immediately invokes the function.

# --- Helper functions (prefixed _gts_ to avoid namespace pollution) ---

# Parse #hex to integers; sets GTS_R, GTS_G, GTS_B (no subshell)
_gts_hex_to_rgb() {
  local hex="${1#\#}"
  # Expand 3-digit hex: #abc → aabbcc
  if [[ ${#hex} -eq 3 ]]; then
    hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}"
  fi
  GTS_R=$(( 16#${hex:0:2} ))
  GTS_G=$(( 16#${hex:2:2} ))
  GTS_B=$(( 16#${hex:4:2} ))
}

# Euclidean distance² between two hex colors; sets GTS_DIST_SQ
_gts_color_distance_sq() {
  local r1 g1 b1 r2 g2 b2
  _gts_hex_to_rgb "$1"; r1=$GTS_R; g1=$GTS_G; b1=$GTS_B
  _gts_hex_to_rgb "$2"; r2=$GTS_R; g2=$GTS_G; b2=$GTS_B
  local dr=$(( r1 - r2 ))
  local dg=$(( g1 - g2 ))
  local db=$(( b1 - b2 ))
  GTS_DIST_SQ=$(( dr*dr + dg*dg + db*db ))
}

# Check if a hex color is perceptually light; sets GTS_LUMINANCE
_gts_is_light_bg() {
  _gts_hex_to_rgb "$1"
  GTS_LUMINANCE=$(( (2126 * GTS_R + 7152 * GTS_G + 722 * GTS_B) / 10000 ))
  [[ $GTS_LUMINANCE -gt 150 ]]
}

# Extract background hex from a theme file (fast, single-line)
_gts_extract_bg() {
  grep -m1 '^background' "$1" 2>/dev/null | sed 's/.*= *//'
}

# Candidate selection with contrast awareness; sets GTS_SELECTED
_gts_select_theme() {
  local -a theme_files=("$@")
  local count=${#theme_files[@]}
  local history_file="$HOME/.config/ghostty/.theme-history"
  local threshold=1500
  local last_bg=""

  # Read last entry's background hex from history
  if [[ -f "$history_file" ]]; then
    local last_line
    last_line="$(tail -n1 "$history_file")"
    last_bg="${last_line#*|}"
  fi

  # Load recent theme names into associative array for O(1) dedup
  typeset -A recent_names
  if [[ -f "$history_file" ]]; then
    while IFS='|' read -r name _hex; do
      recent_names[$name]=1
    done < "$history_file"
  fi

  # Phase 1: Up to 50 random candidates — check distance + dedup
  local i candidate_file candidate_bg
  for (( i=0; i<50; i++ )); do
    candidate_file="${theme_files[$(( RANDOM % count ))]}"
    local candidate_name
    candidate_name="$(basename "$candidate_file")"
    # Skip recently used themes
    [[ -n "${recent_names[$candidate_name]+_}" ]] && continue

    candidate_bg="$(_gts_extract_bg "$candidate_file")"
    [[ -z "$candidate_bg" ]] && continue

    # If no history yet, accept anything
    if [[ -z "$last_bg" ]]; then
      GTS_SELECTED="$candidate_file"
      return 0
    fi

    _gts_color_distance_sq "$candidate_bg" "$last_bg"
    if [[ $GTS_DIST_SQ -ge $threshold ]]; then
      GTS_SELECTED="$candidate_file"
      return 0
    fi
  done

  # Phase 2: Fisher-Yates shuffle indices, pick first not in recent 20
  local -a indices
  for (( i=0; i<count; i++ )); do
    indices+=("$i")
  done
  # Partial Fisher-Yates (shuffle enough to find one)
  local j tmp
  for (( i=count-1; i>0; i-- )); do
    j=$(( RANDOM % (i+1) ))
    tmp=${indices[$i]}
    indices[$i]=${indices[$j]}
    indices[$j]=$tmp

    candidate_file="${theme_files[${indices[$i]}]}"
    local candidate_name
    candidate_name="$(basename "$candidate_file")"
    if [[ -z "${recent_names[$candidate_name]+_}" ]]; then
      GTS_SELECTED="$candidate_file"
      return 0
    fi
  done

  # Phase 3: Ultimate fallback — pure random
  GTS_SELECTED="${theme_files[$(( RANDOM % count ))]}"
}

# Atomic FIFO append to history file with mkdir-based locking
_gts_history_push() {
  local name="$1" bg="$2"
  local history_file="$HOME/.config/ghostty/.theme-history"
  local lock_dir="$HOME/.config/ghostty/.theme-history.lock"

  # Acquire lock (stale detection after 5s)
  local attempts=0
  while ! mkdir "$lock_dir" 2>/dev/null; do
    if [[ -d "$lock_dir" ]]; then
      local lock_age
      lock_age=$(( $(date +%s) - $(stat -f %m "$lock_dir" 2>/dev/null || echo 0) ))
      if [[ $lock_age -gt 5 ]]; then
        rmdir "$lock_dir" 2>/dev/null
      fi
    fi
    (( attempts++ ))
    [[ $attempts -ge 10 ]] && return 1  # Give up after ~1s
    sleep 0.1
  done

  # Write atomically: tail existing + append new → temp → mv
  local tmp
  tmp="$(mktemp)"
  if [[ -f "$history_file" ]]; then
    tail -n 39 "$history_file" > "$tmp"
  fi
  echo "${name}|${bg}" >> "$tmp"
  mv "$tmp" "$history_file"

  rmdir "$lock_dir" 2>/dev/null
}

# --- Main function ---

ghostty_theme_shuffle() {
  [ "$TERM_PROGRAM" = "ghostty" ] || return 0

  # Collect theme files from built-in and custom directories
  local builtin_dir="/Applications/Ghostty.app/Contents/Resources/ghostty/themes"
  local custom_dir="$HOME/.config/ghostty/themes"
  local themes=()

  if [ -d "$builtin_dir" ]; then
    while IFS= read -r -d '' f; do
      themes+=("$f")
    done < <(find "$builtin_dir" -maxdepth 1 -type f -print0)
  fi

  if [ -d "$custom_dir" ]; then
    while IFS= read -r -d '' f; do
      themes+=("$f")
    done < <(find "$custom_dir" -maxdepth 1 -type f -print0)
  fi

  local count=${#themes[@]}
  [ "$count" -eq 0 ] && return 0

  # Select a contrast-aware theme
  _gts_select_theme "${themes[@]}"
  local theme_file="$GTS_SELECTED"
  local theme_name
  theme_name="$(basename "$theme_file")"

  # Parse and apply via OSC sequences
  local applied_bg=""
  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    # Split on '=' and trim whitespace
    local key="${line%%=*}"
    local val="${line#*=}"
    key="${key// /}"
    val="${val// /}"

    case "$key" in
      background)       printf '\e]11;%s\e\\' "$val"; applied_bg="$val" ;;
      foreground)       printf '\e]10;%s\e\\' "$val"; applied_fg="$val" ;;
      cursor-color)     printf '\e]12;%s\e\\' "$val" ;;
      palette)
        # palette value is N=#hex
        local n="${val%%#*}"
        n="${n//=/}"
        local hex="#${val#*#}"
        printf '\e]4;%s;%s\e\\' "$n" "$hex"
        ;;
    esac
  done < "$theme_file"

  # Ensure foreground has enough contrast on light backgrounds
  if [[ -n "$applied_bg" ]] && _gts_is_light_bg "$applied_bg"; then
    local applied_fg="${applied_fg:-#ffffff}"
    _gts_hex_to_rgb "$applied_fg"
    local fg_lum=$(( (2126 * GTS_R + 7152 * GTS_G + 722 * GTS_B) / 10000 ))
    if [[ $fg_lum -gt 140 ]]; then
      printf '\e]10;%s\e\\' "#333333"
    fi
  fi

  # Push to history for future contrast checks
  [[ -n "$applied_bg" ]] && _gts_history_push "$theme_name" "$applied_bg"

  # Subtle theme name display
  printf '\e[2m░ theme: %s\e[0m\n' "$theme_name"
}

ghostty_theme_shuffle
