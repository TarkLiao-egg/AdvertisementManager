import Foundation
import TAdManager_iOS
import AppLovinSDK

class AdManager {
    static let shared = AdManager()
    var ads: [(isSubscribe: Bool?, adLocation: WHAdLocation, logParam: Any?, beforeAction: (() -> Void)?, specialCondition: (() -> Bool)?, adOptions: [WHAdOption], playCompletion: ((WHAdResult) -> ())?)] = []
    var isReady = false
    
    static func initial(_ T: WHAdLocation.Type, adFeatureLogic: AdFeatureLogic) {
        TAdManager.shared = TAdManager(dynamicAdLocationType: T.self, adFeaturelogic: adFeatureLogic)
        MaxManager.initial() {
            shared.isReady = true
            startLoadAd()
            for ad in shared.ads {
                Self.loadAd(isSubscribe: ad.isSubscribe, adLocation: ad.adLocation, logParam: ad.logParam, beforeAction: ad.beforeAction, specialCondition: ad.specialCondition, adOptions: ad.adOptions, playCompletion: ad.playCompletion)
            }
        }
    }
    
    static func startLoadAd() {
        TAdManager.shared.setShowLog(isEnable: false)
        TAdManager.shared.setHandleBannerAction(handleBannerAction: handleBannerAction(tuple:))
        TAdManager.shared.initialAfterAdManager()
    }
    
    static func loadAd(isSubscribe: Bool? = nil, adLocation: WHAdLocation, logParam: Any? = nil, beforeAction: (() -> Void)? = nil, specialCondition: (() -> Bool)? = nil, adOptions: [WHAdOption] = [], playCompletion: ((WHAdResult) -> ())? = nil) {
        if shared.isReady == false {
            shared.ads.append((isSubscribe: isSubscribe, adLocation: adLocation, logParam: logParam, beforeAction: beforeAction, specialCondition: specialCondition, adOptions: TAdManager.getHandleAdOption(adOptions), playCompletion: playCompletion))
            return
        }
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
