import UIKit

class WHAdTask {
    class AdTimeObject {
        var timer: Timer?
        var time: Int = 0
        func over() {
            time = 0
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: init param
    var adTimeObj = AdTimeObject()
    let adLocation: WHAdLocation
    let adFeatureLogic: AdFeatureLogic
    var adLevelObjects: [AdLevelObject] = []
    
    // MARK: Outside param
    var playAdCompletion: ((WHAdTaskResult) -> Void)?
    var fillCompletion: (() -> Void)?
    var optionDic: [WHAdOption: Any] = [:]
    var workItem: DispatchWorkItem?
    
    init(adLocation: WHAdLocation, adFeatureLogic: AdFeatureLogic, adLevelObjects: [AdLevelObject]) {
        self.adLocation = adLocation
        self.adFeatureLogic = adFeatureLogic
        self.adLevelObjects = adLevelObjects
    }
    
    func fillAllAd(optionDic: [WHAdOption: Any], playAdCompletion: ((WHAdTaskResult) -> Void)? = nil) {
        let adLoadFlowLogic = AdLoadFlowLogic()
        
        checkRefresh(adLocation: adLocation, optionDic: optionDic, isAdSelfRefresh: false)
        
        adTimeObj.over()
        adTimeObj.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timerSelector), userInfo: nil, repeats: true)
        
        self.optionDic = optionDic
        self.playAdCompletion = playAdCompletion
        if adFeatureLogic.inAdRequestPeriod(adLevelObjects: adLevelObjects) {
            if adFeatureLogic.getAdLevelObjsStatus(adLevelObjects: adLevelObjects).hasLoading {
                adLoadFlowLogic.adLoadResultLoadAd(isReplace: true, adFeatureLogic: adFeatureLogic, adLocation: adLocation,
                                   adLevelObjects: adLevelObjects, adTaskLoadResultAction: taskLoadResult(taskLoadResult:))
                TAdManager.shared.showLog("WHAdTask \(adLocation.adLocationStr) isLoading, quit")
                return
            }
            guard adFeatureLogic.getAdLevelObjsStatus(adLevelObjects: adLevelObjects).allReloadReady else {
                for notReady in adFeatureLogic.getAdLevelObjs(adLevelObjects: adLevelObjects).notReadys {
                    TAdManager.shared.showLog("WHAdTask \(adLocation.adLocationStr) \(notReady.level) not ready")
                }
                return
            }
        } else {
            TAdManager.shared.showLog("\(adLocation.adLocationStr) force request empty ad")
            for adLevelObject in adLevelObjects {
                adLevelObject.resetStatus()
            }
        }
        
        TAdManager.shared.showLog("WHAdTask \(adLocation.adLocationStr) loading")
        
        adLoadFlowLogic.adLoadResultLoadAd(isReplace: false, adFeatureLogic: adFeatureLogic, adLocation: adLocation,
                           adLevelObjects: adLevelObjects, adTaskLoadResultAction: taskLoadResult(taskLoadResult:))
    }
    
    func setPlayAdCompletion(playAdCompletion: ((WHAdTaskResult) -> Void)? = nil) {
        self.playAdCompletion = playAdCompletion
    }
    
    func taskLoadResult(taskLoadResult: (WHAdTaskLoadResult)) {
        switch taskLoadResult {
        case .getAdResult:
            optionDic[.loadTimeForceQuit(0)] = nil
            playAdCompletion?(.play)
            if playAdCompletion == nil {
                checkRefresh(adLocation: adLocation, optionDic: optionDic, isAdSelfRefresh: true)
            }
        case .checkAds:
            if adFeatureLogic.getAdLevelObjsStatus(adLevelObjects: adLevelObjects).hasLoading == false { // All Ad load finish no matter Get or Fail
                TAdManager.shared.showLog("\(adLocation.adLocationStr) all loaded")
                adTimeObj.over()
            } else {
                TAdManager.shared.showLog("\(adLocation.adLocationStr) still loading")
            }
            playAdCompletion?(.checkReload)
            
        case .forceQuit:
            adTimeObj.over()
            playAdCompletion?(.forceQuit)
            playAdCompletion = nil
        }
    }
    
    @objc func timerSelector() {
        adTimeObj.time += 1
        let tuples = adFeatureLogic.getWaitTuples(adLocation: adLocation, optionDic: optionDic)
        for tuple in tuples {
            if tuple.waitDuration == adTimeObj.time, tuple.forceQuit {
                taskLoadResult(taskLoadResult: .forceQuit)
            } else if tuple.waitDuration == adTimeObj.time, tuple.action(adLevelObjects) {
                taskLoadResult(taskLoadResult: .getAdResult)
            }
        }
    }
    
    func checkRefresh(adLocation: WHAdLocation, optionDic: [WHAdOption: Any], isAdSelfRefresh: Bool) {
        if let refreshObject = adFeatureLogic.hasRefreshWeak(optionDic: optionDic) {
            if !isAdSelfRefresh, refreshObject.refreshDuration == 0 { return } // refreshDuration == 0, autoRefresh ignore, wait adSelf
            workItem?.cancel()
            workItem = DispatchWorkItem {
                if let _ = refreshObject.refreshTargetWeak {
                    TAdManager.shared.showLog(adLocation.adLocationStr + " refresh")
                    refreshObject.refreshAction?()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + refreshObject.refreshDuration, execute: workItem!)
        }
    }
}
