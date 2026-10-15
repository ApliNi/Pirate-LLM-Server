#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="$SCRIPT_DIR/Vendor"
LLAMA_DIR="$VENDOR_DIR/llama.cpp"
PACKAGE_DIR="$SCRIPT_DIR/Packages/LlamaLocal"
XCFW="$LLAMA_DIR/build-apple/llama.xcframework"

CLEAN_BUILD=false
USE_COPY=false
SKIP_BUILD=false
LLAMA_REPO="${LLAMA_REPO:-https://github.com/ggml-org/llama.cpp}"
LLAMA_TAG="${LLAMA_TAG:-137435ff154f8d96bb79986dda9ea4dc1b43d2c3}"

if [[ "${COPY_FRAMEWORK:-0}" == "1" ]]; then
    USE_COPY=true
fi

usage() {
    cat <<EOF
Usage: ./setup.sh [OPTIONS]

Prepares llama.cpp source and builds the iOS llama.xcframework for LLMServer.

Options:
  -c, --clean       Clean previous build artifacts before building
      --copy        Copy xcframework into Packages/LlamaLocal instead of symlinking
      --skip-build  Skip running build-llama.sh if xcframework is already built/cached
  -h, --help        Show this help message

Environment variables:
  LLAMA_REPO        Git repository URL (default: https://github.com/ggml-org/llama.cpp)
  LLAMA_TAG         Git branch or tag to checkout (default: default branch)
  COPY_FRAMEWORK    Set to 1 to force copying xcframework instead of symlinking
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        --copy)
            USE_COPY=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            usage >&2
            exit 1
            ;;
    esac
done

echo "============================================"
echo "  Pirate LLM Server - Setup"
echo "============================================"
echo ""

# 1. Check prerequisites
echo "[1/4] Checking prerequisites..."

if [[ "$(uname -s)" != "Darwin" && "$SKIP_BUILD" != true ]]; then
    echo "Error: Building iOS XCFramework requires macOS with Xcode." >&2
    echo "To build on Windows/Linux, run the GitHub Actions workflow to generate the unsigned IPA." >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is required but not installed." >&2
    exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
    echo "Error: cmake is required but not installed." >&2
    echo "Install it via Homebrew: brew install cmake" >&2
    exit 1
fi

if [[ "$SKIP_BUILD" != true ]]; then
    if ! command -v xcodebuild >/dev/null 2>&1; then
        echo "Error: xcodebuild is required but not found in PATH." >&2
        echo "Ensure Xcode is installed and active via: sudo xcode-select -s /Applications/Xcode.app" >&2
        exit 1
    fi
    if ! command -v xcrun >/dev/null 2>&1; then
        echo "Error: xcrun is required but not found." >&2
        exit 1
    fi
fi

echo "  Platform:   $(uname -s) ($(uname -m))"
echo "  git:        $(git --version | head -n 1)"
echo "  cmake:      $(cmake --version | head -n 1)"
if command -v xcodebuild >/dev/null 2>&1; then
    echo "  xcodebuild: $(xcodebuild -version 2>/dev/null | head -n 1)"
fi
echo ""

# 2. Clone or update llama.cpp repository
echo "[2/4] Preparing llama.cpp source..."

if [[ -f "$LLAMA_DIR/CMakeLists.txt" ]]; then
    echo "  llama.cpp source already present at: $LLAMA_DIR"
else
    if [[ -d "$LLAMA_DIR" ]]; then
        echo "  Incomplete llama.cpp directory detected, re-cloning..."
        rm -rf "$LLAMA_DIR"
    fi
    mkdir -p "$VENDOR_DIR"
    echo "  Cloning llama.cpp from $LLAMA_REPO..."
    if [[ -n "$LLAMA_TAG" ]]; then
        git clone "$LLAMA_REPO" "$LLAMA_DIR"
        echo "  Checking out $LLAMA_TAG..."
        (cd "$LLAMA_DIR" && git checkout "$LLAMA_TAG")
    else
        git clone --depth 1 "$LLAMA_REPO" "$LLAMA_DIR"
    fi
fi
echo ""

# 3. Build llama.xcframework
echo "[3/4] Building llama.xcframework..."

if [[ "$CLEAN_BUILD" == true ]]; then
    echo "  Cleaning previous build directories..."
    rm -rf "$LLAMA_DIR/build-apple" "$LLAMA_DIR/build-ios-device" "$LLAMA_DIR/build-ios-sim"
    rm -rf "$PACKAGE_DIR/llama.xcframework"
fi

if [[ -d "$XCFW" && "$CLEAN_BUILD" != true ]]; then
    echo "  Existing XCFramework found at: $XCFW"
    echo "  (Run with --clean to force re-compilation)"
elif [[ "$SKIP_BUILD" == true ]]; then
    echo "  --skip-build specified. Skipping compilation."
    if [[ ! -d "$XCFW" ]]; then
        echo "Error: Expected XCFramework not found at $XCFW" >&2
        exit 1
    fi
else
    BUILD_SCRIPT="$SCRIPT_DIR/build-llama.sh"
    if [[ ! -f "$BUILD_SCRIPT" ]]; then
        echo "Error: Build script missing: $BUILD_SCRIPT" >&2
        exit 1
    fi
    chmod +x "$BUILD_SCRIPT"
    "$BUILD_SCRIPT"
fi

if [[ ! -d "$XCFW" ]]; then
    echo "Error: XCFramework build completed but $XCFW does not exist." >&2
    exit 1
fi
echo ""

# 4. Link or copy XCFramework into local Swift package
echo "[4/4] Setting up Packages/LlamaLocal/llama.xcframework..."

mkdir -p "$PACKAGE_DIR"
rm -rf "$PACKAGE_DIR/llama.xcframework"

if [[ "$USE_COPY" == true ]]; then
    echo "  Copying XCFramework into local package..."
    cp -R "$XCFW" "$PACKAGE_DIR/llama.xcframework"
else
    echo "  Creating relative symlink to XCFramework..."
    RELATIVE_PATH="../../Vendor/llama.cpp/build-apple/llama.xcframework"
    if (cd "$PACKAGE_DIR" && ln -sf "$RELATIVE_PATH" "llama.xcframework") 2>/dev/null; then
        echo "  Symlink created: Packages/LlamaLocal/llama.xcframework -> $RELATIVE_PATH"
    else
        echo "  Symlink creation failed. Falling back to copy..."
        cp -R "$XCFW" "$PACKAGE_DIR/llama.xcframework"
    fi
fi

if [[ ! -f "$PACKAGE_DIR/llama.xcframework/Info.plist" ]]; then
    echo "Error: Verification failed. $PACKAGE_DIR/llama.xcframework/Info.plist not found." >&2
    exit 1
fi

echo ""
echo "============================================"
echo "  Setup completed successfully!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Open LLMServer.xcodeproj in Xcode"
echo "  2. Select your Team in Signing & Capabilities (or build unsigned via GitHub Actions)"
echo "  3. Select your iPhone as build target"
echo "  4. Build and install (Cmd+R)"
echo ""
