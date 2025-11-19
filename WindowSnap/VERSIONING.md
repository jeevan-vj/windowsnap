# Semantic Versioning for WindowSnap

WindowSnap uses [Semantic Versioning](https://semver.org/) (SemVer) for version management.

## Version Format

Versions follow the format: `MAJOR.MINOR.PATCH`

- **MAJOR**: Incremented for incompatible API changes
- **MINOR**: Incremented for backwards-compatible functionality additions
- **PATCH**: Incremented for backwards-compatible bug fixes

Optional pre-release and build metadata are supported:
- `1.2.0-alpha.1` (pre-release)
- `1.2.0+build.123` (build metadata)

## Version Management

### Current Version

The current version is stored in `WindowSnap/VERSION`:

```bash
cat WindowSnap/VERSION
```

### Bumping Versions

Use the `bump-version.sh` script to increment versions:

```bash
# Bump patch version (1.2.0 → 1.2.1)
./WindowSnap/scripts/bump-version.sh patch

# Bump minor version (1.2.0 → 1.3.0)
./WindowSnap/scripts/bump-version.sh minor

# Bump major version (1.2.0 → 2.0.0)
./WindowSnap/scripts/bump-version.sh major
```

The script will:
1. Update `WindowSnap/VERSION`
2. Update `WindowSnap/WindowSnap/App/Info.plist` (CFBundleShortVersionString)
3. Display next steps for committing and tagging

### Manual Version Updates

You can also manually edit `WindowSnap/VERSION`:

```bash
echo "1.3.0" > WindowSnap/VERSION
```

## Build Process

All build scripts automatically read from `WindowSnap/VERSION`:

- `build_bundle.sh`
- `build-universal-bundle.sh`
- `distribute.sh`

The build number (`CFBundleVersion`) is automatically generated:
- Uses git commit count if in a git repository
- Falls back to timestamp format (`YYYYMMDDHHMMSS`) otherwise

## Git Integration

### Tagging Releases

After bumping the version, create a git tag:

```bash
# After bumping version
git add WindowSnap/VERSION WindowSnap/WindowSnap/App/Info.plist
git commit -m "Bump version to 1.3.0"
git tag -a v1.3.0 -m "Release v1.3.0"
git push origin main --tags
```

### Checking Version from Git

You can check the current version from git tags:

```bash
git describe --tags --abbrev=0  # Latest tag
git describe --tags              # Latest tag with commit info
```

## Version in App Bundle

The version appears in:
- `CFBundleShortVersionString`: Semantic version (from VERSION file)
- `CFBundleVersion`: Build number (git commit count or timestamp)

You can check the version of a built app:

```bash
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" dist/WindowSnap.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" dist/WindowSnap.app/Contents/Info.plist
```

## Best Practices

1. **Always bump version before release**: Use `bump-version.sh` before building for distribution
2. **Tag releases**: Create git tags for each release version
3. **Follow SemVer**: 
   - Patch for bug fixes
   - Minor for new features (backwards compatible)
   - Major for breaking changes
4. **Update changelog**: Document changes in release notes when bumping versions

