/*   Copyright 2018-2021 Prebid.org, Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "PBMORTBAbstract.h"

NS_ASSUME_NONNULL_BEGIN

@interface PBMORTBBidResponseExt : PBMORTBAbstract

/// [ (bidder: String) -> (millis: Integer) ]
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSNumber *> *responsetimemillis;

/// [Integer]
@property (nonatomic, strong, nullable) NSNumber *tmaxrequest;

/// [String]
@property (nonatomic, copy, nullable) NSArray <NSString *> *articleCategories;
@property (nonatomic, copy, nullable) NSArray <NSString *> *monetizationCategories;

@end

NS_ASSUME_NONNULL_END
