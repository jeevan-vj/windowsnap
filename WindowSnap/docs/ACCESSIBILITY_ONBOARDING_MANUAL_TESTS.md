# Accessibility onboarding manual verification

These checks exercise macOS TCC behavior that cannot be simulated reliably by unit tests. Run them with a bundled build of WindowSnap on each supported major macOS version (macOS 13 and later).

## Preparation

1. Quit WindowSnap.
2. Reset the app's Accessibility decision when a clean state is required:

   ```sh
   tccutil reset Accessibility com.windowsnap.app
   ```

3. Remove `HasCompletedAccessibilityOnboarding` from the app's preferences, or test with a fresh macOS user account.

Do not reset TCC on a machine where preserving the current permission decision is important.

## Clean-install and grant path

1. Launch WindowSnap with Accessibility not granted.
2. Confirm the WindowSnap explanation appears before any macOS permission prompt.
3. Confirm the copy says WindowSnap moves and resizes application windows, works locally, and requires no account.
4. Confirm the initial state is **Not granted** and **Finish Setup** is disabled.
5. Confirm neither Screen Recording nor Input Monitoring is requested.
6. Choose **Enable Accessibility** and confirm this explicit click is what triggers the macOS prompt.
7. Grant access in System Settings and return to WindowSnap without relaunching it.
8. Confirm the state changes to **Granted** and **Finish Setup** becomes available.
9. Focus another app and press ⌘⇧←. Confirm its window snaps to the left half, then use the test confirmation in onboarding.
10. Finish setup, relaunch WindowSnap, and confirm onboarding does not reappear.

## Deny and retry path

1. Start again from a reset Accessibility decision and incomplete onboarding state.
2. Choose **Enable Accessibility**, then deny or dismiss the macOS prompt.
3. Confirm WindowSnap remains running in the menu bar and onboarding continues to show **Not granted**.
4. Choose **Not Now** and confirm the onboarding closes without quitting or blocking the menu.
5. Open the menu-bar menu and choose **Accessibility Setup…**.
6. Confirm onboarding reopens and **Open System Settings** opens Privacy & Security > Accessibility.
7. Enable WindowSnap in System Settings, return to the app, and confirm the state refreshes to **Granted** without relaunching.

## Existing-user path

1. Grant WindowSnap Accessibility access before launch and clear only the onboarding-completion preference.
2. Launch WindowSnap.
3. Confirm onboarding is not presented and snapping shortcuts remain available.
4. Confirm **Accessibility Setup…** remains available from the menu for status review or troubleshooting.

## Optional-permission isolation

1. With Screen Recording and Input Monitoring reset, launch WindowSnap and complete or dismiss Accessibility onboarding.
2. Confirm neither optional permission is requested during launch or Accessibility onboarding.
3. Invoke Region Share and confirm Screen Recording is requested only from that feature flow.
4. With Text Expander disabled, confirm Input Monitoring is not requested. Enable or use Text Expander and confirm its permission guidance appears only then.

Record the macOS version, architecture, build identifier, and result for each path in the release checklist or pull request.
