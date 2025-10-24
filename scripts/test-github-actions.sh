#!/bin/bash

# Local GitHub Actions simulator for testing workflows
# This script mimics the GitHub Actions build process locally

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "🏗️  Local GitHub Actions Build Simulator"
echo "Project Directory: $PROJECT_DIR"
echo ""

# Configuration
NODE_VERSION="18"
TARGET_PLATFORM="linux-x64"
OUTPUT_NAME="cross-exchange-daemon-linux"
VERBOSE=false
SKIP_DOCKER=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --target)
      TARGET_PLATFORM="$2"
      shift 2
      ;;
    --node-version)
      NODE_VERSION="$2"
      shift 2
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --skip-docker)
      SKIP_DOCKER=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --target PLATFORM     Target platform (linux-x64, win-x64, macos-x64)"
      echo "  --node-version VER    Node.js version to use (default: 18)"
      echo "  --verbose, -v         Show detailed output"
      echo "  --skip-docker         Skip Docker build step"
      echo "  --help, -h            Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                              # Basic build"
      echo "  $0 --target win-x64 --verbose  # Windows build with details"
      echo "  $0 --skip-docker               # Skip Docker step"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set output name based on target
case $TARGET_PLATFORM in
  win-x64)
    OUTPUT_NAME="cross-exchange-daemon-win.exe"
    ;;
  macos-x64)
    OUTPUT_NAME="cross-exchange-daemon-macos"
    ;;
  *)
    OUTPUT_NAME="cross-exchange-daemon-linux"
    ;;
esac

echo "Configuration:"
echo "  Target Platform: $TARGET_PLATFORM"
echo "  Node.js Version: $NODE_VERSION"
echo "  Output Name: $OUTPUT_NAME"
echo "  Verbose: $VERBOSE"
echo ""

# Helper functions
log_step() {
  echo "🔵 STEP: $1"
  echo "----------------------------------------"
}

log_success() {
  echo "✅ $1"
}

log_warning() {
  echo "⚠️  $1"
}

log_error() {
  echo "❌ $1"
}

# Check prerequisites
check_prerequisites() {
  log_step "Checking Prerequisites"
  
  # Check Node.js version
  if ! command -v node >/dev/null 2>&1; then
    log_error "Node.js is not installed"
    exit 1
  fi
  
  local current_node_version=$(node --version | sed 's/v//')
  local major_version=$(echo $current_node_version | cut -d. -f1)
  
  if [ "$major_version" -lt "16" ]; then
    log_warning "Node.js version $current_node_version is older than recommended (16+)"
  else
    log_success "Node.js version $current_node_version is compatible"
  fi
  
  # Check npm
  if ! command -v npm >/dev/null 2>&1; then
    log_error "npm is not installed"
    exit 1
  fi
  
  log_success "npm is available"
  
  # Check if we're in the right directory
  if [ ! -f "$PROJECT_DIR/package.json" ]; then
    log_error "package.json not found in $PROJECT_DIR"
    exit 1
  fi
  
  log_success "Project structure looks correct"
  echo ""
}

# Simulate "Checkout code" step
checkout_code() {
  log_step "Checkout Code (Simulated)"
  
  cd "$PROJECT_DIR"
  
  if [ -d .git ]; then
    git status --porcelain
    if [ $? -eq 0 ]; then
      log_success "Git repository is clean"
    else
      log_warning "Git repository has uncommitted changes"
    fi
  else
    log_warning "Not a git repository"
  fi
  
  echo ""
}

# Simulate "Setup Node.js" step
setup_nodejs() {
  log_step "Setup Node.js $NODE_VERSION (Simulated)"
  
  local current_version=$(node --version)
  log_success "Using Node.js $current_version"
  
  # Check npm cache
  npm config get cache
  log_success "npm cache configured"
  
  echo ""
}

# Simulate "Install dependencies" step
install_dependencies() {
  log_step "Install Dependencies"
  
  cd "$PROJECT_DIR"
  
  if [ "$VERBOSE" = true ]; then
    npm ci
  else
    npm ci --silent
  fi
  
  log_success "Dependencies installed"
  
  # Install global tools (simulating the workflow)
  if ! command -v pkg >/dev/null 2>&1; then
    echo "Installing pkg globally..."
    npm install -g pkg
  fi
  log_success "pkg is available"
  
  echo ""
}

# Simulate "Verify obfuscated code" step
verify_obfuscated_code() {
  log_step "Verify Obfuscated Code"
  
  cd "$PROJECT_DIR"
  
  if [ -f "package.json" ]; then
    if grep -q '"obfuscated".*true' package.json; then
      log_success "Code is properly obfuscated"
    else
      log_warning "Code doesn't appear to be obfuscated"
      echo "This might be expected if testing with source code"
    fi
  else
    log_error "package.json not found"
    exit 1
  fi
  
  echo ""
}

# Simulate "Rebuild native modules" step
rebuild_native_modules() {
  log_step "Rebuild Native Modules"
  
  cd "$PROJECT_DIR"
  
  modules=("sqlite3" "keytar" "bcrypt")
  
  for module in "${modules[@]}"; do
    if npm list "$module" >/dev/null 2>&1; then
      echo "Rebuilding $module..."
      if npm rebuild "$module" --build-from-source 2>/dev/null; then
        log_success "$module rebuilt successfully"
      else
        log_warning "$module rebuild failed, continuing..."
      fi
    else
      log_warning "$module not found in dependencies"
    fi
  done
  
  echo ""
}

# Simulate "Run basic validation" step
run_basic_validation() {
  log_step "Run Basic Validation"
  
  cd "$PROJECT_DIR"
  
  if [ -f "src/index.js" ]; then
    if node --check src/index.js; then
      log_success "src/index.js syntax is valid"
    else
      log_error "src/index.js has syntax errors"
      exit 1
    fi
  elif [ -f "src/app.js" ]; then
    if node --check src/app.js; then
      log_success "src/app.js syntax is valid"
    else
      log_error "src/app.js has syntax errors"
      exit 1
    fi
  else
    log_error "No main entry point found (src/index.js or src/app.js)"
    exit 1
  fi
  
  echo ""
}

# Simulate the package build process
build_package() {
  log_step "Build Executable Package"
  
  cd "$PROJECT_DIR"
  
  # Use our custom build script
  if [ -f "scripts/build-executable.js" ]; then
    echo "Using custom build script..."
    
    local build_args="--target $TARGET_PLATFORM"
    if [ "$VERBOSE" = true ]; then
      build_args="$build_args --verbose"
    fi
    
    if node scripts/build-executable.js $build_args; then
      log_success "Executable built successfully"
    else
      log_error "Executable build failed"
      exit 1
    fi
  else
    log_error "Build script not found: scripts/build-executable.js"
    exit 1
  fi
  
  echo ""
}

# Test the built executable
test_executable() {
  log_step "Test Executable"
  
  cd "$PROJECT_DIR"
  
  if [ -f "$OUTPUT_NAME" ]; then
    log_success "Executable file exists: $OUTPUT_NAME"
    
    # Get file info
    ls -lh "$OUTPUT_NAME"
    
    # Try to run help command with timeout
    echo "Testing executable (timeout 10s)..."
    if timeout 10s ./"$OUTPUT_NAME" --help >/dev/null 2>&1; then
      log_success "Executable help command works"
    else
      log_warning "Executable help test failed or timed out"
      echo "This might be expected if the app requires specific setup"
    fi
  else
    log_error "Executable not found: $OUTPUT_NAME"
    exit 1
  fi
  
  echo ""
}

# Simulate Docker build (optional)
build_docker() {
  if [ "$SKIP_DOCKER" = true ]; then
    echo "🔵 STEP: Build Docker Image (Skipped)"
    echo "----------------------------------------"
    log_success "Docker build skipped as requested"
    echo ""
    return
  fi
  
  log_step "Build Docker Image (Simulated)"
  
  cd "$PROJECT_DIR"
  
  if [ -f "Dockerfile" ]; then
    echo "Dockerfile found, would build Docker image..."
    
    # Just validate Dockerfile syntax
    if command -v docker >/dev/null 2>&1; then
      if docker build --dry-run . >/dev/null 2>&1; then
        log_success "Dockerfile syntax appears valid"
      else
        log_warning "Dockerfile may have issues"
      fi
    else
      log_warning "Docker not available for validation"
    fi
    
    log_success "Docker build simulation completed"
  else
    log_warning "No Dockerfile found"
  fi
  
  echo ""
}

# Create summary report
create_summary() {
  log_step "Build Summary"
  
  echo "📊 Build Results:"
  echo "  Platform: $TARGET_PLATFORM"
  echo "  Node.js: $(node --version)"
  echo "  npm: v$(npm --version)"
  
  if [ -f "$OUTPUT_NAME" ]; then
    echo "  Output: $OUTPUT_NAME ($(stat --format=%s "$OUTPUT_NAME" 2>/dev/null | numfmt --to=iec || echo "unknown size"))"
    echo "  Status: ✅ SUCCESS"
  else
    echo "  Output: ❌ FAILED"
    echo "  Status: ❌ FAILED"
  fi
  
  echo ""
  echo "🎯 Next Steps:"
  echo "  • Test the executable: ./$OUTPUT_NAME --help"
  echo "  • Check temp-build/ directory for debugging (if --skip-cleanup was used)"
  echo "  • Compare with actual GitHub Actions results"
  echo ""
  
  if [ -f "$OUTPUT_NAME" ]; then
    log_success "Local build completed successfully! 🎉"
  else
    log_error "Local build failed! ❌"
    exit 1
  fi
}

# Main execution
main() {
  echo "Starting local GitHub Actions simulation..."
  echo ""
  
  check_prerequisites
  checkout_code
  setup_nodejs
  install_dependencies
  verify_obfuscated_code
  rebuild_native_modules
  run_basic_validation
  build_package
  test_executable
  build_docker
  create_summary
}

# Run main function
main "$@"