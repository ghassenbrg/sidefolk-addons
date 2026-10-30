// Nori: a chibi tuxedo cat on its hind legs: charcoal felt fur, a cream face, chest and paws, big
// pink-lined ears, round black glasses, a mint scarf with a little tag and a curled tail with a
// cream tip. Sheet: companions-3d/references/nori-sheet.webp. Rig: blender/rig_nori.py.
import { bodyMaterial } from '../engine/materials.js';
import { add, raise, fwd, handBend, face, doze } from '../engine/moves.js';
import { win, smooth } from '../engine/motion.js';

const ear = (s, side) => ({ bones: [`ear${s}1`, `ear${s}2`], side, twitch: true, k: [190, 135], d: [11, 7.5], limit: [40, 35] });

export default {
  id: 'nori',
  name: 'Nori',
  model: 'nori.glb',
  floor: 0.952,
  pivot: [0, 0.5, 0],
  frame: { sidefolk: 2.3 },
  marks: [0.45, 0.65, 0.15],
  blob: [1.4, 0.85],

  // Felt: a short dense pile with a soft pale sheen on the charcoal; cream stays clean; the glasses
  // are glossy black plastic and the scarf is knitted mint.
  material: (body) => bodyMaterial(body, {
    params: { sheenRoughness: 0.45, roughness: 0.88 },
    surface: `
      // Meshy's texture is fixed by place before anything reads it: it wrapped the face's cream round
      // the nape, smudged it up the backs of the arms, and tore the edges of the paws and the tail's
      // tip. On the sheet the head is charcoal all round behind the face (the border runs further
      // forward higher up), and paws (rest pose: the arms' outer ends) and the tail's tip are cream
      // with clean edges. The fur keeps its own mottling.
      float lum0 = dot(s, vec3(0.3, 0.55, 0.15));
      vec3 furT = vec3(0.031, 0.03, 0.035) * clamp(lum0 / 0.18, 0.8, 1.2);
      vec3 creamT = vec3(0.93, 0.86, 0.72) * (0.97 + 0.03 * smoothstep(0.6, 0.95, lum0));
      float napeZ = mix(-0.02, 0.1, smoothstep(-0.1, 0.25, p.y));
      float mint0 = smoothstep(0.1, 0.2, s.g - s.r) * smoothstep(0.45, 0.6, s.g);
      // (Below the ears, whose pink insides face forward, and above the scarf.)
      float nape = smoothstep(napeZ + 0.03, napeZ - 0.03, p.z) * smoothstep(-0.12, -0.04, p.y) * (1.0 - smoothstep(0.5, 0.6, p.y)) * (1.0 - mint0);
      float arms = smoothstep(0.38, 0.42, abs(p.x)) * smoothstep(-0.56, -0.5, p.y) * (1.0 - smoothstep(-0.16, -0.1, p.y))
        * smoothstep(-0.26, -0.18, p.z);
      float tailZ = smoothstep(0.1, 0.16, p.x) * (1.0 - smoothstep(-0.33, -0.27, p.z)) * (1.0 - smoothstep(-0.44, -0.38, p.y));
      tex = mix(tex, furT, nape);
      tex = mix(tex, mix(furT, creamT, smoothstep(0.54, 0.58, abs(p.x))), arms);
      tex = mix(tex, mix(furT, creamT, smoothstep(0.45, 0.5, p.x)), tailZ);
      s = pow(max(tex, vec3(0.0)), vec3(1.0 / 2.2));
      float lum = dot(s, vec3(0.3, 0.55, 0.15));
      float cream = smoothstep(0.55, 0.7, lum);
      float darkF = 1.0 - smoothstep(0.3, 0.44, lum);
      float mint = smoothstep(0.1, 0.2, s.g - s.r) * smoothstep(0.45, 0.6, s.g);
      // The frames: black, standing in front of the face (their lens openings are empty). The rig
      // marks them: by colour alone the charcoal brow above them would turn to glossy plastic.
      float frame = smoothstep(0.3, 0.7, part);
      float earIn = smoothstep(0.6, 0.7, p.y) * step(0.1, abs(p.x)) * smoothstep(0.6, 0.72, lum);
      c = tex * vec3(0.9, 0.88, 0.92);
      c = mix(c, vec3(0.97, 0.9, 0.78) * (0.94 + 0.06 * lum), cream * (1.0 - earIn) * 0.55);
      c = mix(c, vec3(0.78, 0.53, 0.44) * (0.75 + 0.3 * lum), earIn * 0.8);
      c = mix(c, vec3(0.08, 0.56, 0.34) * (0.9 + 0.2 * lum), mint * 0.9);
      c = mix(c, vec3(0.012, 0.012, 0.014), frame);
      float fur = tri(uPlush, p, nR, 6.0);
      float knit = tri(uKnit, p, nR, 5.0);
      bumpH = (fur * 0.0035 * (1.0 - mint) + knit * 0.006 * mint) * (1.0 - frame);
      c *= 0.985 + 0.03 * fur * (1.0 - frame);
      rough = mix(0.88, 0.7, mint);
      rough = mix(rough, 0.26, frame);
      clear = frame * 0.9;
      sheenTint = mix(mix(vec3(0.16, 0.16, 0.2), vec3(1.0), cream), vec3(0.8, 1.0, 0.9), mint) * (1.0 - frame);
      inner = 1.0 - 0.5 * darkF * (1.0 - mint);
      glow = earIn * (1.0 - darkF) * vec3(0.06, 0.03, 0.025);`,
  }),

  face: {
    kind: 'ink',
    unwrap: { R: 0.48, span: 0.5, cz: 0.07, cy: 0.22 },
    region: (x, y, z) => z > 0.2 && y > -0.12 && y < 0.5,
    // Matte ink, as on felt: glossier paint catches the light and the brows read grey.
    paintRoughness: 0.92,
    // The sheet's eyes have round highlights only: no idle twinkle cross.
    twinkle: false,
    colors: { ink: '#2a1812', brow: '#16110f', blush: '255,150,140', mouth: '#a8504a', lip: '#4a2420', mouthLine: '#4a2018' },
    // The sheet's eyes are a deep, almost black brown with a warm glint low in the iris.
    iris: { deep: [0.01, 0.004, 0.002], rim: [0.13, 0.055, 0.018], glow: [0.4, 0.18, 0.06], glowAmt: 0.32, pupil: 0.55 },
    layout: {
      eye: { x: 0.215, y: 0.235, w: 0.17, h: 0.205, depth: 0.04 },
      nose: { y: 0.165, w: 0.072, h: 0.048, shape: 'fox', color: '#1c1a1c' },
      // A small cat's ω tucked under the nose, as on the sheet.
      mouth: { y: 0.118, scale: 1.05, line: 6, cat: true },
      // Short crisp arcs just above the frames' outer corners.
      brow: { base: 1, y: 0.448, x: 0.27, len: 0.11, width: 13, arch: 9, tilt: 0.12 },
      blush: { x: 0.33, y: 0.1, w: 0.1, h: 0.06, alpha: 0.12 },
    },
  },

  // Whiskers: two thin dark curves out of each cheek, on the head so they turn with it.
  extras(c, THREE) {
    const mat = new THREE.MeshStandardMaterial({ color: 0x1b1a1c, roughness: 0.5 });
    const head = c.bones.head;
    for (const side of [1, -1]) {
      for (const [dy, dz] of [[0.04, 0.03], [-0.02, -0.06]]) {
        const a = new THREE.Vector3(side * 0.49, 0.1 + dy, 0.33), b = new THREE.Vector3(side * 0.78, 0.12 + dy + dz, 0.36);
        const m = a.clone().lerp(b, 0.5); m.y += dz * 0.2;
        const geo = new THREE.TubeGeometry(new THREE.QuadraticBezierCurve3(a, m, b), 12, 0.0105, 6);
        const w = new THREE.Mesh(geo, mat);
        head.add(w);
        w.position.copy(head.worldToLocal(new THREE.Vector3()));
        w.quaternion.copy(head.getWorldQuaternion(new THREE.Quaternion()).invert());
      }
    }
  },

  // Its own moment: pushes its glasses up with a paw, a pensive blink after.
  actions: {
    glasses: {
      dur: 2.6,
      fn(t, P) {
        const on = win(t, 0.1, 0.6, 1.5, 2.1);
        raise(P, 'L', 95 * on); fwd(P, 'L', 50 * on); add(P, 'armL', -25 * on); handBend(P, 'L', 30 * on);
        add(P, 'head', -4 * on, -6 * on, 0); add(P, 'chest', 2 * on);
        face(P, { mood: t < 1.5 ? 'attentive' : 'happy' });
      },
    },
  },
  moments: ['glasses'],

  chains: [
    ear('L', 1), ear('R', -1),
    { bones: ['tail1', 'tail2', 'tail3'], side: 1, k: [80, 62, 48], d: [8, 6.5, 5], gain: 0.55, breeze: 0.7, wag: 8, limit: [35, 35], seed: 3 },
  ],
  pick: { head: { r: 0.55, at: [0, 0.25, 0.05] }, body: { r: 0.33, at: [0, -0.42, 0] }, tips: ['earL2', 'earR2'] },
  fidgets: ['lookAround', 'earTwitch', 'earTwitch', 'tilt', 'sniff', 'smile', 'stretch', 'hop', 'blinkDouble', 'giggle'],

  // The model stands in an A: arms come down to the sides, paws a little forward.
  stand(t, P) {
    add(P, 'armL', 0, -10, -48); add(P, 'armR', 0, 10, 48);
    add(P, 'handL', 0, 0, -8); add(P, 'handR', 0, 0, 8);
    add(P, 'thighL', 0, 4, 0); add(P, 'thighR', 0, -4, 0);
  },
};
