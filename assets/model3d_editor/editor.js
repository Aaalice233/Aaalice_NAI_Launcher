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

// ---- 触屏/粗指针适配(iOS 与 Android 的 WebView) ----
// 偏离上游:上游 v4.2.1 的 editor.js 全文没有任何触屏处理(grep isTouch/coarse/
// maxTouchPoints/pointerType 零命中),三处都按鼠标定尺寸:骨骼标记球半径按世界尺寸
// max(bbox*0.008, 0.006)(见 rebuildBoneMarkers)、gizmo 固定 setSize(0.8)、拾取只有
// 一条严格 raycast。在手机上这三处投影出来都只有几 px,属于「看得见点不中」。
// 我们的做法与 Dart 侧 lib/presentation/adaptive/interaction_policy.dart 取同一语义:
// 本会话一旦观察到真实 touch 指针就永久切到大触摸目标,之后即使接鼠标也不回退
// (避免手指/鼠标混用时目标大小来回跳)。精确指针分支的数值与上游逐字相同,桌面观感不变。
let coarsePointer = false;
try {
  coarsePointer = window.matchMedia('(pointer: coarse)').matches;
} catch (_) {
  coarsePointer = false; // 老 WebView 无 matchMedia:按精确指针起步,首个 touch 事件会纠正
}
/** 触屏下骨骼标记球的放大倍数(只放大观感,真正的拾取靠屏幕空间容差) */
const MARKER_TOUCH_SCALE = 1.8;
/** 触屏拾取容差(CSS px 半径);44px 直径对齐 iOS HIG 与 Material 的最小触摸目标 */
const MARKER_TOUCH_PICK_RADIUS = 22;
/** gizmo 尺寸:上游固定 0.8;触屏下放大到手指能捏住 */
const GIZMO_SIZE_POINTER = 0.8;
const GIZMO_SIZE_TOUCH = 1.2;

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
// 触屏:OrbitControls 的默认 touches 就是 { ONE: ROTATE, TWO: DOLLY_PAN },
// 且 screenSpacePanning 默认 true,所以单指旋转 / 双指捏合缩放 / 双指拖动平移(含上下)
// 开箱即有,不需要我们再挂一套手势——再挂一套只会和它抢同一批 pointer 事件。
// 下方 WASDQE 的键盘飞行在触屏上没有等价物,但双指平移已覆盖它的全部自由度。
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
// 偏离上游:上游恒为 0.8,触屏下 gizmo 的拾取几何太细。见文件头 GIZMO_SIZE_* 注释。
transformControls.setSize(coarsePointer ? GIZMO_SIZE_TOUCH : GIZMO_SIZE_POINTER);
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

// 把当前指针形态应用到已存在的对象上(gizmo 尺寸 + 标记球缩放)。
// 上游没有这个概念:上游只在构造时写死一套鼠标尺寸。
function applyPointerMode() {
  transformControls.setSize(coarsePointer ? GIZMO_SIZE_TOUCH : GIZMO_SIZE_POINTER);
  const scale = coarsePointer ? MARKER_TOUCH_SCALE : 1;
  for (const marker of boneMarkers.children) marker.scale.setScalar(scale);
}

// 观察到真实手指触摸后切到大触摸目标(粘性,不回退)。
// 只认 'touch':iOS WKWebView 下 flutter_inappwebview 注入/合成的鼠标事件 pointerType
// 是 'mouse',真实手指才是 'touch';触控笔 'pen' 是精确指针,不应被放大。
function notePointerType(event) {
  if (coarsePointer || event.pointerType !== 'touch') return;
  coarsePointer = true;
  applyPointerMode();
}

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
    // 偏离上游:上游标记球恒为 1 倍。触屏下放大观感,让手指知道该往哪按。
    marker.scale.setScalar(coarsePointer ? MARKER_TOUCH_SCALE : 1);
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
const _projected = new THREE.Vector3();

// 骨骼拾取:先走上游的严格 raycast;未命中且当前是粗指针时,退到屏幕空间最近邻。
//
// 偏离上游:上游只有 raycast 一条路径。标记球半径是世界尺寸 max(bbox*0.008, 0.006),
// 人形模型在手机竖屏上投影出来直径只有几 px,手指几乎不可能命中。容差用 CSS px 表达,
// 因此与相机远近、DPR、标记球半径都解耦。容差分支只在 coarsePointer 为真时进入,
// 桌面鼠标的行为与上游完全一致(点空就是点空,不会「吸」到附近骨骼)。
function pickMarker(event) {
  const rect = canvas.getBoundingClientRect();
  if (rect.width === 0 || rect.height === 0) return null;
  const x = event.clientX - rect.left;
  const y = event.clientY - rect.top;
  raycaster.setFromCamera(
    new THREE.Vector2((x / rect.width) * 2 - 1, -(y / rect.height) * 2 + 1),
    camera,
  );
  const hits = raycaster.intersectObjects(boneMarkers.children, false);
  if (hits.length) return hits[0].object;
  if (!coarsePointer) return null;

  const candidates = [];
  for (const marker of boneMarkers.children) {
    _projected.copy(marker.position).project(camera);
    if (_projected.z < -1 || _projected.z > 1) continue; // 相机背面或裁剪面之外
    const dx = ((_projected.x + 1) / 2) * rect.width - x;
    const dy = ((1 - _projected.y) / 2) * rect.height - y;
    const distance = Math.hypot(dx, dy);
    if (distance > MARKER_TOUCH_PICK_RADIUS) continue;
    candidates.push({ marker, distance, depth: _projected.z });
  }
  if (!candidates.length) return null;
  // 先按屏幕距离(2px 一档,档内视为并列),并列时取离相机更近的那颗——
  // 骨骼在屏幕上重叠时,这与「点到的是看得见的那个」一致。
  candidates.sort(
    (a, b) =>
      Math.round(a.distance / 2) - Math.round(b.distance / 2) ||
      a.depth - b.depth,
  );
  return candidates[0].marker;
}

canvas.addEventListener('pointerdown', (event) => {
  notePointerType(event);
  if (mode !== 'pose' || transformControls.dragging) return;
  const marker = pickMarker(event);
  if (!marker) return;
  controls.enabled = false; // 选骨点击不应带动相机
  // 偏离上游:上游只挂 pointerup。iOS WKWebView 在系统手势接管(边缘返回手势、
  // 多指进出)时只派发 pointercancel 而不派发 pointerup,少这一路会把 controls
  // 永久留在 disabled —— 表现为相机彻底不动,只能退出重进编辑器。
  const releaseControls = () => {
    window.removeEventListener('pointerup', releaseControls);
    window.removeEventListener('pointercancel', releaseControls);
    if (!transformControls.dragging) controls.enabled = true;
  };
  window.addEventListener('pointerup', releaseControls);
  window.addEventListener('pointercancel', releaseControls);
  selectBone(marker);
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
