#!/bin/bash
set -e

echo "🚀 Starting SWP WebAssistant..."

# Install Playwright browsers on first run (runtime, not build time)
# This avoids network issues during docker build
if [ ! -d "/ms-playwright/chromium-1028" ]; then
    echo "📦 Installing Playwright Chromium (first run)..."
    echo "   This may take a few minutes..."

    # Try to install with retries
    for i in 1 2 3; do
        if playwright install chromium; then
            echo "✅ Playwright installation successful!"
            break
        else
            if [ $i -lt 3 ]; then
                echo "⚠️  Installation attempt $i failed, retrying in 5 seconds..."
                sleep 5
            else
                echo "❌ Playwright installation failed after 3 attempts"
                echo "   The application will start, but web scraping may not work"
            fi
        fi
    done
else
    echo "✅ Playwright already installed"
fi

# Execute the main command
echo "🎯 Starting application: $@"
exec "$@"
