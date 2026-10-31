// Purl, the little mended friend: a stitched-linen ragdoll with a huge soft square oatmeal head
// (a cream seam down one side, an indigo patch on a corner), a small indigo body with a mustard
// patch on its belly, stubby arms and legs, big glossy dark eyes, a tiny smile and rosy cheeks.
// Sheet: companions-3d/references/purl-sheet.webp. Rig: blender/rig_purl.py.
import { bodyMaterial } from '../engine/materials.js';
import { add, raise, fwd, handBend, face } from '../engine/moves.js';
import { win } from '../engine/motion.js';

// Sitting flopped on the floor, leaning back `back` degrees, legs out in a V, arms limp at the sides.
const flop = (t, P, C, back) => {
  C?.stand?.(t, P);
  P.root.py -= 0.16; P.root.rx -= back; P.root.rz -= 3;
  for (const [s, d] of [['L', 1], ['R', -1]]) {
    add(P, 'thigh' + s, back - 90, 0, -d * 22);
    raise(P, s, -14); fwd(P, s, -12);
  }
  add(P, 'footL', 0, 0, 8 * Math.sin(t * 1.2));
};

export default {
  id: 'purl',
  name: 'Purl',
  model: 'purl.glb',
  floor: 0.952,
  pivot: [0, 0.4, 0],
  frame: { sidefolk: 2.3 },
  marks: [0.55, 0.85, 0.15],
  blob: [1.3, 0.85],
  skip: ['sniff'],

  // Woven linen: matte, a fine weave, a soft nap sheen in the cloth's own colour. Meshy's colours
  // came out pale and grey: the head goes back to oatmeal greige and the body to deep indigo, with
  // half of the texture's own shading kept (its weave, but not its crumpled patches). Meshy also
  // copied both patches onto the back: only the front ones stay.
  material: (body) => bodyMaterial(body, {
    params: { sheenRoughness: 0.7, roughness: 0.93 },
    surface: `
      float lum = dot(s, vec3(0.3, 0.55, 0.15));
      float head = smoothstep(-0.14, -0.08, p.y);
      float blue = smoothstep(0.03, 0.09, s.b - s.r);
      float patchH = blue * head * smoothstep(0.06, 0.16, p.x) * smoothstep(0.4, 0.5, p.y) * smoothstep(-0.2, -0.05, p.z);
      float mustard = smoothstep(0.1, 0.18, s.r - s.b) * (1.0 - head) * smoothstep(0.0, 0.12, p.z);
      // Stitches only on the front: the back's are the ghost of a copied patch.
      float stitch = smoothstep(0.66, 0.78, lum) * (1.0 - head) * (1.0 - mustard) * smoothstep(-0.12, 0.0, p.z);
      // The back keeps little of the texture's shading: there it is mostly ghosts of copied stitches.
      float front = smoothstep(-0.2, 0.05, p.z);
      vec3 oat = vec3(0.36, 0.305, 0.232) * clamp(mix(1.0, lum / 0.66, mix(0.1, 0.5, front)), 0.8, mix(1.03, 1.2, front));
      vec3 indigo = vec3(0.028, 0.04, 0.105) * clamp(mix(1.0, lum / 0.22, 0.5), 0.75, 1.3);
      c = mix(indigo, oat, head * (1.0 - patchH));
      c = mix(c, vec3(0.47, 0.265, 0.028) * clamp(mix(1.0, lum / 0.32, 0.5), 0.75, 1.3), mustard);
      c = mix(c, vec3(0.86, 0.76, 0.56), stitch);
      // Linen: threads over and under in a plain weave, projected from three sides of the rest pose;
      // they fade out where they would be finer than a pixel (no shimmer at desktop size).
      vec3 wN = pow(abs(nR), vec3(4.0)); wN /= wN.x + wN.y + wN.z;
      float threads = 0.0;
      for (int k = 0; k < 3; k++) {
        vec2 q = (k == 0 ? p.zy : (k == 1 ? p.xz : p.xy)) * 95.0;
        vec2 f = fract(q);
        float warp = sin(f.x * 3.14159), weft = sin(f.y * 3.14159);
        float h = mix(warp * (0.55 + 0.45 * weft), weft * (0.55 + 0.45 * warp), mod(floor(q.x) + floor(q.y), 2.0));
        threads += (h - 0.55) * (1.0 - smoothstep(0.35, 0.9, length(fwidth(q)))) * (k == 0 ? wN.x : (k == 1 ? wN.y : wN.z));
      }
      float weave = tri(uPlush, p, nR, 15.0);
      // (Uneven, like real linen: the pile map thickens some threads and thins others.)
      threads *= (0.55 + 0.9 * weave) * (1.0 - stitch);
      bumpH = weave * 0.002 + threads * 0.0014;
      c *= (0.96 + 0.06 * weave) * (1.0 + 0.07 * threads);
      rough = 0.93;
      float blueCloth = (1.0 - head + patchH) * (1.0 - mustard) * (1.0 - stitch);
      sheenTint = mix(vec3(0.62, 0.58, 0.5), vec3(0.2, 0.24, 0.42), blueCloth);
      inner = 0.9;
      glow = c * vec3(0.02, 0.016, 0.012);`,
  }),

  face: {
    kind: 'ink',
    // Round highlights only, as on the sheet: no idle twinkle cross.
    twinkle: false,
    // Matte ink, as on linen.
    paintRoughness: 0.92,
    // A broad, almost flat face: a far-off axis keeps the features undistorted.
    unwrap: { R: 1.2, span: 0.75, cz: -0.67, cy: 0.4 },
    region: (x, y, z) => z > 0.2 && Math.abs(x) < 0.58 && y > -0.05 && y < 0.88,
    colors: { ink: '#2b1a12', brow: '#3a2418', blush: '236,120,120', mouthLine: '#2b1a12', mouth: '#6a1f26', lip: '#2b1a12' },
    iris: { deep: [0.012, 0.005, 0.003], rim: [0.1, 0.04, 0.018], glow: [0.32, 0.14, 0.05], glowAmt: 0.2, pupil: 0.0 },
    layout: {
      eye: { x: 0.29, y: 0.26, w: 0.15, h: 0.21, depth: 0.045 },
      mouth: { y: 0.155, scale: 1.6, line: 6 },
      brow: { base: 0, y: 0.45, x: 0.29, len: 0.12, width: 9, arch: 7 },
      blush: { x: 0.4, y: 0.11, w: 0.1, h: 0.07, alpha: 0.5 },
    },
  },

  // Its own moment: pats the mending patch on its belly, a contented little nod.
  actions: {
    pat: {
      dur: 2.8,
      fn(t, P) {
        const on = win(t, 0.1, 0.6, 2.0, 2.5);
        const tap = Math.sin(t * 8) * 0.5 * win(t, 0.7, 0.9, 1.7, 1.9);
        raise(P, 'R', -22 * on); fwd(P, 'R', 55 * on + 6 * tap); handBend(P, 'R', 30 * on);
        add(P, 'head', 8 * on + 3 * tap, 0, 0);
        face(P, { mood: t < 2.0 ? 'happy' : 'neutral' });
      },
    },
  },
  moments: ['pat'],

  chains: [],
  pick: { head: { r: 0.62, at: [0, 0.4, 0.1] }, body: { r: 0.32, at: [0, -0.4, 0] }, tipR: 0.1 },
  fidgets: ['lookAround', 'tilt', 'smile', 'stretch', 'hop', 'blinkDouble', 'giggle'],

  // A ragdoll at rest flops: lying down it sits back with its legs out in a V, arms flopped on the
  // floor and its big head lolled to one side; asleep it slumps forward over its lap, head heavy.
  // (On its side or its tummy, the huge head stayed upright over a toppled body.)
  postures: {
    lie: (t, P, C) => { flop(t, P, C, 26); add(P, 'head', 12, 0, 16); },
    sleep: (t, P, C) => {
      flop(t, P, C, 8);
      for (const s of ['L', 'R']) fwd(P, s, 30);
      const br = Math.sin(t * Math.PI * 2 * 0.2);
      add(P, 'chest', 8 + br * 2); add(P, 'head', 22 + br * 1.5, 0, 20); P.squash *= 1 + br * 0.012;
    },
  },

  // The model holds its arms out almost level: relaxed down at the sides, paws a bit forward.
  stand(t, P) {
    add(P, 'armL', 0, -8, -50); add(P, 'armR', 0, 8, 50);
    add(P, 'handL', 0, 0, -25); add(P, 'handR', 0, 0, 25);
    add(P, 'thighL', 0, 3, 0); add(P, 'thighR', 0, -3, 0);
  },
};
