#!/bin/bash

# Exit on error
set -e

echo "=== Starting Vercel Build Script for Flutter Web (Admin) ==="

# 1. Generate the .env file from Vercel system environment variables
echo "Generating .env file..."
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
  echo "SUPABASE_URL=$SUPABASE_URL" > .env
  echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
  echo "Successfully generated .env file."
else
  echo "WARNING: SUPABASE_URL or SUPABASE_ANON_KEY is not defined in the environment. Using existing .env or fallback values."
fi

# 2. Check if Flutter is cached or clone a fresh one
if [ ! -d "flutter" ]; then
  echo "Downloading Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
else
  echo "Flutter SDK directory already exists, using cached version."
fi

# 3. Add Flutter to path
export PATH="$PATH:$(pwd)/flutter/bin"

# 4. Run Flutter Doctor to initialize and verify installation
echo "Checking Flutter version..."
flutter --version

# 5. Build the web app
echo "Building Flutter Web application..."
flutter build web --release

echo "=== Build Completed Successfully! ==="
