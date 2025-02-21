#!/bin/bash

# Script to recursively convert DOS line endings to Unix line endings
# Usage: ./dos2unix_converter.sh [directory]

# Check if this script itself has DOS line endings
if grep -q $'\r' "$0"; then
    echo "Warning: This script has DOS line endings. Converting script to Unix format..."
    tr -d '\r' < "$0" > "$0.tmp" && mv "$0.tmp" "$0"
    echo "Script converted. Please run it again."
    exit 1
fi

# Function to display usage
show_usage() {
    echo "Usage: $0 [directory]"
    echo "If no directory is specified, the current directory will be used."
}

# Function to convert line endings
convert_file() {
    local file="$1"

    # Check if file has DOS line endings
    if grep -q $'\r' "$file"; then
        echo "Converting: $file"
        # Create a temporary file
        local temp_file="$(mktemp)"

        # Convert DOS to Unix line endings
        tr -d '\r' < "$file" > "$temp_file"

        # Preserve file permissions
        local file_perms="$(stat -c %a "$file")"

        # Move temporary file back to original
        mv "$temp_file" "$file"

        # Restore permissions
        chmod "$file_perms" "$file"
    else
        echo "Skipping (already Unix format): $file"
    fi
}

# Check arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# Set the directory to process
target_dir="${1:-.}"

# Check if directory exists
if [ ! -d "$target_dir" ]; then
    echo "Error: Directory '$target_dir' does not exist."
    show_usage
    exit 1
fi

# Main process
echo "Starting conversion in directory: $target_dir"
echo "Finding files..."

# Find all text files recursively and process them
# Excluding common development tool directories and binary file types
find "$target_dir" \
    -type f \
    -not -path "*/\.*" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/.svn/*" \
    -not -path "*/.hg/*" \
    -not -path "*/.idea/*" \
    -not -path "*/.vscode/*" \
    -not -path "*/vendor/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/.next/*" \
    -not -path "*/coverage/*" \
    -not -path "*/__pycache__/*" \
    \( \
        -name "*.txt" -o \
        -name "*.md" -o \
        -name "*.csv" -o \
        -name "*.json" -o \
        -name "*.xml" -o \
        -name "*.yaml" -o \
        -name "*.yml" -o \
        -name "*.env" -o \
        -name "*.sh" -o \
        -name "*.bash" -o \
        -name "*.py" -o \
        -name "*.js" -o \
        -name "*.jsx" -o \
        -name "*.ts" -o \
        -name "*.tsx" -o \
        -name "*.php" -o \
        -name "*.rb" -o \
        -name "*.java" -o \
        -name "*.c" -o \
        -name "*.cpp" -o \
        -name "*.h" -o \
        -name "*.hpp" -o \
        -name "*.cs" -o \
        -name "*.css" -o \
        -name "*.scss" -o \
        -name "*.less" -o \
        -name "*.html" -o \
        -name "*.htm" -o \
        -name "*.conf" -o \
        -name "*.cfg" -o \
        -name "*.ini" \
    \) \
    -print0 | while IFS= read -r -d '' file; do
    convert_file "$file"
done

echo "Conversion complete!"
