import Foundation

class AdLevelObject {
    typealias Level = Int
    enum AdStatus: String {
        case empty
        case Loading
        case Fill
        case Fail
    }
    // MARK: init param
    let id: String?
    var ad: Any?
    var prepareRemoveAds = [Any?]()
    let level: Int
    let source: WHAdSource
    var adStatus: AdStatus = .empty
    var readyReload: Bool = true
    var timeoutInterval: TimeInterval?
    var logParam: Any?
    
    // MARK: Outside param
    var adLocation: WHAdLocation!
    var adSourceResultAction: ((WHAdSourceResult, WHAdLocation, Level) -> Void)?
    var optionDic: [WHAdOption: Any] = [:]
    var playCompletion: ((WHAdResult) -> ())?
    
    var adFeatureLogic: AdFeatureLogic?
    
    let serialQueue = DispatchQueue(label: "serialSaveAd")
    init(id: String?, level: Int, source: WHAdSource, adFeatureLogic: AdFeatureLogic) {
        self.id = id
        self.level = level
        self.source = source
        self.adFeatureLogic = adFeatureLogic
    }
    
    init(adObj: AdLevelObject) {
        self.id = adObj.id
        self.ad = adObj.ad
        self.level = adObj.level
        self.source = adObj.source
    }
    
    func adLevelLoadAd(adLocation: WHAdLocation, adSourceResultAction: @escaping (WHAdSourceResult, WHAdLocation, Int) -> Void) {
        self.adLocation = adLocation
        guard ad == nil else {
            adStatus = .Fill
            return
        }
        self.adSourceResultAction = adSourceResultAction
        timeoutInterval = Date().timeIntervalSince1970
        sourceLoadAd()
    }
    
    func setNewAdSourceResultAction(adLocation: WHAdLocation, adSourceResultAction: @escaping (WHAdSourceResult, WHAdLocation, Level) -> Void) {
        self.adLocation = adLocation
        self.adSourceResultAction = adSourceResultAction
    }
    
    private func sourceLoadAd() {
        readyReload = false
        adStatus = .Loading
        adFeatureLogic?.logLoadAd(adLocation: adLocation)
        adFeatureLogic?.getLoadMethod(adLocation: adLocation, adLevelObj: self, sourceResult: sourceResult)
    }
    
    private func sourceResult(result: WHAdSourceResult) {
        switch result {
        case .getAd(let ad):
            adStatus = .Fill
            timeoutInterval = nil
            let hasBindWeak = adFeatureLogic?.hasBindWeak(optionDic: optionDic)
            if hasBindWeak == false {
                source.bindWeakLost()
            }
            
            serialQueue.sync { [weak self] in
                self?.prepareRemoveAds.append(ad)
                self?.ad = ad
                self?.reservedOnlyTwo()
            }
            
        case .failure(let err):
            adStatus = .Fail
            timeoutInterval = nil
            serialQueue.sync { [weak self] in
                if self?.optionDic[.stopReloadAd] == nil {
                    self?.ad = nil
                }
            }
            playCompletion?(.fail(err))
        case .canReload:
            readyReload = true
        case .doReload:
            sourceLoadAd()
        case .click:
            adFeatureLogic?.logClickAd(adLocation: adLocation, logParam: logParam)
        case .adEnd(let isReward):
            adFeatureLogic?.logFullScreenAdEnd(adLocation: adLocation, isReward: isReward, logParam: logParam)
        }
        adSourceResultAction?(result, adLocation, level)
    }
    
    private func reservedOnlyTwo() {
        if prepareRemoveAds.count > 2  {
            var reservedArray = [Any?]()
            reservedArray.append(prepareRemoveAds.removeLast())
            reservedArray.insert(prepareRemoveAds.removeLast(), at: 0)
            for prepareRemoveAd in prepareRemoveAds {
                source.destroyAd(ad: prepareRemoveAd)
            }
            prepareRemoveAds = reservedArray
        }
    }
    
    func resetStatus() {
        if ad == nil {
            readyReload = true
        }
    }
}
