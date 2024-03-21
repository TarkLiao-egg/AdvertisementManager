import Foundation
import TAdManager_iOS

struct TestAdLocation: WHAdLocation {
    enum AdLocation: String, CaseIterable {
        case locationBanner
        case locationReward
    }

    var adLocationStr: String

    init(_ location: AdLocation) {
        adLocationStr = location.rawValue
    }
}
