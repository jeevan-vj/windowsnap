# Creating Developer ID Certificate

## Steps in Xcode

1. **In the "Signing certificates" dialog you have open:**
   - Click the **"+"** button (bottom left, with dropdown arrow)

2. **Select certificate type:**
   - Choose **"Developer ID Application"** from the dropdown
   - This is for distribution outside the App Store

3. **Xcode will automatically:**
   - Create the certificate
   - Download it to your keychain
   - It will appear in the list

4. **For App Store distribution (optional):**
   - Click "+" again
   - Select **"Apple Distribution"**

## After Creating

Once the Developer ID certificate is created, rebuild your release:

```bash
bash scripts/build-adhoc-release.sh
```

The script will automatically detect and use the Developer ID certificate instead of the development one.

## Verify Certificate

After creating, verify it exists:

```bash
security find-identity -v -p codesigning | grep "Developer ID"
```

You should see:
```
Developer ID Application: Your Name (TEAMID)
```



