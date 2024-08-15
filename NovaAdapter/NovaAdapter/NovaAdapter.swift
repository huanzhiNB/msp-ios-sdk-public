import Foundation
//import shared
import MSPiOSCore
import PrebidMobile
import NovaCore
import UIKit

public class NovaAdapter: AdNetworkAdapter {
    
    public var adListener: AdListener?
    public var priceInDollar: Double?
    public var adUnitId: String?
    
    public var nativeAd: MSPAd?
    public var nativeAdItem: NovaNativeAdItem?
    
    public var nativeAdView: NativeAdView?
    public var novaNativeAdView: NovaNativeAdView?
    
    
    public var rootViewController: UIViewController?
    
    private var adRequest: AdRequest?
    
    public func destroyAd() {
        
    }
    
    public func initialize(initParams: any InitializationParameters, adapterInitListener: any AdapterInitListener, context: Any?) {
        adapterInitListener.onComplete(adNetwork: .nova, adapterInitStatus: .SUCCESS, message: "")
    }
    
    public func loadAdCreative(bidResponse: Any, adListener: any AdListener, context: Any, adRequest: AdRequest) {
        guard bidResponse is BidResponse,
              let mBidResponse = bidResponse as? BidResponse else {
            self.adListener?.onError(msg: "no valid response")
            return
        }
 
        self.adListener = adListener
        self.adRequest = adRequest
        
        guard let adString = mBidResponse.winningBid?.bid.adm,
              let rawBidDict = SafeAs(mBidResponse.winningBid?.bid.rawJsonDictionary, [String: Any].self),
              let bidExtDict = SafeAs(rawBidDict["ext"], [String: Any].self),
              let novaExtDict = SafeAs(bidExtDict["nova"], [String: Any].self),
              let adUnitId = SafeAs(novaExtDict["ad_unit_id"], String.self),
              let prebidExtDict = SafeAs(bidExtDict["prebid"], [String: Any].self),
              let adType = SafeAs(prebidExtDict["type"], String.self)
        else {
            self.adListener?.onError(msg: "no valid response")
            return
        }
         
        self.priceInDollar = Double(mBidResponse.winningBid?.price ?? 0)
        if context is UIViewController {
            self.rootViewController = context as? UIViewController
        }
        self.adUnitId = adUnitId
        let eCPMInDollar = Decimal(priceInDollar ?? 0.0)
        parseNovaAdString(adString: adString, adType: "native", adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
    }
    
    public func prepareViewForInteraction(nativeAd: MSPiOSCore.NativeAd, nativeAdView: Any) {
        let adOpenActionHandler = NovaAdOpenActionHandler()
        let actionHandlerMaster = ActionHandlerMaster(actionHandlers: [adOpenActionHandler])
        guard let rootViewController = self.rootViewController,
              let nativeAdView = nativeAdView as? NativeAdView,
              let mediaView = nativeAdView.mediaView as? NovaNativeAdMediaView,
              let novaNativeAdItem = self.nativeAdItem else {return}
        let novaNativeAdView = NovaNativeAdView(actionHandler: actionHandlerMaster, 
                                                rootViewController: rootViewController,
                                                mediaView: mediaView)
        novaNativeAdView.titleLabel = nativeAdView.titleLabel
        novaNativeAdView.bodyLabel = nativeAdView.bodyLabel
        novaNativeAdView.advertiserLabel = nativeAdView.advertiserLabel
        novaNativeAdView.callToActionButton = nativeAdView.callToActionButton
        novaNativeAdView.prepareViewForInteraction(nativeAd: novaNativeAdItem)
        
        let novaSubViews = [novaNativeAdView.titleLabel, novaNativeAdView.bodyLabel, novaNativeAdView.advertiserLabel, novaNativeAdView.callToActionButton, mediaView]
        novaNativeAdView.tappableViews = [UIView]()
        for view in novaSubViews {
            if let view = view {
                novaNativeAdView.addSubview(view)
                novaNativeAdView.tappableViews?.append(view)
            }
        }
        novaNativeAdView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.nativeAdViewBinder.setUpViews(parentView: novaNativeAdView)
        
        nativeAdView.addSubview(novaNativeAdView)
        NSLayoutConstraint.activate([
            //novaNativeAdView.centerYAnchor.constraint(equalTo: nativeAdView.centerYAnchor),
            novaNativeAdView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            novaNativeAdView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            novaNativeAdView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            novaNativeAdView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
            novaNativeAdView.widthAnchor.constraint(lessThanOrEqualTo: nativeAdView.widthAnchor),
            novaNativeAdView.heightAnchor.constraint(lessThanOrEqualTo: nativeAdView.heightAnchor),
        ])
    }
    
    func parseNovaAdString(adString: String, adType: String, adUnitId: String, eCPMInDollar: Decimal) {
        let data = adString.data(using: .utf8)
        guard let data = data else { return }

        do {
            let decodedData = try JSONDecoder().decode(NovaResponseDataModel.self, from: data)

            guard let ads = decodedData.ads, 
                    !ads.isEmpty,
                    let adItem = ads.first else {
                self.adListener?.onError(msg: "no valid response")
                return
            }
            
            switch adType {
            case "banner":
                return
                

            case "native":
                let nativeAdItem = NovaAdBuilder.buildNativeAd(adItem: adItem, adUnitId: adUnitId, eCPMInDollar: eCPMInDollar)
                let nativeAd = NovaNativeAd(adNetworkAdapter: self,
                                            title: nativeAdItem.headline ?? "",
                                            body: nativeAdItem.body ?? "",
                                            advertiser: nativeAdItem.advertiser ?? "",
                                            callToAction:nativeAdItem.callToAction ?? "")
                DispatchQueue.main.async{
                    let mediaView = {
                        let view = NovaNativeAdMediaView()
                        view.accessibilityIdentifier = "media"
                        view.translatesAutoresizingMaskIntoConstraints = false
                        return view
                    }()
                    nativeAd.mediaView = mediaView
                    nativeAd.priceInDollar = self.priceInDollar
                    nativeAd.adInfo["priceInDollar"] = self.priceInDollar
                    nativeAd.nativeAdItem = nativeAdItem
                    self.nativeAdItem = nativeAdItem
                    self.nativeAd = nativeAd
                    nativeAdItem.delegate = self
                    if let adListener = self.adListener,
                       let adRequest = self.adRequest {
                        handleAdLoaded(ad: nativeAd, listener: adListener, adRequest: adRequest)
                    }
                }
            default:
                self.adListener?.onError(msg: "unknown adType")
            }
        } catch {
            self.adListener?.onError(msg: "error decode nova ad string")
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
    
    public func loadTestAdCreative(adString: String, adListener: any AdListener, context: Any, adRequest: AdRequest) {
 
        self.adListener = adListener
        self.adRequest = adRequest

        if context is UIViewController {
            self.rootViewController = context as? UIViewController
        }

        let eCPMInDollar = Decimal(priceInDollar ?? 0.0)
        parseNovaAdString(adString: adString, adType: "native", adUnitId: "dummy_id", eCPMInDollar: eCPMInDollar)
    }
}

extension NovaAdapter: NovaNativeAdDelegate {
    public func nativeAdDidLogImpression(_ nativeAd: NovaCore.NovaNativeAdItem) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdImpression(ad: nativeAd)
        }
    }
    
    public func nativeAdDidLogClick(_ nativeAd: NovaCore.NovaNativeAdItem, clickAreaName: String) {
        if let nativeAd = self.nativeAd {
            self.adListener?.onAdClick(ad: nativeAd)
        }
    }
    
    public func nativeAdDidFinishRender(_ nativeAd: NovaCore.NovaNativeAdItem) {
        
    }
    
    public func nativeAdRootViewController() -> UIViewController? {
        return self.rootViewController
    }
}


