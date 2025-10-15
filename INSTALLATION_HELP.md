# 🔒 WindowSnap Security Warning - Quick Fix

When you try to open WindowSnap for the first time, you'll see this:

```
"WindowSnap.app" Not Opened

Apple could not verify "WindowSnap.app" is free of 
malware that may harm your Mac or compromise your privacy.

[Done]  [Move to Bin]
```

## ✅ This is NORMAL and the app is SAFE

The warning appears because WindowSnap isn't signed with an Apple Developer certificate (costs $99/year). This is common for free, open-source apps.

---

## 🚀 How to Open WindowSnap

### ⭐ Method 1: Right-Click Open (Easiest - 10 seconds)

1. **Right-click** (or Control+click) on `WindowSnap.app`
2. Select **"Open"** from the menu  
3. A different dialog appears - click **"Open"** again
4. ✅ Done! The app will launch and macOS remembers this choice forever

**Screenshot walkthrough:**
```
Step 1: Right-click          Step 2: Different dialog appears
┌─────────────────┐         ┌────────────────────────────────┐
│ Open            │  →      │ "WindowSnap.app" is from an    │
│ Show in Finder  │         │ unidentified developer.        │
│ Move to Bin     │         │ Are you sure you want to open? │
│ Get Info        │         │                                 │
│ ...             │         │    [Cancel]      [Open] ← Click │
└─────────────────┘         └────────────────────────────────┘
```

---

### Method 2: System Settings (macOS Ventura+ only)

1. Try to open WindowSnap normally (double-click) - it will be blocked
2. Open **System Settings** → **Privacy & Security**
3. Scroll down to the "Security" section
4. You'll see: *"WindowSnap.app" was blocked from use because it is not from an identified developer*
5. Click **"Open Anyway"** next to this message
6. Try opening WindowSnap again - a dialog appears
7. Click **"Open"** in the dialog

---

### Method 3: Terminal Command (Advanced)

Open Terminal and paste:
```bash
xattr -d com.apple.quarantine /Applications/WindowSnap.app
```

This removes the "quarantine" flag macOS adds to downloaded apps.

---

## ❓ Why Does This Happen?

Apple's **Gatekeeper** protects users by requiring apps to be:
1. **Code signed** with a Developer ID certificate
2. **Notarized** by Apple (uploaded for malware scan)

WindowSnap is open source - you can verify the code yourself on GitHub. Many developers don't pay $99/year for Apple's developer program, especially for free apps.

---

## 🎯 After Opening Once

You only need to do this **once**. After using the right-click method:
- ✅ WindowSnap launches normally every time
- ✅ You can open it from Applications
- ✅ It can launch at login automatically
- ✅ macOS remembers your choice

---

## 🛠️ For Developers

If you're distributing WindowSnap and want to eliminate this warning:

1. **Get Apple Developer account** ($99/year)
2. **Sign & notarize** the app:
   ```bash
   export CODESIGN_ID="Developer ID Application: ..."
   export NOTARY_PROFILE="your-profile"
   bash scripts/sign-and-notarize.sh
   ```

See [DISTRIBUTION_GUIDE.md](DISTRIBUTION_GUIDE.md) for complete instructions.

---

## 🆘 Still Having Issues?

### The right-click menu doesn't show "Open"
- Try Control+click instead of right-click
- Make sure you're clicking the `.app` file, not a folder
- Restart your Mac and try again

### "Open Anyway" button is grayed out
- Click the lock icon 🔒 and enter your password first
- You need admin privileges to open unsigned apps

### App crashes after opening
- This is a different issue - not related to the security warning
- Check: System Settings → Privacy & Security → Accessibility
- Add WindowSnap to the list and enable it

---

**Need more help?** Open an issue on GitHub with:
- Your macOS version (System Settings → General → About)
- Screenshot of the error
- What you tried already

