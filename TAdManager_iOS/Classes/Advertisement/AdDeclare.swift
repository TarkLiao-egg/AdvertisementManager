import UIKit

public protocol WHAdLocation {
    var adLocationStr: String { get set }
}

public enum WHAdStyle: String {
    case interstitial
    case banner
    case reward
    case rewardInterstitial
    case native
}

public enum WHAdResult {
    case showAd(UIView?)
    case fail(AdvertisementError)
    case reward
    case bannerRefresh
    case otherFullScreenPlay
    case noAdWithAdOption
    case forceQuitWithAdOption
    case specialNotAllow
}

enum WHAdTaskResult {
    case play
    case checkReload
    case forceQuit
}

public struct AdvertisementError: Error {
    public var code: Int
    public var msg: String
    public init(code: Int, msg: String) {
        self.code = code
        self.msg = msg
    }
}

enum WHAdTaskLoadResult {
    case getAdResult
    case checkAds
    case forceQuit
}

public enum WHAdSourceResult {
    case getAd(Any?)
    case failure(AdvertisementError)
    case canReload
    case doReload
    case click
    case adEnd
}

public enum WHAdOption: Equatable, Hashable {
    case refreshBannerWeak(NSObject?, Bool?) // Refresh需綁定物件，該物件消失就停止, Bool設置true就是以remoteConfig時間做refresh，如果是false就是看廣告本身更新
    case bindWeak(NSObject?) // 綁定物件，該物件消失就不播廣告
    case realBindWeak(WHBindObject?) // library使用
    case requiredAdExist // 廣告必須存在才播，不然就結束
    case loadTimeForceQuit(Int) // 幾秒就結束load Ad
    case stopReloadAd // Ad not reload
}

class WHRefreshObject {
    weak var refreshTargetWeak: NSObject?
    let refreshDuration: Double
    var timer: Timer?
    var refreshAction: (() -> Void)?
    init(refreshTargetWeak: NSObject?, refreshDuration: Double) {
        self.refreshTargetWeak = refreshTargetWeak
        self.refreshDuration = refreshDuration
    }
}

public class WHBindObject: Equatable, Hashable {
    public weak var bindTargetWeak: NSObject?
    init(_ bindTargetWeak: NSObject?) {
        self.bindTargetWeak = bindTargetWeak
    }
    
    public static func == (lhs: WHBindObject, rhs: WHBindObject) -> Bool {
        return lhs.bindTargetWeak == rhs.bindTargetWeak
    }
    
    public func hash(into hasher: inout Hasher) {
        return hasher.combine(bindTargetWeak)
    }
}

public protocol WHAdSource {
    var loader: Any? { get set }
    var isPlay: Bool { get set }
    func loadOpenAd(id: String, sourceResult: ((WHAdSourceResult) -> Void)?)
    func loadInterstitialAd(id: String, sourceResult: ((WHAdSourceResult) -> Void)?)
    func loadRewardAd(id: String, sourceResult: ((WHAdSourceResult) -> Void)?)
    func loadNativeAd(id: String, sourceResult: ((WHAdSourceResult) -> Void)?)
    func loadBannerAd(id: String, sourceResult: ((WHAdSourceResult) -> Void)?)
    
    func destroyAd(ad: Any?)
    func playFullScreenAd(ad: Any?, hasBindWeak: (() -> Bool)?, getRewarded: (() -> Void)?, playSuccessAction: (() -> Void)?)
    
    func bindWeakLost()
}
