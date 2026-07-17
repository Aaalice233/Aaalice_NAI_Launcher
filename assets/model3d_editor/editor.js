// assets/model3d_editor/editor.js
// 3D 模型图层编辑器。与 Dart 的协议:
//   Dart→JS  window.naiEditor.dispatch('{"type":..,"requestId":..,...}')
//   JS→Dart  window.flutter_inappwebview.callHandler('naiModel3d', msg)
//     msg: {type:'response', requestId, ok, data} 或事件 {type:'onReady'|'onModelLoaded'|'onLoadError'|'onDirty', ...}
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { TransformControls } from 'three/addons/controls/TransformControls.js';
import { buildMannequin } from './mannequin.js';

const canvas = document.getElementById('viewport');

function emit(msg) {
  window.flutter_inappwebview.callHandler('naiModel3d', msg);
}

// 就绪宣告:flutterInAppWebViewPlatformReady 事件在 Windows 平台不派发
// (spike 实测),因此轮询 callHandler 注入;事件监听仅作其余平台的加速路径。
let webglError = null;
let readyAnnounced = false;
function announceReady() {
  if (readyAnnounced) return;
  if (!(window.flutter_inappwebview && window.flutter_inappwebview.callHandler)) {
    setTimeout(announceReady, 50);
    return;
  }
  readyAnnounced = true;
  if (webglError) {
    emit({ type: 'onLoadError', error: webglError });
  } else {
    emit({ type: 'onReady' });
  }
}
window.addEventListener('flutterInAppWebViewPlatformReady', announceReady);

let renderer;
try {
  renderer = new THREE.WebGLRenderer({
    canvas, alpha: true, preserveDrawingBuffer: true, antialias: true,
  });
} catch (e) {
  webglError = 'webgl_unavailable: ' + String(e && e.message || e);
  announceReady(); // 启动轮询以上报错误
  throw e; // 中断初始化
}
renderer.setPixelRatio(window.devicePixelRatio);

const scene = new THREE.Scene();

const camera = new THREE.PerspectiveCamera(30, 1, 0.01, 200);
camera.position.set(0, 1.2, 3.2);

const controls = new OrbitControls(camera, canvas);
controls.target.set(0, 0.9, 0);
// 官网键位:左键旋转 / 中键推拉 / 右键平移(OrbitControls 默认即此映射)
controls.update();

const hemiLight = new THREE.HemisphereLight(0xffffff, 0x445566, 1.0);
const dirLight = new THREE.DirectionalLight(0xffffff, 1.6);
scene.add(hemiLight, dirLight);

// 辅助对象(渲染输出时整组隐藏)
const helpers = new THREE.Group();
helpers.name = 'helpers';
helpers.add(new THREE.GridHelper(4, 20, 0x668899, 0x334455));
scene.add(helpers);

// 编辑器共享上下文;后续命令在此对象上读写
const ctx = {
  scene, camera, renderer, controls, helpers,
  hemiLight, dirLight,
  modelRoot: null,      // 当前模型根节点(Task 6)
  skinnedMeshes: [],    // 当前模型的 SkinnedMesh 列表(Task 6)
  restPose: null,       // Map<boneName, {p,q,s}> 加载时的绑定姿势(Task 6)
  dirty: false,
};

function markDirty() {
  if (ctx.dirty) return;
  ctx.dirty = true;
  emit({ type: 'onDirty' });
}

// ---- 命令框架 ----
const commands = new Map();

function registerCommand(type, fn) {
  commands.set(type, fn);
}

window.naiEditor = {
  dispatch(jsonStr) {
    let msg;
    try {
      msg = JSON.parse(jsonStr);
    } catch (e) {
      return; // 非法输入直接丢弃(Dart 侧靠超时兜底)
    }
    const fn = commands.get(msg.type);
    const done = (ok, data) =>
      emit({ type: 'response', requestId: msg.requestId, ok, data: data ?? {} });
    if (!fn) return done(false, { error: 'unknown command: ' + msg.type });
    Promise.resolve()
      .then(() => fn(msg))
      .then((data) => done(true, data))
      .catch((e) => done(false, { error: String(e && e.message || e) }));
  },
};

ctx.lightParams = { intensity: 1.6, azimuth: 37, elevation: 50 };

function applyLight({ intensity, azimuth, elevation }) {
  ctx.lightParams = { intensity, azimuth, elevation };
  ctx.dirLight.intensity = intensity;
  const az = azimuth * Math.PI / 180;
  const el = elevation * Math.PI / 180;
  const r = 4;
  ctx.dirLight.position.set(
    r * Math.cos(el) * Math.sin(az),
    r * Math.sin(el),
    r * Math.cos(el) * Math.cos(az),
  );
}
applyLight(ctx.lightParams);

registerCommand('setLight', (params) => {
  applyLight({
    intensity: params.intensity,
    azimuth: params.azimuth,
    elevation: params.elevation,
  });
  markDirty();
});

// ---- 相机 WASDQE 平移(官网快捷键) ----
const keyMove = { w: [0, 0, -1], s: [0, 0, 1], a: [-1, 0, 0], d: [1, 0, 0], q: [0, -1, 0], e: [0, 1, 0] };
window.addEventListener('keydown', (event) => {
  const move = keyMove[event.key.toLowerCase()];
  if (!move) return;
  const step = 0.05;
  const forward = new THREE.Vector3();
  camera.getWorldDirection(forward);
  forward.y = 0;
  forward.normalize();
  const right = new THREE.Vector3().crossVectors(forward, camera.up).normalize();
  const delta = new THREE.Vector3()
    .addScaledVector(right, move[0] * step)
    .addScaledVector(camera.up, move[1] * step)
    .addScaledVector(forward, -move[2] * step);
  camera.position.add(delta);
  controls.target.add(delta);
  controls.update();
});

// ---- 尺寸与渲染循环 ----
function resize() {
  const w = canvas.clientWidth, h = canvas.clientHeight;
  if (w === 0 || h === 0) return;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);
resize();

renderer.setAnimationLoop(() => {
  controls.update();
  syncBoneMarkers();
  renderer.render(scene, camera);
});

// ---- 模型加载 ----
function clearCurrentModel() {
  if (!ctx.modelRoot) return;
  scene.remove(ctx.modelRoot);
  ctx.modelRoot.traverse((obj) => {
    if (obj.isSkinnedMesh && obj.skeleton) obj.skeleton.dispose();
    if (obj.geometry) obj.geometry.dispose();
    if (obj.material) {
      const materials = Array.isArray(obj.material) ? obj.material : [obj.material];
      for (const material of materials) {
        for (const value of Object.values(material)) {
          if (value && value.isTexture) value.dispose();
        }
        material.dispose();
      }
    }
  });
  ctx.modelRoot = null;
  ctx.skinnedMeshes = [];
  ctx.restPose = null;
  undoStack.length = 0; // 换模型时废弃旧快照,防止跨模型恢复污染
}

function collectBones() {
  const bones = [];
  for (const mesh of ctx.skinnedMeshes) {
    for (const bone of mesh.skeleton.bones) {
      if (!bones.includes(bone)) bones.push(bone);
    }
  }
  return bones;
}

function captureRestPose() {
  ctx.restPose = new Map();
  for (const bone of collectBones()) {
    ctx.restPose.set(bone, {
      p: bone.position.clone(),
      q: bone.quaternion.clone(),
      s: bone.scale.clone(),
    });
  }
}

function frameObject(root) {
  const box = new THREE.Box3().setFromObject(root);
  if (box.isEmpty()) return;
  const center = box.getCenter(new THREE.Vector3());
  const size = box.getSize(new THREE.Vector3()).length() || 1;
  camera.position.copy(center)
    .add(new THREE.Vector3(0, size * 0.15, size * 1.4));
  controls.target.copy(center);
  controls.update();
}

registerCommand('loadModel', async ({ url, builtin, sceneState }) => {
  clearCurrentModel();
  let root;
  try {
    if (builtin === 'mannequin') {
      root = buildMannequin();
    } else if (url) {
      const gltf = await new GLTFLoader().loadAsync(url);
      root = gltf.scene;
    } else {
      throw new Error('loadModel requires url or builtin');
    }
  } catch (e) {
    const error = String(e && e.message || e);
    emit({ type: 'onLoadError', error });
    throw e;
  }

  scene.add(root);
  ctx.modelRoot = root;
  ctx.skinnedMeshes = [];
  root.traverse((obj) => {
    if (obj.isSkinnedMesh) ctx.skinnedMeshes.push(obj);
  });
  captureRestPose();
  if (sceneState) {
    applySceneState(sceneState); // 再编辑:恢复姿势/相机/光照,不自动对焦
  } else {
    frameObject(root);
  }
  rebuildBoneMarkers();
  applyMode();

  const names = collectBones().map((b) => b.name);
  const duplicateBoneNames = [...new Set(
    names.filter((n, i) => names.indexOf(n) !== i),
  )];
  const result = { boneCount: names.length, duplicateBoneNames };
  emit({ type: 'onModelLoaded', ...result });
  return result;
});

// ---- 变换 gizmo 与双模式编辑 ----
const transformControls = new TransformControls(camera, canvas);
transformControls.setSize(0.8);
// r169+ 的 TransformControls 不再是 Object3D,通过 getHelper() 挂载
const gizmoHelper = transformControls.getHelper
  ? transformControls.getHelper()
  : transformControls;
scene.add(gizmoHelper);

transformControls.addEventListener('dragging-changed', (event) => {
  controls.enabled = !event.value;
  if (event.value) pushUndoSnapshot(); // 拖拽开始时记快照
});
transformControls.addEventListener('objectChange', markDirty);

// 骨骼标记球:挂在 helpers 下(渲染输出时随 helpers 整组隐藏),
// visible 由 pose 模式独立控制(嵌套 visible 为 AND 关系)。
const boneMarkers = new THREE.Group();
boneMarkers.name = 'boneMarkers';
boneMarkers.visible = false;
helpers.add(boneMarkers);

const markerMaterial = new THREE.MeshBasicMaterial({
  color: 0x4f8cff, depthTest: false, transparent: true, opacity: 0.85,
});
const markerSelectedColor = new THREE.Color(0xffc24f);
let selectedMarker = null;

function rebuildBoneMarkers() {
  boneMarkers.clear();
  selectedMarker = null;
  if (!ctx.modelRoot) return;
  const box = new THREE.Box3().setFromObject(ctx.modelRoot);
  const radius = Math.max(box.getSize(new THREE.Vector3()).length() * 0.008, 0.006);
  const geometry = new THREE.SphereGeometry(radius, 12, 8);
  for (const bone of collectBones()) {
    const marker = new THREE.Mesh(geometry, markerMaterial.clone());
    marker.renderOrder = 999;
    marker.userData.bone = bone;
    boneMarkers.add(marker);
  }
}

function syncBoneMarkers() {
  const worldPos = new THREE.Vector3();
  for (const marker of boneMarkers.children) {
    marker.userData.bone.getWorldPosition(worldPos);
    marker.position.copy(worldPos);
  }
}

let mode = 'transform';

function applyMode() {
  if (mode === 'pose') {
    boneMarkers.visible = true;
    transformControls.detach(); // 等待用户点选骨骼
  } else {
    boneMarkers.visible = false;
    selectedMarker = null;
    if (ctx.modelRoot) {
      transformControls.attach(ctx.modelRoot);
    } else {
      transformControls.detach();
    }
  }
}

registerCommand('setMode', ({ mode: newMode, gizmo }) => {
  mode = newMode === 'pose' ? 'pose' : 'transform';
  transformControls.setMode(gizmo || (mode === 'pose' ? 'rotate' : 'translate'));
  applyMode();
});

function selectBone(marker) {
  if (selectedMarker) selectedMarker.material.color.set(0x4f8cff);
  selectedMarker = marker;
  marker.material.color.copy(markerSelectedColor);
  transformControls.attach(marker.userData.bone);
}

const raycaster = new THREE.Raycaster();
canvas.addEventListener('pointerdown', (event) => {
  if (mode !== 'pose' || transformControls.dragging) return;
  const rect = canvas.getBoundingClientRect();
  const ndc = new THREE.Vector2(
    ((event.clientX - rect.left) / rect.width) * 2 - 1,
    -((event.clientY - rect.top) / rect.height) * 2 + 1,
  );
  raycaster.setFromCamera(ndc, camera);
  const hits = raycaster.intersectObjects(boneMarkers.children, false);
  if (hits.length) {
    controls.enabled = false; // 选骨点击不应带动相机
    window.addEventListener('pointerup', () => {
      if (!transformControls.dragging) controls.enabled = true;
    }, { once: true });
    selectBone(hits[0].object);
  }
});

// ---- 会话内撤销(仅姿势/变换,不进画布 history) ----
const undoStack = [];

function capturePoseSnapshot() {
  const boneStates = collectBones().map((bone) => ({
    bone,
    p: bone.position.clone(),
    q: bone.quaternion.clone(),
    s: bone.scale.clone(),
  }));
  const root = ctx.modelRoot;
  return {
    boneStates,
    rootState: root
      ? { p: root.position.clone(), q: root.quaternion.clone(), s: root.scale.clone() }
      : null,
  };
}

function pushUndoSnapshot() {
  undoStack.push(capturePoseSnapshot());
  if (undoStack.length > 50) undoStack.shift();
}

function restoreSnapshot(snapshot) {
  for (const { bone, p, q, s } of snapshot.boneStates) {
    bone.position.copy(p);
    bone.quaternion.copy(q);
    bone.scale.copy(s);
  }
  if (snapshot.rootState && ctx.modelRoot) {
    ctx.modelRoot.position.copy(snapshot.rootState.p);
    ctx.modelRoot.quaternion.copy(snapshot.rootState.q);
    ctx.modelRoot.scale.copy(snapshot.rootState.s);
  }
  markDirty();
}

function undoPose() {
  const snapshot = undoStack.pop();
  if (snapshot) restoreSnapshot(snapshot);
}

registerCommand('undoPose', () => undoPose());

registerCommand('resetPose', () => {
  if (!ctx.restPose) return;
  pushUndoSnapshot();
  for (const [bone, rest] of ctx.restPose) {
    bone.position.copy(rest.p);
    bone.quaternion.copy(rest.q);
    bone.scale.copy(rest.s);
  }
  markDirty();
});

window.addEventListener('keydown', (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'z') {
    event.preventDefault();
    undoPose();
  }
});

// ---- sceneState 序列化与恢复 ----
const POSE_EPS = 1e-4;

function serializeScene() {
  const bones = {};
  if (ctx.restPose) {
    for (const bone of collectBones()) {
      const rest = ctx.restPose.get(bone);
      if (!rest) continue;
      const changed =
        bone.position.distanceToSquared(rest.p) > POSE_EPS * POSE_EPS ||
        Math.abs(bone.quaternion.dot(rest.q)) < 1 - POSE_EPS ||
        bone.scale.distanceToSquared(rest.s) > POSE_EPS * POSE_EPS;
      if (changed) {
        bones[bone.name] = {
          position: bone.position.toArray(),
          quaternion: bone.quaternion.toArray(),
          scale: bone.scale.toArray(),
        };
      }
    }
  }
  return {
    version: 1,
    modelTransform: ctx.modelRoot
      ? {
          position: ctx.modelRoot.position.toArray(),
          quaternion: ctx.modelRoot.quaternion.toArray(),
          scale: ctx.modelRoot.scale.toArray(),
        }
      : null,
    bones,
    camera: {
      position: camera.position.toArray(),
      target: controls.target.toArray(),
      fov: camera.fov,
    },
    light: { ...ctx.lightParams },
  };
}

function applySceneState(state) {
  if (!state) return;
  const transform = state.modelTransform;
  if (transform && ctx.modelRoot) {
    ctx.modelRoot.position.fromArray(transform.position);
    ctx.modelRoot.quaternion.fromArray(transform.quaternion);
    ctx.modelRoot.scale.fromArray(transform.scale);
  }
  if (state.bones) {
    const byName = new Map(collectBones().map((b) => [b.name, b]));
    for (const [name, boneState] of Object.entries(state.bones)) {
      const bone = byName.get(name);
      if (!bone) continue; // 换模型后骨骼名不匹配则跳过
      if (boneState.position) bone.position.fromArray(boneState.position);
      if (boneState.quaternion) bone.quaternion.fromArray(boneState.quaternion);
      if (boneState.scale) bone.scale.fromArray(boneState.scale);
    }
  }
  if (state.camera) {
    camera.position.fromArray(state.camera.position);
    controls.target.fromArray(state.camera.target);
    camera.fov = state.camera.fov;
    camera.updateProjectionMatrix();
    controls.update();
  }
  if (state.light) applyLight(state.light);
}

registerCommand('serialize', () => ({ sceneState: serializeScene() }));

// ---- 渲染输出(透明 PNG,精确像素尺寸) ----
registerCommand('render', ({ width, height }) => {
  const prevPixelRatio = renderer.getPixelRatio();
  helpers.visible = false;
  gizmoHelper.visible = false;
  try {
    renderer.setPixelRatio(1); // 输出精确 width×height,不乘 DPR
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.render(scene, camera);
    const png = renderer.domElement.toDataURL('image/png').split(',')[1];
    return { png };
  } finally {
    helpers.visible = true;
    gizmoHelper.visible = true;
    renderer.setPixelRatio(prevPixelRatio);
    resize(); // 恢复视口尺寸与相机纵横比
  }
});

announceReady(); // 模块初始化完成后宣告(轮询直至 callHandler 注入)

export { ctx, registerCommand, emit, markDirty };
