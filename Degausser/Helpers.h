//
//  Helpers.h
//  Degausser
//
//  Created by Alexei Baboulevitch on 2018-1-2.
//  Copyright © 2018 Alexei Baboulevitch. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern const NSWindowLevel kStickyWindowLevel;
extern const NSWindowCollectionBehavior kStickyWindowCollectionBehavior;
//setFloatingPanel:YES
//Application is Agent

CGFloat PerlinNoise(CGFloat x, CGFloat y, CGFloat z, int seed);
CGFloat OctavePerlinNoise(CGFloat x, CGFloat y, CGFloat z, int octaves, CGFloat persistence, int seed);
CGFloat CircleCircleIntersection(CGPoint c0, CGFloat r0, CGPoint c1, CGFloat r1);

@interface Helpers : NSObject
@end
