# =====================================================================
# Greetings

# ---------------------------------------------------------------------
# Time-based greeting
HOUR=$(date "+%H")
case $HOUR in
  [0-9]|1[0-1]) echo "Good morning" ;;
  1[2-7]) echo "Good afternoon" ;;
  *) echo "Good evening" ;;
esac

# ---------------------------------------------------------------------
# Welcome message
echo "Welcome ${USER:-$USERNAME}, to Bash on $HOSTNAME."
echo "Today's date is: $(date +"%A, %d-%m-%Y")"
echo


# =====================================================================
# Required basic aliases. Others added tot he .aliases file
alias la='ls -ah'
alias ll='ls -lah'
alias ls='ls -F --color=auto --show-control-chars'




# =====================================================================
# Function definitions used by shell

# ---------------------------------------------------------------------
# Function to safely append to PATH
add_to_path() {
  [ -d "$1" ] && PATH="$1:$PATH"
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
    echo "Usage: add_alias [--force|-f] <alias_name> <alias_command>"
    echo ""
    echo "Options:"
    echo "  --force, -f     Force creation of alias even if command or path is invalid"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  add_alias cls 'clear'"
    echo "  add_alias laragon 'cd /c/ProgramData/Laragon/'"
    echo "  add_alias --force emqx-start 'cd /c/Laragon/bin/mqtt/emqx/bin && ./emqx foreground'"
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
        echo "❌ Directory '$path' does not exist. Alias '$alias_name' not created."
        return 1
      else
        echo "⚠️ Directory '$path' not found. Alias '$alias_name' forced."
      fi
    fi
  fi

  # Check for executable in the command (e.g. './emqx', './mosquitto.exe')
  if [[ "$alias_command" =~ \&\&[[:space:]]+\.\/([a-zA-Z0-9._-]+) ]]; then
    local exec_file="${BASH_REMATCH[1]}"
    local exec_path="${path}/${exec_file}"
    if [ ! -x "$exec_path" ]; then
      if [ "$force" = false ]; then
        echo "❌ Executable '$exec_file' not found or not executable at '$exec_path'. Alias '$alias_name' not created."
        return 1
      else
        echo "⚠️ Executable '$exec_file' not found. Alias '$alias_name' forced."
      fi
    fi
  else
    # Extract the first command word
    local cmd="${alias_command%% *}"
    if ! command -v "$cmd" &> /dev/null; then
      if [ "$force" = false ]; then
        echo "❌ Command '$cmd' not found. Alias '$alias_name' not created."
        return 1
      else
        echo "⚠️ Command '$cmd' not found. Alias '$alias_name' forced."
      fi
    fi
  fi

  # Create the alias
  alias "$alias_name"="$alias_command"
  echo "✅ Alias '$alias_name' created for: $alias_command"
}

# ---------------------------------------------------------------------
# Display paths in a folder as a tree

pathtree() {
  local delimiter=":"
  local show_hidden=false

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --show-hidden) show_hidden=true ;;
      --delimiter=*) delimiter="${1#*=}" ;;
      *) echo "Usage: pathtree [--show-hidden] [--delimiter=CHAR]"; return 1 ;;
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
    echo "${indent}+-- ${parts[-1]}"
  done
}



# =====================================================================
# Add tools and environments to PATH

# ---------------------------------------------------------------------
# All Computers
add_to_path "./vendor/bin"
add_to_path "./.venv/Scripts"
add_to_path "./.venv/bin"
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


# ---------------------------------------------------------------------
# TDM and Home Computers
add_to_path "/c/Laragon/bin/mailpit"
add_to_path "/c/Laragon/bin/gh/bin"
add_to_path "/c/Laragon/bin/pie"
add_to_path "/c/Laragon/bin/mongodb/mongodb-8.0.8/bin"
add_to_path "/c/Laragon/bin/mongodb/mongodb-shell"
add_to_path "/c/Laragon/usr/bin"
add_to_path "/c/Laragon/bin/mqtt/emqx/bin"
add_to_path "/c/Laragon/bin/utils"
add_to_path "/c/Laragon/bin/mqtt/mosquitto"
add_to_path "/c/Laragon/bin/marp"

# =====================================================================
# Source aliases if available
[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"
