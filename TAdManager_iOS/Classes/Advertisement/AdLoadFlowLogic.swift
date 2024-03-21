import Foundation

class AdLoadFlowLogic {
    func adLoadResultLoadAd(isReplace: Bool, adFeatureLogic: AdFeatureLogic, adLocation: WHAdLocation, adLevelObjects: [AdLevelObject], adTaskLoadResultAction: ((WHAdTaskLoadResult) -> Void)?) {
        /**
         因為得到的最高權限的廣告時會即時傳，可能會跟原先流程data race
         建立一個SerialQueue，一次只有一Thread去回傳結果
         */
        let serialQueue = DispatchQueue(label: "serialReturn")
        let backgroundQueue = DispatchQueue.global()
        
        func getOneAd(level: Int) {
            serialQueue.sync {
                if level == 0 || adFeatureLogic.getAdLevelObjsStatus(adLevelObjects: adLevelObjects).hasLoading == false {
                    adTaskLoadResultAction?(.getAdResult)
                }
            }
        }
        
        func adSourceResultAction(sourceResult: WHAdSourceResult, adLocation: WHAdLocation, level: Int) {
            switch sourceResult {
            case .getAd(_):
                TAdManager.shared.showLog("\(adLocation.adLocationStr): \(level) get")
                getOneAd(level: level)
            case .failure(let err):
                TAdManager.shared.showLog("\(adLocation.adLocationStr) \(level): \(err.localizedDescription)")
                getOneAd(level: level)
            case .canReload:
                adTaskLoadResultAction?(.checkAds)
            default:break
            }
        }
        
        let taskObjs: [AdLevelObject]
        if isReplace {
            taskObjs = adLevelObjects
        } else {
            taskObjs = adLevelObjects.filter({$0.ad == nil && $0.readyReload})
        }
        
        guard taskObjs.count > 0 else {
            adTaskLoadResultAction?(.getAdResult)
            return
        }
        
        for obj in taskObjs {
            backgroundQueue.async {
                if isReplace {
                    obj.setNewAdSourceResultAction(adLocation: adLocation, adSourceResultAction: adSourceResultAction(sourceResult:adLocation:level:))
                } else {
                    TAdManager.shared.showLog("\(adLocation.adLocationStr): \(obj.level) loading")
                    obj.adLevelLoadAd(adLocation: adLocation, adSourceResultAction: adSourceResultAction(sourceResult:adLocation:level:))
                }
            }
        }
    }
}
