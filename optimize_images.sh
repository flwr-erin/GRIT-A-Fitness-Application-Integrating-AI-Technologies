#!/bin/bash

# Install required tools if not already installed
# On Windows, you might need to run this in WSL or use equivalent Windows tools

# Optimize PNG files
find app/src/main/res -name "*.png" -exec optipng -o5 {} \;

# Optimize JPEG files
find app/src/main/res -name "*.jpg" -exec jpegoptim --max=85 {} \;

# Convert high-resolution PNGs to WebP format
find app/src/main/res -name "*.png" -size +100k -exec cwebp -q 80 {} -o {}.webp \;

echo "Image optimization complete"
