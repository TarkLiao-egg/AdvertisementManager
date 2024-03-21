import Foundation
import AppLovinSDK
import TAdManager_iOS

struct MaxError: Error {
    var localizedDescription: String
}

class MaxManager: NSObject, WHAdSource {
    public var loader: Any?
    var sourceResult: ((WHAdSourceResult) -> Void)?
    var getRewarded: (() -> Void)?
    var notReload: Bool = false // for openAd
    var reloadWhenHide: Bool = false // for Reward
    public var isPlay: Bool = false
    var retryCount: Int = 0
    var adStyle: WHAdStyle = .interstitial
    var waitingRevenue = false
    
    static func initial(isFirst: Bool = false, completion: @escaping () -> Void) {
        if isFirst {
            guard UserDefaults.standard.object(forKey: "kIsAttAllowed") == nil else {
                completion()
                return
            }
        } else {
            guard let _ = UserDefaults.standard.object(forKey: "kIsAttAllowed") else { return }
        }
        let config = getConfig()
        setSDK(config: config, completion: completion)
    }
    
    static func getConfig() -> ALSdkInitializationConfiguration {
        let initConfig = ALSdkInitializationConfiguration(sdkKey: "sdk-key") { builder in
            builder.mediationProvider = ALMediationProviderMAX
//            builder.settings.termsAndPrivacyPolicyFlowSettings.isEnabled = true
//            builder.settings.termsAndPrivacyPolicyFlowSettings.termsOfServiceURL = URL(string: "")
//            builder.settings.termsAndPrivacyPolicyFlowSettings.privacyPolicyURL = URL(string: "")
        }
        return initConfig
    }
    
    static func setSDK(config: ALSdkInitializationConfiguration, completion: @escaping () -> Void) {
        ALSdk.shared()?.initialize(with: config, completionHandler: { (configuration: ALSdkConfiguration) in
            UserDefaults.standard.set(configuration.consentFlowUserGeography == .GDPR, forKey: "kisGDPRCheck")
            switch configuration.appTrackingTransparencyStatus {
            case .notDetermined:
                break
            case .authorized:
                break
            default:
                break
            }
            completion()
        })
    }
    
    public func playFullScreenAd(ad: Any?, hasBindWeak: (() -> Bool)?, getRewarded: (() -> Void)? = nil, playSuccessAction: (() -> Void)?) {
        if let ad = loader as? MARewardedAd {
            self.getRewarded = getRewarded
            if ad.isReady {
                if let hasBindWeak = hasBindWeak, hasBindWeak() {
                    ad.show()
                    playSuccessAction?()
                }
            } else {
                TAdManager.shared.showLog("Ad not ready")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.playFullScreenAd(ad: ad, hasBindWeak: hasBindWeak, getRewarded: getRewarded, playSuccessAction: playSuccessAction)
                }
            }
        } else if let ad = loader as? MAInterstitialAd {
            if ad.isReady {
                if let hasBindWeak = hasBindWeak, hasBindWeak() {
                    ad.show()
                    playSuccessAction?()
                }
            } else {
                TAdManager.shared.showLog("Ad not ready")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.playFullScreenAd(ad: ad, hasBindWeak: hasBindWeak, getRewarded: getRewarded, playSuccessAction: playSuccessAction)
                }
            }
        } else if let ad = loader as? MAAppOpenAd {
            if ad.isReady {
                if let hasBindWeak = hasBindWeak, hasBindWeak() {
                    ad.show()
                    playSuccessAction?()
                }
            } else {
                TAdManager.shared.showLog("Ad not ready")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.playFullScreenAd(ad: ad, hasBindWeak: hasBindWeak, getRewarded: getRewarded, playSuccessAction: playSuccessAction)
                }
            }
        } else {
            self.getRewarded = nil
            TAdManager.shared.showLog("Pare ad error")
        }
    }
    
    public func loadOpenAd(id: String, sourceResult: ((WHAdSourceResult) -> Void)?) {
        adStyle = .interstitial
        notReload = true
        self.sourceResult = sourceResult
        let openAd = MAAppOpenAd(adUnitIdentifier: id)
        openAd.delegate = self
        openAd.revenueDelegate = self
        openAd.load()
        loader = openAd
    }
    
    public func loadInterstitialAd(id: String, sourceResult: ((WHAdSourceResult) -> Void)?) {
        adStyle = .interstitial
        reloadWhenHide = true
        self.sourceResult = sourceResult
        let interstitial = MAInterstitialAd(adUnitIdentifier: id)
        interstitial.delegate = self
        interstitial.revenueDelegate = self
        interstitial.load()
        loader = interstitial
    }
    
    public func loadRewardAd(id: String, sourceResult: ((WHAdSourceResult) -> Void)?) {
        adStyle = .reward
        reloadWhenHide = true
        self.sourceResult = sourceResult
        let rewarded = MARewardedAd.shared(withAdUnitIdentifier: id)
        rewarded.delegate = self
        rewarded.revenueDelegate = self
        rewarded.load()
        loader = rewarded
    }
    
    public func loadBannerAd(id: String, sourceResult: ((WHAdSourceResult) -> Void)?) {
        adStyle = .banner
        self.sourceResult = sourceResult
        DispatchQueue.main.async { [weak self] in
            let banner = MAAdView(adUnitIdentifier: id)
            banner.delegate = self
            banner.revenueDelegate = self
            banner.loadAd()
            self?.loader = banner
        }
    }
    
    public func loadNativeAd(id: String, sourceResult: ((WHAdSourceResult) -> Void)?) {
        adStyle = .native
        waitingRevenue = true
        self.sourceResult = sourceResult
        let nativeAdLoader = MANativeAdLoader(adUnitIdentifier: id)
        nativeAdLoader.nativeAdDelegate = self
        nativeAdLoader.revenueDelegate = self
        nativeAdLoader.loadAd()
        loader = nativeAdLoader
    }
    
    public func destroyAd(ad: Any?) {
        if let ad = ad as? MAAd {
            DispatchQueue.main.async { [weak self] in
                (self?.loader as? MANativeAdLoader)?.destroy(ad)
            }
        }
    }
    
    public func bindWeakLost() {
        (loader as? MAAdView)?.stopAutoRefresh()
    }
}

extension MaxManager: MAAdDelegate {
    func didLoad(_ ad: MAAd) {
        sourceResult?(.getAd(ad))
        if notReload {
        } else if reloadWhenHide == false {
            sourceResult?(.canReload)
        }
    }
    
    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        if retryCount >= TAdManager.shared.retryCount {
            retryCount = 0
            TAdManager.shared.showLog("didFailToLoadAd: \(adUnitIdentifier) " + error.message)
            sourceResult?(.failure(AdvertisementError(code: error.code.rawValue, msg: error.message)))
            sourceResult?(.canReload)
        } else {
            TAdManager.shared.showLog("didFailToLoadAd: \(adUnitIdentifier) retry: \(retryCount) " + error.message)
            sourceResult?(.failure(AdvertisementError(code: error.code.rawValue, msg: error.message)))
            sourceResult?(.doReload)
        }
        retryCount += 1
    }
    
    func didDisplay(_ ad: MAAd) {
        TAdManager.shared.showLog(#function)
        if let _ = loader as? MAAdView {
            
        } else {
            isPlay = true
        }
    }
    
    func didHide(_ ad: MAAd) {
        isPlay = false
        print(#function)
        if reloadWhenHide {
            sourceResult?(.canReload)
            sourceResult?(.doReload)
        }
    }
    
    func didClick(_ ad: MAAd) {
        TAdManager.shared.showLog(#function)
        sourceResult?(.click)
    }
    
    func didFail(toDisplay ad: MAAd, withError error: MAError) {
        TAdManager.shared.showLog(#function + error.description)
        sourceResult?(.failure(AdvertisementError(code: error.code.rawValue, msg: error.mediatedNetworkErrorMessage)))
        sourceResult?(.canReload)
        sourceResult?(.doReload)
    }
}

extension MaxManager: MARewardedAdDelegate { // MARK: reward
    func didRewardUser(for ad: MAAd, with reward: MAReward) {
        getRewarded?()
    }
    
}

extension MaxManager: MAAdViewAdDelegate { // MARK: Banner
    func didExpand(_ ad: MAAd) {
        print(#function)
    }
    
    func didCollapse(_ ad: MAAd) {
        print(#function)
    }
    
}

extension MaxManager: MANativeAdDelegate { // MARK: Native
    func didLoadNativeAd(_ maxNativeAdView: MANativeAdView?, for ad: MAAd) {
        sourceResult?(.getAd(ad))
        if notReload {
            
        } else if reloadWhenHide == false && waitingRevenue == false {
            sourceResult?(.canReload)
        }
    }
    
    func didFailToLoadNativeAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        if retryCount >= TAdManager.shared.retryCount {
            retryCount = 0
            sourceResult?(.failure(AdvertisementError(code: error.code.rawValue, msg: error.message)))
            sourceResult?(.canReload)
        } else {
            TAdManager.shared.showLog("didFailToLoadAd: \(adUnitIdentifier) retry \(retryCount)")
            sourceResult?(.doReload)
        }
        retryCount += 1
    }
    
    public func didClickNativeAd(_ ad: MAAd) {
        print(#function)
        sourceResult?(.click)
    }
}


extension MaxManager: MAAdRevenueDelegate {
    func didPayRevenue(for ad: MAAd) {
//        LogManager_pbn10.logSingularAdRevenue(adSource: MaxManager.self,
//                                                     revenueAmount: ad.revenue,
//                                                     currencyCode: "USD", networkName: ad.networkName,
//                                                     adUnitIdentifier: ad.adUnitIdentifier,
//                                                     format: ad.format.label)
//        if waitingRevenue {
//            sourceResult?(.canReload)
//            sourceResult?(.doReload)
//        }
    }
}
