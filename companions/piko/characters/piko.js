// Piko: a chibi robot cat dressed like Spark: an ivory helmet and sweater, a dark blue glass visor (its face is aqua
// light on the glass), aqua headphones and ear panels that glow, an aqua knit scarf, a little bunny on its chest, navy
// paws with aqua pads and navy feet.
import { bodyMaterial } from '../engine/materials.js';
import { damp, curve, win } from '../engine/motion.js';
import { ACTIONS, POSTURES, add, face, raise, fwd } from '../engine/moves.js';

// Resting and sleeping sitting up: lying down, tipped onto its side, its big head made it
// look like a dropped toy. Resting, it swings its stub feet one after the other and its head sways as it looks
// around; asleep, its chin dips, its paws rest in its lap and each slow breath nods its head (only a little: a
// big head tipped far reads as broken).
const rest = (t, P) => {
  POSTURES.sit(t, P);
  add(P, 'spine', -3);
  add(P, 'head', -2 + 2 * Math.sin(t * 0.6), 7 * Math.sin(t * 0.43), 4 * Math.sin(t * 0.31));
  add(P, 'footL', 16 * Math.sin(t * 1.7)); add(P, 'footR', 16 * Math.sin(t * 1.7 + 1.6));
};
const nap = (t, P) => {
  POSTURES.sit(t, P);
  const br = Math.sin(t * Math.PI * 2 * 0.2);
  add(P, 'spine', 6); add(P, 'chest', 4 + br * 2); add(P, 'head', 13 + br * 2.5, 0, 8);
  for (const s of ['L', 'R']) { raise(P, s, -8); fwd(P, s, 14); }
  P.squash *= 1 + br * 0.014;
};

export default {
  id: 'piko',
  name: 'Piko',
  model: 'piko.glb',
  floor: 0.952,
  pivot: [0, 0.9, 0],
  // Its head is as wide as a gallery companion is tall: a little more room, so a lean or a hop stays in its window.
  frame: { sidefolk: 2.5 },
  petLean: 0.55,
  marks: [0.55, 0.7, 0.15],
  blob: [1.1, 0.75],

  // The outfit is all here. The texture only says which part is which (its red parts, its dark parts), and every
  // colour below is Spark's.
  // Soft-touch ivory plastic, a glossy glass visor, aqua and navy parts, a soft aqua knit scarf.
  material: (body) => bodyMaterial(body, {
    params: { sheen: 0.7, sheenRoughness: 0.5, clearcoat: 0.7, clearcoatRoughness: 0.18, roughness: 0.42 },
    ao: [0.5, 0.35, 0.85],
    uniforms: { uPulse: { value: 0 } },
    surface: `
      float lum = dot(s, vec3(0.3, 0.55, 0.15));
      float red = smoothstep(0.2, 0.32, s.r - s.g) * smoothstep(0.4, 0.5, s.r);
      float dark = (1.0 - smoothstep(0.26, 0.4, lum)) * (1.0 - red);
      float ax = abs(p.x);
      // The visor is the dark glass on the front of the helmet. Its outline is a curve fitted to the model's,
      // antialiased: the texture's edge showed stair-steps up close.
      vec2 q = vec2(p.x, p.y - 0.245);
      float th = atan(abs(q.x), q.y);
      float rim = 0.3972 - 0.0116 * cos(th) - 0.0604 * cos(2.0 * th) + 0.016 * cos(3.0 * th) - 0.004 * cos(4.0 * th) - 0.0022 * cos(5.0 * th);
      float dv = length(q) - rim, aa = fwidth(dv) * 0.75 + 0.0006;
      float helmetFront = smoothstep(-0.2, -0.15, p.y) * smoothstep(0.18, 0.24, p.z) * (1.0 - step(0.5, abs(p.x)));
      float visor = (1.0 - smoothstep(-aa, aa, dv)) * helmetFront;
      dark = mix(dark, visor, helmetFront); red *= 1.0 - helmetFront;
      // The chest is plain under the bunny, drawn over it (extras): a few flecks in the texture there are painted out.
      // The scarf's tail, just beside it, is marked by the rig (part).
      float logo = (1.0 - smoothstep(0.127, 0.132, abs(p.x))) * smoothstep(-0.6, -0.59, p.y) * (1.0 - smoothstep(-0.357, -0.352, p.y - 0.012 * smoothstep(0.06, 0.08, p.x)))
        * smoothstep(0.15, 0.2, p.z) * (1.0 - smoothstep(0.36, 0.37, p.z)) * (1.0 - step(0.5, part));
      red *= 1.0 - logo; dark *= 1.0 - logo;
      // Low on each leg's outer side the model has a little red slot: it goes ivory and a round navy dot
      // sits on it.
      float slot = red * (1.0 - smoothstep(-0.7, -0.68, p.y)) * (1.0 - smoothstep(0.1, 0.12, abs(p.z)));
      red *= 1.0 - slot;
      // Low on the body only the tail (the rig's mark) is scarf, and the mark also fills in the knot: the texture has
      // red and white flecks in and near them.
      float below = 1.0 - smoothstep(-0.37, -0.35, p.y);
      red = mix(red, red * smoothstep(0.02, 0.1, part), below);
      red = max(red, smoothstep(0.45, 0.6, part) * (1.0 - logo));
      float knit = red * (1.0 - smoothstep(-0.17, -0.15, p.y));
      float phones = red * smoothstep(0.46, 0.52, ax) * smoothstep(-0.12, -0.05, p.y);
      // The white ring in each cup (round its axis at height 0.188), measured on the mesh and drawn here with a clean
      // edge: ivory between the aqua rim and dome, like the rings on Spark's cups.
      float cupR = length(vec2(p.y - 0.188, p.z));
      float cupAA = fwidth(cupR) * 0.75 + 0.0006;
      float stripe = smoothstep(0.6, 0.62, ax) * smoothstep(0.1705 - cupAA, 0.1705 + cupAA, cupR) * (1.0 - smoothstep(0.1985 - cupAA, 0.1985 + cupAA, cupR));
      // The paws and feet were dark and stay dark, in Spark's navy; the legs between are ivory like its legs.
      float paw = dark * step(0.4, ax) * smoothstep(-0.62, -0.6, p.y) * (1.0 - visor);
      float footAA = fwidth(p.y) * 0.75 + 0.0006;
      float foot = dark * (1.0 - smoothstep(-0.858 - footAA, -0.858 + footAA, p.y)) * (1.0 - visor);
      float navyPart = max(paw, foot);
      float dotD = length(vec2(p.y + 0.757, p.z)) / 0.048;
      float dotAA = fwidth(dotD) * 0.75 + 0.002;
      float legDot = (1.0 - smoothstep(1.0 - dotAA, 1.0 + dotAA, dotD)) * smoothstep(0.2, 0.26, ax);
      // Pink pads on the paws' outer front: a big one and three toes, round each paw's middle.
      vec3 pd = normalize(vec3(ax - 0.645, p.y + 0.45, p.z - 0.02));
      vec2 pu = vec2(dot(pd, normalize(vec3(-0.8, 0.0, 0.6))), pd.y);
      float pad = 0.0;
      pad = max(pad, 1.0 - smoothstep(0.85, 1.15, length((pu - vec2(0.02, -0.08)) / vec2(0.3, 0.24))));
      for (int i = 0; i < 3; i++) {
        vec2 toe = vec2(-0.26 + 0.26 * float(i), 0.3 - 0.05 * abs(float(i) - 1.0));
        pad = max(pad, 1.0 - smoothstep(0.8, 1.2, length((pu - toe) / vec2(0.1, 0.12))));
      }
      pad *= paw * step(0.0, dot(pd, normalize(vec3(0.6, 0.0, 0.8))));
      // Spark's colours, every one.
      vec3 aqua = vec3(0.07, 0.62, 0.62), navy = vec3(0.022, 0.035, 0.11);
      c = vec3(0.93, 0.915, 0.88) * (0.97 + 0.03 * lum);
      c = mix(c, navy, navyPart);
      c = mix(c, aqua, pad);
      c = mix(c, aqua, red);
      c = mix(c, vec3(0.04, 0.44, 0.44), knit);
      c = mix(c, vec3(0.93, 0.915, 0.88), stripe);
      c = mix(c, navy, legDot);
      c = mix(c, vec3(0.008, 0.012, 0.035), visor);
      rough = mix(mix(0.4, 0.3, red), 0.5, navyPart);
      rough = mix(rough, 0.75, knit);
      // Dark smoked glass: a soft, dim sheen of the room, not a mirror with a lamp in it.
      rough = mix(rough, 0.32, visor);
      clear = mix(0.6, 1.0, red) * (1.0 - knit) * (1.0 - 0.6 * visor);
      spec = 1.0 - 0.75 * visor;
      sheenTint = knit * vec3(0.05, 0.3, 0.3);
      // A faint grain on the plastic so it isn't a CG-perfect surface.
      bumpH = tri(uKnit, p, nR, 14.0) * 0.006 * knit + tri(uPlush, p, nR, 9.0) * 0.0012 * (1.0 - knit - visor) * (1.0 - red) * (1.0 - legDot);
      inner = 0.55 * (1.0 - navyPart) * (1.0 - visor);
      // As on Spark, the visor glows a deep blue from inside, and the aqua parts glow, brighter while Piko listens or
      // thinks. The knit is cloth: it doesn't.
      glow = visor * vec3(0.0024, 0.0072, 0.018) + ((red * (1.0 - knit) * (1.0 - stripe)) + pad * 0.6) * vec3(0.02, 0.2, 0.2) * (0.25 + uPulse);`,
  }),

  // Spark's face, in its colour and proportions: eyes and mouth measured on its portrait as fractions of its visor.
  face: {
    kind: 'screen',
    glow: '64,236,228',
    softGlow: true,
    unwrap: { R: 0.62, span: 0.5, cz: -0.04, cy: 0.25 },
    region: (x, y, z) => z > 0.26 && Math.abs(x) < 0.47 && y > -0.08 && y < 0.58,
    lift: 0.004,
    layout: {
      eye: { x: 0.208, y: 0.265, w: 0.195, h: 0.236 },
      mouth: { y: 0.08, scale: 1.6 },
    },
  },

  // The bunny on the chest, crisp at any size: a decal cut from the chest (skinned like it) with its own canvas.
  extras(c, THREE) {
    const body = c.body, g = body.geometry, pos = g.attributes.position, nor = g.attributes.normal;
    const scarf = body.skeleton.bones.findIndex((b) => b.name === 'scarf');
    const SI = g.attributes.skinIndex, SW = g.attributes.skinWeight;
    const scarfW = (i) => { let w = 0; for (let j = 0; j < 4; j++) if (SI.getComponent(i, j) === scarf) w += SW.getComponent(i, j); return w; };
    // Box on the chest, in model units: x -0.15…0.15, y -0.61…-0.31.
    const X0 = -0.15, Y1 = -0.31, SIZE = 0.3;
    const inBox = (i) => {
      const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
      return Math.abs(x) < 0.15 && y > -0.61 && y < -0.31 && z > 0.15 && z < 0.35 && nor.getZ(i) > 0.05 && scarfW(i) < 0.4;
    };
    const idx = g.index.array, keep = [];
    for (let t = 0; t < idx.length; t += 3) if (inBox(idx[t]) && inBox(idx[t + 1]) && inBox(idx[t + 2])) keep.push(idx[t], idx[t + 1], idx[t + 2]);
    const map = new Map(), order = [];
    for (const i of keep) if (!map.has(i)) { map.set(i, order.length); order.push(i); }
    const n = order.length, P = new Float32Array(n * 3), N = new Float32Array(n * 3), U = new Float32Array(n * 2);
    const I = new (SI.array.constructor)(n * 4), Wt = new Float32Array(n * 4);
    order.forEach((i, k) => {
      const nx = nor.getX(i), ny = nor.getY(i), nz = nor.getZ(i);
      P.set([pos.getX(i) + nx * 0.002, pos.getY(i) + ny * 0.002, pos.getZ(i) + nz * 0.002], k * 3); N.set([nx, ny, nz], k * 3);
      U.set([(pos.getX(i) - X0) / SIZE, 1 - (Y1 - pos.getY(i)) / SIZE], k * 2);
      for (let j = 0; j < 4; j++) { I[k * 4 + j] = SI.getComponent(i, j); Wt[k * 4 + j] = SW.getComponent(i, j); }
    });
    const dg = new THREE.BufferGeometry();
    dg.setAttribute('position', new THREE.BufferAttribute(P, 3));
    dg.setAttribute('normal', new THREE.BufferAttribute(N, 3));
    dg.setAttribute('uv', new THREE.BufferAttribute(U, 2));
    dg.setAttribute('skinIndex', new THREE.BufferAttribute(I, 4));
    dg.setAttribute('skinWeight', new THREE.BufferAttribute(Wt, 4));
    dg.setIndex(keep.map((i) => map.get(i)));

    // Traced in pixels at 2893 a unit: its middle, (330, 390), sits on the chest at x -0.01, y -0.47.
    const canvas = document.createElement('canvas'); canvas.width = canvas.height = 1024;
    const ctx = canvas.getContext('2d'), k = 1024 / SIZE / (5 * 578.6);
    ctx.setTransform(k, 0, 0, k, (-0.01 - X0) * 1024 / SIZE - 330 * k, (Y1 + 0.47) * 1024 / SIZE - 390 * k);
    ctx.lineJoin = 'round';
    const shape = (d, fill) => { const a = new Path2D(d); ctx.fillStyle = fill; ctx.fill(a); return a; };
    const oval = (x, y, rx, ry, fill) => { ctx.fillStyle = fill; ctx.beginPath(); ctx.ellipse(x, y, rx, ry, 0, 0, 7); ctx.fill(); };
    const WHITE = '#fffdfb', NAVY = '#222c4e', LINE = 'rgba(176,170,164,0.75)';
    for (const d of [
      'M150 355 C95 310 60 215 72 150 C80 100 125 80 170 90 C235 105 295 180 308 240 C315 275 305 300 295 315 Z',
      'M350 300 C345 250 355 225 372 205 C395 130 470 72 530 78 C575 85 595 130 590 185 C585 225 560 265 538 292 C530 310 520 325 505 345 Z',
    ]) { ctx.strokeStyle = LINE; ctx.lineWidth = 4; ctx.stroke(shape(d, WHITE)); }
    shape('M108 297 C78 250 62 195 70 160 C78 105 125 80 170 90 C225 102 275 160 290 205 C255 205 200 205 165 235 C140 255 120 275 108 297 Z', NAVY);
    shape('M372 205 C395 130 470 72 530 78 C575 85 595 130 590 185 C585 225 560 265 538 292 C520 250 490 215 450 205 C420 198 395 200 372 205 Z', NAVY);
    const headPath = 'M103 480 C103 380 200 295 325 295 C450 295 545 380 545 470 C545 510 525 545 495 560 C420 590 240 590 150 565 C120 550 103 520 103 480 Z';
    ctx.strokeStyle = LINE; ctx.lineWidth = 4; ctx.stroke(shape(headPath, WHITE));
    oval(245, 465, 30, 31, NAVY); oval(424, 450, 29, 32, NAVY);
    oval(258, 443, 6, 6, WHITE); oval(436, 428, 6, 6, WHITE);
    oval(339, 472, 19, 10, NAVY);
    shape('M148 590 C200 580 280 580 360 565 C410 555 470 545 495 540 C515 550 515 575 495 590 L470 605 L478 680 C478 695 470 702 450 703 L400 706 C385 706 380 698 378 685 L372 640 C300 650 230 650 175 630 C150 620 145 605 148 590 Z', '#36b9b9');
    shape('M360 568 C390 560 430 552 460 555 L478 680 C478 695 470 702 450 703 L400 706 C385 706 380 698 378 685 Z', '#55cfcf');
    const tex = new THREE.CanvasTexture(canvas);
    tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 8;
    // Printed ink, matte: a glossy print caught the key light as a pale wash over its top.
    const mat = new THREE.MeshPhysicalMaterial({ map: tex, transparent: true, depthWrite: false, roughness: 0.85, specularIntensity: 0.15,
      polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 });
    const decal = new THREE.SkinnedMesh(dg, mat);
    decal.name = 'Logo'; decal.frustumCulled = false; decal.renderOrder = 2;
    decal.bind(body.skeleton, body.bindMatrix);
    body.parent.add(decal);
  },

  actions: {
    // Lower leaps: with its tall head the shared ones carried its ears out of the top of its window.
    ...Object.fromEntries([['hop', 0.42], ['jump', 0.15], ['flip', 0.08]].map(([n, k]) => [n, {
      dur: ACTIONS[n].dur,
      fn(t, P, fx) { const y = P.root.py; ACTIONS[n].fn(t, P, fx); P.root.py = y + (P.root.py - y) * k; },
    }])),
    // Stub arms fused to the body: the shared cheer lifts them straight up and stretches the armpits, so
    // Piko's paws pump beside its headphones.
    cheer: {
      dur: ACTIONS.cheer.dur,
      fn(t, P, fx) {
        ACTIONS.cheer.fn(t, P, fx);
        const on = win(t, 0, 0.25, 2.6, 3.0);
        for (const s of ['L', 'R']) raise(P, s, -24 * on);
      },
    },
    // Its own moment: a slow scan of the room.
    scan: {
      dur: 3.6,
      fn(t, P, fx) {
        fx.at(0.3, 'dots');
        const on = win(t, 0, 0.4, 3.0, 3.6);
        const sweep = curve([[0, 0], [0.8, -40], [1.8, 40], [2.8, 0], [3.6, 0]], t);
        add(P, 'head', -4 * on, sweep * on, 0); add(P, 'chest', 0, sweep * 0.25 * on, 0);
        P.look *= 1 - on;
        P.gaze = [sweep / 45, 0];
        face(P, { mood: 'attentive' });
      },
    },
  },
  moments: ['scan'],
  postures: { lie: rest, sleep: nap },

  chains: [],
  pick: { head: { r: 0.62, at: [0, 0.38, 0] }, body: { r: 0.36, at: [0, -0.5, 0] } },
  fidgets: ['lookAround', 'tilt', 'smile', 'stretch', 'hop', 'blinkDouble', 'giggle'],
  skip: ['sniff', 'sneeze'],

  // As on Spark, the aqua parts light up while Piko pays attention. Asleep it is on standby: the face dims to a faint
  // glow and the aqua parts go dark but for a slow pulse.
  dynamics(c, dt) {
    const busy = ['listening', 'hearing', 'thinking', 'working'].includes(c.loopName);
    const standby = c.postureW.sleep.x;
    const slow = 0.5 + 0.5 * Math.sin(c.time * Math.PI * 2 * 0.2);
    const target = busy ? 0.55 + 0.35 * Math.sin(c.time * (c.loopName === 'thinking' ? 5 : 3)) : -0.22 * standby * (1 - 0.4 * slow);
    const u = c.body.material.userData.u.uPulse;
    u.value = damp(u.value, target, 6, dt);
    c.faceDecal ||= c.body.parent.getObjectByName('FaceDecal');
    c.faceDecal.material.color.setScalar(1 - standby * (0.62 - 0.12 * slow));
  },

  // Arms relaxed down from the modelled A-pose.
  stand(t, P) {
    add(P, 'armL', 0, 0, -24); add(P, 'armR', 0, 0, 24);
    add(P, 'handL', 0, 0, -6); add(P, 'handR', 0, 0, 6);
    add(P, 'thighL', 0, 3, 0); add(P, 'thighR', 0, -3, 0);
  },
};
