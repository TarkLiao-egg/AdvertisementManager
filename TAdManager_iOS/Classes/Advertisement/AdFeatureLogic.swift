import UIKit

public protocol AdFeatureLogic {
    func prepareAd(manager: TAdManager)
    func getSource(adLocation: WHAdLocation) -> WHAdSource
    func getUnitIDs(source: WHAdSource, adLocation: WHAdLocation) -> [String]
    func logLoadAd(adLocation: WHAdLocation)
    func logShouldShowAd(adLocation: WHAdLocation, logParam: Any?)
    func logShowAd(adLocation: WHAdLocation, logParam: Any?)
    func logReward(adLocation: WHAdLocation, logParam: Any?)
    func logClickAd(adLocation: WHAdLocation, logParam: Any?)
    func logFullScreenAdEnd(adLocation: WHAdLocation, isReward: Bool?, logParam: Any?)
    func getAdStyle(adLocation: WHAdLocation) -> WHAdStyle
    func renderAdToAdView(adLocation: WHAdLocation, loader: Any?, ad: Any?) -> UIView?
}

extension AdFeatureLogic {
    // load廣告等待邏輯
    func getWaitTuples(adLocation: WHAdLocation, optionDic: [WHAdOption: Any]) -> [(waitDuration: Int, action: ([AdLevelObject]) -> Bool, forceQuit: Bool)] {
        var waitTuples = [(waitDuration: Int, action: ([AdLevelObject]) -> Bool, forceQuit: Bool)]()
        switch adLocation.adLocationStr {
        default:
            waitTuples.append((10, hasHighest0, false))
        }
        if let time = optionDic[.loadTimeForceQuit(0)] as? Int {
            waitTuples.append((time, hasHighest0, true))
        }
        return waitTuples
    }
    
    func hasHighest0(adLevelObjects: [AdLevelObject]) -> Bool {
        return adLevelObjects.filter({$0.ad != nil && $0.level == 0}).count > 0
    }
}

extension AdFeatureLogic {
    func getRefreshDuration(isUseRemote: Bool?) -> TimeInterval {
        let isUseRemote: Bool = isUseRemote ?? true
        if isUseRemote {
            return TimeInterval(TAdManager.shared.getRefreshPeriod())
        } else { // according ad itself
            return TimeInterval(0)
        }
    }
    
    func getAdTaskStatus(whAdTask: WHAdTask, isPlay: Bool) -> TAdManager.AdTaskStatus {
        if isPlay {
            if let _ = whAdTask.adLevelObjects.filter({$0.ad != nil}).first {
                return .existAdAndPlay
            } else {
                return .noAdAndPlay
            }
        } else {
            return .prepare
        }
    }
    
    func getLoadMethod(adLocation: WHAdLocation, adLevelObj: AdLevelObject, sourceResult: @escaping (WHAdSourceResult) -> Void) {
        guard let id = adLevelObj.id else { return }
        let adStyle = getAdStyle(adLocation: adLocation)
        switch adStyle {
        case .interstitial:
            adLevelObj.source.loadInterstitialAd(id: id, sourceResult: sourceResult)
        case .banner:
            adLevelObj.source.loadBannerAd(id: id, sourceResult: sourceResult)
        case .native:
            adLevelObj.source.loadNativeAd(id: id, sourceResult: sourceResult)
        case .reward:
            adLevelObj.source.loadRewardAd(id: id, sourceResult: sourceResult)
        case .rewardInterstitial:
            return
        }
    }
    
    func isAnyPlaying(playCompletion: ((WHAdResult) -> ())?, unitIdDics: [String: AdLevelObject]) -> Bool {
        guard let _ = playCompletion else { return false }
        var isPlay: Bool = false
        for adLevelObject in unitIdDics {
            if adLevelObject.value.source.isPlay {
                isPlay = true
                break
            }
        }
        return isPlay
    }
    
    func getAdLevelObjs(adLevelObjects: [AdLevelObject]) -> (loadings: [AdLevelObject], notReadys: [AdLevelObject]) {
        let loadings = adLevelObjects.filter({$0.adStatus == .Loading})
        let notReadys = adLevelObjects.filter({$0.readyReload == false})
        return (loadings: loadings, notReadys: notReadys)
    }
    
    func getAdLevelObjsStatus(adLevelObjects: [AdLevelObject]) -> (hasLoading: Bool, allReloadReady: Bool) {
        let tuple = getAdLevelObjs(adLevelObjects: adLevelObjects)
        return (hasLoading: tuple.loadings.count > 0, allReloadReady: tuple.loadings.count == 0 && tuple.notReadys.count == 0)
    }
    
    func inAdRequestPeriod(adLevelObjects: [AdLevelObject]) -> Bool {
        for adLevelObject in adLevelObjects {
            if let timeoutInterval = adLevelObject.timeoutInterval, Date().timeIntervalSince1970 - timeoutInterval >= TAdManager.shared.forceAdRequestPeriod {
                return false
            }
        }
        return true
    }
}

extension AdFeatureLogic { // MARK: AdOption
    // 判斷該Ad 是否能Refresh，根據 refreshTargetWeak 物件還存不存在
    func hasRefreshWeak(optionDic: [WHAdOption: Any]) -> WHRefreshObject? {
        if let obj = optionDic[.refreshBannerWeak(nil, nil)] as? WHRefreshObject, let _ = obj.refreshTargetWeak {
            return obj
        }
        return nil
    }
    
    // 判斷該Ad 是否能play，根據 bindTargetWeak 物件還存不存在
    func hasBindWeak(optionDic: [WHAdOption: Any]) -> Bool {
        if let obj = optionDic[.bindWeak(nil)] as? WHBindObject {
            if let _ = obj.bindTargetWeak {
                return true
            } else {
                return false
            }
        }
        return true
    }
}

extension AdFeatureLogic {
    /**
     1. 該位置沒有Task，建新Task
     2. 該位置有Task，用舊Task
     3. Task內的AdLevelObject每次都會重組
     4. 有共用Ad UnitId，所以建立的AdLevelObject會依照id存到unitIdDics
     */
    func newOrGetExistWHAdObj(adLocation: WHAdLocation, logParam: Any?, whAdObj: WHAdTask?, unitIdDics: [String: AdLevelObject], playCompletion: ((WHAdResult) -> ())? = nil) -> (whAdObj: WHAdTask, unitIdDics: [String: AdLevelObject]) {
        let source: WHAdSource = getSource(adLocation: adLocation)
        let unitIDs = getUnitIDs(source: source, adLocation: adLocation)
        var unitIdDics = unitIdDics
        
        var adLevelObjects = [AdLevelObject]()
        for (index, id) in unitIDs.enumerated() {
            if let adLevelObj = unitIdDics[id] {
                adLevelObjects.append(adLevelObj)
            } else {
                let adLevelObj = AdLevelObject(id: id, level: index, source: source, adFeatureLogic: self)
                unitIdDics[id] = adLevelObj
                adLevelObjects.append(adLevelObj)
            }
        }
        for adLevelObject in adLevelObjects {
            adLevelObject.adLocation = adLocation
            adLevelObject.logParam = logParam
            adLevelObject.playCompletion = playCompletion
        }
        if let whAdObj = whAdObj {
            whAdObj.adLevelObjects = adLevelObjects
            return (whAdObj: whAdObj, unitIdDics: unitIdDics)
        } else {
            return (whAdObj: WHAdTask(adLocation: adLocation, adFeatureLogic: self, adLevelObjects: adLevelObjects), unitIdDics: unitIdDics)
        }
    }
    
    // 取得當前最高等級的廣告
    func getExistHighestAd(whAdTask: WHAdTask) -> AdLevelObject? {
        if let exist = whAdTask.adLevelObjects.filter({$0.ad != nil}).first {
            return exist
        }
        return nil
    }
}
