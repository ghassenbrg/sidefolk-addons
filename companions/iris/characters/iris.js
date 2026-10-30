// Iris, the little camera scout: a butter-yellow toy camera with one huge glossy lens for an eye
// (a dark brown ring, slate-blue glass, a black pupil and big highlights), a small viewfinder, a
// coral shutter button, stub arms and feet. Blinking shuts a brown lens cap. Sheet:
// companions-3d/references/iris-sheet.webp. Rig: blender/rig_iris.py.
import { bodyMaterial } from '../engine/materials.js';
import { add, raise, face } from '../engine/moves.js';
import { win, smooth } from '../engine/motion.js';

// Lens centre on the front (model x, y), the radius of the glass and the ring's outer edge.
const LENS = [0.0, 0.106], GLASS = 0.315, RING = 0.47;

export default {
  id: 'iris',
  name: 'Iris',
  model: 'iris.glb',
  floor: 0.858,
  pivot: [0, 0.4, 0],
  frame: { sidefolk: 2.3, fullY: 0.95, tightY: 0.9 },
  marks: [0.5, 0.95, 0.15],
  blob: [1.5, 0.75],
  skip: ['sniff', 'sneeze'],

  // Soft glossy plastic, coloured by place: the body butter yellow (Meshy's specks go), the lens a
  // chocolate ring around slate glass, the stub limbs the same chocolate, the shutter button coral.
  // The glass is a brown lens cap underneath, which shows whenever the eye shuts.
  material: (body) => bodyMaterial(body, {
    params: { sheen: 0, clearcoat: 0.6, clearcoatRoughness: 0.2, roughness: 0.38 },
    ao: [0.55, 0.4, 0.85],
    surface: `
      float lum = dot(s, vec3(0.3, 0.55, 0.15));
      float front = smoothstep(0.12, 0.26, p.z);
      float lensR = length(p.xy - vec2(${LENS[0]}, ${LENS[1]}));
      float cap = (1.0 - smoothstep(${GLASS - 0.02}, ${GLASS + 0.01}, lensR)) * front;
      float ring = (1.0 - smoothstep(${RING - 0.01}, ${RING + 0.02}, lensR)) * front * (1.0 - cap);
      vec2 vf = abs(p.xy - vec2(-0.467, 0.51)) - vec2(0.07, 0.05);
      float finder = (1.0 - smoothstep(0.03, 0.05, length(max(vf, 0.0)))) * front;
      float button = smoothstep(0.7, 0.76, p.y) * step(0.3, p.x) * smoothstep(0.12, 0.2, s.r - s.b);
      // The stub arms and feet: dark, beside or below the body (its own sides stay yellow).
      float darkT = 1.0 - smoothstep(0.42, 0.56, lum);
      float limb = max(smoothstep(0.7, 0.74, abs(p.x)) * step(p.y, 0.15), 1.0 - smoothstep(-0.64, -0.6, p.y)) * darkT;
      vec3 yellow = vec3(0.86, 0.6, 0.18);
      vec3 brown = vec3(0.07, 0.03, 0.016);
      c = yellow * (0.97 + 0.05 * smoothstep(0.6, 0.95, lum));
      c = mix(c, brown * (0.75 + 0.8 * lum), max(ring, limb));
      c = mix(c, tex, finder * (1.0 - ring));
      c = mix(c, vec3(0.8, 0.3, 0.19) * (0.9 + 0.2 * lum), button);
      c = mix(c, brown * (0.9 + 0.3 * lum), cap);
      float dark = max(max(ring, limb), cap);
      rough = mix(0.38, 0.3, dark);
      rough = mix(rough, 0.12, finder);
      clear = 0.55 + 0.35 * max(dark, finder);
      bumpH = 0.0;
      inner = 0.55;
      sheenTint = vec3(0.0);`,
  }),

  face: {
    kind: 'ink',
    // The front is a flat sheet: a far-off axis makes the unwrap nearly a plain projection.
    unwrap: { R: 2.0, span: 0.8, cz: -1.67, cy: 0.1 },
    region: (x, y, z) => z > 0.12 && Math.abs(x) < 0.66 && y > -0.66 && y < 0.72,
    colors: { ink: '#a07850', brow: '#4a3022', blush: '255,140,120', mouth: '#7a2a24', mouthLine: '#4a3022', lip: '#4a3022' },
    // The lens: one eye, slate-blue glass over a black pupil. The second eye the engine builds is
    // taken away below, so the highlights are not doubled.
    iris: { deep: [0.025, 0.05, 0.085], rim: [0.08, 0.17, 0.28], glow: [0.22, 0.36, 0.52], glowAmt: 0.5, pupil: 0.46, glint: 1.1, travel: 0.18 },
    eyeForward: 3,
    layout: {
      eye: { x: LENS[0], y: LENS[1], w: GLASS * 2 - 0.02, h: GLASS * 2 - 0.02, depth: 0.05, sink: 0.7 },
      mouth: { y: -0.43, scale: 2.1, line: 8 },
      brow: { base: 1, y: 0.655, x: 0.11, len: 0.25, width: 26, arch: 16 },
      blush: { x: 0.48, y: -0.38, w: 0.1, h: 0.06, alpha: 0 },
    },
  },

  // One eye only: the lens. (Closed-eye arcs and winks use the first, the left one.)
  extras(c) {
    const second = c.eyes.pop();
    second.group.removeFromParent();
    // The idle twinkle would draw a thin cross over a lens this big: only strong sparkles show.
    const u = c.eyes[0].uniforms.uSparkle; let v = 0;
    Object.defineProperty(u, 'value', { get: () => v, set: (x) => { v = x > 0.5 ? x : 0; } });
    // A lens has no cheeks: smiles would push a lower lid up over the glass.
    Object.defineProperty(c.eyes[0].uniforms.uLid.value, 'z', { get: () => 0, set: () => {} });
  },

  // Its own moment: the lens zooms in and out like a camera focusing, a little click of the head.
  actions: {
    focus: {
      dur: 2.6,
      fn(t, P, fx) {
        fx.at(1.5, 'sparkle');
        const on = win(t, 0.1, 0.5, 1.7, 2.2);
        const z = Math.sin(t * 7) * 0.5 * win(t, 0.6, 0.8, 1.4, 1.6);
        P.eyeOpen = 1 + 0.18 * z * on;
        add(P, 'head', -3 * on, 0, 0); add(P, 'chest', 2 * on);
        face(P, { mood: t < 1.5 ? 'attentive' : 'happy' });
      },
    },
  },
  moments: ['focus'],

  chains: [],
  pick: { head: { r: 0.62, at: [0, 0.2, 0.1] }, body: { r: 0.5, at: [0, -0.3, 0], bone: 'spine' } },
  fidgets: ['lookAround', 'tilt', 'smile', 'stretch', 'hop', 'blinkDouble', 'giggle'],

  // The arms hang from the sides; a little out, and the feet turned out a touch.
  stand(t, P) {
    add(P, 'armL', 0, 0, -6); add(P, 'armR', 0, 0, 6);
    add(P, 'thighL', 0, 4, 0); add(P, 'thighR', 0, -4, 0);
  },
};
