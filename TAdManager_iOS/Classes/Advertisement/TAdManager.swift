import UIKit
import Combine
/**
 AdvertisementManager：Ad流程
 WHAdTask：1個WHAdLocation對應1個WHAdTask，根據該 WHAdLocation 的 id 數量產生 同數量的 AdLevelObject。 一次對底下所有AdLevelObject進行Load Ad，且在AdLoadFlowLogic處理結果
 AdLevelObject：儲存 AdUnitID、ad 及管理 AdSource(AdMob, Max...)，實際 Load Ad，並儲存從AdSource load到的結果
 AdLoadFlowLogic：處理 Load Ad 結果流程
 AdFeatureLogic：定義Ad邏輯
 AdTransfer：將Ad物件轉成實際可使用的UIView
*/

public class TAdManager: NSObject {
    enum AdTaskStatus {
        case existAdAndPlay
        case noAdAndPlay
        case prepare
    }
    
    public static var shared: TAdManager!
    public let retryCount = 3
    public let forceAdRequestPeriod: TimeInterval = TimeInterval(30)
    private var defaultRefreshPeriod = 25
    private let adFeaturelogic: AdFeatureLogic
    private var adTaskDics: [String: WHAdTask] = [:]
    private var unitIdDics: [String: AdLevelObject] = [:] //每個Ad UnitID對應一組AdLevelObject，為共用ID所使用
    private(set) var segementedRefresh: Int = 1
    private var showLog: Bool = false
    let dynamicAdLocationType: WHAdLocation.Type
    private var handleBannerAction: (((loader: Any?, hasBindWeak: Bool?)) -> UIView?)?
    
    public init(dynamicAdLocationType: WHAdLocation.Type, adFeaturelogic: AdFeatureLogic) {
        self.dynamicAdLocationType = dynamicAdLocationType
        self.adFeaturelogic = adFeaturelogic
    }
    
    public func initialAfterAdManager() {
        adFeaturelogic.prepareAd(manager: TAdManager.shared)
    }
    
    public func showLog(_ msg: String) {
        #if DEBUG
        let debug = showLog
        #else
        let debug = false
        #endif
        if debug {
            print("AdLog", msg)
        }
    }
    
    public func setShowLog(isEnable: Bool) {
        showLog = isEnable
    }
    
    public func setRefreshPeriod(period: Int) {
        defaultRefreshPeriod = period
    }
    
    public func getRefreshPeriod() -> Int {
        return defaultRefreshPeriod
    }
    
    public func setSegementedRefresh(_ segemented: Int) {
        segementedRefresh = segemented
    }
    
    public func getSegementedRefresh() -> Int {
        return segementedRefresh
    }
    
    public func setHandleBannerAction(handleBannerAction: (((loader: Any?, hasBindWeak: Bool?)) -> UIView?)?) {
        self.handleBannerAction = handleBannerAction
    }
}

extension TAdManager {
    /**
     params
     AdLocation：廣告位置
     AdOption：多功能設定，請看定義
     playCompletion： 若宣告則會播放廣告，否則只預加載
     */
    public func loadAd(isSubscribe: Bool, adLocation: WHAdLocation, logParam: Any? = nil, beforeAction: (() -> Void)? = nil, specialCondition: (() -> Bool)? = nil, adOptions: [WHAdOption] = [], playCompletion: ((WHAdResult) -> ())? = nil) {
        guard String(describing: dynamicAdLocationType) == String(describing: type(of: adLocation)) else {
            playCompletion?(.showAd(nil))
            playCompletion?(.reward)
            return
        }
        
        // if subscibe then end, for preLoad ad
        if isSubscribe { return }
        
        // 重組出符合AdLocation的WHAdTask
        let tuple = adFeaturelogic.newOrGetExistWHAdObj(adLocation: adLocation, logParam: logParam, whAdObj: adTaskDics[adLocation.adLocationStr], unitIdDics: unitIdDics, playCompletion: playCompletion)
        adTaskDics[adLocation.adLocationStr] = tuple.whAdObj
        unitIdDics = tuple.unitIdDics
        
        guard let whAdTask = adTaskDics[adLocation.adLocationStr] else { return }
        guard whAdTask.adLevelObjects.count > 0 else {
            playCompletion?(.showAd(nil))
            playCompletion?(.reward)
            return
        }
        beforeAction?()
        
        // 處理AdOptions
        var optionDic: [WHAdOption: Any] = [:]
        for adOption in adOptions {
            switch adOption {
            case .refreshBannerWeak(let refreshTargetWeak, let isUseRemote): // refresh的生命週期會根據父物件refreshTargetWeak來開/關
                let refreshObj = WHRefreshObject(refreshTargetWeak: refreshTargetWeak, refreshDuration: adFeaturelogic.getRefreshDuration(isUseRemote: isUseRemote))
                refreshObj.refreshAction = { [weak self] in
                    guard let self = self else { return }
                    self.playAdLevelObject(whAdTask: whAdTask, logParam: logParam, optionDic: optionDic, specialCondition: specialCondition, playCompletion: playCompletion) {
                        if let _ = optionDic[.stopReloadAd] { return }  // exist ad, ignore loadAd
                        whAdTask.fillAllAd(optionDic: optionDic)
                    }
                }
                optionDic[.refreshBannerWeak(nil, nil)] = refreshObj
                
            case .bindWeak(let bindTargetWeak):
                let bindTargetWeak = WHBindObject(bindTargetWeak: bindTargetWeak)
                optionDic[.bindWeak(nil)] = bindTargetWeak
                
            case .loadTimeForceQuit(let time):
                optionDic[.loadTimeForceQuit(0)] = time
                
            case .stopReloadAd:
                optionDic[.stopReloadAd] = true
                
            default:
                optionDic[adOption] = true
            }
        }
        for adLevelObject in whAdTask.adLevelObjects {
            adLevelObject.optionDic = optionDic
        }
        
        let adStyle = adFeaturelogic.getAdStyle(adLocation: adLocation)
        switch adStyle {
        case .reward, .interstitial, .rewardInterstitial:
            if adFeaturelogic.isAnyPlaying(playCompletion: playCompletion, unitIdDics: unitIdDics) {
                whAdTask.fillAllAd(optionDic: optionDic)
                TAdManager.shared.showLog("has full screen play")
                playCompletion?(.otherFullScreenPlay)
                return } //如果要求playAd 但任何全頻廣告還在播放則結束
        default: break
        }
        
        if let _ = playCompletion {
            adFeaturelogic.logShouldShowAd(adLocation: adLocation, logParam: logParam)
        }
        
        let taskStatus = adFeaturelogic.getAdTaskStatus(whAdTask: whAdTask, isPlay: playCompletion != nil)
        switch taskStatus {
        case .existAdAndPlay: // 如果有實作play且存在廣告則會立即回傳，回傳完再預加載
            TAdManager.shared.showLog("existAdAndPlay \(adLocation.adLocationStr)")
            
            optionDic[.loadTimeForceQuit(0)] = nil // clear forceQuit because exist Ad
            
            playAdLevelObject(whAdTask: whAdTask, logParam: logParam, optionDic: optionDic, specialCondition: specialCondition, playCompletion: playCompletion) { [weak self] in
                if let _ = optionDic[.stopReloadAd] { // exist ad, ignore loadAd
                    self?.forMaxBannerAction(whAdTask: whAdTask, logParam: logParam, optionDic: optionDic, specialCondition: specialCondition, playCompletion: playCompletion)
                    return
                }
                whAdTask.fillAllAd(optionDic: optionDic)
            }
            
        case .noAdAndPlay: // 如果有實作play，但沒廣告，等待廣告才播放，廣告有播再預加載
            TAdManager.shared.showLog("noAdAndPlay \(adLocation.adLocationStr)")
            if adOptions.contains(.requiredAdExist) { // 必須要有廣告才播放
                TAdManager.shared.showLog("\(adLocation.adLocationStr) requiredAdExist")
                whAdTask.fillAllAd(optionDic: optionDic)
                playCompletion?(.noAdWithAdOption)
                return
            }
            
            whAdTask.fillAllAd(optionDic: optionDic, playAdCompletion: { [weak self] result in
                switch result {
                case .play:
                    self?.playAdLevelObject(whAdTask: whAdTask, logParam: logParam, optionDic: optionDic, specialCondition: specialCondition, playCompletion: playCompletion) {
                        if self?.adFeaturelogic.getAdStyle(adLocation: adLocation) == .banner {
                            playCompletion?(.bannerRefresh)
                        }
                        if let _ = optionDic[.stopReloadAd] { return }  // exist ad, ignore loadAd
                        whAdTask.fillAllAd(optionDic: optionDic)
                    }
                case .checkReload:
                    break
                case .forceQuit:
                    playCompletion?(.forceQuitWithAdOption)
                }
            })
        case .prepare: // 如果沒實作play，就預加載
            whAdTask.fillAllAd(optionDic: optionDic)
        }
    }
}

extension TAdManager {
    func playAdLevelObject(whAdTask: WHAdTask, logParam: Any?, optionDic: [WHAdOption: Any], specialCondition: (() -> Bool)?, playCompletion: ((WHAdResult) -> ())? = nil, completion: (() -> Void)? = nil) {
        if let specialCondition = specialCondition {
            guard specialCondition() else {
                TAdManager.shared.showLog("Special Condition not allow")
                playCompletion?(.specialNotAllow)
                return
            }
        }
        
        let adLevelObj = adFeaturelogic.getExistHighestAd(whAdTask: whAdTask)
        DispatchQueue.main.async { [weak self] in
            self?.handleAdLevelObjectToPlay(adLocation: whAdTask.adLocation, logParam: logParam, adLevelObj: adLevelObj, hasBindWeak: { [weak self] in
                guard let self = self else { return false }
                let hasBindWeak = self.adFeaturelogic.hasBindWeak(optionDic: optionDic)
                if hasBindWeak == false {
                    TAdManager.shared.showLog("\(whAdTask.adLocation.adLocationStr) BindWeak is lost")
                }
                return hasBindWeak
            }, playCompletion: playCompletion, playSuccessAction: { [weak self] in
                if let adLevelObj = adLevelObj {
                    self?.adFeaturelogic.logShowAd(adLocation: whAdTask.adLocation, logParam: logParam)
                    TAdManager.shared.showLog("\(whAdTask.adLocation.adLocationStr): \(adLevelObj.level) playSuccess")
                    
                    if optionDic[.stopReloadAd] == nil {
                        adLevelObj.ad = nil // set nil to reload
                    }
                    completion?()
                }
            })
        }
    }
    
    // 將取得的AdLevelObject 根據 AdLocation 整理成最終廣告Ouput
    func handleAdLevelObjectToPlay(adLocation: WHAdLocation, logParam: Any?, adLevelObj: AdLevelObject?, hasBindWeak: (() -> Bool)?, playCompletion: ((WHAdResult) -> ())?, playSuccessAction: (() -> Void)? = nil) {
        guard let adLevelObj = adLevelObj else {
            playCompletion?(.fail(AdvertisementError(code: 1, msg: "Ad load failed")))
            return
        }
        
        let adStyle = adFeaturelogic.getAdStyle(adLocation: adLocation)
        
        switch adStyle {
        case .native:
            guard let hasBindWeak = hasBindWeak?(), hasBindWeak else { return }
            guard let adView = adFeaturelogic.renderAdToAdView(adLocation: adLocation, loader: adLevelObj.source.loader, ad: adLevelObj.ad) else {
                playCompletion?(.fail(AdvertisementError(code: 2, msg: "Ad parse fail")))
                return
            }
            playCompletion?(.showAd(adView))
            playSuccessAction?()
            
        case .reward:
            playCompletion?(.showAd(nil))
            adLevelObj.source.playFullScreenAd(ad: adLevelObj.ad, hasBindWeak: hasBindWeak) { [weak self] in
                self?.adFeaturelogic.logReward(adLocation: adLocation, logParam: logParam)
                playCompletion?(.reward)
            } playSuccessAction: {
                playSuccessAction?()
            }
            
        case .interstitial:
            playCompletion?(.showAd(nil))
            adLevelObj.source.playFullScreenAd(ad: adLevelObj.ad, hasBindWeak: hasBindWeak, getRewarded: nil, playSuccessAction: {
                playSuccessAction?()
            })
            
        case .banner:
            guard let adView = handleBannerAction?((adLevelObj.source.loader, hasBindWeak?())) else {
                playCompletion?(.fail(AdvertisementError(code: 3, msg: "Ad banner parse fail")))
                return
            }
            
            playCompletion?(.showAd(adView))
            playSuccessAction?()
        case .rewardInterstitial:
            break
        }
    }
}

extension TAdManager { //MARK: For MaxBanner
    func forMaxBannerAction(whAdTask: WHAdTask, logParam: Any?, optionDic: [WHAdOption: Any], specialCondition: (() -> Bool)?, playCompletion: ((WHAdResult) -> ())? = nil) {
        whAdTask.optionDic = optionDic
        whAdTask.setPlayAdCompletion { [weak self] result in
            switch result {
            case .play:
                self?.playAdLevelObject(whAdTask: whAdTask, logParam: logParam, optionDic: optionDic, specialCondition: specialCondition, playCompletion: playCompletion) {
                    playCompletion?(.bannerRefresh)
                }
            default:break
            }
        }
    }
}

extension TAdManager {
    public func getWHAdTaskStatus(adLocation: WHAdLocation) -> [(statusStr: String, hasAd: Bool, id: String?)] {
        let whAdTask = adFeaturelogic.newOrGetExistWHAdObj(adLocation: adLocation, logParam: nil, whAdObj: nil, unitIdDics: TAdManager.shared.unitIdDics).whAdObj
        return whAdTask.adLevelObjects.map({(statusStr: $0.adStatus.rawValue, hasAd: $0.ad != nil, id: $0.id)})
    }
}
