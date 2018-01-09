//
//  FakeCRTView.m
//  Degausser
//
//  Created by Alexei Baboulevitch on 2018-1-4.
//  Copyright © 2018 Alexei Baboulevitch. All rights reserved.
//

#import "FakeCRTView.h"
#import "Helpers.h"
#import "linalg.h"

using namespace linalg;

@interface FakeCRTView ()
@property (nonatomic, assign) CGImageRef screenshot;
@property (nonatomic, assign) CFDataRef screenshotData;
@property (nonatomic, assign) CFDataRef distortionData;
@property (nonatomic, assign) CGFloat*** perlinGrid;
@property (nonatomic, assign) vec<CGFloat, 2>*** perlinNormals;
@end

@implementation FakeCRTView

static CGFloat ratio = 0.625;
static CGFloat vWidth = 400;
static CGFloat vHeight = round(vWidth * ratio);

/* Our perlin grid mostly has the same resolution as our buffer, but with depth and an extra border on the sides
 to improve interpolation behavior. pFuncWidth and pFuncHeight refer to the grid resolution passed into the
 Perlin noise function. This determines the size of the Perlin geometry. */

static CGFloat pBorder = 0.15 * vHeight;
static CGFloat pWidth = vWidth + pBorder * 2;
static CGFloat pHeight = vHeight + pBorder * 2;
static CGFloat pDepth = 20;
static CGFloat pFuncWidth = 2.5;
static CGFloat pFuncHeight = pFuncWidth * ratio;
static CGFloat pGeometryScale = 80; //blobbiness
static CGFloat pNormalReach = 0.3 * vHeight; //foldiness
static CGFloat pSamplingWidth = pBorder * 0.75;
static int pSamplingSideCount = 5; //only odd

static CGFloat PerlinValue(CGFloat p)
{
    p = (p + 1) / 2.0; //linearize
    p = tan(p * M_PI + M_PI / 2.0) / 7.0;
    p = p * pGeometryScale;
    return p;
}

-(void) dealloc
{
    CGImageRelease(self.screenshot);
    CFRelease(self.screenshotData);
    
    // cleanup perlin grid
    for (int x = 0; x < pWidth; x++)
    {
        for (int y = 0; y < pHeight; y++)
        {
            delete _perlinGrid[x][y];
        }
        delete _perlinGrid[x];
    }
    delete _perlinGrid;
    
    // cleanup perlin normal grid
    for (int x = 0; x < pWidth - 1; x++)
    {
        for (int y = 0; y < pHeight - 1; y++)
        {
            delete _perlinNormals[x][y];
        }
        delete _perlinNormals[x];
    }
    delete _perlinNormals;
}

-(instancetype) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self)
    {
        auto imageName = @"screenshot.png";
        auto imageURL = [[NSBundle mainBundle] URLForResource:imageName withExtension:nil];
        auto image = [[NSImage alloc] initWithContentsOfFile:imageURL.path];
        auto imageRect = NSMakeRect(0, 0, image.size.width, image.size.height);
        
        auto cgImage = [image CGImageForProposedRect:&imageRect context:NULL hints:nil];
        auto cgImageDataProvider = CGImageGetDataProvider(cgImage);
        auto cgImageData = CGDataProviderCopyData(cgImageDataProvider);
        
        CGImageRetain(cgImage);
        self.screenshot = cgImage;
        self.screenshotData = cgImageData;
        
        CGDataProviderRelease(cgImageDataProvider);
        
        // create perlin grid
        self.perlinGrid = new CGFloat**[pWidth];
        for (int x = 0; x < pWidth; x++)
        {
            self.perlinGrid[x] = new CGFloat*[pHeight];
            for (int y = 0; y < pHeight; y++)
            {
                self.perlinGrid[x][y] = new CGFloat[pDepth];
            }
        }
        
        // create perlin normal grid
        self.perlinNormals = new vec<CGFloat, 2>**[pWidth - 1];
        for (int x = 0; x < pWidth - 1; x++)
        {
            self.perlinNormals[x] = new vec<CGFloat, 2>*[pHeight - 1];
            for (int y = 0; y < pHeight - 1; y++)
            {
                self.perlinNormals[x][y] = new vec<CGFloat, 2>[pDepth];
            }
        }
        
        // generate perlin grid values
        auto seed = arc4random();
        for (int x = 0; x < pWidth; x++)
        {
            for (int y = 0; y < pHeight; y++)
            {
                for (int z = 0; z < pDepth; z++)
                {
                    self.perlinGrid[x][y][z] = OctavePerlinNoise(x * pFuncWidth / (pWidth - 1),
                                                                 y * pFuncHeight / (pHeight - 1),
                                                                 z/(CGFloat)30, 1, 0, seed);
                }
            }
        }
        
        // generate perlin normal grid values
        for (int x = 0; x < pWidth - 1; x++)
        {
            for (int y = 0; y < pHeight - 1; y++)
            {
                for (int z = 0; z < pDepth; z++)
                {
                    auto tl = self.perlinGrid[x][y][z];
                    auto tr = self.perlinGrid[x + 1][y][z];
                    auto br = self.perlinGrid[x + 1][y + 1][z];
                    auto bl = self.perlinGrid[x][y + 1][z];
                    
                    tl = PerlinValue(tl);
                    tr = PerlinValue(tr);
                    br = PerlinValue(br);
                    bl = PerlinValue(bl);
                    
                    auto vtl = vec<CGFloat, 3>(x, y, tl);
                    auto vtr = vec<CGFloat, 3>(x + 1, y, tr);
                    auto vbr = vec<CGFloat, 3>(x + 1, y + 1, br);
                    auto vbl = vec<CGFloat, 3>(x, y + 1, bl);
                    
                    //NSLog(@"vtl: %f, %f, %f", vtl.x, vtl.y, vtl.z);
                    //NSLog(@"vtr: %f, %f, %f", vtr.x, vtr.y, vtr.z);
                    //NSLog(@"vbr: %f, %f, %f", vbr.x, vbr.y, vbr.z);
                    //NSLog(@"vbl: %f, %f, %f", vbl.x, vbl.y, vbl.z);
                    
                    // tri 1 normal
                    auto & t1p1 = vtl;
                    auto & t1p2 = vtr;
                    auto & t1p3 = vbl;
                    auto t1v = t1p2 - t1p1;
                    auto t1w = t1p3 - t1p1;
                    auto t1n = linalg::cross(t1v, t1w);
                    
                    // tri 2 normal
                    auto & t2p1 = vtr;
                    auto & t2p2 = vbr;
                    auto & t2p3 = vbl;
                    auto t2v = t2p2 - t2p1;
                    auto t2w = t2p3 - t2p1;
                    auto t2n = linalg::cross(t2v, t2w);
                    
                    // average normal
                    auto n = (t1n + t2n) / 2.0;
                    n = normalize(n);
                    
                    // projection onto 2d plane
                    auto pn = n.xy();
                    
                    self.perlinNormals[x][y][z] = pn;
                }
            }
        }
    }
    return self;
}

-(void) drawRect:(NSRect)dirtyRect
{
    auto ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    
    auto rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    //CGContextSetBlendMode (myContext, kCGBlendModeDarken);
    auto bctx = CGBitmapContextCreate(NULL, vWidth, vHeight, 8, 0, rgbColorSpace, kCGImageAlphaPremultipliedFirst);
    
    CGFloat supersamples = 3;
    
    // regular draw
//    if (NO)
    {
        for (int sy = 0; sy < vHeight * supersamples; sy++)
        {
            for (int sx = 0; sx < vWidth * supersamples; sx++)
            {
                CGFloat x = sx / supersamples;
                CGFloat y = sy / supersamples;
                
                CGFloat dx = x;
                CGFloat dy = y;
                for (int i = 0; i < 1; i++)
                {
                    auto avg = [self perlinNormalXPercent:x / (vWidth - 1) yPercent:y / (vHeight - 1)] * pNormalReach;
                    
                    dx += avg.x;
                    dy += avg.y;
                }
                
                {
                    //dx = round(dx);
                    //dy = round(dy);
                    
                    auto rect = NSMakeRect(dx, dy, 1, 1);
                    
                    CGContextSetBlendMode(bctx, kCGBlendModeClear);
                    CGContextSetRGBFillColor(bctx, 0, 0, 0, 1.0);
                    CGContextFillRect(bctx, rect);
                    
                    auto color = [self screenshotPixelXPercent:x / (vWidth - 1) yPercent:y / (vHeight - 1)];
                    CGContextSetBlendMode(bctx, kCGBlendModePlusLighter);
                    CGContextSetRGBFillColor(bctx, color.redComponent, 0, 0, 1.0);
                    CGContextFillRect(bctx, rect);
                    CGContextSetRGBFillColor(bctx, 0, color.greenComponent, 0, 1.0);
                    CGContextFillRect(bctx, rect);
                    CGContextSetRGBFillColor(bctx, 0, 0, color.blueComponent, 1.0);
                    CGContextFillRect(bctx, rect);
                    
                    //auto dx0 = floor(dx);
                    //auto dy0 = floor(dy);
                    //auto dx1 = ceil(dx);
                    //auto dy1 = ceil(dy);
                    //auto ix = 1 - (dx - dx0);
                    //auto iy = 1 - ix;
                    //
                    //auto ibl = ix * iy; //0.75 * 0.25
                    //auto ibr = (1 - ix) * iy; //0.25 * 0.25
                    //auto itr = (1 - ix) * (1 - iy); //0.25 * 0.75
                    //auto itl = ix * (1 - iy); //0.75 * 0.75
                    //
                    //auto rbl = NSMakeRect(dx0, dy0, 1, 1);
                    //auto rbr = NSMakeRect(dx1, dy0, 1, 1);
                    //auto rtr = NSMakeRect(dx1, dy1, 1, 1);
                    //auto rtl = NSMakeRect(dx0, dy1, 1, 1);
                    //
                    //CGContextSetRGBFillColor(bctx, color.redComponent, color.greenComponent, color.blueComponent, ibl);
                    //CGContextFillRect(bctx, rbl);
                    //CGContextSetRGBFillColor(bctx, color.redComponent, color.greenComponent, color.blueComponent, ibr);
                    //CGContextFillRect(bctx, rbr);
                    //CGContextSetRGBFillColor(bctx, color.redComponent, color.greenComponent, color.blueComponent, itr);
                    //CGContextFillRect(bctx, rtr);
                    //CGContextSetRGBFillColor(bctx, color.redComponent, color.greenComponent, color.blueComponent, itl);
                    //CGContextFillRect(bctx, rtl);
                }
            }
        }
    }
    
    CGContextSetBlendMode(bctx, kCGBlendModeNormal);
    
    // perlin draw
    {
        if (NO)
        {
            for (int y = 0; y < vHeight; y++)
            {
                for (int x = 0; x < vWidth; x++)
                {
                    int px = x + pBorder;
                    int py = y + pBorder;
                    
                    auto perlin = self.perlinGrid[px][py][0];
                    
                    auto rect = NSMakeRect(x, y, 1, 1);
                    
                    NSColor* color;
                    auto epsilon = 0.05;
                    perlin = (perlin + 1) / 2.0;
                    if (perlin >= 0.5 - epsilon && perlin <= 0.5 + epsilon)
                    {
                        color = [NSColor blueColor];
                    }
                    else if (perlin <= 0.2)
                    {
                        color = [NSColor purpleColor];
                    }
                    else if (perlin >= 0.8)
                    {
                        color = [NSColor greenColor];
                    }
                    else
                    {
                        color = [NSColor colorWithWhite:perlin alpha:1];
                    }
                    CGContextSetFillColorWithColor(bctx, color.CGColor);
                    CGContextFillRect(bctx, rect);
                }
            }
        }
        if (NO)
        {
            for (int y = 0; y < vHeight; y++)
            {
                for (int x = 0; x < vWidth; x++)
                {
                    if (x % 10 == 0 && y % 10 == 0)
                    {
                        int px = x + pBorder;
                        int py = y + pBorder;
                        
                        auto dir = self.perlinNormals[px][py][0];
                        dir = dir * pNormalReach / 2.0;
                        auto p0 = NSMakePoint(x, y);
                        auto p1 = NSMakePoint(x + dir.x, y + dir.y);
                        
                        auto linePath = CGPathCreateMutable();
                        CGPathMoveToPoint(linePath, NULL, p0.x, p0.y);
                        CGPathAddLineToPoint(linePath, NULL, p1.x, p1.y);
                        
                        auto circlePath = CGPathCreateWithEllipseInRect(NSMakeRect(p1.x - 1.5, p1.y - 1.5, 1.5 * 2, 1.5 * 2), NULL);
                        
                        CGContextSetFillColorWithColor(bctx, NSColor.redColor.CGColor);
                        CGContextSetStrokeColorWithColor(bctx, NSColor.redColor.CGColor);
                        CGContextSetLineWidth(bctx, 1);
                        
                        CGContextSaveGState(bctx);
                        CGContextAddPath(bctx, linePath);
                        CGContextStrokePath(bctx);
                        CGContextRestoreGState(bctx);
                        
                        CGContextSaveGState(bctx);
                        CGContextAddPath(bctx, circlePath);
                        CGContextFillPath(bctx);
                        CGContextRestoreGState(bctx);
                    }
                }
            }
        }
    }
    
    auto bImg = CGBitmapContextCreateImage(bctx);
    
    CGContextDrawImage(ctx, self.bounds, bImg);
    
    CGContextRelease(bctx);
    CGImageRelease(bImg);
}

-(vec<CGFloat, 2>) perlinNormalXPercent:(CGFloat)xPercent yPercent:(CGFloat)yPercent
{
    auto px = pBorder + (pWidth - pBorder * 2) * xPercent;
    auto py = pBorder + (pHeight - pBorder * 2) * yPercent;
    auto px0 = px - pSamplingWidth / 2.0;
    auto py0 = py - pSamplingWidth / 2.0;
    
    auto avg = vec<CGFloat, 2>(0.0);
    
    for (int i = 0; i < pSamplingSideCount; i++)
    {
        for (int j = 0; j < pSamplingSideCount; j++)
        {
            auto pxn = px0 + pSamplingWidth * ((CGFloat)i / (pSamplingSideCount - 1));
            auto pyn = py0 + pSamplingWidth * ((CGFloat)j / (pSamplingSideCount - 1));
            
            avg += [self perlinSingleNormalXPercent:(pxn - pBorder) / (pWidth - pBorder * 2) yPercent:(pyn - pBorder) / (pHeight - pBorder * 2)];
        }
    }
    
    avg /= (CGFloat)(pSamplingSideCount * pSamplingSideCount);
    
    return avg;
}

-(vec<CGFloat, 2>) perlinSingleNormalXPercent:(CGFloat)xPercent yPercent:(CGFloat)yPercent
{
    auto px = pBorder + (pWidth - pBorder * 2) * xPercent;
    auto py = pBorder + (pHeight - pBorder * 2) * yPercent;
    
    auto px0 = floor(px);
    auto py0 = floor(py);
    auto px1 = ceil(px);
    auto py1 = ceil(py);
    CGFloat ix = 1 - (px - px0);
    CGFloat iy = 1 - ix;
    
    auto ibl = ix * iy;
    auto ibr = (1 - ix) * iy;
    auto itr = (1 - ix) * (1 - iy);
    auto itl = ix * (1 - iy);
    
    auto avg =
    self.perlinNormals[(int)px0][(int)py0][0] * ibl
    + self.perlinNormals[(int)px1][(int)py0][0] * ibr
    + self.perlinNormals[(int)px1][(int)py1][0] * itr
    + self.perlinNormals[(int)px0][(int)py1][0] * itl;
    
    return avg;
}

-(NSColor*) screenshotPixelXPercent:(CGFloat)xPercent yPercent:(CGFloat)yPercent
{
    auto w = CGImageGetWidth(self.screenshot);
    auto h = CGImageGetHeight(self.screenshot);
    auto x = MIN(w, MAX(0, round(w * xPercent)));
    auto y = h - MIN(h, MAX(0, round(h * yPercent)));
    
    const UInt8* data = CFDataGetBytePtr(self.screenshotData);
    
    NSInteger pixelIndex = ((w * y) + x) * 4;
    
    return [NSColor colorWithRed:data[pixelIndex + 0] / 255.0
                           green:data[pixelIndex + 1] / 255.0
                            blue:data[pixelIndex + 2] / 255.0
                           alpha:data[pixelIndex + 3] / 255.0];
}

@end
