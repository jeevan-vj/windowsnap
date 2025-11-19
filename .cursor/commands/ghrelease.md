Create a new GitHub release with the latest build. Follow these steps:

1. **Build the universal app bundle:**

   - Navigate to WindowSnap directory
   - Run `bash scripts/build-universal-bundle.sh` to build the universal binary (ARM64 + Intel)
   - This creates `dist/WindowSnap.app` and `dist/WindowSnap.zip`

2. **Create the DMG package:**

   - Run `bash scripts/package_dmg.sh` to create the disk image
   - If the script fails or leaves a read-write DMG, complete the conversion:
     - Detach any mounted volumes: `hdiutil detach /Volumes/WindowSnap 2>/dev/null; hdiutil detach "/Volumes/WindowSnap 1" 2>/dev/null; hdiutil detach "/Volumes/WindowSnap 2" 2>/dev/null; hdiutil detach "/Volumes/WindowSnap 3" 2>/dev/null`
     - Convert to compressed DMG: `hdiutil convert dist/WindowSnap-rw.dmg -format UDZO -imagekey zlib-level=9 -o dist/WindowSnap.dmg`
     - Clean up: `rm -f dist/WindowSnap-rw.dmg`

3. **Determine the next version:**

   - Get the latest GitHub release tag: `gh release list --limit 1`
   - Extract the version number (e.g., v1.2.5)
   - Increment the patch version (e.g., v1.2.5 → v1.2.6)
   - If no releases exist, start with v1.0.0

4. **Generate release notes:**

   - Check recent git commits: `git log --oneline -10`
   - Look for meaningful changes since the last release
   - Create release notes highlighting:
     - New features
     - Bug fixes
     - UI improvements
     - Other notable changes

5. **Create the GitHub release:**

   - Use `gh release create` with:
     - Version tag (e.g., `v1.2.6`)
     - Title: `v1.2.6 - [Brief description]`
     - Release notes with markdown formatting
     - Attach both packages: `WindowSnap/dist/WindowSnap.dmg` and `WindowSnap/dist/WindowSnap.zip`
   - Example command:
     ```bash
     gh release create v1.2.6 \
       --title "v1.2.6 - [Feature Description]" \
       --notes "## What's New\n\n- Feature 1\n- Feature 2\n\n## Downloads\n\n- **WindowSnap.dmg** - Disk image for easy installation\n- **WindowSnap.zip** - Zip archive\n\nBoth packages include universal binaries supporting Apple Silicon (M1/M2/M3/M4) and Intel Macs." \
       WindowSnap/dist/WindowSnap.dmg \
       WindowSnap/dist/WindowSnap.zip
     ```

6. **Verify the release:**
   - Check that the release was created: `gh release list --limit 1`
   - Confirm both packages are attached and the release is published

**Important notes:**

- Always build fresh packages before creating a release
- Ensure the DMG is properly compressed (not the read-write version)
- Both packages should be universal binaries (check with `lipo -info`)
- The release will be published immediately (not as a draft)
