export CLI_OUTPUT=SUCCESS

# =====================================================================
# Output filtering via $CLI_OUTPUT (case-insensitive)
# Categories: success | warning | error | info
# Presets: ALL (default) | NONE
#
# Examples:
#   export CLI_OUTPUT=warning|success
#   export CLI_OUTPUT="ERROR, SUCCESS"
#   export CLI_OUTPUT="success error"     # space-separated
#   export CLI_OUTPUT=NONE                # only final completed message
#   export CLI_OUTPUT=ALL                 # show everything

__cli_out_raw="${CLI_OUTPUT:-}"
__cli_out_norm="$(printf '%s' "$__cli_out_raw" | tr '[:upper:]' '[:lower:]')"

# Split by | , or whitespace into an array of tokens
# Shell-safe tokenizer: translate separators to spaces, then read into array.
__cli_tokens=()
if [ -n "$__cli_out_norm" ]; then
  __cli_out_seps="$(printf '%s' "$__cli_out_norm" | tr ',|' '  ')"
  # trim extra spaces
  # shellcheck disable=SC2086
  set -- $__cli_out_seps
  for t in "$@"; do
    [ -n "$t" ] && __cli_tokens+=("$t")
  done
fi

# Resolve preset: default ALL unless explicitly NONE or ALL provided,
# but if specific categories are given, switch to CUSTOM.
__cli_preset="all"
for t in "${__cli_tokens[@]}"; do
  case "$t" in
    none) __cli_preset="none" ;;
    all)  __cli_preset="all"  ;;
  esac
done

# Build an allow-list set only when not NONE
# We use a simple "contains" function against a normalized list
__cli_allow_list=""
if [ "$__cli_preset" = "none" ]; then
  __cli_allow_list=""         # nothing allowed
else
  # If tokens include specific categories, use them; otherwise ALL
  __has_specific=0
  for t in "${__cli_tokens[@]}"; do
    case "$t" in
      success|warning|error|info)
        __has_specific=1
        # de-duplicate
        case "$__cli_allow_list" in
          *" $t "* ) ;;                     # already present
          * ) __cli_allow_list="$__cli_allow_list $t " ;;
        esac
        ;;
    esac
  done

  if [ "$__has_specific" -eq 1 ]; then
    # Specific categories provided → CUSTOM preset
    __cli_preset="custom"
  else
    # No specific categories → ALL categories allowed
    __cli_allow_list=" success warning error info "
    __cli_preset="all"
  fi
fi

# Predicate: is a category enabled?
cli_enabled() {
  # $1: category name (success|warning|error|info)
  case "$__cli_preset" in
    none)   return 1 ;;  # nothing allowed
    all)    return 0 ;;  # everything allowed
    custom)
      case "$__cli_allow_list" in
        *" $1 "* ) return 0 ;;
        * )        return 1 ;;
      esac
      ;;
    *) return 0 ;;       # safety: treat unknown as ALL
  esac
}

# Log helpers: route messages through these instead of echo
# (Keep icons; warnings/errors go to stderr.)
cli_success()  { cli_enabled success && printf '✅ %b\n' "$*"; }
cli_warning()  { cli_enabled warning && printf '⚠️ %b\n' "$*" >&2; }
cli_error()    { cli_enabled error   && printf '🛑 %b\n' "$*" >&2; }
cli_info()     { cli_enabled info    && printf 'ℹ️  %b\n' "$*"; }
cli_blank()    { printf '%b\n' "$*"; }
cli_completed(){ printf '🧐 %s\n' "BashRC executed and Aliases added"; }  # single final line


# =====================================================================
# Add JRE location as environment variable
export EXE4J_JAVA_HOME="/c/laragon/bin/Java/jdk-25.0.1+8-jre/bin"


# =====================================================================
# Required basic aliases. Others added tot he .aliases file
add_alias la 'ls -ah'
add_alias ll 'ls -lah'
add_alias ls 'ls -F --color=auto --show-control-chars'


# =====================================================================
# Function definitions used by shell

# ---------------------------------------------------------------------
# Function to safely append to PATH

add_to_path() {
  local force=0
  local show_help=0
  local path=""
  for arg in "$@"; do
    case "$arg" in
      --force) force=1 ;;
      --help|-h) show_help=1 ;;
      *) path="$arg" ;;
    esac
  done

  if [ "$show_help" -eq 1 ] || [ -z "$path" ]; then
    cli_info "Usage: add_to_path [--force] <path>"
    cli_info " "
    cli_info "Adds <path> to the PATH environment variable."
    cli_info " "
    cli_info "Options:"
    cli_info "  --force  Add the path even if it does not exist."
    cli_info "  --help, -h  Show this help message."
    cli_info " "
    cli_info "Examples:"
    cli_info "  add_to_path ./vendor/bin"
    cli_info "  add_to_path --force ./vendor/bin"
    return 0
  fi

  if [ "$force" -eq 1 ] || [ -d "$path" ]; then
    PATH="$path:$PATH"
    cli_success "Added '$path' to PATH."
  else
    cli_warning "Warning: '$path' does not exist. Use --force to add it anyway."
  fi
}



# ---------------------------------------------------------------------
# Add_Alias function that adds aliases as well
# as verifying commands/folders exist before creating the alias
#
# Examples of how to use:
# 
# add_alias 'alias-edit' 'nano /c/Users/$USERNAME/.aliases'
# add_alias laragon 'cd /c/ProgramData/Laragon/'
# add_alias emqx-stop 'cd /c/Laragon/bin/mqtt/emqx/bin && emqx stop'
# add_alias makeapi 'artisan make:model -acs --api'


add_alias() {
  # Help option
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cli_info "Usage: add_alias [--force|-f] <alias_name> <alias_command>"
    cli_info " "
    cli_info "Options:"
    cli_info "  --force, -f  Force creation of alias even if command or path is invalid"
    cli_info "  --help, -h   Show this help message"
    cli_info " "
    cli_info "Examples:"
    cli_info "  add_alias cls 'clear'"
    cli_info "  add_alias laragon 'cd /c/ProgramData/Laragon/'"
    cli_info "  add_alias --force emqx-start 'cd /c/Laragon/bin/mqtt/emqx/bin && ./emqx foreground'"
    return 0
  fi

  local force=false
  local alias_name
  local alias_command

  # Check for --force or -f flag
  if [[ "$1" == "--force" || "$1" == "-f" ]]; then
    force=true
    alias_name="$2"
    alias_command="$3"
  else
    alias_name="$1"
    alias_command="$2"
  fi

  # Check if the command starts with 'cd'
  if [[ "$alias_command" =~ ^cd[[:space:]]+([^&]+) ]]; then
    local path="${BASH_REMATCH[1]}"
    eval path="$path"
    if [ ! -d "$path" ]; then
      if [ "$force" = false ]; then
        cli_error "Directory '$path' does not exist. Alias '$alias_name' not created."
        return 1
      else
        cli_warning "Directory '$path' not found. Alias '$alias_name' forced."
      fi
    fi
  fi

  # Check for executable in the command (e.g., './emqx', './mosquitto.exe')
  if [[ "$alias_command" =~ \&\&[[:space:]]+\./([a-zA-Z0-9._-]+) ]]; then
    local exec_file="${BASH_REMATCH[1]}"
    local exec_path="${path}/${exec_file}"
    if [ ! -x "$exec_path" ]; then
      if [ "$force" = false ]; then
        cli_error "Executable '$exec_file' not found or not executable at '$exec_path'. Alias '$alias_name' not created."
        return 1
      else
        cli_warning "Executable '$exec_file' not found. Alias '$alias_name' forced."
      fi
    fi
  else
    # Extract the first command word
    local cmd="${alias_command%% *}"
    if ! command -v "$cmd" &> /dev/null; then
      if [ "$force" = false ]; then
        cli_error "Command '$cmd' not found. Alias '$alias_name' not created."
        return 1
      else
        cli_warning "Command '$cmd' not found. Alias '$alias_name' forced."
      fi
    fi
  fi

  # Create the alias
  alias "$alias_name"="$alias_command"
  cli_success "Alias '$alias_name' created for: $alias_command"
}


# ---------------------------------------------------------------------
# Display paths in a folder as a tree

pathtree() {
  cli_blank " "
  local delimiter=":"
  local show_hidden=false

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --show-hidden) show_hidden=true ;;
      --delimiter=*) delimiter="${1#*=}" ;;
      *) cli_info "Usage: pathtree [--show-hidden] [--delimiter=CHAR]"; return 1 ;;
    esac
    shift
  done

  IFS="$delimiter" read -ra paths <<< "$PATH"

  # Build tree as a list of paths
  local tree=()
  for path in "${paths[@]}"; do
    IFS='/' read -ra parts <<< "$path"
    local current=""
    for part in "${parts[@]}"; do
      [[ -z "$part" ]] && continue
      [[ "$show_hidden" = false && "$part" == .* ]] && continue
      current="$current/$part"
      tree+=("$current")
    done
  done

  # Remove duplicates
  local unique_tree=()
  for item in "${tree[@]}"; do
    local found=false
    for existing in "${unique_tree[@]}"; do
      [[ "$item" == "$existing" ]] && found=true && break
    done
    [[ "$found" == false ]] && unique_tree+=("$item")
  done

  # Print tree
  for path in "${unique_tree[@]}"; do
    local indent=""
    IFS='/' read -ra parts <<< "$path"
    for ((i = 1; i < ${#parts[@]}; i++)); do
      indent+="|   "
    done
    cli_blank "${indent}+-- ${parts[-1]}"
  done
}


# ---------------------------------------------------------------------
# Locate latest version of Python and add to path

find_latest_python() {
    local META_FILE="$HOME/.python_version"
    local SEARCH_DIRS=("/c/Program Files" "/c/Program Files (x86)" "/c/Laragon/bin")
    local FORCE=false
    local SHOW=false
    local PERSIST=false
    local REMOVE=false

    cli_info " "
    cli_info "Searching for Python, and checking for latest version"
    cli_info " "
    cli_info "First run may take several minutes"
    # Parse flags
    for arg in "$@"; do
        case "$arg" in
            --force) FORCE=true ;;
            --show) SHOW=true ;;
            --set-persistent) PERSIST=true ;;
            --remove-persistent) REMOVE=true ;;
            --help)
                cli_info "Usage: find_latest_python [options]"
                cli_info "Options:"
                cli_info "  --force            Force rescan even if cached this month"
                cli_info "  --show             Show all detected Python versions and paths"
                cli_info "  --set-persistent   Add or update latest Python path in ~/.bashrc"
                cli_info "  --remove-persistent Remove any Python PATH entry from ~/.bashrc"
                cli_info "  --help             Show this help message"
                return 0
                ;;
        esac
    done

    # Handle remove persistent
    if [ "$REMOVE" = true ]; then
        _remove_bashrc
        return 0
    fi

    local TODAY=$(date +%Y-%m)
    local LAST_SCAN=""
    local LAST_VERSION=""
    local LAST_PATH=""

    if [ -f "$META_FILE" ]; then
        LAST_SCAN=$(awk -F= '/last_scan/{print $2}' "$META_FILE")
        LAST_VERSION=$(awk -F= '/version/{print $2}' "$META_FILE")
        LAST_PATH=$(awk -F= '/path/{print $2}' "$META_FILE")
    fi

    # Skip scan if same month and not forced
    if [ "$FORCE" = false ] && [ "$LAST_SCAN" == "$TODAY" ] && [ -n "$LAST_VERSION" ]; then
        cli_info "Using cached Python version: $LAST_VERSION"
        export PATH="$(dirname "$LAST_PATH"):$PATH"
        cli_success "Current Python: $(python --version)"
        if ! python -m pip --version &>/dev/null; then
            cli_error "pip is not installed for this Python."
        fi
        if [ "$PERSIST" = true ]; then
            _update_bashrc "$(dirname "$LAST_PATH")"
        fi
        return 0
    fi

    # Scan for python.exe, ignoring venv folders
    local PYTHON_PATHS=()
    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r path; do
                PYTHON_PATHS+=("$path")
            done < <(find "$dir" -type f -iname "python.exe" \
                     -not -path "*/venv/*" -not -path "*/.venv/*" 2>/dev/null)
        fi
    done

    if [ ${#PYTHON_PATHS[@]} -eq 0 ]; then
        cli_error "No Python installation found."
        return 1
    fi

    # Map versions to paths
    declare -A VERSION_MAP
    for path in "${PYTHON_PATHS[@]}"; do
        local version=$("$path" --version 2>&1 | awk '{print $2}')
        VERSION_MAP["$version"]="$path"
    done

    # Show all versions if requested
    if [ "$SHOW" = true ]; then
        cli_info "Detected Python installations:"
        for v in $(printf "%s\n" "${!VERSION_MAP[@]}" | sort -V); do
            cli_info "  $v -> ${VERSION_MAP[$v]}"
        done
    fi

    # Sort versions and pick latest
    local LATEST_VERSION=$(printf "%s\n" "${!VERSION_MAP[@]}" | sort -V | tail -n 1)
    local LATEST_PATH="${VERSION_MAP[$LATEST_VERSION]}"
    local PYTHON_DIR=$(dirname "$LATEST_PATH")

    # Update PATH
    export PATH="$PYTHON_DIR:$PATH"
    cli_success "Added Python $LATEST_VERSION from $PYTHON_DIR to PATH."
    cli_info "Current Python: $(python --version)"

    # Check pip
    if ! python -m pip --version &>/dev/null; then
        cli_error "pip is not installed for this Python."
    else
        cli_info "pip is available."
    fi

    # Save metadata
    cat > "$META_FILE" <<EOF
last_scan=$TODAY
version=$LATEST_VERSION
path=$LATEST_PATH
EOF

    # Persist if requested
    if [ "$PERSIST" = true ]; then
        _update_bashrc "$PYTHON_DIR"
    fi
}

# Helper: Update ~/.bashrc with latest Python path
_update_bashrc() {
    cli_info " "
    local PYTHON_DIR="$1"
    local BASHRC="$HOME/.bashrc"
    if grep -q "export PATH=.*python" "$BASHRC"; then
        sed -i "s|export PATH=.*python.*|export PATH=\"$PYTHON_DIR:\$PATH\"|" "$BASHRC"
        cli_info "Updated Python path in $BASHRC"
    else
        cli_info "export PATH=\"$PYTHON_DIR:\$PATH\"" >> "$BASHRC"
        cli_info "Added Python path to $BASHRC"
    fi
}

# Helper: Remove Python PATH from ~/.bashrc
_remove_bashrc() {
    cli_info " "
    local BASHRC="$HOME/.bashrc"
    if grep -q "export PATH=.*python" "$BASHRC"; then
        sed -i "/export PATH=.*python.*/d" "$BASHRC"
        cli_info "Removed Python path from $BASHRC"
    else
        cli_error "No Python path entry found in $BASHRC"
    fi
}


# =====================================================================
# Add tools and environments to PATH

# ---------------------------------------------------------------------
# All Computers
add_to_path --force "./vendor/bin"
add_to_path --force "./.venv/Scripts"
add_to_path --force "./.venv/bin"
add_to_path "$HOME/appdata/roaming/python/python311/site-packages"

# ---------------------------------------------------------------------
# TAFE Computers
add_to_path "/c/ProgramData/Laragon/bin/mailpit"
add_to_path "/c/ProgramData/Laragon/bin/gh/bin"
add_to_path "/c/ProgramData/Laragon/bin/pie"
add_to_path "/c/ProgramData/Laragon/bin/mongodb/mongodb-8.0.8/bin"
add_to_path "/c/ProgramData/Laragon/bin/mongodb/mongodb-shell"
add_to_path "/c/ProgramData/Laragon/usr/bin/"
add_to_path "/c/ProgramData/Laragon/bin/mqtt/emqx/bin"
add_to_path "/c/ProgramData/Laragon/bin/utils"
add_to_path "/c/ProgramData/Laragon/bin/mqtt/mosquitto"
add_to_path "/c/ProgramData/Laragon/bin/marp"
add_to_path "/c/ProgramData/Laragon/bin/mqtt/nanomq/bin"


# ---------------------------------------------------------------------
# TDM and Home Computers
add_to_path /c/Laragon/bin/mailpit
add_to_path /c/Laragon/bin/gh/bin
add_to_path /c/Laragon/bin/pie
add_to_path /c/Laragon/bin/mongodb/mongodb-8.0.8/bin
add_to_path /c/Laragon/bin/mongodb/mongodb-shell
add_to_path /c/Laragon/usr/bin
add_to_path /c/Laragon/bin/utils
add_to_path /c/Laragon/bin/marp
add_to_path /c/Laragon/bin/mqtt/emqx/bin
add_to_path /c/Laragon/bin/mqtt/mosquitto
add_to_path /c/Laragon/bin/mqtt/nanomq/bin
add_to_path "/c/Program\ Files/Erlang\ OTP/bin/"
add_to_path "/C/laragon/bin/DbVisualizer"
add_to_path "/C/laragon/bin/Java/jdk-25.0.1+8-jre/bin"


#
# Any Windows PC
add_to_path "/c/Program Files/7-Zip"


# =====================================================================
cli_info " "
find_latest_python
cli_info " "

# =====================================================================
# Source aliases if available
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"


# =====================================================================
# End-of-initialization message (single line) and cleanup
cli_blank " "
cli_completed


# =====================================================================
# Greetings

# ---------------------------------------------------------------------
# Time-based greeting
cli_blank " "
HOUR=$(date "+%H")
case $HOUR in
  [0-9]|1[0-1]) cli_info "Good morning" ;;
  1[2-7])       cli_info "Good afternoon" ;;
  *)            cli_info "Good evening" ;;
esac


# ---------------------------------------------------------------------
# Welcome message
cli_blank "Welcome ${USER:-$USERNAME}, to Bash on $HOSTNAME."
cli_blank "Today's date is: $(date +"%A, %d-%m-%Y")"
cli_blank " "

unset CLI_OUTPUT
unset __cli_out
