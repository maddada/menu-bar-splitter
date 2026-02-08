# Build & Release

## Prerequisites

- Xcode with Developer ID Application certificate installed
- Notarization credentials stored in keychain:
  ```bash
  xcrun notarytool store-credentials "notarytool-profile" --apple-id "YOUR_APPLE_ID" --team-id "KTKP595G3B" --password "YOUR_APP_SPECIFIC_PASSWORD"
  ```
- `ExportOptions.plist` in the project root (already committed)

## Build & Install Locally

```bash
xcodebuild -project "Menu Bar Splitter.xcodeproj" -scheme "Menu Bar Splitter" -configuration Release archive -archivePath /tmp/MenuBarSplitter.xcarchive && \
xcodebuild -exportArchive -archivePath /tmp/MenuBarSplitter.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath /tmp/MenuBarSplitterExport && \
cp -R "/tmp/MenuBarSplitterExport/Menu Bar Splitter.app" /Applications/
```

## Publish a New Release

1. **Bump the version** in `Menu Bar Splitter.xcodeproj/project.pbxproj` (search for `MARKETING_VERSION`).

2. **Archive and export:**
   ```bash
   xcodebuild -project "Menu Bar Splitter.xcodeproj" -scheme "Menu Bar Splitter" -configuration Release archive -archivePath /tmp/MenuBarSplitter.xcarchive && \
   xcodebuild -exportArchive -archivePath /tmp/MenuBarSplitter.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath /tmp/MenuBarSplitterExport
   ```

3. **Notarize and staple:**
   ```bash
   ditto -c -k --sequesterRsrc --keepParent "/tmp/MenuBarSplitterExport/Menu Bar Splitter.app" /tmp/MenuBarSplitter.zip && \
   xcrun notarytool submit /tmp/MenuBarSplitter.zip --keychain-profile "notarytool-profile" --wait && \
   xcrun stapler staple "/tmp/MenuBarSplitterExport/Menu Bar Splitter.app"
   ```

4. **Re-zip with stapled ticket and get the SHA:**
   ```bash
   rm /tmp/MenuBarSplitter.zip && \
   ditto -c -k --sequesterRsrc --keepParent "/tmp/MenuBarSplitterExport/Menu Bar Splitter.app" /tmp/MenuBarSplitter.zip && \
   shasum -a 256 /tmp/MenuBarSplitter.zip
   ```

5. **Commit, push, and create GitHub release:**
   ```bash
   git add -A && git commit -m "chore: bump version to vX.Y" && git push origin master
   gh release create vX.Y /tmp/MenuBarSplitter.zip --repo maddada/menu-bar-splitter --title "vX.Y" --notes "Release notes here"
   ```

6. **Update Homebrew tap** — in the [homebrew-tap](https://github.com/maddada/homebrew-tap) repo, edit `Casks/menu-bar-splitter.rb`:
   - Set `version` to the new version
   - Set `sha256` to the hash from step 4
   - Commit and push

## Install via Homebrew

```bash
brew install --cask maddada/tap/menu-bar-splitter
```
