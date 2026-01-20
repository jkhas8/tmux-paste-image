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
SCREENSHOT_DIR="$1"
mkdir -p "$SCREENSHOT_DIR"

# --- Main Logic ---

# Generate a unique filename.
FILENAME="image_$(date +%Y-%m-%d_%H-%M-%S).png"
FILE_PATH="$SCREENSHOT_DIR/$FILENAME"

# Detect environment and save clipboard image
if grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL: Use PowerShell to access Windows clipboard
    WIN_PATH=$(wslpath -w "$FILE_PATH")
    powershell.exe -NoProfile -Command "
        Add-Type -AssemblyName System.Windows.Forms
        \$img = [System.Windows.Forms.Clipboard]::GetImage()
        if (\$img) {
            \$img.Save('$WIN_PATH', [System.Drawing.Imaging.ImageFormat]::Png)
        }
    " 2>/dev/null
elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-paste &> /dev/null; then
    wl-paste --type image/png > "$FILE_PATH"
elif command -v xclip &> /dev/null; then
    xclip -selection clipboard -t image/png -o > "$FILE_PATH"
else
    tmux display-message "[tmux-paste-image] Error: No clipboard tool available."
    exit 1
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
