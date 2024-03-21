import Foundation
import TAdManager_iOS
import AppLovinSDK

class AdManager {
    static func initial(_ T: WHAdLocation.Type, adFeatureLogic: AdFeatureLogic) {
        TAdManager.shared = TAdManager(dynamicAdLocationType: T.self, adFeaturelogic: adFeatureLogic)
        MaxManager.initial() {
            startLoadAd()
        }
    }
    
    static func startLoadAd() {
        TAdManager.shared.setHandleBannerAction(handleBannerAction: handleBannerAction(tuple:))
        TAdManager.shared.initialAfterAdManager()
        TAdManager.shared.setShowLog(isEnable: false)
    }
    
    static func loadAd(isSubscribe: Bool? = nil, adLocation: WHAdLocation, logParam: Any? = nil, beforeAction: (() -> Void)? = nil, specialCondition: (() -> Bool)? = nil, adOptions: [WHAdOption] = [], playCompletion: ((WHAdResult) -> ())? = nil) {
        TAdManager.shared.loadAd(isSubscribe: false, adLocation: adLocation, logParam: logParam, beforeAction: beforeAction, specialCondition: specialCondition, adOptions: adOptions, playCompletion: playCompletion)
    }
    
    static func getAdLocation(_ adLocation: TestAdLocation.AdLocation) -> TestAdLocation {
        return TestAdLocation(adLocation)
    }
    
    static func handleBannerAction(tuple: (loader: Any?, hasBindWeak: Bool?)) -> UIView? {
        switch tuple.loader {
        case let view as MAAdView:
            guard let hasBinkWeak = tuple.hasBindWeak, hasBinkWeak else {
                view.stopAutoRefresh()
                return view
            }
            view.startAutoRefresh()
            return view
        default:
            return nil
        }
    }
}
