#if os(iOS) || os(macOS)
import DesignKit
import SpriteKit
import SwiftUI

public enum BeadsSpriteMetrics {
  public static let preferredFramesPerSecond = 60
  public static let conservingFramesPerSecond = 30
  /// How brightly a bead is lit lying on the floor, off the finger.
  public static let looseEmphasis = 0.8
  /// Every bead draws into the same square: room for the finish's swell and
  /// for the soft shadow a bead casts on the one beneath it.
  public static let quadSide: CGFloat = 76
  public static let cordWidth: CGFloat = 1.7
  public static let cordShadeWidth: CGFloat = 2.6
  public static let cordShadeOpacity: CGFloat = 0.5
  public static let tasselWidth: CGFloat = 1.1
  public static let bindingWidth: CGFloat = 2.2
  public static let labelFontSize: CGFloat = 19
}

/// Each bead is a small studio render, shaded per pixel as a sphere in a lit
/// room: a rectangular softbox up and to the right, a cool strip light on the
/// left, a warm bounce from below, a dark floor. That window-shaped reflection
/// is what makes polished metal and stone read as the real thing; a painted
/// radial highlight reads as a button.
///
/// One shader draws every material. Metals mirror the room and tint it. Wood
/// scatters it across a grain. Jade and amber are mottled, wear a glassy coat,
/// and glow on their far side where light passes through. A Bodhi seed is
/// matte and furrowed, and not quite round.
@MainActor
enum BeadsSpriteAssets {
  @MainActor
  struct BeadMaterial {
    let shader: SKShader
    let surface: SKUniform
    let body: SKUniform
    let deep: SKUniform
    let pale: SKUniform
    let glow: SKUniform
    let finish: SKUniform
    let skin: SKUniform
    let scale: SKUniform

    func apply(_ material: BeadsMaterial) {
      let palette = material.palette
      surface.floatValue = material.surface.rawValue
      body.vectorFloat4Value = BeadsSpriteAssets.vector(palette.body)
      deep.vectorFloat4Value = BeadsSpriteAssets.vector(palette.deep)
      pale.vectorFloat4Value = BeadsSpriteAssets.vector(palette.pale)
      glow.vectorFloat4Value = BeadsSpriteAssets.vector(palette.glow)
      finish.vectorFloat2Value = SIMD2(material.roughness, material.translucency)
    }

    func makeSprite(radius: CGFloat, seed: Float = 1, visible: Bool = false) -> SKSpriteNode {
      let side = BeadsSpriteMetrics.quadSide
      let node = SKSpriteNode(texture: BeadsSpriteAssets.blank, size: CGSize(width: side, height: side))
      node.shader = shader
      node.setValue(SKAttributeValue(vectorFloat4: SIMD4(Float(radius), 0, 0, seed)), forAttribute: "a_shape")
      node.setValue(SKAttributeValue(vectorFloat4: visible ? SIMD4(0, 1, 0, 0) : SIMD4(1, 0, 0, 0)), forAttribute: "a_state")
      node.setValue(SKAttributeValue(vectorFloat4: .zero), forAttribute: "a_finger")
      node.setValue(SKAttributeValue(vectorFloat4: .zero), forAttribute: "a_thumb")
      return node
    }
  }

  /// Shader sprites are textured with a flat white pixel. SpriteKit's
  /// untextured colour sprites take a different draw path whose texture
  /// coordinates are not reliable inside a custom fragment shader.
  static let blank: SKTexture = {
    let context = bitmap(width: 2, height: 2)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    return SKTexture(cgImage: context.makeImage()!)
  }()

  /// a_shape: radius in points, swell, unused, pattern seed.
  /// a_state: fade, emphasis.
  /// a_finger, a_thumb: unit direction toward the skin and how much of its
  /// warmth the bead picks up there.
  static func beadShader() -> BeadMaterial {
    let surface = SKUniform(name: "u_surface", float: 0)
    let body = SKUniform(name: "u_body", vectorFloat4: SIMD4(repeating: 1))
    let deep = SKUniform(name: "u_deep", vectorFloat4: SIMD4(repeating: 1))
    let pale = SKUniform(name: "u_pale", vectorFloat4: SIMD4(repeating: 1))
    let glow = SKUniform(name: "u_glow", vectorFloat4: SIMD4(repeating: 1))
    let finish = SKUniform(name: "u_finish", vectorFloat2: .zero)
    let skin = SKUniform(name: "u_skin", vectorFloat4: SIMD4(repeating: 1))
    let scale = SKUniform(name: "u_scale", float: 2)
    let shader = SKShader(source: """
      float sstep(float e0, float e1, float x) {
        float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
        return t * t * (3.0 - 2.0 * t);
      }
      float hash1(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
      float vnoise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), u.x),
                   mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), u.x), u.y);
      }
      float fbm(vec2 p) { return 0.55 * vnoise(p) + 0.3 * vnoise(p * 2.1) + 0.15 * vnoise(p * 4.3); }
      // Thin meandering lines, as the furrows of a dried seed.
      float wrinkle(vec2 p) {
        float a = 1.0 - abs(2.0 * vnoise(p) - 1.0);
        float b = 1.0 - abs(2.0 * vnoise(p * 2.3 + 7.1) - 1.0);
        return 0.65 * a * a + 0.35 * b * b;
      }
      // What a mirror pointing along r would see of the room.
      vec3 room(vec3 r, float soft) {
        float sky = sstep(-0.06, 0.1, r.y);
        float amb = 0.015 + sky * (0.07 + 0.2 * max(0.0, r.y));
        vec3 c = vec3(amb, amb, amb * 1.14);
        float front = step(-0.25, r.z);
        float key = sstep(0.24 + soft, 0.24 - soft, abs(r.x - 0.46))
          * sstep(0.30 + soft, 0.30 - soft, abs(r.y - 0.56)) * 3.2 * front;
        c += key * vec3(1.0, 0.97, 0.90);
        float strip = sstep(0.075 + soft, 0.075 - soft * 0.5, abs(r.x + 0.74))
          * sstep(0.78, 0.42, abs(r.y - 0.05)) * 0.9 * front;
        c += strip * vec3(0.8, 0.88, 1.0);
        c += sstep(-0.2, -0.9, r.y) * 0.16 * vec3(1.0, 0.8, 0.6);
        return c;
      }
      // Skin close to polished metal shows in it. Screened on, so it warms
      // the bead without flattening the reflection underneath. SpriteKit only
      // exposes uniforms inside main, so the skin tone is passed in.
      vec3 warmed(vec3 col, vec2 d, vec4 source, vec3 skin) {
        float w = length(d - source.xy * 0.62) / 0.95;
        float fall = w < 0.5 ? mix(1.0, 0.4, w / 0.5) : mix(0.4, 0.0, clamp((w - 0.5) / 0.5, 0.0, 1.0));
        return 1.0 - (1.0 - col) * (1.0 - skin * source.z * fall);
      }

      void main() {
        vec2 pt = (v_tex_coord - 0.5) * u_quad;
        float swell = a_shape.y;
        float R = a_shape.x * (1.0 + 0.7 * swell);
        float seed = a_shape.w;
        vec2 d = pt / R;
        // A seed is not turned on a lathe: its outline wanders a little.
        if (u_surface > 2.5) {
          d /= 1.0 - 0.07 * vnoise(d / max(length(d), 0.001) * 1.4 + vec2(seed * 3.1, seed));
        }
        float rr = length(d);
        float body = clamp((1.0 - rr) * R * u_scale + 0.5, 0.0, 1.0);
        float visible = 1.0 - a_state.x;
        float shade = (1.0 - sstep(0.75, 1.5, length(d - vec2(-0.06, -0.2)))) * 0.5 * (1.0 - body) * (1.0 - swell);
        vec3 col = vec3(0.0);
        if (body > 0.0) {
          vec2 n2 = rr > 1.0 ? d / rr : d;
          float nz = sqrt(max(0.0, 1.0 - dot(n2, n2)));
          vec3 L = normalize(vec3(0.45, 0.62, 0.64));
          float ndl = dot(vec3(n2, nz), L);
          vec3 r = vec3(2.0 * nz * n2, 2.0 * nz * nz - 1.0);
          float fres = pow(1.0 - nz, 5.0);
          if (u_surface < 0.5) {
            vec3 E = room(r, 0.03 + u_finish.x * 0.35);
            col = E * (u_body.rgb + (1.0 - u_body.rgb) * fres) * 1.15 + u_body.rgb * (0.05 + 0.1 * max(0.0, ndl));
          } else if (u_surface < 1.5) {
            float grain = 0.76 + 0.24 * sin(n2.y * 20.0 + 4.0 * vnoise(n2 * 2.0 + vec2(seed * 9.0, seed)));
            float fine = 0.9 + 0.2 * vnoise(vec2(n2.x * 16.0 + seed * 5.0, n2.y * 46.0));
            float diff = 0.05 + 0.95 * pow(max(0.0, (ndl + 0.3) / 1.3), 1.4);
            vec3 E = room(r, 0.2);
            col = u_body.rgb * grain * fine * diff * 1.5 + E * (0.04 + 0.96 * fres) * 2.6;
          } else if (u_surface < 2.5) {
            float mottle = sstep(0.25, 0.85, fbm(n2 * 1.6 + vec2(seed * 7.3, -seed * 3.1))) * 0.75;
            vec3 alb = mix(u_deep.rgb, u_pale.rgb, mottle);
            float diff = 0.06 + 0.94 * pow(max(0.0, (ndl + 0.45) / 1.45), 1.5);
            float through = u_finish.y * sstep(0.15, -0.85, ndl) * (0.5 + 0.5 * (1.0 - nz));
            float F = 0.05 + 0.95 * fres;
            vec3 E = room(r, 0.035);
            col = (alb * diff * 1.5 + u_glow.rgb * (0.3 + 0.7 * alb) * through * 1.3) * (1.0 - F) + E * (F * 4.5 + 0.02);
          } else {
            // A dried seed: matte, furrowed, with one dark seam where its
            // two halves meet. The furrows bend the light as well as darken
            // it, which is what keeps them from reading as a printed pattern.
            // Turned and warped first, so the furrows wander instead of
            // following the noise's own grid.
            vec2 q = vec2(n2.x * 0.8 - n2.y * 0.6, n2.x * 0.6 + n2.y * 0.8) * 2.3 + vec2(seed * 5.7, seed * 2.3);
            q += 0.9 * vec2(fbm(q * 0.6 + 3.0), fbm(q * 0.6 + 11.0));
            float w0 = wrinkle(q);
            float wx = wrinkle(q + vec2(0.06, 0.0));
            float wy = wrinkle(q + vec2(0.0, 0.06));
            vec3 nb = normalize(vec3(n2 + vec2(wx - w0, wy - w0) * 2.2, nz));
            vec2 across = vec2(cos(seed * 2.4), sin(seed * 2.4));
            float seam = 1.0 - sstep(0.015, 0.085, abs(dot(n2, across)));
            // Mostly smooth skin with a few deep creases, not a net of them.
            float furrow = sstep(0.62, 0.98, w0);
            vec3 alb = mix(u_pale.rgb, u_deep.rgb, furrow) * (0.82 + 0.36 * vnoise(n2 * 1.3 + vec2(seed, seed * 4.0)));
            alb *= 1.0 - 0.62 * seam;
            float diff = 0.05 + 0.95 * pow(max(0.0, (dot(nb, L) + 0.25) / 1.25), 1.3);
            float sheen = pow(max(0.0, dot(nb, normalize(L + vec3(0.0, 0.0, 1.0)))), 14.0) * 0.1 * (1.0 - furrow);
            vec3 E = room(r, 0.3);
            col = alb * diff * 1.7 + u_pale.rgb * sheen * 4.0 + E * u_pale.rgb * (0.02 + 0.3 * fres);
          }
          col = col / (1.0 + col) * 1.3;
          col = pow(clamp(col, 0.0, 1.0), vec3(1.0 / 2.2));
          col = mix(col, vec3(0.031, 0.027, 0.043), (1.0 - a_state.y) * 0.62);
          col = warmed(col, d, a_finger, u_skin.rgb);
          col = warmed(col, d, a_thumb, u_skin.rgb);
        }
        float alpha = (body + shade) * visible;
        gl_FragColor = vec4(col * body * visible, alpha);
      }
      """, uniforms: [surface, body, deep, pale, glow, finish, skin, scale,
        SKUniform(name: "u_quad", float: Float(BeadsSpriteMetrics.quadSide))])
    shader.attributes = [
      SKAttribute(name: "a_shape", type: .vectorFloat4),
      SKAttribute(name: "a_state", type: .vectorFloat4),
      SKAttribute(name: "a_finger", type: .vectorFloat4),
      SKAttribute(name: "a_thumb", type: .vectorFloat4),
    ]
    return BeadMaterial(shader: shader, surface: surface, body: body, deep: deep, pale: pale,
      glow: glow, finish: finish, skin: skin, scale: scale)
  }

  static func native(_ color: Color) -> SKColor {
    #if os(iOS)
    return UIColor(color)
    #else
    return NSColor(color).usingColorSpace(.deviceRGB)!
    #endif
  }

  static func vector(_ color: Color) -> SIMD4<Float> {
    let components = native(color).cgColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)!.components!
    return SIMD4(Float(components[0]), Float(components[1]), Float(components[2]), Float(components[3]))
  }

  private static func bitmap(width: Int, height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  }
}
#endif
