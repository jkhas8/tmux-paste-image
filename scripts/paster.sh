#!/bin/bash

# A script to take an image from the clipboard, save it to a file,
# and insert the path into the current tmux pane.

# --- Argument Handling ---

# The save path is passed as the first argument from the .tmux file.
# If it's not provided, exit with an error.
if [ -z "$1" ]; then
    tmux display-message "[tmux-paste-image] Error: Save path not provided. $1"
    exit 1
fi

# The directory where screenshots will be saved.
# Expand ~ and $HOME properly (handles tilde from tmux config)
SCREENSHOT_DIR="${1/#\~/$HOME}"
SCREENSHOT_DIR="${SCREENSHOT_DIR/#\$HOME/$HOME}"
mkdir -p "$SCREENSHOT_DIR"

# --- Dependency Check ---

# Check for pngpaste (macOS), xclip (X11), or wl-paste (Wayland).
if [[ "$(uname)" == "Darwin" ]]; then
    if ! command -v pngpaste &> /dev/null; then
        tmux display-message "[tmux-paste-image] Error: Please install 'pngpaste' (brew install pngpaste)."
        exit 1
    fi
else
    if ! command -v xclip &> /dev/null && ! command -v wl-paste &> /dev/null; then
        tmux display-message "[tmux-paste-image] Error: Please install 'xclip' or 'wl-paste'."
        exit 1
    fi
fi

# --- Main Logic ---

# Generate a unique filename.
FILENAME="image_$(date +%Y-%m-%d_%H-%M-%S).png"
FILE_PATH="$SCREENSHOT_DIR/$FILENAME"

# Save the clipboard content to the file, checking platform.
if [[ "$(uname)" == "Darwin" ]]; then
    pngpaste "$FILE_PATH"
elif [ -n "$WAYLAND_DISPLAY" ]; then
    wl-paste --type image/png > "$FILE_PATH"
else
    xclip -selection clipboard -t image/png -o > "$FILE_PATH"
fi

# --- Final Step ---

# Check if the file was created and is not empty.
if [ -s "$FILE_PATH" ]; then
    # Check if we're in Claude Code interactive mode
    # Look for the claude prompt or empty line (typical interactive prompt)
    PANE_CONTENT=$(tmux capture-pane -t "$TMUX_PANE" -p | tail -5)
    
    if echo "$PANE_CONTENT" | grep -qE "(^›|^>|claude.*›|Human:|Assistant:)"; then
        # For Claude Code, use the /image slash command
        tmux send-keys -t "$TMUX_PANE" "/image $FILE_PATH" Enter
        tmux display-message "[tmux-paste-image] Image sent to Claude: $(basename $FILE_PATH)"
    else
        # For regular commands, just paste the file path
        tmux send-keys -t "$TMUX_PANE" "$FILE_PATH"
        tmux display-message "[tmux-paste-image] Path pasted: $FILE_PATH"
    fi
else
    # Inform the user if it failed and clean up the empty file.
    tmux display-message "[tmux-paste-image] Error: No PNG image found in clipboard."
    rm "$FILE_PATH"
fi
