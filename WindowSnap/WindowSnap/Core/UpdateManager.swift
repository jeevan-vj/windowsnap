import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

final class UpdateManager {
    static let shared = UpdateManager()
    
    #if canImport(Sparkle)
    private var updaterController: SPUStandardUpdaterController?
    #endif
    
    private init() {}
    
    func initialize() {
        #if canImport(Sparkle)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Check for updates periodically (default is every 24 hours)
        updaterController?.updater.checkForUpdatesInBackground()
        
        print("UpdateManager initialized - Sparkle auto-update enabled")
        #else
        print("UpdateManager initialized - Sparkle module unavailable; auto-update disabled")
        #endif
    }
    
    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController?.checkForUpdates(nil)
        #else
        print("Check for updates skipped - Sparkle module unavailable")
        #endif
    }
    
    func checkForUpdatesInBackground() {
        #if canImport(Sparkle)
        updaterController?.updater.checkForUpdatesInBackground()
        #else
        print("Background update check skipped - Sparkle module unavailable")
        #endif
    }
}



