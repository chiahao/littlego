// -----------------------------------------------------------------------------
// Copyright 2013 Patrick Näf (herzbube@herzbube.ch)
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


// Project includes
#import "PlayViewLayerDelegateBase.h"


// -----------------------------------------------------------------------------
/// @brief The InfluenceLayerDelegate class is responsible for drawing a
/// rectangle on each intersection that indicates which player has more
/// influence on that intersection. The size of the rectangle indicates the
/// degree of influence the player has.
// -----------------------------------------------------------------------------
@interface InfluenceLayerDelegate : PlayViewLayerDelegateBase
{
}

/// @name PlayViewLayerDelegate methods
//@{
- (void) notify:(enum PlayViewLayerDelegateEvent)event eventInfo:(id)eventInfo;
//@}

/// @name CALayer delegate methods
//@{
- (void) drawLayer:(CALayer*)layer inContext:(CGContextRef)context;
//@}

@end
