/**
 * Plog助手 - 数据模型定义
 * Demo 版：内置模板与模拟分析结果，真实大模型/视觉模型接口留扩展点。
 */

export class PlogElement {
  id: string;
  type: string; // 'TEXT' | 'STICKER' | 'CAPTION' | 'HASHTAG' | 'PHOTO' | 'CUTOUT'
  text: string;
  x: number; // 相对画布百分比 0-100
  y: number;
  scale: number; // 缩放倍率
  color: string;
  fontSize: number;
  sticker: string; // 特效笔/贴纸标识
  owner: string; // 协同锁定：'' 自由 | '我' | 协作者名，锁定后仅 owner 可拖动

  constructor(id: string, type: string, text: string, x: number, y: number, scale: number, color: string,
    fontSize: number, sticker: string, owner: string = '') {
    this.id = id;
    this.type = type;
    this.text = text;
    this.x = x;
    this.y = y;
    this.scale = scale;
    this.color = color;
    this.fontSize = fontSize;
    this.sticker = sticker;
    this.owner = owner;
  }
}

export class Template {
  id: string;
  name: string;
  desc: string;
  cover: string; // 资源名
  elements: PlogElement[];

  constructor(id: string, name: string, desc: string, cover: string, elements: PlogElement[]) {
    this.id = id;
    this.name = name;
    this.desc = desc;
    this.cover = cover;
    this.elements = elements;
  }
}

export class PhotoItem {
  uri: string; // 资源名或 file:// 路径
  name: string;
  isResource: boolean;
  isWaste: boolean; // 是否废片
  category: string; // 人物/景物/文案/生日派对/夜景/自拍/未知
  desc: string; // 大模型描述（模拟）
  hasPerson: boolean; // 是否检测到人物（驱动姿态提取）
  personCount: number; // 检测到的人数（多人姿态）

  constructor(uri: string, name: string, isResource: boolean, isWaste: boolean, category: string, desc: string,
    hasPerson: boolean = false, personCount: number = 0) {
    this.uri = uri;
    this.name = name;
    this.isResource = isResource;
    this.isWaste = isWaste;
    this.category = category;
    this.desc = desc;
    this.hasPerson = hasPerson;
    this.personCount = personCount;
  }
}

export class CameraTip {
  subject: string; // 人物/景物
  angle: string;   // 仰拍/俯拍/平拍
  desc: string;
  icon: string;    // 表情符号

  constructor(subject: string, angle: string, desc: string, icon: string) {
    this.subject = subject;
    this.angle = angle;
    this.desc = desc;
    this.icon = icon;
  }
}

export class CollabUser {
  name: string;
  color: string;
  isMe: boolean;
  action: string;

  constructor(name: string, color: string, isMe: boolean, action: string) {
    this.name = name;
    this.color = color;
    this.isMe = isMe;
    this.action = action;
  }
}

export class VersionRecord {
  version: string;
  time: string;
  author: string;
  note: string;

  constructor(version: string, time: string, author: string, note: string) {
    this.version = version;
    this.time = time;
    this.author = author;
    this.note = note;
  }
}

/**
 * 素材库：长按抠图提取 / 相册导入 的关键元素素材。
 */
export class CropRegion {
  left: number;
  top: number;
  width: number;
  height: number;

  constructor(left: number, top: number, width: number, height: number) {
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
  }
}

export class MaterialItem {
  id: string;
  name: string;
  kind: string; // 'CUTOUT'（抠图）| 'IMAGE'（导入图）| 'STICKER'（图形贴纸）| 'TEXT'
  source: string; // file:// 路径 / 资源名 / 文字
  region: CropRegion | undefined; // 抠图的裁剪区域（原图坐标系）

  constructor(id: string, name: string, kind: string, source: string, region: CropRegion | undefined = undefined) {
    this.id = id;
    this.name = name;
    this.kind = kind;
    this.source = source;
    this.region = region;
  }
}

/**
 * 姿态骨架：火柴人式（13 关键点 + 骨骼连线），坐标已归一化 0-1。
 */
export class SkeletonPose {
  joints: Array<Array<number>>; // [x,y]，索引：0头 1颈 2左肩 3右肩 4左肘 5右肘 6左腕 7右腕 8左髋 9右髋 10左膝 11右膝 12左踝 13右踝
  color: string;

  constructor(joints: Array<Array<number>>, color: string) {
    this.joints = joints;
    this.color = color;
  }
}

/** 骨骼连线定义（关节索引对） */
const BONES: Array<Array<number>> = [
  [0, 1], [1, 2], [1, 3], [2, 4], [4, 6], [3, 5], [5, 7],
  [1, 8], [1, 9], [8, 9], [8, 10], [10, 12], [9, 11], [11, 13]
];

export function getBones(): Array<Array<number>> {
  return BONES;
}

/** 涂鸦笔画：点为归一化坐标 0-1 */
export class Stroke {
  id: string;
  color: string;
  width: number;
  owner: string;
  points: Array<Array<number>>;

  constructor(id: string, color: string, width: number, owner: string, points: Array<Array<number>>) {
    this.id = id;
    this.color = color;
    this.width = width;
    this.owner = owner;
    this.points = points;
  }
}

/** 音频（BGM/MP3）：本地导入或内置演示 */
export class AudioItem {
  name: string;
  path: string; // '' 表示内置演示（无真实文件）
  isPreset: boolean;
  icon: string;

  constructor(name: string, path: string, isPreset: boolean, icon: string) {
    this.name = name;
    this.path = path;
    this.isPreset = isPreset;
    this.icon = icon;
  }
}

/** 拍摄建议：给摄影师/被拍摄者的文字建议 */
export class PhotoAdvice {
  angle: string;
  subjectText: string; // 给被拍摄者（姿态参考）的建议
  photoText: string;   // 给摄影师（机位/构图）的建议
  hasPerson: boolean;

  constructor(angle: string, subjectText: string, photoText: string, hasPerson: boolean) {
    this.angle = angle;
    this.subjectText = subjectText;
    this.photoText = photoText;
    this.hasPerson = hasPerson;
  }
}

/**
 * 内置模板库（模拟）：真实场景应由大模型拆解优质 Plog 截图后生成。
 * cover 支持 sample1-4 与导入的 demo1-11 示例图。
 */
export function getTemplates(): Template[] {
  const t1 = new Template('t1', '旅行日记', '横版标题+照片墙+地点标签', 'sample1',
    [
      new PlogElement('a', 'TEXT', 'Weekend Trip', 8, 10, 1, '#FFFFFF', 30, ''),
      new PlogElement('b', 'PHOTO', 'sample1', 8, 30, 1, '#000000', 0, ''),
      new PlogElement('c', 'HASHTAG', '#日落 #海边', 8, 86, 1, '#FFD54A', 16, ''),
    ]);
  const t2 = new Template('t2', '咖啡日常', '居中大字+贴纸点缀', 'sample3',
    [
      new PlogElement('a', 'TEXT', 'coffee time', 20, 12, 1, '#4E342E', 26, ''),
      new PlogElement('b', 'STICKER', '✦', 86, 8, 1, '#FF7043', 0, 'sparkle'),
      new PlogElement('c', 'CAPTION', '今天的燕麦拿铁刚刚好', 12, 42, 1, '#5D4037', 18, ''),
    ]);
  const t3 = new Template('t3', '穿搭打卡', '竖版拼贴+氛围文案', 'demo3',
    [
      new PlogElement('a', 'TEXT', 'OOTD', 60, 20, 1, '#1B5E20', 32, ''),
      new PlogElement('b', 'PHOTO', 'demo3', 8, 28, 1, '#000000', 0, ''),
      new PlogElement('c', 'HASHTAG', '#通勤穿搭', 8, 6, 1, '#8BC34A', 16, ''),
    ]);
  const t4 = new Template('t4', '生日派对', '人物抠图+气氛贴纸+祝福语', 'demo4',
    [
      new PlogElement('a', 'TEXT', 'Happy Birthday', 12, 8, 1, '#E91E63', 28, ''),
      new PlogElement('b', 'PHOTO', 'demo4', 26, 24, 1, '#000000', 0, ''),
      new PlogElement('c', 'STICKER', '🎂', 82, 28, 1, '#FF9800', 0, 'cake'),
      new PlogElement('d', 'STICKER', '🎈', 12, 52, 1, '#3F51B5', 0, 'balloon'),
      new PlogElement('e', 'HASHTAG', '#生日趴 #20岁', 8, 88, 1, '#E91E63', 16, ''),
    ]);
  const t5 = new Template('t5', '纪念碑打卡', '景点抠图+大标题+地标标签', 'demo2',
    [
      new PlogElement('a', 'TEXT', '纪念碑', 22, 10, 1, '#FFFFFF', 30, ''),
      new PlogElement('b', 'PHOTO', 'demo2', 20, 26, 1, '#000000', 0, ''),
      new PlogElement('c', 'HASHTAG', '#城市地标 #打卡', 8, 88, 1, '#FFD54A', 16, ''),
    ]);
  const t6 = new Template('t6', '家居沙发', '沙发抠图元素+舒适文案', 'demo6',
    [
      new PlogElement('a', 'TEXT', 'cozy home', 14, 10, 1, '#4E342E', 26, ''),
      new PlogElement('b', 'PHOTO', 'demo6', 24, 26, 1, '#000000', 0, ''),
      new PlogElement('c', 'CAPTION', '窝在沙发里的一下午', 12, 58, 1, '#5D4037', 18, ''),
    ]);
  return [t1, t2, t3, t4, t5, t6];
}

/**
 * 模拟 AI 拆解：从模板库随机取一个模板并微调位置，模拟"大模型拆解优质Plog"。
 * 真实实现应接入视觉大模型 API，从截图中抽取元素与排版。
 */
export function aiAnalyzeTemplate(): Template {
  const list = getTemplates();
  const idx = Math.floor(Math.random() * list.length);
  return list[idx];
}

/** 分类标签集 */
export function getCategories(): string[] {
  return ['全部', '人物', '景物', '生日派对', '文案', '夜景', '自拍'];
}

/**
 * 模拟照片分析：废片筛选 + 分类 + 人物检测（驱动姿态提取）。
 * 真实实现应接入视觉语言模型（VLM）返回图像描述、构图与姿态关键点。
 */
export function analyzePhotos(samples: PhotoItem[]): PhotoItem[] {
  const out: PhotoItem[] = [];
  for (let i = 0; i < samples.length; i++) {
    const s = samples[i];
    analyzeOne(s);
    out.push(s);
  }
  return out;
}

function analyzeOne(s: PhotoItem): void {
  const n = s.name;
  if (n.indexOf('sample4') >= 0) {
    s.isWaste = true;
    s.category = '废片';
    s.desc = '全黑/模糊，亮度极低，建议删除';
    s.hasPerson = false;
    s.personCount = 0;
  } else if (n.indexOf('sample1') >= 0) {
    s.isWaste = false; s.category = '景物'; s.desc = '日落海面，暖色调，适合做封面';
    s.hasPerson = false; s.personCount = 0;
  } else if (n.indexOf('sample2') >= 0) {
    s.isWaste = false; s.category = '人物'; s.desc = '草地人物场景，适合穿搭Plog';
    s.hasPerson = true; s.personCount = 1;
  } else if (n.indexOf('sample3') >= 0) {
    s.isWaste = false; s.category = '文案'; s.desc = '咖啡杯特写，氛围感强，可配文字';
    s.hasPerson = false; s.personCount = 0;
  } else if (n.indexOf('demo') >= 0) {
    // 示例图：按编号轮换分类（真机接入 VLM 后输出真实结果）
    const idx = parseInt(n.replace('demo', ''), 10);
    const catTable: string[] = ['人物', '景物', '生日派对', '文案', '夜景', '自拍', '景物', '人物', '生日派对', '文案', '夜景'];
    const cat = catTable[(idx - 1) % catTable.length];
    s.category = cat;
    s.hasPerson = (cat === '人物' || cat === '生日派对' || cat === '自拍');
    // 模拟偶尔的废片（欠曝/抖动），真机由亮度直方图+拉普拉斯方差判定
    s.isWaste = (idx % 9 === 0);
    s.personCount = s.hasPerson ? (idx % 4 === 0 ? 2 : 1) : 0;
    if (s.isWaste) {
      s.desc = '疑似模糊/抖动，已归入废片，可手动移回';
    } else {
      s.desc = '示例素材图，接入 VLM 后自动生成描述';
    }
  } else {
    s.isWaste = false;
    s.category = '未知';
    s.desc = '已加入，等待大模型描述';
    s.hasPerson = false;
    s.personCount = 0;
  }
}

/**
 * 生成姿态骨架（模拟姿态提取模型输出的人体关键点）。
 * 位置全随机（站立/举手等基础姿态），真机替换为姿态估计模型的 2D 关键点。
 */
export function buildSkeletons(seed: number, count: number): Array<SkeletonPose> {
  const colors: string[] = ['#3A7BFF', '#FF6B6B', '#FF9800'];
  const poses: Array<SkeletonPose> = [];
  for (let p = 0; p < count; p++) {
    const cx = 0.25 + (seed % 5) * 0.13 + p * 0.35;
    const cy = 0.18 + (seed % 3) * 0.09;
    const h = 0.55; // 身高（归一化）
    const reach = 0.16 + (seed % 5) * 0.02;
    const jx = (dx: number): number => cx + dx;
    const jy = (dy: number): number => cy + dy;
    const joints: Array<Array<number>> = [
      [jx(0), jy(0)],                  // 0 头
      [jx(0), jy(0.10 * h)],           // 1 颈
      [jx(-0.16 * h), jy(0.14 * h)],   // 2 左肩
      [jx(0.16 * h), jy(0.14 * h)],    // 3 右肩
      [jx(-0.26 * h), jy(0.34 * h)],   // 4 左肘
      [jx(0.26 * h), jy(0.34 * h)],    // 5 右肘
      [jx(-0.30 * h + reach), jy(0.52 * h)], // 6 左腕（微抬）
      [jx(0.30 * h - reach), jy(0.52 * h)],  // 7 右腕
      [jx(-0.10 * h), jy(0.55 * h)],   // 8 左髋
      [jx(0.10 * h), jy(0.55 * h)],    // 9 右髋
      [jx(-0.11 * h), jy(0.78 * h)],   // 10 左膝
      [jx(0.11 * h), jy(0.78 * h)],    // 11 右膝
      [jx(-0.09 * h), jy(1.0 * h)],    // 12 左踝
      [jx(0.09 * h), jy(1.0 * h)],     // 13 右踝
    ];
    poses.push(new SkeletonPose(joints.map((j: Array<number>) => [j[0], j[1]]), colors[p % colors.length]));
  }
  return poses;
}

/**
 * 生成拍摄建议：有人物 → 给被拍摄者姿态参考 + 给摄影师机位建议；
 * 无人物 → 只给摄影师构图/机位建议。
 */
export function buildAdvice(p: PhotoItem): PhotoAdvice {
  if (p.hasPerson) {
    const angles: string[] = ['平拍', '仰拍', '45° 侧拍'];
    const a = angles[p.personCount % angles.length];
    const multi = p.personCount > 1 ? '检测到多人，注意错开站位、两人呈 V 字排布，让肩膀相互靠近。' : '';
    const subject: string = '⛹ 被拍摄者姿态参考：' + (multi.length > 0 ? multi : '') +
      '肩膀放松下沉，重心放前脚，' + (a === '仰拍' ? '下巴微收' : '轻微侧头露出侧脸线') + '，手臂自然摆放不夹紧。';
    const photo: string = '📷 摄影师建议：' + (p.personCount > 1 ? '多人合影用 f/4-f/5.6 保证前后清晰，' : '单人大头/半身用 f/1.8-f/2.8 虚化背景突出主体，') +
      a + '，相机与人物腰部齐平；逆光时对焦人脸并+0.7EV 提亮。';
    return new PhotoAdvice(a, subject, photo, true);
  }
  const angles: string[] = ['平拍', '45° 斜拍', '俯拍'];
  const a = angles[p.personCount % angles.length];
  const subject: string = '';
  const photo: string = '📷 摄影师建议（无人物场景）：' + a + '让水平线对齐画面 1/3 分界线，' +
    '主体置于三分点；找前景（桌角/树叶/栏杆）形成纵深，开广角端增强气势。';
  return new PhotoAdvice(a, subject, photo, false);
}

export function getCameraTips(): CameraTip[] {
  return [
    new CameraTip('人物', '仰拍', '仰拍显腿长、显气场，适合全身照、站姿Plog。', '🙆'),
    new CameraTip('人物', '俯拍', '俯拍适合坐姿、桌面场景，突出居家的轻松感。', '🙇'),
    new CameraTip('景物', '平拍', '平拍视线与主体齐平，适合食物、咖啡等特写。', '🍰'),
    new CameraTip('景物', '45°斜拍', '45°斜上方拍摄静物最有层次，构图更高级。', '📸'),
  ];
}

export function getPresetAudios(): AudioItem[] {
  return [
    new AudioItem('无BGM', '', true, '🔇'),
    new AudioItem('轻音乐', '', true, '🎵'),
    new AudioItem('海边白噪音', '', true, '🌊'),
    new AudioItem('爵士', '', true, '🎷'),
  ];
}

export function getCollabUsers(): CollabUser[] {
  return [
    new CollabUser('我', '#3A7BFF', true, '正在编辑标题'),
    new CollabUser('晓琳', '#FF6B6B', false, '添加了贴纸'),
    new CollabUser('阿哲', '#20C997', false, '正在上传照片'),
  ];
}

export function getVersionRecords(): VersionRecord[] {
  const now = new Date();
  const fmt = (d: Date): string =>
    d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate() + ' ' + d.getHours() + ':' + d.getMinutes();
  return [
    new VersionRecord('v3', fmt(now), '我', '添加滤镜与标题'),
    new VersionRecord('v2', fmt(new Date(now.getTime() - 3600000)), '晓琳', '加入贴纸元素'),
    new VersionRecord('v1', fmt(new Date(now.getTime() - 7200000)), '我', '创建Plog'),
  ];
}
