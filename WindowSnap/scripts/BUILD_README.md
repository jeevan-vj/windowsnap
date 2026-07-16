# WindowSnap Build Scripts

This directory contains build scripts for creating universal binaries that work on both Apple Silicon and Intel Macs.

## Quick Start

### Build Universal Binary Only

Creates a standalone universal binary (no app bundle):

```bash
cd WindowSnap
./scripts/build-universal.sh
```

**Output:** `.build/universal/WindowSnap` (runs on both ARM64 and x86_64)

### Build Universal App Bundle

Creates a complete `.app` bundle with universal binary:

```bash
cd WindowSnap
./scripts/build-universal-bundle.sh
```

**Output:**
- `dist/WindowSnap.app` - Complete app bundle
- `dist/WindowSnap.zip` - Compressed archive for distribution

### Build with Code Signing

For distribution to other users (requires Developer ID certificate):

```bash
cd WindowSnap
CODESIGN_ID="Developer ID Application: Your Name (TEAM_ID)" \
  ./scripts/build-universal-bundle.sh
```

## Available Scripts

### 1. `build-universal.sh`

**Purpose:** Build universal binary supporting both architectures
**Requirements:** Xcode Command Line Tools, Swift 5.9+
**Output:** `.build/universal/WindowSnap`

**Features:**
- ✅ Builds for ARM64 (Apple Silicon)
- ✅ Builds for x86_64 (Intel)
- ✅ Combines both using `lipo`
- ✅ Verifies architectures
- ✅ Shows file sizes

**Usage:**
```bash
./scripts/build-universal.sh
```

**Testing the binary:**
```bash
# Run directly
./.build/universal/WindowSnap

# Check architectures
lipo -info ./.build/universal/WindowSnap
# Output: Architectures in the fat file: WindowSnap are: x86_64 arm64
```

---

### 2. `build-universal-bundle.sh`

**Purpose:** Create complete universal app bundle for distribution
**Requirements:** Same as above + asset tools
**Output:** `dist/WindowSnap.app`

**Features:**
- ✅ Builds universal binary
- ✅ Creates proper `.app` bundle structure
- ✅ Compiles asset catalog (icons)
- ✅ Generates Info.plist
- ✅ Code signing support
- ✅ Creates distribution ZIP

**Usage:**

**Basic build (unsigned - local testing only):**
```bash
./scripts/build-universal-bundle.sh
```

**Signed build (for distribution):**
```bash
CODESIGN_ID="Developer ID Application: Your Name (TEAM_ID)" \
  ./scripts/build-universal-bundle.sh
```

**Custom version:**
```bash
VERSION="1.3.0" ./scripts/build-universal-bundle.sh
```

---

### 3. `build_bundle.sh` (Original)

**Purpose:** Original single-architecture bundle builder
**Output:** Builds for current Mac's architecture only

**Note:** This is kept for backward compatibility. For distribution, use `build-universal-bundle.sh` instead.

---

## Architecture Information

### What You Get

| Build Type | ARM64 (M1/M2/M3/M4) | Intel (x86_64) | File Size |
|------------|---------------------|----------------|-----------|
| ARM64 only | ✅ Native | ⚠️ Rosetta 2 | ~2-3 MB |
| x86_64 only | ⚠️ Rosetta 2 | ✅ Native | ~2-3 MB |
| Universal | ✅ Native | ✅ Native | ~4-5 MB |

### Performance Comparison

**Apple Silicon Mac:**
- Universal binary → Native ARM64 code (best performance)
- Intel-only binary → Runs via Rosetta 2 (slight overhead)

**Intel Mac:**
- Universal binary → Native x86_64 code (best performance)
- ARM64-only binary → Won't run (error)

### Recommended for Distribution

**Always use universal binaries** to ensure:
- ✅ Works on all modern Macs
- ✅ Best performance on each architecture
- ✅ No Rosetta 2 dependency
- ✅ Professional distribution

---

## Build Process Explained

### Step-by-Step: Universal Binary Creation

1. **Clean Build Directories**
   ```bash
   rm -rf .build/arm64-apple-macosx .build/x86_64-apple-macosx
   ```

2. **Build ARM64 Version**
   ```bash
   swift build -c release --arch arm64
   # Output: .build/arm64-apple-macosx/release/WindowSnap
   ```

3. **Build x86_64 Version**
   ```bash
   swift build -c release --arch x86_64
   # Output: .build/x86_64-apple-macosx/release/WindowSnap
   ```

4. **Combine with lipo**
   ```bash
   lipo -create \
     .build/arm64-apple-macosx/release/WindowSnap \
     .build/x86_64-apple-macosx/release/WindowSnap \
     -output .build/universal/WindowSnap
   ```

5. **Verify**
   ```bash
   lipo -info .build/universal/WindowSnap
   file .build/universal/WindowSnap
   ```

---

## Distribution Workflow

### For Public Release

Do not assemble public artifacts from individual build scripts. Follow the canonical, fail-closed workflow in the repository `DISTRIBUTION_GUIDE.md`:

```bash
CODESIGN_ID="Developer ID Application: Your Name (TEAM_ID)" \
NOTARY_PROFILE="windowsnap-notary" \
  ./scripts/release.sh
```

Use `./scripts/build-adhoc-release.sh` only for local testing. Its output is isolated under `dist/local-only/` and must not be published.

---

## Troubleshooting

### Build Fails on Intel Mac

**Problem:** Building ARM64 on Intel Mac
```
error: unable to spawn process (Unsupported architecture)
```

**Solution:** Intel Macs can still build universal binaries using cross-compilation. Ensure you have latest Xcode:
```bash
xcode-select --install
```

### "Command not found: lipo"

**Problem:** Xcode Command Line Tools not installed

**Solution:**
```bash
xcode-select --install
sudo xcode-select --switch /Applications/Xcode.app
```

### Code Signing Fails

**Problem:** Invalid code signing identity

**Solution:** List available identities:
```bash
security find-identity -v -p codesigning
```

Use the full identity name:
```bash
CODESIGN_ID="Developer ID Application: Your Name (TEAM_ID)" \
  ./scripts/build-universal-bundle.sh
```

### Asset Catalog Warning

**Problem:** `actool` compilation warnings

**Solution:** This is usually safe to ignore. The app will still work, but icons might not display correctly. Install Xcode (not just Command Line Tools) to fix.

---

## Testing

### Verify Universal Binary

```bash
# Check architectures
lipo -info .build/universal/WindowSnap

# Expected output:
# Architectures in the fat file: WindowSnap are: x86_64 arm64

# Detailed info
lipo -detailed_info .build/universal/WindowSnap

# File type
file .build/universal/WindowSnap
# Output: Mach-O universal binary with 2 architectures
```

### Test on Different Systems

**On Apple Silicon Mac:**
```bash
arch -arm64 ./.build/universal/WindowSnap  # Native
arch -x86_64 ./.build/universal/WindowSnap  # Rosetta 2
```

**On Intel Mac:**
```bash
arch -x86_64 ./.build/universal/WindowSnap  # Native
# arch -arm64 will fail (ARM64 not supported on Intel)
```

---

## System Requirements

### Build Requirements

- **macOS:** 12.0+ (for building)
- **Xcode:** 14.0+ or Command Line Tools
- **Swift:** 5.9+
- **Disk Space:** ~500 MB for build artifacts

### Runtime Requirements

- **macOS:** 12.0 (Monterey) or later
- **Architecture:** ARM64 or x86_64
- **Permissions:** Accessibility access required

---

## File Sizes

Typical build sizes:

| Component | Size |
|-----------|------|
| ARM64 binary | ~2.5 MB |
| x86_64 binary | ~2.8 MB |
| Universal binary | ~5.0 MB |
| Complete .app bundle | ~6-8 MB |
| ZIP archive | ~3-4 MB (compressed) |

---

## Advanced Usage

### Build Only Specific Architecture

**ARM64 only:**
```bash
swift build -c release --arch arm64
```

**Intel only:**
```bash
swift build -c release --arch x86_64
```

### Extract Architecture from Universal Binary

```bash
# Extract ARM64
lipo .build/universal/WindowSnap \
  -thin arm64 \
  -output WindowSnap-arm64

# Extract x86_64
lipo .build/universal/WindowSnap \
  -thin x86_64 \
  -output WindowSnap-x86_64
```

### Custom Build Configuration

```bash
# Debug build (with symbols)
swift build --arch arm64 --arch x86_64

# Release build with optimizations
swift build -c release --arch arm64 --arch x86_64
```

---

## Continuous Integration

### GitHub Actions Example

```yaml
name: Build Universal Binary

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3
      - name: Build Universal Binary
        run: |
          cd WindowSnap
          ./scripts/build-universal.sh
      - name: Upload Artifact
        uses: actions/upload-artifact@v3
        with:
          name: WindowSnap-Universal
          path: WindowSnap/.build/universal/WindowSnap
```

---

## Support

For issues or questions:
- Check troubleshooting section above
- Open an issue on GitHub
- Review build logs for specific errors

---

## Version History

- **v1.2.0** - Added universal binary build scripts
- **v1.1.0** - Original single-architecture build
