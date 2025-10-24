# paste-image.tmux

# A helper function to get tmux options with a default value.
get_tmux_option() {
    local option_name="$1"
    local default_value="$2"
    local option_value=$(tmux show-option -gqv "$option_name")
    if [ -z "$option_value" ]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

# Get the directory of the current script to reliably find our `paster.sh`
# Use readlink to resolve the absolute path, works with run-shell
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]:-$0}")"
CURRENT_DIR="$(dirname "$SCRIPT_PATH")"
PASTER_SCRIPT="$CURRENT_DIR/scripts/paster.sh"

# --- User Configurable Options ---

# 1. Keybinding: User can set `@paste-image-key` in their .tmux.conf
#    Default key is 'P'.
paste_key=$(get_tmux_option "@paste-image-key" "P")

# 2. Save Path: User can set `@paste-image-path` in their .tmux.conf
#    Default is a cache directory, which is good practice.
save_path=$(get_tmux_option "@paste-image-path" "$HOME/.cache/tmux-paste-image")

# --- Main Plugin Logic ---

# Create the keybinding.
# We pass the configured save path as an argument to the script.
tmux bind-key "$paste_key" "run-shell 'bash $PASTER_SCRIPT \"$save_path\"'"

# Optional: Display a message on load (good for debugging)
# tmux display-message "tmux-paste-image plugin loaded. Press (prefix)+$paste_key to use."
