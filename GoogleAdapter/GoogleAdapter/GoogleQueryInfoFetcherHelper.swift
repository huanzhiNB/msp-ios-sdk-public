//
//  GoogleQueryInfoFetcherHelper.swift
//  GoogleAdapter
//
//  Created by Huanzhi Zhang on 12/21/23.
//

import Foundation
import MSPiOSCore
import GoogleMobileAds

public class GoogleQueryInfoFetcherHelper: GoogleQueryInfoFetcher {
    public init() {
        
    }
    
    public func fetch(completeListener: GoogleQueryInfoListener, adRequest: AdRequest) {
        let request = GAMRequest()
        // Specify the "query_info_type" as "requester_type_8" to
        // denote that the usage of QueryInfo is for Ad Manager S2S.
        let extras = GADExtras()
        extras.additionalParameters = ["query_info_type" : "requester_type_8"]
        request.register(extras)
        let googleAdFormat = GADAdFormat.banner
        GADQueryInfo.createQueryInfo(with: request, adFormat: googleAdFormat) { [weak self] queryInfo, error in
            guard let self = self else {return}
            if let error = error {
                print("demo error: \(error.localizedDescription)")
                return
            }

            if let queryInfoString = queryInfo?.query {
                completeListener.onComplete(queryInfo: queryInfoString)
            } else {
                print("demo error: no query info string")
            }
        }
    }
    
    private func getExtras(adRequest: AdRequest) -> GADExtras {
        let extras = GADExtras()
        if let adapterBannerSize = adRequest.adaptiveBannerSize,
           adapterBannerSize.isInlineAdaptiveBanner {
            extras.additionalParameters = ["query_info_type" : "requester_type_8",
                                           "inlined_adaptive_banner_w" : adapterBannerSize.width,
                                           "inlined_adaptive_banner_h" : adapterBannerSize.height]
        } else {
            extras.additionalParameters = ["query_info_type" : "requester_type_8"]
        }
        return extras
    }
}