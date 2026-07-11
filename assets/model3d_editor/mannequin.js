// assets/model3d_editor/mannequin.js
// 程序化生成的可摆姿势素体人偶(builtin:mannequin)。
// 零外部资产:标准 humanoid 19 骨 + box 蒙皮,T-pose 建模,单位米。
import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

// [name, parentName, head(T-pose 世界坐标), boxSize, box中心相对 head 的偏移]
const BONE_DEFS = [
  ['Hips',       null,         [0, 0.95, 0],     [0.28, 0.18, 0.15], [0, 0.02, 0]],
  ['Spine',      'Hips',       [0, 1.06, 0],     [0.24, 0.12, 0.13], [0, 0.06, 0]],
  ['Chest',      'Spine',      [0, 1.18, 0],     [0.30, 0.22, 0.15], [0, 0.11, 0]],
  ['Neck',       'Chest',      [0, 1.42, 0],     [0.09, 0.09, 0.09], [0, 0.04, 0]],
  ['Head',       'Neck',       [0, 1.50, 0],     [0.19, 0.23, 0.21], [0, 0.11, 0]],
  ['L_Shoulder', 'Chest',      [0.10, 1.40, 0],  [0.10, 0.09, 0.11], [0.04, 0, 0]],
  ['L_UpperArm', 'L_Shoulder', [0.19, 1.40, 0],  [0.27, 0.09, 0.09], [0.13, 0, 0]],
  ['L_LowerArm', 'L_UpperArm', [0.45, 1.40, 0],  [0.25, 0.08, 0.08], [0.12, 0, 0]],
  ['L_Hand',     'L_LowerArm', [0.69, 1.40, 0],  [0.16, 0.04, 0.09], [0.08, 0, 0]],
  ['R_Shoulder', 'Chest',      [-0.10, 1.40, 0], [0.10, 0.09, 0.11], [-0.04, 0, 0]],
  ['R_UpperArm', 'R_Shoulder', [-0.19, 1.40, 0], [0.27, 0.09, 0.09], [-0.13, 0, 0]],
  ['R_LowerArm', 'R_UpperArm', [-0.45, 1.40, 0], [0.25, 0.08, 0.08], [-0.12, 0, 0]],
  ['R_Hand',     'R_LowerArm', [-0.69, 1.40, 0], [0.16, 0.04, 0.09], [-0.08, 0, 0]],
  ['L_UpperLeg', 'Hips',       [0.09, 0.90, 0],  [0.12, 0.42, 0.13], [0, -0.21, 0]],
  ['L_LowerLeg', 'L_UpperLeg', [0.09, 0.48, 0],  [0.10, 0.42, 0.11], [0, -0.21, 0]],
  ['L_Foot',     'L_LowerLeg', [0.09, 0.06, 0.02], [0.10, 0.07, 0.24], [0, -0.02, 0.06]],
  ['R_UpperLeg', 'Hips',       [-0.09, 0.90, 0], [0.12, 0.42, 0.13], [0, -0.21, 0]],
  ['R_LowerLeg', 'R_UpperLeg', [-0.09, 0.48, 0], [0.10, 0.42, 0.11], [0, -0.21, 0]],
  ['R_Foot',     'R_LowerLeg', [-0.09, 0.06, 0.02], [0.10, 0.07, 0.24], [0, -0.02, 0.06]],
];

export function buildMannequin() {
  const bones = [];
  const byName = new Map();

  for (const [name, parent, head] of BONE_DEFS) {
    const bone = new THREE.Bone();
    bone.name = name;
    const parentHead = parent ? byName.get(parent).userData.head : [0, 0, 0];
    bone.position.set(
      head[0] - parentHead[0],
      head[1] - parentHead[1],
      head[2] - parentHead[2],
    );
    bone.userData.head = head;
    if (parent) byName.get(parent).add(bone);
    bones.push(bone);
    byName.set(name, bone);
  }

  const geometries = BONE_DEFS.map(([, , head, size, center], boneIndex) => {
    const geometry = new THREE.BoxGeometry(size[0], size[1], size[2]);
    geometry.translate(
      head[0] + center[0],
      head[1] + center[1],
      head[2] + center[2],
    );
    const count = geometry.attributes.position.count;
    const skinIndex = new Uint16Array(count * 4);
    const skinWeight = new Float32Array(count * 4);
    for (let i = 0; i < count; i++) {
      skinIndex[i * 4] = boneIndex;   // 每个 box 100% 绑定到自己的骨骼
      skinWeight[i * 4] = 1;
    }
    geometry.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(skinIndex, 4));
    geometry.setAttribute('skinWeight', new THREE.Float32BufferAttribute(skinWeight, 4));
    return geometry;
  });

  const merged = mergeGeometries(geometries);
  const material = new THREE.MeshStandardMaterial({
    color: 0xb8bcc4,
    roughness: 0.7,
    metalness: 0.05,
  });
  const mesh = new THREE.SkinnedMesh(merged, material);
  mesh.add(bones[0]);
  mesh.updateMatrixWorld(true);           // bind 前必须刷新骨骼世界矩阵
  mesh.bind(new THREE.Skeleton(bones));

  const root = new THREE.Group();
  root.name = 'MannequinRoot';
  root.add(mesh);
  return root;
}
