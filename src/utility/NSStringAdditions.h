// -----------------------------------------------------------------------------
// Copyright 2011-2013 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// Forward declarations
@class NSString;


// -----------------------------------------------------------------------------
/// @brief The NSStringAdditions category enhances NSString by adding a number
/// of useful class methods.
///
/// @ingroup utility
// -----------------------------------------------------------------------------
@interface NSString(NSStringAdditions)
+ (NSString*) UUIDString;
- (UIImage*) imageWithFont:(UIFont*)font drawShadow:(bool)drawShadow;
+ (NSString*) stringWithKomi:(double)komi numericZeroValue:(bool)numericZeroValue;
+ (NSString*) stringWithFractionValue:(double)value;
- (NSString*) stringByAppendingDeviceSuffix;
+ (NSString*) stringWithKoRule:(enum GoKoRule)koRule;
+ (NSString*) stringWithScoringSystem:(enum GoScoringSystem)scoringSystem;
+ (NSString*) stringWithMoveIsIllegalReason:(enum GoMoveIsIllegalReason)reason;
@end
