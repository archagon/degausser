//
//  Helpers.m
//  Degausser
//
//  Created by Alexei Baboulevitch on 2018-1-2.
//  Copyright © 2018 Alexei Baboulevitch. All rights reserved.
//

#include <random>
#import "Helpers.h"

const NSWindowLevel kStickyWindowLevel = NSScreenSaverWindowLevel;
const NSWindowCollectionBehavior kStickyWindowCollectionBehavior =
        NSWindowCollectionBehaviorCanJoinAllSpaces |
        NSWindowCollectionBehaviorStationary |
        NSWindowCollectionBehaviorIgnoresCycle |
        NSWindowCollectionBehaviorFullScreenNone |
        NSWindowCollectionBehaviorFullScreenDisallowsTiling |
        0;

@implementation Helpers
@end

// MARK: - Perlin -

CF_INLINE CFHashCode CFHashInt(long i) {
    return ((i > 0) ? (CFHashCode)(i) : (CFHashCode)(-i)) * 2654435761U;
}
CF_INLINE CFHashCode CFHashDouble(double d)
{
    double dInt;
    if (d < 0) d = -d;
    dInt = floor(d+0.5);
    CFHashCode integralHash = 2654435761U * (CFHashCode)fmod(dInt, (double)ULONG_MAX);
    return (CFHashCode)(integralHash + (CFHashCode)((d - dInt) * ULONG_MAX));
}
CGFloat PerlinInterp(CGFloat x, CGFloat y, CGFloat t)
{
    auto t0 = MIN(1, MAX(0, t));
    auto t1 =  6 * pow(t0, 5) - 15 * pow(t0, 4) + 10 * pow(t0, 3);
    
    return (1 - t1) * x + t1 * y;
}
CGFloat PerlinGrad(CGFloat x, CGFloat y, CGFloat z, int hash)
{
    switch (hash & 0xF)
    {
        case 0x0: return  x + y;
        case 0x1: return -x + y;
        case 0x2: return  x - y;
        case 0x3: return -x - y;
        case 0x4: return  x + z;
        case 0x5: return -x + z;
        case 0x6: return  x - z;
        case 0x7: return -x - z;
        case 0x8: return  y + z;
        case 0x9: return -y + z;
        case 0xA: return  y - z;
        case 0xB: return -y - z;
        case 0xC: return  y + x;
        case 0xD: return -y + z;
        case 0xE: return  y - x;
        case 0xF: return -y - z;
        default: return 0; // never happens
    }
}
CGFloat PerlinNoise(CGFloat x, CGFloat y, CGFloat z, int seed)
{
    std::mt19937 rand(seed);
    //std::uniform_int_distribution<> range(0, 255);
    
    auto xi = (int)x + rand();
    auto yi = (int)y + rand();
    auto zi = (int)z + rand();
    auto xf = x - (int)x;
    auto yf = y - (int)y;
    auto zf = z - (int)z;
    
    int aaa, aba, aab, abb, baa, bba, bab, bbb;
    aaa = (int)CFHashInt(CFHashInt(CFHashInt(xi) + yi) + zi);
    aba = (int)CFHashInt(CFHashInt(CFHashInt(xi) + yi+1) + zi);
    aab = (int)CFHashInt(CFHashInt(CFHashInt(xi) + yi) + zi+1);
    abb = (int)CFHashInt(CFHashInt(CFHashInt(xi) + yi+1) + zi+1);
    baa = (int)CFHashInt(CFHashInt(CFHashInt(xi+1) + yi) + zi);
    bba = (int)CFHashInt(CFHashInt(CFHashInt(xi+1) + yi+1) + zi);
    bab = (int)CFHashInt(CFHashInt(CFHashInt(xi+1) + yi) + zi+1);
    bbb = (int)CFHashInt(CFHashInt(CFHashInt(xi+1) + yi+1) + zi+1);
    
    CGFloat x1, x2, y1, y2, v;
    x1 = PerlinInterp(PerlinGrad(xf, yf, zf, aaa), PerlinGrad(xf - 1, yf, zf, baa), xf);
    x2 = PerlinInterp(PerlinGrad(xf, yf - 1, zf, aba), PerlinGrad(xf - 1, yf - 1, zf, bba), xf);
    y1 = PerlinInterp(x1, x2, yf);
    x1 = PerlinInterp(PerlinGrad(xf, yf, zf - 1, aab), PerlinGrad(xf - 1, yf, zf - 1, bab), xf);
    x2 = PerlinInterp(PerlinGrad(xf, yf - 1, zf - 1, abb), PerlinGrad(xf - 1, yf - 1, zf - 1, bbb), xf);
    y2 = PerlinInterp(x1, x2, yf);
    v = PerlinInterp(y1, y2, zf);
    
    return v;
}
CGFloat OctavePerlinNoise(CGFloat x, CGFloat y, CGFloat z, int octaves, CGFloat persistence, int seed)
{
    CGFloat total = 0;
    CGFloat frequency = 1;
    CGFloat amplitude = 1;
    CGFloat maxValue = 0;
    
    for (int i=0; i<octaves; i++)
    {
        total += PerlinNoise(x * frequency, y * frequency, z * frequency, seed) * amplitude;
        maxValue += amplitude;
        amplitude *= persistence;
        frequency *= 2;
    }
    
    return total / maxValue;
}

// https://stackoverflow.com/a/14646734/89812
CGFloat CircleCircleIntersection(CGPoint c0, CGFloat r0, CGPoint c1, CGFloat r1)
{
    auto rr0 = r0 * r0;
    auto rr1 = r1 * r1;
    auto d = sqrt(pow((c1.x - c0.x), 2) + pow((c1.y - c0.y), 2));
    
    // circles do not overlap
    if (d > r1 + r0)
    {
        return 0;
    }
    
    // c1 is completely inside c0
    else if (d <= ABS(r0 - r1) && r0 >= r1)
    {
        // area of c1
        return M_PI * rr1;
    }
    
    // c0 is completely inside c1
    else if (d <= ABS(r0 - r1) && r0 < r1)
    {
        // area of circle0
        return M_PI * rr0;
    }
    
    // circles partially overlap
    else
    {
        auto phi = (acos((rr0 + (d * d) - rr1) / (2 * r0 * d))) * 2;
        auto theta = (acos((rr1 + (d * d) - rr0) / (2 * r1 * d))) * 2;
        auto area1 = 0.5 * theta * rr1 - 0.5 * rr1 * sin(theta);
        auto area2 = 0.5 * phi * rr0 - 0.5 * rr0 * sin(phi);
        
        // area of intersection
        return area1 + area2;
    }
}
