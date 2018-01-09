//
//  CaptureView.h
//  Degausser
//
//  Created by Alexei Baboulevitch on 2017-12-31.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//@interface CaptureView : NSOpenGLView
@interface CaptureView : NSView
-(instancetype) initWithFrame:(NSRect)frameRect NS_DESIGNATED_INITIALIZER;
-(void) start;
@end
