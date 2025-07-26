function config() {
  # Constants
  local CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
  local CONFIG_EDITOR="${EDITOR:-nvim}"
  local CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/config_manager"
  local CACHE_FILE="$CACHE_DIR/paths.cache"
  local CACHE_TTL=86400 # 24 hours in seconds

  # Initialize search paths (can include both files and directories)
  local -a search_paths=(
    "$CONFIG_DIR"
    "$ZSH_CUSTOM"
    "$HOME/.zshrc"
    "$HOME/.ssh/"
    "$HOME/.local/share/fcitx5/rime/"
  )

  # Initialize fzf options
  local fzf_opts=(
    --height 40%
    --reverse
    --prompt='Config> '
    --preview-window 'right:60%'
    --preview "bat --color=always --style=numbers {} 2>/dev/null || exa -l --color=always {} 2>/dev/null || cat {}"
    --bind 'ctrl-d:preview-page-down,ctrl-u:preview-page-up'
  )

  # Create cache directory if it doesn't exist
  [[ -d "$CACHE_DIR" ]] || mkdir -p "$CACHE_DIR"

  # Helper functions
  function _config::cache_valid() {
    [[ -f "$CACHE_FILE" ]] && (( $(date +%s) - $(stat -c %Y "$CACHE_FILE") < CACHE_TTL ))
  }

  function _config::build_cache() {
    local fd_opts=(
      --hidden
      --no-ignore-vcs
      --color=never
      --exclude '.git'
    )

    # Start fresh
    : > "$CACHE_FILE"

    # Build cache for both files and directories
    for config_path in "${search_paths[@]}"; do
      if [[ -f "$config_path" ]]; then
        echo "$config_path" >> "$CACHE_FILE"
      elif [[ -d "$config_path" ]]; then
        echo "${config_path%/}/" >> "$CACHE_FILE"
        fd "${fd_opts[@]}" --type f . "$config_path" >> "$CACHE_FILE"
        fd "${fd_opts[@]}" --type d . "$config_path" >> "$CACHE_FILE"
      fi
    done

    # Remove duplicates
    sort -u "$CACHE_FILE" -o "$CACHE_FILE"
  }

  function _config::search_directories() {
    local query="$1"
    local result
    
    if ! _config::cache_valid; then
      _config::build_cache
    fi

    # Get directories from cache (paths ending with /)
    result=$(grep '/$' "$CACHE_FILE" 2>/dev/null || true)

    if [[ -n "$query" ]]; then
      result=$(echo "$result" | grep -i "$query")
    fi

    echo "$result"
  }

  function _config::search_files() {
    local query="$1"
    local result
    
    if ! _config::cache_valid; then
      _config::build_cache
    fi

    # Get files from cache (paths not ending with /)
    result=$(grep -v '/$' "$CACHE_FILE" 2>/dev/null || true)

    if [[ -n "$query" ]]; then
      result=$(echo "$result" | grep -i "$query")
    fi

    echo "$result"
  }

  function _config::list_help() {
    echo "Config file manager usage:"
    echo "  (no args)        - List all config files"
    echo "  <query>          - Search config files matching query"
    echo "  -d [query]       - Search config directories"
    echo "  -e               - Edit the config manager paths"
    echo "  -a <path>       - Add a new path to search"
    echo "  -r               - Refresh the cache"
    echo "  -h               - Show this help"
  }

  function _config::edit_paths() {
    local temp_file=$(mktemp)
    printf '%s\n' "${search_paths[@]}" > "$temp_file"
    $CONFIG_EDITOR "$temp_file"
    
    if [[ $? -eq 0 ]]; then
      search_paths=("${(@f)$(<$temp_file)}")
      _config::build_cache
      echo "Search paths updated and cache rebuilt."
    fi
    
    rm -f "$temp_file"
  }

  function _config::add_path() {
    local new_path="$1"
    if [[ -z "$new_path" ]]; then
      echo "Error: No path specified"
      return 1
    fi

    new_path=${new_path/#\~/$HOME}  # Expand ~ to $HOME
    if [[ ! -e "$new_path" ]]; then
      echo "Error: Path does not exist: $new_path"
      return 1
    fi

    search_paths+=("$new_path")
    _config::build_cache
    echo "Added path: $new_path"
  }

  # Main logic
  case "$1" in
    -h|--help)
      _config::list_help
      ;;
    -e|--edit)
      _config::edit_paths
      ;;
    -a|--add)
      _config::add_path "$2"
      ;;
    -r|--refresh)
      _config::build_cache
      echo "Cache refreshed."
      ;;
    -d|--directory)
      local query="${@:2}"
      local result=$(_config::search_directories "$query")
      if [[ -z "$result" ]]; then
        echo "No directories found matching: $query"
        return 1
      fi
      local selected=$(echo "$result" | fzf "${fzf_opts[@]}")
      if [[ -n "$selected" ]]; then
        if [[ -d "$selected" ]]; then
          cd "$selected"
        else
          $CONFIG_EDITOR "$selected"
        fi
      fi
      ;;
    '')
      echo "Hello! Here are your config paths:"
      printf '  • %s\n' "${search_paths[@]}"
      echo "\nUse -h for help"
      ;;
    *)
      local query="$*"
      local result=$(_config::search_files "$query")
      if [[ -z "$result" ]]; then
        echo "No files found matching: $query"
        return 1
      fi
      local selected=$(echo "$result" | fzf "${fzf_opts[@]}")
      [[ -n "$selected" ]] && $CONFIG_EDITOR "$selected"
      ;;
  esac
}
