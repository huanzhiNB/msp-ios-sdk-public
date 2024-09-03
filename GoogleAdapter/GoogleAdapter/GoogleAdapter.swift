import Foundation
import GoogleMobileAds
import MSPiOSCore
//import shared
import PrebidMobile

@objc public class GoogleAdapter : NSObject, AdNetworkAdapter {
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        
    }
    
    public func destroyAd() {
        
    }
    
    @objc public static func initializeGAD() {
        GADMobileAds.sharedInstance().start()
    }
    
    public func initialize(initParams: InitializationParameters, adapterInitListener: AdapterInitListener, context: Any?) {
        GADMobileAds.sharedInstance().start(completionHandler: {_ in
            adapterInitListener.onComplete(adNetwork: .google, adapterInitStatus: .SUCCESS, message: "")
        })
    }
    
    public var gadBannerView: GAMBannerView?
    public var rootViewController: UIViewController?
    public var adListener: AdListener?
    public var priceInDollar: Double?
    
    private var adLoader: GADAdLoader?
    private var adRequest: AdRequest?
    
    private var bannerAd: BannerAd?
    private var nativeAd: MSPiOSCore.NativeAd?
    
    public func loadAdCreative(bidResponse: Any, adListener: any AdListener, context: Any, adRequest: AdRequest) {
        
        self.adRequest = adRequest
        
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            self.adListener?.onError(msg: "no valid response")
            return
        }
        
        if context is UIViewController {
            self.rootViewController = context as? UIViewController
        }
        
        self.adListener = adListener
        
        guard let adString = mBidResponse.winningBid?.bid.adm,
              let rawBidDict = SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self),
              let bidExtDict = SafeAs(rawBidDict["ext"], [String: Any].self),
              let googleExtDict = SafeAs(bidExtDict["google"], [String: Any].self),
              let adUnitId = SafeAs(googleExtDict["ad_unit_id"], String.self),
              let prebidExtDict = SafeAs(bidExtDict["prebid"], [String: Any].self),
              let adType = SafeAs(prebidExtDict["type"], String.self)
        else {
            self.adListener?.onError(msg: "no valid response")
            return
        }
        self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
        
        switch adType {
        case "banner":
            DispatchQueue.main.async {
                let gadBannerView = GAMBannerView(adSize: self.getGADAdSize(adRequest: adRequest))
                self.gadBannerView = gadBannerView
                gadBannerView.isAutoloadEnabled = false
                let request = GAMRequest()
                request.adString = adString
                gadBannerView.adUnitID = adUnitId
                gadBannerView.delegate = self
                gadBannerView.rootViewController = self.rootViewController
                gadBannerView.load(request)
            }

        case "native":
            self.adListener?.onError(msg: "unknown adType")
            /*
            let gadMultiFormatEnable = false
            let adTypes: [GADAdLoaderAdType] = gadMultiFormatEnable ? [.native, .gamBanner] : [.native]
            let videoOptions = GADVideoOptions()
            videoOptions.startMuted = true
            adLoader = GADAdLoader(
                adUnitID: adUnitId,
                rootViewController: rootViewController,
                adTypes: adTypes,
                options: [videoOptions])
            adLoader?.delegate = self

            let gamRequest = GAMRequest()
            gamRequest.adString = adString
            adLoader?.load(gamRequest)
            
             */
            
        default:
            self.adListener?.onError(msg: "unknown adType")
        }
    }
    
    public func SafeAs<T, U>(_ object: T?, _ objectType: U.Type) -> U? {
        if let object = object {
            if let temp = object as? U {
                return temp
            } else {
                return nil
            }
        } else {
            // It's always OK to cast nil to nil
            return nil
        }
    }

    
    private func getGADAdSize(adRequest: AdRequest) -> GADAdSize {
        if let adaptiveBannerAdSize = adRequest.adaptiveBannerSize {
            if adaptiveBannerAdSize.isAnchorAdaptiveBanner {
                return GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(CGFloat(adaptiveBannerAdSize.width))
            } else if adaptiveBannerAdSize.isInlineAdaptiveBanner {
                return GADInlineAdaptiveBannerAdSizeWithWidthAndMaxHeight(CGFloat(adaptiveBannerAdSize.width), CGFloat(adaptiveBannerAdSize.height))
            }
        }
        if let width = adRequest.adSize?.width,
           let height = adRequest.adSize?.height {
            if width == 300, height == 250 {
                return GADAdSizeMediumRectangle
            }
        }
        return GADAdSizeBanner
    }
}

extension GoogleAdapter : GADBannerViewDelegate {
    public func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        var bannerAd = BannerAd(adView: bannerView, adNetworkAdapter: self)
        self.bannerAd = bannerAd
        if let priceInDollar = self.priceInDollar {
            bannerAd.adInfo["priceInDollar"] = priceInDollar
        }
        
        if let adListener = adListener,
           let adRequest = adRequest {
            handleAdLoaded(ad: bannerAd, listener: adListener, adRequest: adRequest)
        }
    }
    
    public func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        self.adListener?.onError(msg: error.localizedDescription)
    }
    
    public func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
        if let googleAd = self.bannerAd {
            self.adListener?.onAdClick(ad: googleAd)
        }
    }
    
    public func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
        if let googleAd = self.bannerAd {
            self.adListener?.onAdImpression(ad: googleAd)
        }
    }
}

extension GoogleAdapter: GADNativeAdLoaderDelegate {
    public func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        //let mediaView = GADMediaView()
        //mediaView.translatesAutoresizingMaskIntoConstraints = false
        //mediaView.contentMode = .scaleAspectFill
        //mediaView.mediaContent = nativeAd.mediaContent
        //let googleNativeAd = GoogleNativeAd(adNetworkAdapter: self, builder: shared.NativeAd.Builder(adNetworkAdapter: self)
        //    .title(title: nativeAd.headline ?? "")
        //    .body(body: nativeAd.body ?? "")
        //    .advertiser(advertiser: nativeAd.advertiser ?? "")
        //    .callToAction(callToAction: nativeAd.callToAction ?? "")
        //    .mediaView(mediaView: mediaView))
        
        /*
        let googleNativeAd = GoogleNativeAd(adNetworkAdapter: self)
        self.googleNativeAd = googleNativeAd
        googleNativeAd.priceInDollar = self.priceInDollar
        googleNativeAd.nativeAdItem = nativeAd
        //self.adListener?.onAdLoaded(ad: googleNativeAd)
        if let adListener = adListener,
           let adRequest = adRequest {
            handleAdLoaded(ad: googleNativeAd, listener: adListener, adRequest: adRequest)
        }
         */
    }
    
    public func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: any Error) {
        self.adListener?.onError(msg: error.localizedDescription)
    }
}
                            
