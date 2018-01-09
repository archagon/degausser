//
//  CaptureView.m
//  Degausser
//
//  Created by Alexei Baboulevitch on 2017-12-31.
//  Copyright © 2017 Alexei Baboulevitch. All rights reserved.
//

#import "CaptureView.h"
#include <OpenGL/gl.h>

// TODO: failsafe timer: if stays up for more than 10sec, force quit app
// a) opengl context w/o hardware acceleration, b) shader that just spins the rgbs, c) actual degauss shader

@interface CaptureView ()
@property (nonatomic, assign) CVDisplayLinkRef displayLink;
@property (nonatomic, retain) NSTimer* timer;
@property (nonatomic, assign) CGImageRef image;
@end

@implementation CaptureView

-(instancetype) initWithFrame:(NSRect)frameRect
{
    //kCGLPFASupportsAutomaticGraphicsSwitching
    
    NSOpenGLPixelFormatAttribute attribs[] =
    {
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAllowOfflineRenderers, // lets OpenGL know this context is offline renderer aware
        (NSOpenGLPixelFormatAttribute)0
    };
//    NSOpenGLPixelFormatAttribute attribs[] = {
//        //NSOpenGLPFADoubleBuffer,
//        NSOpenGLPFAAccelerated,
//        NSOpenGLPFANoRecovery,
//        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
//        NSOpenGLPFADepthSize, 24,
//        NSOpenGLPFAStencilSize, 8,
//        NSOpenGLPFAColorSize, 24,
//        NSOpenGLPFAAlphaSize, 8,
//        NSOpenGLPFAAllowOfflineRenderers, // lets OpenGL know this context is offline renderer aware
//        (NSOpenGLPixelFormatAttribute)0
//    };
    auto pixFmt = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
    
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_5
    if(pixFmt == nil)
    {
        // NSOpenGLPFAAllowOfflineRenderers is not supported on this OS version
        attribs[3] = (NSOpenGLPixelFormatAttribute)0;
        pixFmt = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
    }
#endif
    
    //pixFmt = [[self class] defaultPixelFormat];
    
//    self = [super initWithFrame:frameRect pixelFormat:pixFmt];
    self = [super initWithFrame:frameRect];
    if (self)
    {
        self.displayLink = NULL;
        self.timer = nil;
        self.image = NULL;
    }
    return self;
}

-(void) setImage:(CGImageRef)image
{
    if (_image == image)
    {
        return;
    }
    
    if (self.image != NULL)
    {
        CGImageRelease(_image);
    }
    
    _image = image;
}

-(void) viewDidMoveToWindow
{
    // prevents window from appearing in screen capture
    self.window.sharingType = NSWindowSharingNone;
}

-(void) drawRect:(NSRect)dirtyRect
//-(void) drawRect2:(NSRect)dirtyRect
{
    if (self.image == NULL)
    {
        return;
    }

    auto ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextDrawImage(ctx, self.bounds, self.image);

    self.image = NULL;
}

//-(void) drawRect:(NSRect)dirtyRect
//{
//    glClearColor(0, 0, 0, 0);
//    glClear(GL_COLOR_BUFFER_BIT);
//    glColor3f(1.0f, 0.85f, 0.35f);
//    glBegin(GL_TRIANGLES);
//    {
//        glVertex3f(  0.0, (double)(arc4random()%1000)/999.0, 0.0);
//        glVertex3f( -0.2, -0.3, 0.0);
//        glVertex3f(  0.2, -0.3 ,0.0);
//    }
//    glEnd();
//    //glFlush();
//    glSwapAPPLE();
//}

//-(void) drawRect:(NSRect)dirtyRect
-(void) drawRect2:(NSRect)dirtyRect
{
    if (self.image == NULL)
    {
        return;
    }
    
    CGImageRef myImageRef = self.image;
    GLuint myTextureName;
    
    CGFloat width = CGImageGetWidth(myImageRef);
    CGFloat height = CGImageGetHeight(myImageRef);
    CGRect rect = {{0, 0}, {width, height}};
    
    void* myData = calloc(width * 4, height);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef myBitmapContext = CGBitmapContextCreate(myData,
                                                         width, height, 8,
                                                         width * 4, space,
                                                         kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
    CGContextSetBlendMode(myBitmapContext, kCGBlendModeCopy);
    CGContextDrawImage(myBitmapContext, rect, myImageRef);
    CGContextRelease(myBitmapContext);
    
    glPixelStorei(GL_UNPACK_ROW_LENGTH, width);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glGenTextures(1, &myTextureName);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, myTextureName);
    glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,
                    GL_TEXTURE_MIN_FILTER,
                    GL_LINEAR);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB,
                 0,
                 GL_RGBA8,
                 width,
                 height,
                 0,
                 GL_BGRA_EXT,
                 GL_UNSIGNED_INT_8_8_8_8_REV,
                 myData);
    
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    glColor3f(1.0f, 0.85f, 0.35f);
    glEnable(GL_TEXTURE);
    glBegin(GL_QUADS);
    {
        glTexCoord2f(0, 0);
        glVertex2f(0.25, 0.25);
        glTexCoord2f(1, 0);
        glVertex2f(0.75, 0.25);
        glTexCoord2f(1, 1);
        glVertex2f(0.75, 0.75);
        glTexCoord2f(0, 1);
        glVertex2f(0.25, 0.75);
    }
    glEnd();
    
    glSwapAPPLE();
    
    glDeleteTextures(1, &myTextureName);
    free(myData);
    self.image = NULL;
}

-(void) start
{
    // display link
    if (NO)
    {
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, &CaptureViewLoop, (__bridge void*)self);
        
    //    // Set the display link for the current renderer
    //    CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
    //    CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
    //    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);
        
        CVDisplayLinkStart(_displayLink);
    }
    
    // timer
    {
        auto timer = [NSTimer timerWithTimeInterval:1/20.0 repeats:YES block:^(NSTimer * _Nonnull timer)
        {
            [self updateCapture];
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        
        self.timer = timer;
    }
}

-(void) stop
{
}

-(void) updateCapture
{
    self.image = NULL;

    auto screenshot = CreateScreenshot((CGWindowID)self.window.windowNumber);
    self.image = screenshot;
    
    [self setNeedsDisplay:YES];
}

static CVReturn CaptureViewLoop(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
    [(__bridge CaptureView*)displayLinkContext updateCapture];
    return kCVReturnSuccess;
}

// requires release!
static CGImageRef CreateScreenshot(CGWindowID windowId = kCGNullWindowID)
{
    //CGImageRef screenshot = CGWindowListCreateImage(CGRectInfinite, kCGWindowListOptionOnScreenBelowWindow, windowId, kCGWindowImageDefault);
    
    CGImageRef screenshot = CGWindowListCreateImage(CGRectInfinite, kCGWindowListOptionOnScreenOnly, kCGNullWindowID, kCGWindowImageDefault);
    
    // cursor
    {
        NSPoint mouseLoc = [NSEvent mouseLocation];
        NSImage* overlay = [[[NSCursor currentSystemCursor] image] copy];
        
        int x = (int)mouseLoc.x;
        int y = (int)mouseLoc.y;
        int w = (int)[overlay size].width;
        int h = (int)[overlay size].height;
        int org_x = x;
        int org_y = y;
        
        size_t height = CGImageGetHeight(screenshot);
        size_t width =  CGImageGetWidth(screenshot);
        size_t bytesPerRow = CGImageGetBytesPerRow(screenshot);
        
        unsigned int* imgData = (unsigned int*)malloc(height * bytesPerRow);
        
        CGRect bgBoundingBox = CGRectMake(0, 0, width, height);
        
        CGContextRef context =  CGBitmapContextCreate(imgData,
                                                      width,
                                                      height,
                                                      8,
                                                      bytesPerRow,
                                                      CGImageGetColorSpace(screenshot),
                                                      CGImageGetBitmapInfo(screenshot));
        CGContextDrawImage(context, bgBoundingBox, screenshot);
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), screenshot);
        CGContextDrawImage(context, CGRectMake(org_x, org_y, w,h), [overlay CGImageForProposedRect:NULL context:NULL hints:NULL]);
        CGImageRef pFinalImage = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        
        return pFinalImage;
    }
    
    //return screenshot;
}

@end
