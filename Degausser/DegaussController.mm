//
//  DegaussController.m
//  Degausser
//
//  Created by Alexei Baboulevitch on 2017-12-31.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

#import "DegaussController.h"
#import "CaptureView.h"
#import "Helpers.h"
#import "FakeCRTView.h"

@interface DegaussController ()
@property (nonatomic, retain) NSButton* degaussButton;
@property (nonatomic, retain) NSWindow* overlay;
@end

@implementation DegaussController

-(void) loadView
{
    auto view = [NSView new];
    view.frame = NSMakeRect(0, 0, 100, 100);
    view.wantsLayer = YES;
    self.view = view;
}

-(void) viewDidLoad
{
    [super viewDidLoad];
    
    // appearance
    {
        self.view.layer.backgroundColor = NSColor.blueColor.CGColor;
        self.view.frame = NSMakeRect(0, 0, 300, 100);
    }
    
    // subview setup
    {
        auto button = [NSButton buttonWithTitle:@"Degauss!" target:self action:@selector(degauss:)];
        [self.view addSubview:button];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        auto centerX = [button.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor];
        auto centerY = [button.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor];
        [NSLayoutConstraint activateConstraints:@[centerX, centerY]];
        self.degaussButton = button;
    }
}

-(void) degauss:(NSButton*)sender
{
    NSLog(@"Degaussing!");
    
    // window shenanigans
    {
//        [self.overlay close];
//        self.overlay = nil;
        
        //NSRect windowRect0 = [[NSScreen screens][0] frame];
        //NSRect windowRect = NSMakeRect(10, 0, windowRect0.size.width, windowRect0.size.height);
        //NSRect windowRect = [[NSScreen screens][0] frame];
        NSRect windowRect = NSMakeRect(100, 100, 700 * 1.6, 700);
        NSWindow* overlayWindow = [[NSWindow alloc] initWithContentRect:windowRect
                                                              styleMask:NSWindowStyleMaskBorderless
                                                                backing:NSBackingStoreBuffered
                                                                  defer:NO
                                                                 screen:[NSScreen mainScreen]];
        
        [overlayWindow setReleasedWhenClosed:YES];
        [overlayWindow setBackgroundColor:[NSColor colorWithCalibratedRed:0.0
                                                                    green:0.0
                                                                     blue:0.0
                                                                    alpha:1.0]];
        [overlayWindow setAlphaValue:1];
        [overlayWindow setOpaque:NO];
        [overlayWindow setIgnoresMouseEvents:YES];
        [overlayWindow makeKeyAndOrderFront:nil];
//
//        overlayWindow.level = kStickyWindowLevel;
//        overlayWindow.collectionBehavior = kStickyWindowCollectionBehavior;
        
//        auto captureView = [CaptureView new];
//        captureView.frame = NSMakeRect(0, 0, windowRect.size.width, windowRect.size.height);
//        overlayWindow.contentView = captureView;
//
//        [captureView start];
        
        auto crtView = [FakeCRTView new];
        crtView.frame = NSMakeRect(0, 0, windowRect.size.width, windowRect.size.height);
        overlayWindow.contentView = crtView;
        
//        NSImageView* image = [NSImageView new];
//        image.frame = NSMakeRect(0, 0, windowRect.size.width, windowRect.size.height);
//        overlayWindow.contentView = image;
//
//        auto screenshot = CreateScreenshot();
//        image.image = [[NSImage alloc] initWithCGImage:screenshot size:CGSizeMake(CGImageGetWidth(screenshot), CGImageGetHeight(screenshot))];
//        CGImageRelease(screenshot);
        
        self.overlay = overlayWindow;
        
//        [NSCursor hide];
    }
}

@end
