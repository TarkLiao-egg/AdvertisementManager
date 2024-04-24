import Foundation
import AppLovinSDK
import TAdManager_iOS

class AdFeatureLogic_10: AdFeatureLogic {
    func prepareAd(manager: TAdManager) {
        manager.loadAd(isSubscribe: false, adLocation: TestAdLocation(.locationBanner))
        manager.loadAd(isSubscribe: false, adLocation: TestAdLocation(.locationReward))
    }
    
    func getSource(adLocation: WHAdLocation) -> WHAdSource {
        switch adLocation {
        default:
            return MaxManager()
        }
    }
    
    func getUnitIDs(source: WHAdSource, adLocation: WHAdLocation) -> [String] {
        var ids = [String]()
        let adLocation = TestAdLocation.AdLocation(rawValue: adLocation.adLocationStr)
        switch adLocation {
        case .locationBanner:
            ids.append(contentsOf: [
                "adunitID"
            ])
        case .locationReward:
            ids.append(contentsOf: [
                "adunitID"
            ])
        case .none:
            break
        }
        return ids
    }
    
    func logLoadAd(adLocation: WHAdLocation) {
        let adStyle = getAdStyle(adLocation: adLocation)
        let adLocation = TestAdLocation.AdLocation(rawValue: adLocation.adLocationStr)
        switch adStyle {
        case .reward:
            break
        case .native:
            break
        case .banner:
            break
        case .interstitial:
            break
        case .rewardInterstitial:
            break
        }
    }
    
    func logShouldShowAd(adLocation: WHAdLocation, logParam: Any?) {
        let adStyle = getAdStyle(adLocation: adLocation)
        let adLocation = TestAdLocation.AdLocation(rawValue: adLocation.adLocationStr)
    }
    
    func logShowAd(adLocation: WHAdLocation, logParam: Any?) {
        let adStyle = getAdStyle(adLocation: adLocation)
        let adLocation = TestAdLocation.AdLocation(rawValue: adLocation.adLocationStr)
    }
    
    func logReward(adLocation: WHAdLocation, logParam: Any?) {
        let adStyle = getAdStyle(adLocation: adLocation)
        if adStyle == .reward {
            let adLocation = TestAdLocation.AdLocation(rawValue: adLocation.adLocationStr)
        }
    }

    func logClickAd(adLocation: WHAdLocation, logParam: Any?) {
        let adLocation = TestAdLocation.AdLocation(rawValue: adLocation.adLocationStr)
    }
    
    func logFullScreenAdEnd(adLocation: WHAdLocation, logParam: Any?) {
        let adLocation = TestAdLocation.AdLocation(rawValue: adLocation.adLocationStr)
    }
    
    func getAdStyle(adLocation: WHAdLocation) -> WHAdStyle {
        let adLocation = TestAdLocation.AdLocation(rawValue: adLocation.adLocationStr)
        switch adLocation {
        case .locationReward:
            return .reward
            
        case .locationBanner:
            return .banner
        case .none:
            return .banner
        }
    }
}

extension AdFeatureLogic_10 {
    func renderAdToAdView(adLocation: WHAdLocation, loader: Any?, ad: Any?) -> UIView? {
        let adLocation = TestAdLocation.AdLocation(rawValue: adLocation.adLocationStr)
        guard let loader = loader, let ad = ad else { return nil }
        guard let loader = loader as? MANativeAdLoader,
              let ad = ad as? MAAd else { return nil }
        switch adLocation {
        default:
            return nil
        }
    }
    
    func getMaxNativeUI(xibName: String) -> MANativeAdView? {
        let nativeAdViewNib = UINib(nibName: xibName, bundle: Bundle.main)
        let nativeAdView = nativeAdViewNib.instantiate(withOwner: nil, options: nil).first! as! MANativeAdView?
        
        let adViewBinder = MANativeAdViewBinder(builderBlock: { (builder) in
            builder.titleLabelTag = 1001
            builder.advertiserLabelTag = 1002
            builder.bodyLabelTag = 1003
            builder.iconImageViewTag = 1004
            builder.optionsContentViewTag = 1005
            builder.mediaContentViewTag = 1006
            builder.callToActionButtonTag = 1007
            //builder.starRatingContentViewTag = 1008
        })
        nativeAdView?.bindViews(with: adViewBinder)
        return nativeAdView
    }
}
