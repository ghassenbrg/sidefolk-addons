// Noor: a chubby baby moth who carries his own light: lapis fur, a pearl face, a wide cream ruff, gold feather antennae, a
// gold rosette with a star of light on his chest, and big wings in lapis, amethyst and rose with gold inlay.
// Sheet: companions-3d/references/noor-sheet.png. Rig: blender/rig_noor.py. His fur is drawn in shells over the body;
// wings, feathers and rosette are parts of their own in the GLB, painted, so they keep fine lines the body's texture can't.
import { bodyMaterial } from '../engine/materials.js';
import { add, face, doze, POSTURES } from '../engine/moves.js';
import { win } from '../engine/motion.js';

// Fur layers: enough for a window on the desktop; twice that when he is drawn large (review close-ups, the stage in Settings).
const SHELLS = 12, SMALL_CANVAS = 640;
// How bright his star is right now: the material's glow on the fur, the rosette and its halo all read it.
const star = { value: 1 };
// Strand fineness: strands thinner than a pixel turn to speckle, so they coarsen as he is drawn smaller.
const fine = { value: 1 };

const SURFACE = `
  float furR = smoothstep(0.72, 0.9, part);
  float zone = smoothstep(0.2, 0.42, part);
  float fur = zone * (1.0 - furR);
  // The face's outline is drawn, measured on the sheet: Meshy's was smaller, with a torn edge. Its heart-shaped dip included.
  float dz = p.y - 0.235, notch = 0.075 * exp(-pow(p.x / 0.06, 2.0));
  float d2 = dz > 0.0 ? dz + notch : dz, bb = dz > 0.0 ? 0.24 : 0.25;
  float fv = pow(abs(p.x) / 0.335, 2.3) + pow(abs(d2) / bb, 2.3);
  float faceM = (1.0 - smoothstep(1.0 - fwidth(fv), 1.0 + fwidth(fv), fv)) * step(0.1, p.z) * (1.0 - furR);
  float bare = max(1.0 - zone, faceM);
  c = mix(vec3(0.03, 0.03, 0.17), vec3(0.8, 0.62, 0.53), furR);
  c = mix(c, vec3(0.84, 0.73, 0.69), bare);
  // Hands and feet are a little deeper than the face, as on the sheet; the chin falls into a warm shadow toward the ruff.
  c *= mix(1.0, 0.94, (1.0 - faceM) * bare);
  c *= 1.0 - 0.1 * faceM * smoothstep(0.2, 0.02, p.y);
  rough = mix(0.92, 0.42, bare);
  sheenTint = (1.0 - bare) * mix(vec3(0.14, 0.14, 0.42), vec3(0.8, 0.7, 0.62), furR);
  clear = 0.0;
  inner = 0.85 + 0.75 * bare + 0.4 * furR;
  // The star's warm light on the fur round it, falling off fast.
  float starL = exp(-pow(length((p - vec3(0.0, -0.35, 0.43)) * vec3(1.0, 1.0, 0.8)) / 0.21, 2.0));
  glow = (1.0 - bare) * starL * vec3(0.17, 0.08, 0.02) * uStar;`;

const HASH = `
  float hs(vec3 v) { return fract(sin(dot(v, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
  vec3 hv(vec3 v) { return vec3(hs(v), hs(v + 17.1), hs(v + 31.7)); }`;

// Strands drawn as columns through stacked copies of the body: each is thinner further out, strands lean into their
// clump toward the tip, so the fur falls in soft points, and they fall short near the face so it has a soft edge.
const SHELL_SURFACE = SURFACE + `
  float cf = mix(16.0, 9.0, furR);
  vec3 cid = floor(p * cf), ccen = (cid + 0.5 + (hv(cid) - 0.5) * 0.7) / cf;
  vec3 q = mix(p, ccen, uL * mix(0.5, 0.72, furR));
  float F = mix(175.0, 150.0, furR) * uFine;
  vec3 qr = mat3(0.72, -0.48, 0.5, 0.62, 0.71, -0.33, -0.31, 0.51, 0.8) * q * F;
  vec3 cell = floor(qr), lc = fract(qr) - 0.5 - (hv(cell) - 0.5) * 0.55;
  float hh = hs(cell), cl = hs(cid + 5.0);
  float sl = mix(0.5, 1.0, hh) * mix(0.72, 1.0, cl) * smoothstep(0.22, 0.42, part);
  float frontFace = step(0.1, p.z) * (1.0 - furR);
  sl *= mix(1.0, smoothstep(0.92, 1.45, fv), frontFace);
  float underRosette = step(length(p.xy - vec2(0.0, -0.35)), 0.1) * step(0.2, p.z) * (1.0 - furR);
  if (zone < 0.3 || underRosette > 0.5 || uL > sl) discard;
  if (fv < 1.0 + (hh - 0.5) * 0.1 && frontFace > 0.5) discard;
  if (length(lc) > mix(0.8, mix(0.42, 0.2, uFine), uL / sl)) discard;
  // Small, strands hardly a pixel wide: less contrast from root to tip, or they read as speckle.
  float soft = smoothstep(0.9, 0.5, uFine);
  c *= mix(mix(0.46, 0.8, soft), mix(1.34, 1.12, soft), uL) * (0.94 + 0.12 * cl) * (0.96 + 0.08 * hh);
  // Deeper between the tufts, as a pile parts.
  c *= 1.0 - mix(0.26, 0.1, soft) * smoothstep(0.25, 0.8, length((p - ccen) * cf)) * (1.0 - uL);
  c += furR * uL * uL * vec3(0.1, 0.1, 0.08) + fur * uL * uL * vec3(0.012, 0.012, 0.05);
  // The light a pile catches at its edge, here in place of the sheen, which would cost every layer dearly.
  float rim = pow(1.0 - abs(dot(normalize(vNormal), normalize(vViewPosition))), 3.0);
  c += rim * uL * mix(vec3(0.03, 0.03, 0.12), vec3(0.14, 0.11, 0.09), furR);`;

function furShells(c, THREE) {
  const body = c.body, geo = body.geometry, col = geo.attributes.color, src = geo.index.array, keep = [];
  // Only the fur draws again: the hands and feet cost nothing.
  for (let i = 0; i < src.length; i += 3) { if (Math.max(col.getY(src[i]), col.getY(src[i + 1]), col.getY(src[i + 2])) > 0.2) keep.push(src[i], src[i + 1], src[i + 2]); }
  const fur = new THREE.BufferGeometry();
  for (const n of Object.keys(geo.attributes)) fur.setAttribute(n, geo.attributes[n]);
  fur.setIndex(keep);
  c.shells = [];
  for (let i = 1; i <= SHELLS; i++) {
    const L = i / SHELLS;
    const mat = bodyMaterial(body, {
      ao: [0.5, 0.4, 0.85], params: { sheen: 0, roughness: 0.92 }, uniforms: { uL: { value: L }, uStar: star, uFine: fine }, surface: SHELL_SURFACE,
    });
    const base = mat.onBeforeCompile;
    mat.onBeforeCompile = (sh) => {
      base(sh);
      sh.uniforms.uLen = { value: L };
      sh.fragmentShader = sh.fragmentShader.replace('#include <common>', '#include <common>\n' + HASH);
      sh.vertexShader = sh.vertexShader.replace('#include <common>', '#include <common>\nuniform float uLen;')
        .replace('vRest = position; vRestN = normal;', `vRest = position; vRestN = normal;
          float ruffV = smoothstep(0.72, 0.9, color.g), zoneV = smoothstep(0.2, 0.45, color.g);
          float furLen = zoneV * mix(0.038, 0.085, ruffV);
          vec3 fn = normalize(normal), down = vec3(0.0, -1.0, 0.0);
          vec3 flow = down - fn * dot(down, fn);
          flow = mix(flow, normalize(vec3(sign(position.x) * 0.6, -0.5, 0.15)), ruffV * 0.45);
          transformed += fn * uLen * furLen + flow * uLen * uLen * furLen * mix(1.0, 1.5, ruffV);`);
    };
    mat.customProgramCacheKey = () => 'noor-shell';
    const s = new THREE.SkinnedMesh(fur, mat);
    s.bind(body.skeleton, body.bindMatrix); s.frustumCulled = false; s.receiveShadow = true;
    body.parent.add(s); c.shells.push(s);
  }
}

function starHalo(THREE, size) {
  const S = 256, cv = document.createElement('canvas'); cv.width = cv.height = S; const g = cv.getContext('2d');
  const gr = g.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
  gr.addColorStop(0, 'rgba(255,240,205,0.85)'); gr.addColorStop(0.25, 'rgba(255,205,120,0.42)'); gr.addColorStop(0.6, 'rgba(255,165,70,0.1)'); gr.addColorStop(1, 'rgba(255,150,50,0)');
  g.fillStyle = gr; g.fillRect(0, 0, S, S);
  const t = new THREE.CanvasTexture(cv); t.colorSpace = THREE.SRGBColorSpace;
  return new THREE.Mesh(new THREE.PlaneGeometry(size, size), new THREE.MeshBasicMaterial({ map: t, blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, toneMapped: false }));
}

export default {
  id: 'noor',
  name: 'Noor',
  model: 'noor.glb',
  floor: 0.952,
  pivot: [0, 0.9, 0],
  // His feathers rise well above his head and spring on landings: a 2.3 window cut them off at the top.
  frame: { sidefolk: 2.7, tight: 2.5, tightY: 1.02 },
  marks: [0.45, 0.62, 0.15],
  blob: [1.5, 0.8],

  material: (body) => bodyMaterial(body, { params: { sheen: 1, sheenRoughness: 0.5, roughness: 0.85 }, uniforms: { uStar: star }, surface: SURFACE }),

  extras(c, THREE) {
    const part = (n) => c.model.getObjectByName(n);
    const take = (n) => {
      const o = part('tx_' + n), t = o.material.map; o.removeFromParent();
      t.anisotropy = 8; t.colorSpace = THREE.NoColorSpace; t.needsUpdate = true; return t;
    };
    const skinned = (n) => { const m = part(n); m.frustumCulled = false; m.castShadow = true; m.receiveShadow = true; m.material.map.anisotropy = 8; return m; };

    const wings = skinned('A_Wings'), wmat = take('wing_mat');
    wings.material = new THREE.MeshPhysicalMaterial({ map: wings.material.map, bumpMap: take('wing_height'), bumpScale: 2.6, roughnessMap: wmat, metalnessMap: wmat, roughness: 1, metalness: 1, sheen: 1, sheenRoughness: 0.6, sheenColor: new THREE.Color(0x6a4fb0), side: THREE.DoubleSide, envMapIntensity: 0.85, color: new THREE.Color(0.9, 0.86, 0.93) });
    const feathers = skinned('A_Feathers');
    feathers.material = new THREE.MeshPhysicalMaterial({ map: feathers.material.map, alphaMap: take('feather_alpha'), transparent: true, alphaTest: 0.04, side: THREE.DoubleSide, roughness: 0.8, sheen: 0.5, sheenColor: new THREE.Color(0xffd8a0), envMapIntensity: 0.8, color: new THREE.Color(1.1, 1.08, 1.06) });
    const rosette = skinned('A_Rosette'), rmap = rosette.material.map;
    rosette.material = c.rosetteMat = new THREE.MeshPhysicalMaterial({ map: rmap, alphaMap: take('rosette_alpha'), transparent: true, alphaTest: 0.12, side: THREE.DoubleSide, roughness: 0.42, metalness: 0.35, envMapIntensity: 0.9, emissive: new THREE.Color(0xffffff), emissiveMap: rmap, emissiveIntensity: 0.12 });

    // A soft warm halo over the star, lying on the chest (edge-on from the side, so it never hangs in the air).
    rosette.geometry.computeBoundingBox();
    const box = rosette.geometry.boundingBox, halo = c.halo = starHalo(THREE, 0.3);
    const chest = c.bones.chest; chest.updateWorldMatrix(true, false); chest.add(halo);
    const keep = new THREE.Matrix4().compose(new THREE.Vector3((box.min.x + box.max.x) / 2, (box.min.y + box.max.y) / 2, box.max.z + 0.006), new THREE.Quaternion(), new THREE.Vector3(1, 1, 1));
    new THREE.Matrix4().copy(chest.matrixWorld).invert().multiply(keep).decompose(halo.position, halo.quaternion, halo.scale);

    furShells(c, THREE);

    // The engine eases hops under the window's top from the body's box: the feathers must count, with how far they flick up.
    const bb = c.body.geometry.boundingBox || (c.body.geometry.computeBoundingBox(), c.body.geometry.boundingBox);
    bb.max.y = Math.max(bb.max.y, 1.16);
  },

  face: {
    kind: 'ink',
    twinkle: false,
    unwrap: { R: 0.4, span: 0.42, cz: 0.03, cy: 0.24 },
    region: (x, y, z) => z > 0.1 && y > 0.0 && y < 0.6,
    colors: { ink: '#15182F', brow: '#15182F', blush: '245,140,135', lip: '#6a2a3a', mouth: '#7a2a2a' },
    iris: { deep: [0.004, 0.005, 0.03], rim: [0.035, 0.035, 0.2], glow: [0.14, 0.12, 0.42], glowAmt: 0.45, pupil: 0.58 },
    layout: {
      eye: { x: 0.19, y: 0.245, w: 0.165, h: 0.18, depth: 0.04 },
      mouth: { y: 0.185, scale: 0.85 },
      brow: { base: 0, y: 0.4, len: 0.09, width: 10, arch: 8 },
      blush: { x: 0.265, y: 0.135, w: 0.09, h: 0.055, alpha: 0.38 },
    },
  },

  chains: [
    { bones: ['antennaL1', 'antennaL2', 'antennaL3'], side: 1, twitch: true, k: [190, 150, 120], d: [11, 9, 7], limit: [20, 20, 20] },
    { bones: ['antennaR1', 'antennaR2', 'antennaR3'], side: -1, twitch: true, k: [190, 150, 120], d: [11, 9, 7], limit: [20, 20, 20] },
  ],
  pick: { head: { r: 0.45, at: [0, 0.3, 0] }, body: { r: 0.4, at: [0, -0.45, 0] }, tips: ['antennaL3', 'antennaR3'] },
  fidgets: ['lookAround', 'tilt', 'smile', 'stretch', 'hop', 'blinkDouble', 'giggle', 'flutter'],

  // His own moment: a quick shiver of the wings, and the star flares once.
  actions: {
    flutter: {
      dur: 1.6,
      fn(t, P, fx) {
        fx.at(0.5, 'sparkle');
        const on = win(t, 0.05, 0.25, 1.1, 1.5);
        const beat = 18 + 16 * Math.sin(t * 30);
        add(P, 'wingL', 0, beat * on, 0); add(P, 'wingR', 0, -beat * on, 0);
        add(P, 'head', -4 * on); P.flare = on;
        face(P, { mood: 'happy' });
      },
    },
  },
  moments: ['flutter'],

  // Resting, his wings open and close a little, as a moth's do.
  life(t, P, live) {
    const open = 4 + 4 * Math.sin(t * 0.55);
    add(P, 'wingL', 0, open * live, 0); add(P, 'wingR', 0, -open * live, 0);
  },

  dynamics(c, dt, P, { lin, happy }) {
    // Small flutters for lift whenever he leaves the ground, and when he is delighted.
    const air = Math.min(1, Math.max(0, P.root.py) * 5 + Math.abs(lin.y) * 0.4);
    const beat = (air * 0.9 + happy * 0.35) * (11 + 11 * Math.sin(c.time * 34));
    add(P, 'wingL', 0, beat, 0); add(P, 'wingR', 0, -beat, 0);
    // The star breathes with him, dims while he thinks, sleeps low, and flares when something goes well.
    const st = c.state;
    const low = st === 'thinking' || st === 'working' ? 0.5 : st === 'sleeping' || P.lidsShut ? 0.35 : 1;
    const flare = st === 'celebrating' || st === 'success' ? 1 : (P.flare || 0);
    const target = low * (0.86 + 0.14 * Math.sin(c.time * Math.PI * 2 * 0.22)) + flare * 0.7;
    star.value += (target - star.value) * Math.min(1, dt * 5);
    c.halo.material.opacity = Math.min(1, 0.25 + 0.75 * star.value);
    c.rosetteMat.emissiveIntensity = 0.06 + 0.08 * star.value;
    // While he thinks, one antenna tilts.
    if (st === 'thinking') { add(P, 'antennaL1', 0, 0, -10); add(P, 'antennaL2', 0, 0, -8); }
    // Half the layers are enough in a small window.
    const half = c.canvas.height <= SMALL_CANVAS;
    c.shells.forEach((s, i) => { s.visible = !half || i % 2 === 1; });
    fine.value = Math.max(0.42, Math.min(1, c.canvas.height / 1000));
  },

  // He rests sitting up. The shared rests lie on the tummy, head thrown back, which tore his ruff across his chin: he swings
  // his feet and looks about instead, and asleep he dozes where he sits, wings folded close.
  postures: {
    lie: (t, P) => {
      POSTURES.sit(t, P);
      add(P, 'thighL', 7 * Math.sin(t * 1.2)); add(P, 'thighR', 7 * Math.sin(t * 1.2 + 2.2));
      add(P, 'head', 0, 9 * Math.sin(t * 0.37), 3 * Math.sin(t * 0.53));
    },
    sleep: (t, P) => { doze(t, P); add(P, 'wingL', 0, -3, 0); add(P, 'wingR', 0, 3, 0); },
  },

  // Arms relaxed down from the modelled A-pose.
  stand(t, P) {
    add(P, 'armL', 0, -10, -28); add(P, 'armR', 0, 10, 28);
  },
};
