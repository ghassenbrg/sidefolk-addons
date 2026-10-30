// Rune, the pocket golem: a little stone creature with a big smooth boulder head (a patch of olive
// moss on top), a small torso with a glowing amber gem, egg-shaped stone arms and pebble feet,
// big glossy amber-brown eyes and a carved smile. Sheet: companions-3d/references/rune-sheet.webp.
// Rig: blender/rig_rune.py.
import { bodyMaterial } from '../engine/materials.js';
import { add, raise, face } from '../engine/moves.js';
import { damp, win } from '../engine/motion.js';

export default {
  id: 'rune',
  name: 'Rune',
  model: 'rune.glb',
  floor: 0.952,
  pivot: [0, 0.4, 0],
  frame: { sidefolk: 2.3 },
  marks: [0.55, 0.85, 0.15],
  blob: [1.5, 0.95],
  skip: ['sniff', 'sneeze'],

  // Weathered stone: matte and a little rough, a fine speckle, no sheen; the moss is a deep, soft
  // pile with a green sheen; the amber gem is glossy glass that glows from inside, brighter while
  // Rune listens or thinks.
  material: (body) => bodyMaterial(body, {
    params: { sheen: 1, sheenRoughness: 0.4, roughness: 0.92, clearcoat: 1.0, clearcoatRoughness: 0.08 },
    ao: [0.5, 0.35, 0.8],
    uniforms: { uPulse: { value: 0 } },
    surface: `
      float lum = dot(s, vec3(0.3, 0.55, 0.15));
      // The thick moss cushion on the head's top left; elsewhere green is a thin lichen on the stone.
      float green = smoothstep(0.04, 0.12, s.g - s.b);
      float moss = smoothstep(0.1, 0.2, s.g - s.b) * smoothstep(0.6, 0.7, p.y) * step(p.x, 0.1);
      float lichen = green * (1.0 - moss);
      // The gem: the amber oval on the chest, by place and colour; glass with depth, bright in the
      // middle and deepening to a dark amber edge.
      float gr = length(vec2(p.x / 0.075, (p.y + 0.33) / 0.1));
      float gem = (1.0 - smoothstep(0.85, 1.05, gr)) * step(0.2, p.z) * smoothstep(0.15, 0.3, s.r - s.b);
      vec3 amber = mix(vec3(1.0, 0.68, 0.1), vec3(0.42, 0.14, 0.008), smoothstep(0.15, 0.95, gr));
      // Warm grey granite, darker and greyer than Meshy's pale version, with most of its mottling,
      // fine dark pits and pale grains, and grey-green lichen.
      c = vec3(0.158, 0.155, 0.138) * clamp(mix(1.0, lum / 0.53, 0.7), 0.65, 1.35);
      // (A high pass of the pile map at two scales: its fine peaks and hollows become specks.)
      float speck = tri(uPlush, p, nR, 38.0) - tri(uPlush, p, nR, 11.0);
      float pits = smoothstep(0.06, 0.16, speck) * (1.0 - moss), grains = smoothstep(-0.06, -0.16, speck) * (1.0 - moss);
      c *= (1.0 - 0.4 * pits) * (1.0 + 0.2 * grains);
      c = mix(c, vec3(0.16, 0.2, 0.08) * (0.8 + 0.3 * lum), lichen * 0.75);
      c = mix(c, vec3(0.075, 0.13, 0.02) * (0.65 + 0.7 * lum), moss);
      c = mix(c, amber * (0.85 + 0.3 * lum), gem);
      float grain = tri(uPlush, p, nR, 9.0);
      float pile = tri(uPlush, p, nR, 22.0);
      bumpH = (grain * 0.0025 - pits * 0.003) * (1.0 - moss) + pile * 0.016 * moss;
      c *= 0.96 + 0.06 * grain;
      rough = mix(0.92, 0.95, moss);
      rough = mix(rough, 0.18, gem);
      clear = gem;
      sheenTint = vec3(0.3, 0.55, 0.2) * moss;
      inner = 0.5 + 0.4 * moss;
      glow = gem * amber * vec3(0.4, 0.3, 0.2) * (0.6 + uPulse);`,
  }),

  face: {
    kind: 'ink',
    // Round highlights only, as on the sheet: no idle twinkle cross.
    twinkle: false,
    unwrap: { R: 1.0, span: 0.65, cz: -0.45, cy: 0.3 },
    region: (x, y, z) => z > 0.25 && Math.abs(x) < 0.6 && y > -0.05 && y < 0.75,
    // Matte paint, so the smile reads as a dark carved groove.
    paintRoughness: 0.92,
    colors: { ink: '#2a2218', brow: '#4a4034', blush: '210,130,100', mouthLine: '#241c14', mouth: '#6a2a1c', lip: '#40382a' },
    iris: { deep: [0.012, 0.005, 0.002], rim: [0.2, 0.08, 0.018], glow: [0.7, 0.36, 0.07], glowAmt: 0.38, pupil: 0.0 },
    layout: {
      eye: { x: 0.27, y: 0.26, w: 0.16, h: 0.21, depth: 0.045 },
      mouth: { y: 0.15, scale: 2.6, line: 7 },
      brow: { base: 0, y: 0.44, x: 0.27, len: 0.12, width: 9, arch: 6 },
      blush: { x: 0.4, y: 0.1, w: 0.1, h: 0.06, alpha: 0.12 },
    },
  },

  // Its own moment: knocks its stone knuckles together twice, the gem flashing.
  actions: {
    clack: {
      dur: 2.4,
      fn(t, P, fx) {
        fx.at(0.7, 'sparkle');
        const on = win(t, 0.1, 0.5, 1.7, 2.1);
        const hit = Math.abs(Math.sin(t * 7)) * win(t, 0.6, 0.8, 1.6, 1.8);
        for (const s of ['L', 'R']) { raise(P, s, -16 * on - 8 * hit); add(P, 'arm' + s, 0, (s === 'L' ? -1 : 1) * (50 * on + 10 * hit), 0); }
        add(P, 'head', 4 * hit, 0, 0);
        face(P, { mood: 'excited' });
      },
    },
  },
  moments: ['clack'],

  chains: [],
  pick: { head: { r: 0.62, at: [0, 0.35, 0.05] }, body: { r: 0.33, at: [0, -0.35, 0] }, tipR: 0.1 },
  fidgets: ['lookAround', 'tilt', 'smile', 'stretch', 'hop', 'blinkDouble', 'giggle'],

  // The gem glows brighter while Rune pays attention.
  dynamics(c, dt) {
    const busy = ['listening', 'hearing', 'thinking', 'working'].includes(c.loopName);
    const target = busy ? 0.5 + 0.4 * Math.sin(c.time * (c.loopName === 'thinking' ? 5 : 3)) : 0;
    const u = c.body.material.userData.u.uPulse;
    u.value = damp(u.value, target, 6, dt);
  },

  // Eggs of stone at the sides: a little forward and down from the modelled A-pose.
  stand(t, P) {
    add(P, 'armL', 0, -6, -22); add(P, 'armR', 0, 6, 22);
    add(P, 'thighL', 0, 3, 0); add(P, 'thighR', 0, -3, 0);
  },
};
