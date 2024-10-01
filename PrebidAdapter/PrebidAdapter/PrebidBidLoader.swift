import Foundation
//import shared
import MSPiOSCore
import PrebidMobile

public class PrebidBidLoader : BidLoader {
    
    public var bidRequester: PBMBidRequester?
    public var configId: String?
    public var bidListener: BidListener?
    
    public var adRequest: AdRequest?
    
    public var googleQueryInfo: String?
    public var facebookBidToken: String?
    private let dispatchGroup = DispatchGroup()
    
    public override init(googleQueryInfoFetcher: GoogleQueryInfoFetcher, facebookBidTokenProvider: FacebookBidTokenProvider) {
        
        super.init(googleQueryInfoFetcher: googleQueryInfoFetcher, facebookBidTokenProvider: facebookBidTokenProvider)
        
    }
    
    public override func loadBid(placementId: String, adParams: [String : Any], bidListener: any BidListener, adRequest: AdRequest) {
        self.configId = placementId
        self.bidListener = bidListener
        self.adRequest = adRequest
        
        //googleQueryInfoFetcher.fetch(completeListener: self, adRequest: adRequest)
        self.fetchTokens(adRequest: adRequest){ googleQueryInfo, facebookBidToken in
            self.loadBidWithTokens(googleQueryInfo: googleQueryInfo, facebookBidToken: facebookBidToken, adRequest: adRequest)
        }
    }
    
    func fetchTokens(adRequest: AdRequest, completion: @escaping (String?, String?) -> Void) {
        self.dispatchGroup.enter()
        self.googleQueryInfoFetcher.fetch(completeListener: self, adRequest: adRequest)
        
        self.dispatchGroup.enter()
        self.facebookBidTokenProvider.fetch(completeListener: self, context: self)

        dispatchGroup.notify(queue: .main) {
            completion(self.googleQueryInfo, self.facebookBidToken)
        }
    }
    
    public func loadBidWithTokens(googleQueryInfo: String?, facebookBidToken: String?, adRequest: AdRequest) {

        let width = Int(adRequest.adSize?.width ?? 320)
        let height = Int(adRequest.adSize?.height ?? 50)
        let adSize = CGSize(width: width, height: height)
        var adUnitConfig = getAdUnitConfig(configId: configId ?? "demo-ios-article-top",
                                           gadQueryInfo: googleQueryInfo,
                                           facebookBidToken: facebookBidToken,
                                           requestUUID: UUID().uuidString,
                                           prebidBannerAdSize: adSize,
                                           adRequest: adRequest)
        
        let bidRequester = PBMBidRequester(connection: ServerConnection.shared,
                                           sdkConfiguration: Prebid.shared,
                                           targeting: Targeting.shared,
                                           adUnitConfiguration: adUnitConfig)
        self.bidRequester = bidRequester
        
        bidRequester.requestBids { [weak self] bidResponse, error in
            guard let self = self else { return }

            if let error = error {
                bidListener?.onError(msg: error.localizedDescription)
                return
            }
            
            if let bidResponse = bidResponse {
                let seat = bidResponse.winningBidSeat
                if self.bidListener == nil {
                }
                if seat == "msp_google" {
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.google)
                } else if seat == "audienceNetwork" {
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.facebook)
                } else if seat == "msp_nova" {
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.nova)
                }else {
                    self.bidListener?.onBidResponse(bidResponse: bidResponse, adNetwork: AdNetwork.prebid)
                }
            } else {
                bidListener?.onError(msg: "missing response")
            }
        }
    }
    
    
    public func getAdUnitConfig(configId: String,
                                gadQueryInfo: String?,
                                facebookBidToken: String?,
                                requestUUID: String,
                                prebidBannerAdSize: CGSize,
                                adRequest: AdRequest) -> AdUnitConfig {
        let adUnitConfig = AdUnitConfig(configId: configId, size: prebidBannerAdSize)
        if adRequest.adFormat == .banner {
            adUnitConfig.adConfiguration.bannerParameters.api = PrebidConstants.supportedRenderingBannerAPISignals
            adUnitConfig.adFormats = [.display]
        } else if adRequest.adFormat == .native {
            adUnitConfig.nativeAdConfiguration = NativeAdConfiguration()
            adUnitConfig.adFormats = [.native]
        } else if adRequest.adFormat == .multi_format {
            adUnitConfig.adConfiguration.bannerParameters.api = PrebidConstants.supportedRenderingBannerAPISignals
            adUnitConfig.nativeAdConfiguration = NativeAdConfiguration()
            adUnitConfig.adFormats = [.display, .native]
        } else if adRequest.adFormat == .interstitial {
            adUnitConfig.adPosition = .fullScreen
            adUnitConfig.adConfiguration.adFormats = [.display]
            adUnitConfig.adConfiguration.isInterstitialAd = true
            adUnitConfig.adConfiguration.bannerParameters.api = PrebidConstants.supportedRenderingBannerAPISignals
        }
        
        var userExt = Targeting.shared.userExt ?? [String: AnyHashable]()
        userExt["geo"] = getGeoDict()
        Targeting.shared.userExt = userExt
        
        let customParams = adRequest.customParams
        for (key, value) in customParams {
            if value is String {
                adUnitConfig.addContextData(key: key, value: value as? String ?? "")
            }
        }
        
        
        let testParams = adRequest.testParams
        for (key, value) in testParams {
            if value is String {
                adUnitConfig.addContextData(key: key, value: value as? String ?? "")
            }
        }
        

        if let gadQueryInfo = gadQueryInfo {
            adUnitConfig.addContextData(key: "query_info", value: gadQueryInfo)
        }
        if let facebookBidToken = facebookBidToken {
            Targeting.shared.buyerUID = facebookBidToken
        }
        
        if adRequest.adFormat == .native || adRequest.adFormat == .multi_format {
            var assets = [NativeAsset]()
            assets.append(NativeAssetTitle(length: 100, required: true))
            adUnitConfig.nativeAdConfiguration?.markupRequestObject.assets = assets
        }
        
        return adUnitConfig
    }
    
    private func getGeoDict() -> [String: String] {
        var geoDict = [String: String]()
        geoDict["city"] = adRequest?.geo?.city
        geoDict["state_code"] = adRequest?.geo?.stateCode
        geoDict["zipcode"] = adRequest?.geo?.zipCode
        geoDict["lat"] = adRequest?.geo?.lat
        geoDict["lon"] = adRequest?.geo?.lon
        return geoDict
    }
}

extension PrebidBidLoader: GoogleQueryInfoListener {
    public func onComplete(queryInfo: String) {
        //loadBidWithQueryInfo(queryInfo: queryInfo)
        self.googleQueryInfo = queryInfo
        dispatchGroup.leave()
    }
}

extension PrebidBidLoader: FacebookBidTokenListener {
    public func onComplete(bidToken: String) {
        self.facebookBidToken = bidToken
        dispatchGroup.leave()
    }
}


