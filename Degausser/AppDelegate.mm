//
//  AppDelegate.m
//  Degausser
//
//  Created by Alexei Baboulevitch on 2017-12-31.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

#import "AppDelegate.h"
#import "DegaussController.h"
#import "Helpers.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

-(void) applicationDidFinishLaunching:(NSNotification*)aNotification
{
    self.window.level = kStickyWindowLevel;
    self.window.collectionBehavior = kStickyWindowCollectionBehavior;
    
    DegaussController* dvc = [[DegaussController alloc] initWithNibName:nil bundle:nil];
    [self.window setContentViewController:dvc];
}

//    NSWindowCollectionBehaviorCanJoinAllSpaces = 1 << 0,
//    NSWindowCollectionBehaviorMoveToActiveSpace = 1 << 1,

//typedef NS_ENUM(NSInteger, NSWindowAnimationBehavior) {
//    NSWindowAnimationBehaviorDefault = 0,       // let AppKit infer animation behavior for this window
//    NSWindowAnimationBehaviorNone = 2,          // suppress inferred animations (don't animate)
//
//    NSWindowAnimationBehaviorDocumentWindow = 3,
//    NSWindowAnimationBehaviorUtilityWindow = 4,
//    NSWindowAnimationBehaviorAlertPanel = 5
//} NS_ENUM_AVAILABLE_MAC(10_7);

-(void) applicationWillTerminate:(NSNotification*)aNotification
{
}

@end
