#include <TargetConditionals.h>

// DesignKit is also linked by WristKit, but watchOS has no SwiftUI::Layer.
// The Swift side never reaches these shaders on the watch either.
#if TARGET_OS_IOS || TARGET_OS_OSX
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// A distortion wave that reveals the inside of a card: one field, three shaders.
//
// Everything the wave does is read from the same signed distance to its front,
// so the swell, the blur and the colour can never drift apart.
//
//   d > 0  the wave has not got here yet
//   d = 0  the front
//   d < 0  the wave has passed
//
// The front is a ring spreading from a point near the top of the card. Its x
// metric is compressed (`squash` < 1), so the ring is wider than it is tall and
// crosses the card as a bowed front rather than a tight circle. A slow bend
// along it keeps it from looking drawn with a compass.
//
// Adapted from Jakub Antalík's DistortionWavesKit (MIT), which carries a whole
// screen into another. This version works at card scale, with no particles and
// a single-hue palette, and reads the card's own rectangle for the rim so the
// content it bends can be clipped and animated independently of the colour.
//
// field: 0 originX, 1 originY, 2 radius, 3 squash, 4 time, 5 energy, 6 swell,
//        7 gravity, 8 glow, 9 clearRadius, 10 rim, 11 launched,
//        12 hairClearRadius, 13 cardX, 14 cardY, 15 cardW, 16 cardH,
//        17 coverZone

struct Field {
    float d;
    float2 n;   // points away from the origin
    float2 raw; // position relative to the origin
    float g;    // how fast the raw distance grows, which d has been divided by
};

static Field fieldAt(float2 p, device const float *f) {
    float2 raw = p - float2(f[0], f[1]);
    float squash = f[3], time = f[4], swell = f[6];
    float2 q = float2(raw.x * squash, raw.y);
    float l = max(length(q), 1e-3);
    float2 grad = float2(q.x * squash, q.y) / l;
    float g = max(length(grad), 1e-3);
    float a = atan2(raw.y, raw.x);
    // Low frequencies only: anything quicker reads as a wobble at this speed.
    float bend = 0.62 * sin(2.0 * a + time * 1.1) + 0.38 * sin(3.0 * a - time * 1.5 + 1.7);
    Field out;
    out.d = (l - f[2]) / g + swell * bend;
    out.n = grad / g;
    out.raw = raw;
    out.g = g;
    return out;
}

static float sq(float x) { return x * x; }

// ─── Swell ───────────────────────────────────────────────────────────────────
//
// layer: one side of the card's content, with its progressive blur already in it.
// side:  +1 the content the wave leaves behind (visible ahead of the front),
//        -1 the content it reveals (visible behind the front).
//
// Content rises once as the swell passes and settles back: one smooth pulse per
// pixel, never a reversal. Gravity is the anticipation before that: everything
// is drawn a little toward the origin, and let go as the wave leaves.
//
// Chromatic aberration follows from the same displacement: the colours part
// along the way a pixel has been moved, so it shows exactly where the text is
// distorted and anything unmoved stays clean.

constant int spectrumSamples = 5;
constant half3 spectrum[spectrumSamples] = {
    half3(0.571, 0.000, 0.000),
    half3(0.343, 0.206, 0.000),
    half3(0.086, 0.588, 0.086),
    half3(0.000, 0.206, 0.343),
    half3(0.000, 0.000, 0.571),
};

[[ stitchable ]] half4 appWaveLens(
    float2 p, SwiftUI::Layer layer,
    device const float *f, int fc,
    float4 bounds,
    float amplitude, float width, float aberration, float side
) {
    Field w = fieldAt(p, f);
    float energy = f[5], gravity = f[7], coverZone = f[17];
    bool launched = f[11] > 0.5;

    // Ahead of the zone the outgoing side covers the incoming one completely, so
    // the incoming side has nothing to draw there. Before the launch it is not
    // drawn at all: the outgoing side alone takes the pull.
    float cover = 1.0;
    if (side > 0.0) {
        if (launched) cover = smoothstep(-coverZone, coverZone, w.d);
        if (cover <= 0.0) return half4(0.0);
    } else {
        if (!launched || w.d > coverZone + 6.0) return half4(0.0);
    }

    // Steeper ahead, where it compresses what it is about to reach; long behind.
    float u = w.d / (width * (w.d > 0.0 ? 0.85 : 1.5));
    float lift = exp(-u * u);
    float r = max(length(w.raw), 1.0);
    float2 swollen = w.n * energy * amplitude * lift;
    float2 inward = w.raw / r;
    float2 s = p - swollen + inward * gravity * exp(-r / 320.0);
    float2 split = (swollen - inward * gravity * exp(-r / 120.0)) * aberration;

    float2 lo = bounds.xy + 0.5;
    float2 hi = bounds.xy + bounds.zw - 0.5;
    // Under a quarter of a point the colours can't be seen apart.
    if (dot(split, split) < 0.0625) {
        return layer.sample(clamp(s, lo, hi)) * half(cover);
    }
    half4 out = half4(0.0);
    for (int i = 0; i < spectrumSamples; i++) {
        float along = float(i) / float(spectrumSamples - 1) * 2.0 - 1.0;
        half4 c = layer.sample(clamp(s + split * along, lo, hi));
        out += half4(c.rgb * spectrum[i], c.a / half(spectrumSamples));
    }
    return out * half(cover);
}

// ─── Progressive blur ────────────────────────────────────────────────────────
//
// The blur radius this pixel should have, turned into the coverage of one
// blurred copy of the content: copies stacked over the sharp original, each
// taking over where the last one ends, approximate a gaussian at every radius.
// Blur gathers ahead of the front, peaks on it, and clears slowly behind it.

[[ stitchable ]] half4 appWaveBlurMask(
    float2 p, half4 color,
    device const float *f, int fc,
    float blur, float ahead, float behind, float from, float to
) {
    Field w = fieldAt(p, f);
    float u = w.d / (w.d > 0.0 ? ahead : behind);
    float radius = f[5] * blur * exp(-u * u);
    float t = clamp((radius - from) / max(to - from, 1e-3), 0.0, 1.0);
    return color * half(t * t * (3.0 - 2.0 * t));
}

// ─── Colour ──────────────────────────────────────────────────────────────────

// Signed distance to a rect with continuous corners, as `AppListSection` draws.
// A superellipse within a fraction of a point of Apple's curve, which the
// hairline on the card's edge needs; a circular corner leaves the edge where
// the curve begins.
static float continuousRectSDF(float2 p, float2 halfSize, float radius) {
    float a = min(radius * 1.528665, min(halfSize.x, halfSize.y));
    float2 q = abs(p) - (halfSize - a);
    if (q.x <= 0.0 || q.y <= 0.0) {
        return max(abs(p.x) - halfSize.x, abs(p.y) - halfSize.y);
    }
    const float n = 3.26;
    float2 u = q / a;
    float norm = pow(pow(u.x, n) + pow(u.y, n), 1.0 / n);
    float2 g = pow(u / max(norm, 1e-4), float2(n - 1.0));
    return (norm - 1.0) * a / max(length(g), 1e-3);
}

// Interleaved gradient noise: enough to hide banding, not enough to see.
static float dither(float2 p) {
    return fract(52.9829189 * fract(dot(p, float2(0.06711056, 0.00583715)))) - 0.5;
}

// One colour from a ring of three, mixed so the join never shows. All three are
// tints of the one brand hue, so mixing in sRGB passes through no grey.
static half3 paletteAt(half3 c0, half3 c1, half3 c2, float u) {
    float x = fract(u) * 3.0;
    int i = min(int(x), 2);
    float m = fract(x);
    m = m * m * (3.0 - 2.0 * m);
    half3 a = i == 0 ? c0 : (i == 1 ? c1 : c2);
    half3 b = i == 0 ? c1 : (i == 1 ? c2 : c0);
    return mix(a, b, half(m));
}

// The wave's colour, in two parts, drawn only inside the card.
//
// The band rides the front: the palette flowing along it, a light fringe ahead,
// a deep one behind, and a bright line close behind the front. Every edge of it
// is wide and feathered.
//
// The rim is what the band leaves on the card's edges: colour clinging to them
// after the middle has cleared, with a hairline right on the edge, until a
// second, later front wipes them away.

[[ stitchable ]] half4 appWaveBand(
    float2 p, half4 color,
    device const float *f, int fc,
    float lead, float tail, float strength,
    float rimWidth, float rimSoftness, float cornerRadius,
    float hairWidth, float hairOpacity,
    half4 c0, half4 c1, half4 c2
) {
    float glow = f[8], rim = f[10];
    float2 cardSize = float2(f[15], f[16]);
    float2 c = p - float2(f[13], f[14]) - cardSize * 0.5;
    float sdf = continuousRectSDF(c, cardSize * 0.5, cornerRadius);
    if (sdf > 0.0) return half4(0.0);
    float inset = -sdf;
    bool nearEdge = rim > 0.0 && inset < max(rimWidth * 5.0, hairWidth * 0.5 + 0.75);
    if (glow <= 0.0 && !nearEdge) return half4(0.0);

    Field w = fieldAt(p, f);
    float d = w.d, time = f[4];
    float turn = atan2(w.raw.y, w.raw.x);

    // The tail swells and thins along the front, lighter in the middle of the
    // card, which it clears first.
    float lobes = 0.5 + 0.5 * sin(2.0 * turn + time * 1.4) * cos(turn - time * 0.7 + 1.2);
    float bandA = 0.0;
    if (glow > 0.0 && d < lead) {
        if (d >= 0.0) {
            float k = 1.0 - d / lead;
            bandA = k * k * k * (k * (k * 6.0 - 15.0) + 10.0);
        } else {
            bandA = pow(1.0 - clamp(-d / (tail * mix(0.6, 1.3, lobes)), 0.0, 1.0), 2.3);
        }
        bandA *= glow * strength * mix(0.6, 1.0, exp(-inset / 60.0));
    }

    // Around the card: normalised, so the long sides get their share of colour.
    float around = atan2(c.y / cardSize.y, c.x / cardSize.x);
    float rimA = 0.0, hairA = 0.0, shimmer = 0.5;
    if (nearEdge) {
        // Lumps of their own length and depth drifting round the edge, with thin
        // stretches between them, so the rim never reads as a uniform border.
        float thickness = max(1.0 + 0.55 * sin(3.0 * around + time * 1.3)
            + 0.35 * sin(5.0 * around - time * 0.9 + 0.8), 0.15);
        float hug = exp(-sq(inset / (rimWidth * thickness)));
        float reached = 1.0 - smoothstep(-lead * 0.7, lead * 0.5, d);
        float kept = smoothstep(-rimSoftness, rimSoftness, d + (f[2] - f[9]) / w.g);
        // Two soft swells of brightness running round the edge.
        shimmer = 0.5 + 0.5 * sin(time * 3.4 - around * 2.0);
        rimA = hug * reached * kept * rim * mix(1.0, 0.7 + 0.3 * shimmer, 0.6);

        if (hairWidth > 0.0) {
            float line = 1.0 - smoothstep(hairWidth * 0.5, hairWidth * 0.5 + 0.75, inset);
            // Wiped by a front of its own, later and slower than the colour's,
            // so the line outlasts the colour it sits on.
            float hairKept = smoothstep(-rimSoftness, rimSoftness, d + (f[2] - f[12]) / w.g);
            hairA = line * reached * hairKept * rim * hairOpacity
                * mix(0.5, 1.0, smoothstep(0.1, 1.5, thickness))
                * mix(1.0, 0.55 + 0.45 * shimmer, 0.6);
        }
    }

    float a = 1.0 - (1.0 - bandA) * (1.0 - rimA);
    float total = 1.0 - (1.0 - a) * (1.0 - hairA);
    if (total <= 0.0005) return half4(0.0);

    float flow = 0.62 + turn / (2.0 * M_PI_F) + time * 0.13 + d * 0.004;
    half3 rgb = paletteAt(c0.rgb, c1.rgb, c2.rgb, flow);
    half3 light = mix(c1.rgb, half3(1.0h), 0.45h);
    half3 deep = c0.rgb * 0.55h;
    rgb = mix(rgb, light, half(0.5 * exp(-sq((d - 12.0) / 20.0))));
    rgb = mix(rgb, deep, half(0.5 * exp(-sq((d + 34.0) / 30.0))));
    rgb = mix(rgb, mix(rgb, half3(1.0h), 0.55h), half(0.7 * exp(-sq((d + 3.0) / 10.0))));

    half3 rimRGB = paletteAt(c0.rgb, c1.rgb, c2.rgb, around / (2.0 * M_PI_F) + time * 0.27 + inset * 0.003);
    rgb = mix(rgb, rimRGB, half(rimA / (rimA + bandA + 1e-4)));

    if (hairA > 0.0) {
        half3 hair = mix(rimRGB, half3(1.0h), half(0.7 * (0.5 + 0.5 * shimmer)));
        rgb = (rgb * half(a * (1.0 - hairA)) + hair * half(hairA)) / half(total);
    }

    float noise = dither(p) * 2.0 / 255.0;
    return half4(clamp(rgb * half(total) + half(noise), 0.0h, 1.0h), half(clamp(total + noise, 0.0, 1.0)));
}
#endif
