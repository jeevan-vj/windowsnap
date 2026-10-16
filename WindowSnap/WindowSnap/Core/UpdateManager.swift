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
        
        AppLog.updates.info("Sparkle automatic updates enabled")
        #else
        AppLog.updates.info("Sparkle unavailable; automatic updates disabled")
        #endif
    }
    
    func checkForUpdates() {
        #if canImport(Sparkle)
        updaterController?.checkForUpdates(nil)
        #else
        AppLog.updates.info("Update check skipped because Sparkle is unavailable")
        #endif
    }
    
    func checkForUpdatesInBackground() {
        #if canImport(Sparkle)
        updaterController?.updater.checkForUpdatesInBackground()
        #else
        AppLog.updates.debug("Background update check skipped because Sparkle is unavailable")
        #endif
    }
}


