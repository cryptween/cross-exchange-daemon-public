#!/bin/bash

# Optimized Node.js application packager for Cryptween daemon
# Creates portable packages with bundled source code for protection

set -e  # Exit on any error

PROJECT_NAME="cryptween-daemon"
VERSION=$(node -p "require('./package.json').version")
BUILD_DIR="./dist-portable"
ENABLE_BUNDLING=true

echo "Building optimized portable packages for ${PROJECT_NAME} v${VERSION}"

# Create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"



# Function to optimize node_modules
optimize_node_modules() {
    local target_dir=$1
    echo "Optimizing node_modules..."
    
    # Remove common unnecessary files from node_modules
    find "$target_dir/node_modules" -type f \( \
        -name "*.md" -o \
        -name "*.txt" -o \
        -name "CHANGELOG*" -o \
        -name "HISTORY*" -o \
        -name "LICENSE*" -o \
        -name "README*" -o \
        -name "*.ts" -o \
        -name "*.d.ts" -o \
        -name "*.map" -o \
        -name "Makefile" -o \
        -name "*.gyp" -o \
        -name "*.h" -o \
        -name "*.c" -o \
        -name "*.cc" \) -delete 2>/dev/null || true
    
    # Remove test directories
    find "$target_dir/node_modules" -type d -name "test" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir/node_modules" -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir/node_modules" -type d -name "__tests__" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir/node_modules" -type d -name "spec" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir/node_modules" -type d -name "example" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir/node_modules" -type d -name "examples" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir/node_modules" -type d -name "demo" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir/node_modules" -type d -name "docs" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir/node_modules" -type d -name "documentation" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir/node_modules" -type d -name "bench" -exec rm -rf {} + 2>/dev/null || true
    find "$target_dir/node_modules" -type d -name "benchmark" -exec rm -rf {} + 2>/dev/null || true
    
    echo "✓ node_modules optimized"
}

# Function to build package for a specific platform
build_platform_package() {
    local platform=$1
    echo "Building $platform package..."
    
    # Create bundled application if bundling is enabled
    local bundle_dir=""
    if [ "$ENABLE_BUNDLING" = true ]; then
        echo "Creating bundled application for source code protection..."
        
        # Create bundled version in a temporary location
        bundle_dir="$(mktemp -d)"
        
        # Bundle the main application from the source directory
        if npx ncc build "src/index.js" \
            --out "$bundle_dir" \
            --minify \
            --no-source-map-register \
            --external sqlite3 \
            --external keytar \
            --external bcrypt \
            --external bcryptjs \
            --external websocket \
            --external web3 \
            --external web3-core \
            --external web3-providers-ws \
            --external web3-core-requestmanager \
            --external @truffle/contract \
            --external @truffle/hdwallet-provider \
            --quiet 2>/dev/null; then
            echo "✓ Application bundled successfully"
        else
            echo "Warning: ncc bundling failed, using original source"
            rm -rf "$bundle_dir"
            bundle_dir=""
        fi
    fi
    
    # Create package directory
    local package_dir="$BUILD_DIR/${PROJECT_NAME}-${platform}"
    mkdir -p "$package_dir/app"
    
    if [ -n "$bundle_dir" ]; then
        # Use bundled application
        echo "Using bundled application (source code protected)..."
        
        # Copy essential files (not source code)
        cp package.json "$package_dir/app/" 2>/dev/null || true
        cp README.md "$package_dir/" 2>/dev/null || echo "README.md not found, skipping..."
        cp LICENSE "$package_dir/" 2>/dev/null || echo "LICENSE not found, skipping..."
        
        # Copy additional required directories
        [ -d "assets" ] && cp -r assets "$package_dir/app/" 2>/dev/null || true
        [ -d "contracts" ] && cp -r contracts "$package_dir/app/" 2>/dev/null || true
        [ -d "exchanges" ] && cp -r exchanges "$package_dir/app/" 2>/dev/null || true
        [ -d "lib" ] && cp -r lib "$package_dir/app/" 2>/dev/null || true
        [ -d "prebuilds" ] && cp -r prebuilds "$package_dir/app/" 2>/dev/null || true
        [ -d "build" ] && cp -r build "$package_dir/app/" 2>/dev/null || true
        
        # Copy environment files
        [ -f ".env" ] && cp .env "$package_dir/app/" 2>/dev/null || true
        [ -f ".env.test" ] && cp .env.test "$package_dir/app/" 2>/dev/null || true
        
        # Copy the bundled main file
        cp "$bundle_dir/index.js" "$package_dir/app/"
        
        # Copy any additional bundled assets
        [ -d "$bundle_dir/assets" ] && cp -r "$bundle_dir/assets" "$package_dir/app/" 2>/dev/null || true
        [ -d "$bundle_dir/contracts" ] && cp -r "$bundle_dir/contracts" "$package_dir/app/" 2>/dev/null || true
        [ -d "$bundle_dir/exchanges" ] && cp -r "$bundle_dir/exchanges" "$package_dir/app/" 2>/dev/null || true
        [ -d "$bundle_dir/lib" ] && cp -r "$bundle_dir/lib" "$package_dir/app/" 2>/dev/null || true
        [ -d "$bundle_dir/prebuilds" ] && cp -r "$bundle_dir/prebuilds" "$package_dir/app/" 2>/dev/null || true
        [ -d "$bundle_dir/build" ] && cp -r "$bundle_dir/build" "$package_dir/app/" 2>/dev/null || true
        [ -f "$bundle_dir/.env" ] && cp "$bundle_dir/.env" "$package_dir/app/" 2>/dev/null || true
        [ -f "$bundle_dir/.env.test" ] && cp "$bundle_dir/.env.test" "$package_dir/app/" 2>/dev/null || true
        
        # Clean up temporary bundle directory
        rm -rf "$bundle_dir"
        
        echo "✓ Bundled application files copied"
    else
        # Use original source
        echo "Using original source code..."
        
        # Copy application files
        cp -r src "$package_dir/app/"
        cp package.json "$package_dir/app/"
        cp README.md "$package_dir/" 2>/dev/null || echo "README.md not found, skipping..."
        cp LICENSE "$package_dir/" 2>/dev/null || echo "LICENSE not found, skipping..."
        
        # Copy additional directories
        [ -d "assets" ] && cp -r assets "$package_dir/app/" 2>/dev/null || true
        [ -d "contracts" ] && cp -r contracts "$package_dir/app/" 2>/dev/null || true
        
        echo "✓ Original source files copied"
    fi
    
    # Copy and optimize dependencies
    echo "Copying and optimizing dependencies..."
    if [ -d node_modules ]; then
        cp -r node_modules "$package_dir/"
        optimize_node_modules "$package_dir"
    fi
    
    # Create launcher script for platform
    if [[ "$platform" == *"windows"* ]]; then
        cat > "$package_dir/${PROJECT_NAME}.bat" << 'EOF'
@echo off
cd /d "%~dp0"
node app/index.js %*
EOF
        echo "✓ Windows batch launcher created"
    else
        cat > "$package_dir/${PROJECT_NAME}" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
node app/index.js "$@"
EOF
        chmod +x "$package_dir/${PROJECT_NAME}"
        echo "✓ Unix shell launcher created"
    fi
    
    # Create compressed package
    echo "Creating compressed package..."
    cd "$BUILD_DIR"
    tar -czf "${PROJECT_NAME}-${platform}-v${VERSION}.tar.gz" "${PROJECT_NAME}-${platform}"
    rm -rf "${PROJECT_NAME}-${platform}"
    cd - > /dev/null
    
    echo "✓ $platform package created"
}

# Build packages for all platforms
echo ""
echo "🚀 Building packages..."

# Build for each platform
build_platform_package "linux-x64"
build_platform_package "macos-x64" 
build_platform_package "windows-x64"

# Display results
echo ""
echo "✅ Build completed successfully!"
echo ""
echo "Portable packages created in: $BUILD_DIR"
echo ""
ls -la "$BUILD_DIR"
echo ""
echo "📦 Distribution packages:"
echo "  • Linux:   Extract .tar.gz and run ./cryptween-daemon"
echo "  • macOS:   Extract .tar.gz and run ./cryptween-daemon"  
echo "  • Windows: Extract .tar.gz and run cryptween-daemon.bat"
echo ""
echo "💡 Optimizations applied:"
if [ "$ENABLE_BUNDLING" = true ]; then
    echo "  • 🔒 Source code bundled and protected"
else
    echo "  • 📁 Original source code included"
fi
echo "  • 📦 Removed development files"
echo "  • 🧹 Cleaned unnecessary files (docs, tests, examples)"
echo "  • 🚫 Removed TypeScript declaration files"
echo "  • 🗜️  Removed source maps"
echo "  • 🗂️  Used tar.gz compression for all platforms"
echo ""
echo "Requirements: Node.js must be installed on target system"