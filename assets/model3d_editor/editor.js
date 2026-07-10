// assets/model3d_editor/editor.js
// 3D 模型图层编辑器。与 Dart 的协议:
//   Dart→JS  window.naiEditor.dispatch('{"type":..,"requestId":..,...}')
//   JS→Dart  window.flutter_inappwebview.callHandler('naiModel3d', msg)
//     msg: {type:'response', requestId, ok, data} 或事件 {type:'onReady'|'onModelLoaded'|'onLoadError'|'onDirty', ...}
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

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
dirLight.position.set(1.5, 3, 2);
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

registerCommand('setLight', ({ intensity, azimuth, elevation }) => {
  // intensity: 0..3;azimuth/elevation: 度
  ctx.dirLight.intensity = intensity;
  const az = azimuth * Math.PI / 180;
  const el = elevation * Math.PI / 180;
  const r = 4;
  ctx.dirLight.position.set(
    r * Math.cos(el) * Math.sin(az),
    r * Math.sin(el),
    r * Math.cos(el) * Math.cos(az),
  );
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
  renderer.render(scene, camera);
});

announceReady(); // 模块初始化完成后宣告(轮询直至 callHandler 注入)

export { ctx, registerCommand, emit, markDirty };
