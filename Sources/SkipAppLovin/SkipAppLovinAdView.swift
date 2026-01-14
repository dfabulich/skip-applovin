//
//  SkipAppLovinAdView.swift
//  skip-applovin
//
//  Created by Dan Fabulich on 1/12/26.
//
#if !SKIP_BRIDGE
import SwiftUI
import OSLog

let logger: Logger = Logger(subsystem: "SkipAppLovin", category: "SkipAppLovinAdView")

#if SKIP
import androidx.compose.ui.viewinterop.AndroidView
import com.applovin.mediation.ads.MaxAdView
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxAdFormat
import com.applovin.mediation.MaxAdViewAdListener
import com.applovin.mediation.MaxAdViewConfiguration
import com.applovin.mediation.MaxError

// MARK: - Protocols

/// This protocol defines a listener to be notified about ad events.
public protocol MAAdDelegate: AnyObject {
    /// The SDK invokes this method when a new ad has been loaded.
    func didLoad(_ ad: MAAd)
    
    /// The SDK invokes this method when an ad could not be retrieved.
    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError)
    
    /// The SDK invokes this method when a full-screen ad is displayed.
    ///
    /// - Warning: This method is deprecated for MRECs. It will only be called for full-screen ads.
    func didDisplay(_ ad: MAAd)
    
    /// The SDK invokes this method when a full-screen ad is hidden.
    ///
    /// - Warning: This method is deprecated for MRECs. It will only be called for full-screen ads.
    func didHide(_ ad: MAAd)
    
    /// The SDK invokes this method when the ad is clicked.
    func didClick(_ ad: MAAd)
    
    /// The SDK invokes this method when the ad failed to display.
    func didFail(toDisplay ad: MAAd, withError error: MAError)
}

/// This protocol defines a listener to be notified about ad view events.
public protocol MAAdViewAdDelegate: MAAdDelegate {
    /// The SDK invokes this method when the MAAdView has expanded to the full screen.
    func didExpand(_ ad: MAAd)
    
    /// The SDK invokes this method when the MAAdView has collapsed back to its original size.
    func didCollapse(_ ad: MAAd)
}

// MARK: - MAErrorCode

/// This enum contains various error codes that the SDK can return when a MAX ad fails to load or display.
public enum MAErrorCode: Int {
    /// This error code represents an error that could not be categorized into one of the other defined errors.
    case unspecified = -1
    
    /// This error code indicates that MAX returned no eligible ads from any mediated networks for this app/device.
    case noFill = 204
    
    /// This error code indicates that MAX returned eligible ads from mediated networks, but all ads failed to load.
    case adLoadFailed = -5001
    
    /// This error code indicates that the SDK failed to load an ad because the publisher provided an invalid ad unit identifier.
    case invalidAdUnitIdentifier = -5603
    
    /// This error code indicates that the ad request failed due to a generic network error.
    case networkError = -1000
    
    /// This error code indicates that the ad request timed out due to a slow internet connection.
    case networkTimeout = -1001
    
    /// This error code indicates that the ad request failed because the device is not connected to the internet.
    case noNetwork = -1009
    
    /// This error code indicates that you attempted to show a fullscreen ad while another fullscreen ad is still showing.
    case fullscreenAdAlreadyShowing = -23
    
    /// This error code indicates you are attempting to show a fullscreen ad before the one has been loaded.
    case fullscreenAdNotReady = -24
    
    /// This error code indicates you attempted to present a fullscreen ad from an invalid view controller.
    case fullscreenAdInvalidViewController = -25
}

// MARK: - MAError

/// This class encapsulates various data for MAX load and display errors.
public class MAError {
    /// The error code for the error.
    public let code: MAErrorCode
    
    /// The error message for the error.
    public let message: String
    
    /// The mediated network's error code for the error. Available for errors returned in didFailToDisplayAd only.
    public let mediatedNetworkErrorCode: Int
    
    /// The mediated network's error message for the error. Defaults to an empty string. Available for errors returned in didFailToDisplayAd only.
    public let mediatedNetworkErrorMessage: String
    
    /// The underlying waterfall of ad responses.
    public let waterfall: MAAdWaterfallInfo?
    
    /// The latency of the mediation ad load request in seconds.
    public let requestLatency: TimeInterval
    
    internal init(_ maxError: MaxError) {
        self.code = MAErrorCode(rawValue: maxError.getCode()) ?? .unspecified
        self.message = maxError.getMessage() ?? ""
        self.mediatedNetworkErrorCode = maxError.getMediatedNetworkErrorCode()
        self.mediatedNetworkErrorMessage = maxError.getMediatedNetworkErrorMessage() ?? ""
        self.waterfall = nil // TODO: Implement MAAdWaterfallInfo wrapper
        self.requestLatency = TimeInterval(maxError.getRequestLatencyMillis()) / 1000.0
    }
}

// MARK: - MAAdWaterfallInfo

/// Placeholder for MAAdWaterfallInfo - to be implemented later
public class MAAdWaterfallInfo {
    // TODO: Implement MAAdWaterfallInfo wrapper
}

// MARK: - MAAd

/// This class represents an ad that has been served by AppLovin MAX.
public class MAAd {
    /// The format of this ad.
    public let format: MAAdFormat
    
    /// The size of the AdView format ad, or CGSize.zero otherwise.
    let size: CGSize
    
    /// The ad unit ID for which this ad was loaded.
    public let adUnitIdentifier: String
    
    /// The ad network from which this ad was loaded.
    public let networkName: String
    
    /// The ad network placement for which this ad was loaded.
    public let networkPlacement: String
    
    /// The creative id tied to the ad, if any.
    public let creativeIdentifier: String?
    
    /// The ad's revenue amount. In the case where no revenue amount exists, or it is not available yet, will return a value of 0.
    public let revenue: Double
    
    /// The precision of the revenue value for this ad.
    public let revenuePrecision: String
    
    /// The placement name that you assign when you integrate each ad format.
    public let placement: String?
    
    /// The underlying waterfall of ad responses.
    public let waterfall: MAAdWaterfallInfo?
    
    /// The latency of the mediation ad load request in seconds.
    public let requestLatency: TimeInterval
    
    /// For Native ads only. Get an instance of the MANativeAd containing the assets used to render the native ad view.
    public let nativeAd: MANativeAd?
    
    /// The DSP network that provided the loaded ad when the ad is served through AppLovin Exchange.
    public let DSPName: String?
    
    /// The DSP id network that provided the loaded ad when the ad is served through AppLovin Exchange.
    public let DSPIdentifier: String?
    
    private let maxAd: MaxAd
    
    internal init(_ maxAd: MaxAd, format: MAAdFormat) {
        self.maxAd = maxAd
        self.format = format
        
        let sizeObj = maxAd.getSize()
        self.size = CGSize(width: Double(sizeObj.getWidth()), height: Double(sizeObj.getHeight()))
        
        self.adUnitIdentifier = maxAd.getAdUnitId() ?? ""
        self.networkName = maxAd.getNetworkName() ?? ""
        self.networkPlacement = maxAd.getNetworkPlacement() ?? ""
        self.creativeIdentifier = maxAd.getCreativeId()
        self.revenue = maxAd.getRevenue()
        self.revenuePrecision = maxAd.getRevenuePrecision() ?? ""
        self.placement = maxAd.getPlacement()
        self.waterfall = nil // TODO: Implement MAAdWaterfallInfo wrapper
        self.requestLatency = TimeInterval(maxAd.getRequestLatencyMillis()) / 1000.0
        self.nativeAd = nil // TODO: Implement MANativeAd wrapper
        self.DSPName = maxAd.getDspName()
        self.DSPIdentifier = maxAd.getDspId()
    }
    
    /// Gets the ad value for a given key.
    public func adValue(forKey key: String) -> String? {
        return maxAd.getAdValue(key)
    }
    
    /// Gets the ad value for a given key.
    public func adValue(forKey key: String, defaultValue: String?) -> String? {
        return maxAd.getAdValue(key, defaultValue)
    }
}

// MARK: - MANativeAd

/// Placeholder for MANativeAd - to be implemented later
public class MANativeAd {
    // TODO: Implement MANativeAd wrapper
}

public class MAAdFormat: CustomStringConvertible {
    // MARK: - Static Ad Formats
    
    /// Represents a 320×50 banner advertisement.
    static let banner = MAAdFormat(
        label: "BANNER",
        size: CGSize(width: 320, height: 50),
        maxAdFormat: MaxAdFormat.BANNER
    )
    
    /// Represents a 300×250 rectangular advertisement.
    static let mrec = MAAdFormat(
        label: "MREC",
        size: CGSize(width: 300, height: 250),
        maxAdFormat: MaxAdFormat.MREC
    )
    
    /// Represents a 728×90 leaderboard advertisement
    /// (for tablets).
    static let leader = MAAdFormat(
        label: "LEADER",
        size: CGSize(width: 728, height: 90),
        maxAdFormat: MaxAdFormat.LEADER
    )
    
    /// Represents a full-screen advertisement.
    static let interstitial = MAAdFormat(
        label: "INTER",
        size: .zero,
        maxAdFormat: MaxAdFormat.INTERSTITIAL
    )
    
    /// Similar to `interstitial`, except that it is shown
    /// upon opening the app.
    static let appOpen = MAAdFormat(
        label: "APP_OPEN",
        size: .zero,
        maxAdFormat: MaxAdFormat.APP_OPEN
    )
    
    /// Similar to `interstitial` except that users are given
    /// a reward at the end of the advertisement.
    static let rewarded = MAAdFormat(
        label: "REWARDED",
        size: .zero,
        maxAdFormat: MaxAdFormat.REWARDED
    )
    
    /// Represents a native advertisement.
    static let native = MAAdFormat(
        label: "NATIVE",
        size: .zero,
        maxAdFormat: MaxAdFormat.NATIVE
    )
    
    /// Rewarded interstitial ads have been removed and this
    /// property will be removed in a future SDK version.
    @available(*, deprecated, message: "Rewarded interstitial ads have been removed and this property will be removed in a future SDK version.")
    static let rewardedInterstitial = MAAdFormat(
        label: "REWARDED_INTER",
        size: .zero,
        maxAdFormat: MaxAdFormat.REWARDED_INTERSTITIAL
    )
    
    // MARK: - Properties
    
    /// String representing the name of this ad format.
    /// Sample values include "BANNER", "MREC", "INTER",
    /// "REWARDED", etc.
    let label: String
    
    /// The size of the AdView format ad, or CGSize.zero
    /// otherwise.
    let size: CGSize
    
    let maxAdFormat: MaxAdFormat
    
    private init(label: String, size: CGSize, maxAdFormat: MaxAdFormat) {
        self.label = label
        self.size = size
        self.maxAdFormat = maxAdFormat
    }
    
    // MARK: - Adaptive Banners
    
    /// Get the adaptive banner size for the screen width
    /// (with safe areas insetted) at the current orientation.
    ///
    /// - Note: The height is the only adaptive dimension;
    ///   the width spans the screen.
    /// - Note: Only AdMob / Google Ad Manager currently has
    ///   support for adaptive banners and the maximum height
    ///   is 15% the height of the screen.
    var adaptiveSize: CGSize {
        let context = ProcessInfo.processInfo.androidContext
        let result = maxAdFormat.getAdaptiveSize(context)
        return CGSize(Double(result.getWidth()), Double(result.getHeight()))
    }
    
    /// Get the adaptive banner size for the provided width
    /// at the current orientation.
    ///
    /// - Note: The height is the only adaptive dimension;
    ///   the width that you provide will be passed back to
    ///   you in the returned size.
    /// - Note: Only AdMob / Google Ad Manager currently has
    ///   support for adaptive banners and the maximum height
    ///   is 15% the height of the screen.
    ///
    /// - Parameter width: The width to retrieve the adaptive
    ///   banner size for, in points.
    /// - Returns: The adaptive banner size for the current
    ///   orientation and width.
    func adaptiveSize(forWidth width: CGFloat) -> CGSize {
        let context = ProcessInfo.processInfo.androidContext
        let result = maxAdFormat.getAdaptiveSize(Int(width.rounded(.down)), context)
        return CGSize(Double(result.getWidth()), Double(result.getHeight()))
    }
    
    // MARK: - Type Checks
    
    /// Whether or not the ad format is fullscreen: that is,
    /// an interstitial or rewarded.
    var isFullscreenAd: Bool {
        return self === Self.interstitial ||
               self === Self.appOpen ||
               self === Self.rewarded ||
               self === Self.rewardedInterstitial
    }
    
    /// Whether or not the ad format is one of the following:
    /// a banner, leader, or MREC.
    var isAdViewAd: Bool {
        return self === Self.banner ||
               self === Self.leader ||
               self === Self.mrec
    }
    
    /// Whether or not the ad format is a banner or leader.
    var isBannerOrLeaderAd: Bool {
        return self === Self.banner || self === Self.leader
    }
    
    /// Human-readable representation of the format.
    var displayName: String {
        switch self {
        case Self.banner:
            return "Banner"
        case Self.mrec:
            return "MREC"
        case Self.leader:
            return "Leader"
        case Self.interstitial:
            return "Interstitial"
        case Self.appOpen:
            return "App Open"
        case Self.rewarded:
            return "Rewarded"
        case Self.native:
            return "Native"
        case Self.rewardedInterstitial:
            return "Rewarded Interstitial"
        default:
            return label
        }
    }
    
    var description: String {
        self.displayName
    }
    
    static func fromMaxAdFormat(_ maxAdFormat: MaxAdFormat) -> MAAdFormat {
        switch maxAdFormat {
        case MaxAdFormat.BANNER:
            return .banner
        case MaxAdFormat.MREC:
            return .mrec
        case MaxAdFormat.LEADER:
            return .leader
        case MaxAdFormat.INTERSTITIAL:
            return .interstitial
        case MaxAdFormat.APP_OPEN:
            return .appOpen
        case MaxAdFormat.REWARDED:
            return .rewarded
        case MaxAdFormat.NATIVE:
            return .native
        case MaxAdFormat.REWARDED_INTERSTITIAL:
            return .rewardedInterstitial
        default:
            fatalError("Unknown MaxAdFormat: \(maxAdFormat)")
        }
    }
}

/// Defines the type of adaptive MAAdView.
public enum MAAdViewAdaptiveType: Int {
    /// Default type - standard banner/leader or MREC.
    case none
    
    /// Adaptive ad view anchored to the screen. The MAX SDK
    /// determines the height of the adaptive ad view by
    /// invoking adaptiveSize(forWidth:) which results in a
    /// height that ranges from 50 to 90 points but does not
    /// exceed 15% of the screen height in the current
    /// orientation.
    case anchored
    
    /// Adaptive ad view embedded within scrollable content.
    /// The height can extend up to the device height in the
    /// current orientation unless you restrict it by setting
    /// inlineMaximumHeight.
    case inline
}

/// This class contains configurable fields for the MAAdView.
public class MAAdViewConfiguration {
    /// The adaptive type of the MAAdView. Defaults to
    /// .none.
    let adaptiveType: MAAdViewAdaptiveType
    
    /// The custom width, in points, for the adaptive
    /// MAAdView. Defaults to -1, which indicates that the
    /// width adapts to span the application window.
    /// This value is only used when you set adaptiveType to
    /// either .anchored or .inline.
    let adaptiveWidth: CGFloat
    
    /// The maximum height, in points, for an inline adaptive
    /// MAAdView. Defaults to -1, allowing the height to
    /// extend up to the device height.
    /// This value is only used when you set adaptiveType to
    /// .inline.
    let inlineMaximumHeight: CGFloat
    
    internal init(
        adaptiveType: MAAdViewAdaptiveType,
        adaptiveWidth: CGFloat,
        inlineMaximumHeight: CGFloat
    ) {
        self.adaptiveType = adaptiveType
        self.adaptiveWidth = adaptiveWidth
        self.inlineMaximumHeight = inlineMaximumHeight
    }
    
    var maxAdViewConfiguration: MaxAdViewConfiguration {
        let maxAdaptiveType: MaxAdViewConfiguration.AdaptiveType
        switch adaptiveType {
        case .none:
            maxAdaptiveType = MaxAdViewConfiguration.AdaptiveType.NONE
        case .anchored:
            maxAdaptiveType = MaxAdViewConfiguration.AdaptiveType.ANCHORED
        case .inline:
            maxAdaptiveType = MaxAdViewConfiguration.AdaptiveType.INLINE
        }
        let result = MaxAdViewConfiguration.builder()
            .setAdaptiveType(maxAdaptiveType)
            .setAdaptiveWidth(Int(adaptiveWidth))
            .setInlineMaximumHeight(Int(inlineMaximumHeight))
            .build()
        return result
    }
    
    // MARK: - Initialization
    
    /// Creates a MAAdViewConfiguration object constructed
    /// from the MAAdViewConfigurationBuilder block.
    /// You may modify the configuration from within the
    /// block.
    ///
    /// - Parameter builderBlock: A closure that configures
    ///   the builder.
    /// - Returns: A MAAdViewConfiguration object.
    public init(
        withBuilderBlock builderBlock: (
            MAAdViewConfigurationBuilder
        ) -> Void
    ) {
        let builder = MAAdViewConfigurationBuilder()
        builderBlock(builder)
        self.adaptiveType = builder.adaptiveType
        self.adaptiveWidth = builder.adaptiveWidth
        self.inlineMaximumHeight = builder.inlineMaximumHeight
    }
}

// MARK: - MAAdViewConfiguration Builder

/// Builder class that you instantiate to create a
/// MAAdViewConfiguration object before you create a
/// MAAdView. This class contains properties that you can set
/// to configure the properties of the MAAdView that results
/// from the configuration object this class builds.
public class MAAdViewConfigurationBuilder {
    /// The adaptive type of the MAAdView. Defaults to
    /// .none.
    public var adaptiveType: MAAdViewAdaptiveType = .none
    
    /// The custom width, in points, for the adaptive
    /// MAAdView. Must not exceed the width of the application
    /// window.
    public var adaptiveWidth: CGFloat = -1
    
    /// The custom maximum height, in points, for the inline
    /// adaptive MAAdView.
    /// Must be at least 32 points and no more than the device
    /// height in the current orientation. A minimum of 50
    /// points is recommended.
    public var inlineMaximumHeight: CGFloat = -1
    
    // MARK: - Build
    
    /// Builds a MAAdViewConfiguration object from the builder
    /// properties' values.
    ///
    /// - Returns: A MAAdViewConfiguration object.
    func build() -> MAAdViewConfiguration {
        return MAAdViewConfiguration(
            adaptiveType: adaptiveType,
            adaptiveWidth: adaptiveWidth,
            inlineMaximumHeight: inlineMaximumHeight
        )
    }
}

struct AppLovinAdViewWrapper: View {
    let bannerAdUnitIdentifier: String
    let placement: String?
    let adFormat: MAAdFormat?
    let configuration: MAAdViewConfiguration?
    let backgroundColor: Color
    let delegate: MAAdViewAdDelegate?
    
    init(bannerAdUnitIdentifier: String, adFormat: MAAdFormat, placement: String?, backgroundColor: Color = .black, delegate: MAAdViewAdDelegate? = nil) {
        self.bannerAdUnitIdentifier = bannerAdUnitIdentifier
        self.placement = placement
        self.adFormat = adFormat
        self.configuration = nil
        self.backgroundColor = backgroundColor
        self.delegate = delegate
    }
    
    init(bannerAdUnitIdentifier: String, configuration: MAAdViewConfiguration, placement: String?, backgroundColor: Color = .black, delegate: MAAdViewAdDelegate? = nil) {
        self.bannerAdUnitIdentifier = bannerAdUnitIdentifier
        self.placement = placement
        self.adFormat = nil
        self.configuration = configuration
        self.backgroundColor = backgroundColor
        self.delegate = delegate
    }
    
    var body: some View {
        guard let androidActivity = UIApplication.shared.androidActivity else {
            return EmptyView()
        }
        ComposeView { ctx in
            //let color = backgroundColor.colorImpl().toArgb()
            AndroidView(factory: { ctx in
                var adView: MaxAdView?
                if let adFormat {
                    adView = MaxAdView(bannerAdUnitIdentifier, adFormat.maxAdFormat)
                } else if let configuration {
                    adView = MaxAdView(bannerAdUnitIdentifier, configuration.maxAdViewConfiguration)
                }
                guard let adView else { fatalError() }
                adView.setListener(AdViewWrapperListener(delegate: delegate))
                //adView.setBackground(backgroundColor.colorImpl().toArgb())
                adView.loadAd()
                return adView
            }, modifier: ctx.modifier, update: { adView in })
        }
    }
}

class AdViewWrapperListener: MaxAdViewAdListener {
    weak var delegate: MAAdViewAdDelegate?
    
    init(delegate: MAAdViewAdDelegate?) {
        self.delegate = delegate
    }
    
    override func onAdLoaded(maxAd: MaxAd) {
        logger.info("onAdLoaded \(maxAd)")
        guard let delegate = delegate else { return }
        let format = MAAdFormat.fromMaxAdFormat(maxAd.getFormat())
        let ad = MAAd(maxAd, format: format)
        delegate.didLoad(ad)
    }

    override func onAdLoadFailed(adUnitId: String, error: MaxError) {
        logger.error("onAdLoadFailed \(error)")
        guard let delegate = delegate else { return }
        let maError = MAError(error)
        delegate.didFailToLoadAd(forAdUnitIdentifier: adUnitId, withError: maError)
    }

    override func onAdDisplayFailed(ad: MaxAd, error: MaxError) {
        logger.error("onAdDisplayFailed \(error)")
        guard let delegate = delegate else { return }
        let format = MAAdFormat.fromMaxAdFormat(ad.getFormat())
        let maAd = MAAd(ad, format: format)
        let maError = MAError(error)
        delegate.didFail(toDisplay: maAd, withError: maError)
    }

    override func onAdClicked(maxAd: MaxAd) {
        guard let delegate = delegate else { return }
        let format = MAAdFormat.fromMaxAdFormat(maxAd.getFormat())
        let ad = MAAd(maxAd, format: format)
        delegate.didClick(ad)
    }

    override func onAdExpanded(maxAd: MaxAd) {
        guard let delegate = delegate else { return }
        let format = MAAdFormat.fromMaxAdFormat(maxAd.getFormat())
        let ad = MAAd(maxAd, format: format)
        delegate.didExpand(ad)
    }

    override func onAdCollapsed(maxAd: MaxAd) {
        guard let delegate = delegate else { return }
        let format = MAAdFormat.fromMaxAdFormat(maxAd.getFormat())
        let ad = MAAd(maxAd, format: format)
        delegate.didCollapse(ad)
    }

    override func onAdDisplayed(maxAd: MaxAd) {
        /* DO NOT USE - THIS IS RESERVED FOR FULLSCREEN ADS ONLY AND WILL BE REMOVED IN A FUTURE SDK RELEASE */
        guard let delegate = delegate else { return }
        let format = MAAdFormat.fromMaxAdFormat(maxAd.getFormat())
        let ad = MAAd(maxAd, format: format)
        delegate.didDisplay(ad)
    }

    override func onAdHidden(maxAd: MaxAd) {
        /* DO NOT USE - THIS IS RESERVED FOR FULLSCREEN ADS ONLY AND WILL BE REMOVED IN A FUTURE SDK RELEASE */
        guard let delegate = delegate else { return }
        let format = MAAdFormat.fromMaxAdFormat(maxAd.getFormat())
        let ad = MAAd(maxAd, format: format)
        delegate.didHide(ad)
    }
}

#else
import AppLovinSDK

struct AppLovinAdViewWrapper: UIViewRepresentable {
    let bannerAdUnitIdentifier: String
    let placement: String?
    let adFormat: MAAdFormat?
    let configuration: MAAdViewConfiguration?
    let backgroundColor: UIColor
    let delegate: MAAdViewAdDelegate?
    
    init(bannerAdUnitIdentifier: String, adFormat: MAAdFormat, placement: String?, backgroundColor: Color = .black, delegate: MAAdViewAdDelegate? = nil) {
        self.bannerAdUnitIdentifier = bannerAdUnitIdentifier
        self.placement = placement
        self.adFormat = adFormat
        self.configuration = nil
        self.backgroundColor = UIColor(backgroundColor)
        self.delegate = delegate
    }
    
    init(bannerAdUnitIdentifier: String, configuration: MAAdViewConfiguration, placement: String?, backgroundColor: Color = .black, delegate: MAAdViewAdDelegate? = nil) {
        self.bannerAdUnitIdentifier = bannerAdUnitIdentifier
        self.placement = placement
        self.adFormat = nil
        self.configuration = configuration
        self.backgroundColor = UIColor(backgroundColor)
        self.delegate = delegate
    }
    func makeUIView(context: Context) -> AppLovinSDK.MAAdView
    {
        let adView: AppLovinSDK.MAAdView
        if let adFormat {
            adView = AppLovinSDK.MAAdView(adUnitIdentifier: bannerAdUnitIdentifier, adFormat: adFormat)
        } else if let configuration {
            adView = AppLovinSDK.MAAdView(adUnitIdentifier: bannerAdUnitIdentifier, configuration: configuration)
        } else {
            fatalError("Invalid initialization for AppLovinAdViewWrapper")
        }
        context.coordinator.delegate = delegate
        adView.delegate = context.coordinator
        if let placement {
            adView.placement = placement
        }
        // Set background color for banners to be fully functional
        adView.backgroundColor = backgroundColor
        
        // Load the first Ad
        adView.loadAd()
        
        return adView
    }
    
    func updateUIView(_ uiView: AppLovinSDK.MAAdView, context: Context) {}
    
    func makeCoordinator() -> Coordinator
    {
        Coordinator()
    }
}

extension AppLovinAdViewWrapper {
    class Coordinator: NSObject, AppLovinSDK.MAAdViewAdDelegate
        {
            weak var delegate: MAAdViewAdDelegate?
            
            // MARK: MAAdDelegate Protocol
            
            func didLoad(_ ad: AppLovinSDK.MAAd) {
                delegate?.didLoad(ad)
            }
            
            func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: AppLovinSDK.MAError) {
                delegate?.didFailToLoadAd(forAdUnitIdentifier: adUnitIdentifier, withError: error)
            }
            
            func didClick(_ ad: AppLovinSDK.MAAd) {
                delegate?.didClick(ad)
            }
            
            func didFail(toDisplay ad: AppLovinSDK.MAAd, withError error: AppLovinSDK.MAError) {
                delegate?.didFail(toDisplay: ad, withError: error)
            }
            
            // MARK: MAAdViewAdDelegate Protocol
            
            func didExpand(_ ad: AppLovinSDK.MAAd) {
                delegate?.didExpand(ad)
            }
            
            func didCollapse(_ ad: AppLovinSDK.MAAd) {
                delegate?.didCollapse(ad)
            }
            
            // MARK: Deprecated Callbacks
            
            func didDisplay(_ ad: AppLovinSDK.MAAd) {
                /* use this for impression tracking */
                delegate?.didDisplay(ad)
            }
            
            func didHide(_ ad: AppLovinSDK.MAAd) {
                /* DO NOT USE - THIS IS RESERVED FOR FULLSCREEN ADS ONLY AND WILL BE REMOVED IN A FUTURE SDK RELEASE */
                delegate?.didHide(ad)
            }
        }
}

#endif
private struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        guard let value2 = nextValue() else { return }
        value = value2
    }
}

public struct SkipAppLovinAdView: View {
    let bannerAdUnitIdentifier: String
    let placement: String?
    let delegate: MAAdViewAdDelegate?
    
    public init(bannerAdUnitIdentifier: String, placement: String? = nil, delegate: MAAdViewAdDelegate? = nil) {
        self.bannerAdUnitIdentifier = bannerAdUnitIdentifier
        self.placement = placement
        self.delegate = delegate
    }
    @State var width: CGFloat? = nil
    @State var adFormat: MAAdFormat?
    public var body: some View {
        Group {
            if let adFormat, let width {
                AppLovinAdViewWrapper(
                    bannerAdUnitIdentifier: bannerAdUnitIdentifier,
                    adFormat: adFormat,
                    placement: placement,
                    delegate: delegate
                )
                    .id(adFormat) // rebuild AdView from scratch when the format changes
                    .frame(height: adFormat.adaptiveSize(forWidth: width).height)
                    .frame(maxWidth: .infinity)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
        }
        .background {
            GeometryReader { proxy in
                let _ = logger.debug("background \(proxy.size.width)")
                Color.clear
                    .preference(key: WidthPreferenceKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(WidthPreferenceKey.self) { availableWidth in
            logger.debug("availableWidth: \(String(describing: availableWidth))")
            guard let availableWidth else { return }
            width = availableWidth
            let availableAdFormat: MAAdFormat = availableWidth >= MAAdFormat.leader.size.width ? .leader : .banner
            if availableAdFormat != adFormat {
                logger.debug("updating adFormat to \(availableAdFormat)")
                adFormat = availableAdFormat
            }
        }
    }
}

public struct SkipAppLovinAdaptiveAdView: View {
    let bannerAdUnitIdentifier: String
    let placement: String?
    let configuration: MAAdViewConfiguration
    let delegate: MAAdViewAdDelegate?
    
    public init(bannerAdUnitIdentifier: String, configuration: MAAdViewConfiguration, placement: String? = nil, delegate: MAAdViewAdDelegate? = nil) {
        self.bannerAdUnitIdentifier = bannerAdUnitIdentifier
        self.configuration = configuration
        self.placement = placement
        self.delegate = delegate
    }
    @State var width: CGFloat? = nil
    @State var adFormat: MAAdFormat?
    public var body: some View {
        Group {
            if let adFormat, let width {
                AppLovinAdViewWrapper(
                    bannerAdUnitIdentifier: bannerAdUnitIdentifier,
                    configuration: configuration,
                    placement: placement,
                    delegate: delegate
                )
                    .id(adFormat) // rebuild AdView from scratch when the format changes
                    .frame(height: adFormat.adaptiveSize(forWidth: width).height)
                    .frame(maxWidth: .infinity)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
        }
        .background {
            GeometryReader { proxy in
                let _ = logger.debug("background \(proxy.size.width)")
                Color.clear
                    .preference(key: WidthPreferenceKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(WidthPreferenceKey.self) { availableWidth in
            logger.debug("availableWidth: \(String(describing: availableWidth))")
            guard let availableWidth else { return }
            width = availableWidth
            let availableAdFormat: MAAdFormat = availableWidth >= MAAdFormat.leader.size.width ? .leader : .banner
            if availableAdFormat != adFormat {
                logger.debug("updating adFormat to \(availableAdFormat)")
                adFormat = availableAdFormat
            }
        }
    }
}

#endif

