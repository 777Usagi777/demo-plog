/**
 * Plog助手 - 数据模型定义
 * Demo 版：内置模板与模拟分析结果，真实大模型/视觉模型接口留扩展点。
 */

export class PlogElement {
  id: string;
  type: string; // 'TEXT' | 'STICKER' | 'CAPTION' | 'HASHTAG' | 'PHOTO'
  text: string;
  x: number; // 相对画布百分比 0-100
  y: number;
  scale: number; // 缩放倍率
  color: string;
  fontSize: number;
  sticker: string; // 特效笔/贴纸标识

  constructor(id: string, type: string, text: string, x: number, y: number, scale: number, color: string, fontSize: number, sticker: string) {
    this.id = id;
    this.type = type;
    this.text = text;
    this.x = x;
    this.y = y;
    this.scale = scale;
    this.color = color;
    this.fontSize = fontSize;
    this.sticker = sticker;
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
  category: string; // 人物/景物/文案/未知
  desc: string; // 大模型描述（模拟）

  constructor(uri: string, name: string, isResource: boolean, isWaste: boolean, category: string, desc: string) {
    this.uri = uri;
    this.name = name;
    this.isResource = isResource;
    this.isWaste = isWaste;
    this.category = category;
    this.desc = desc;
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
 * 内置模板库（模拟）：真实场景应由大模型拆解优质 Plog 截图后生成。
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
  const t3 = new Template('t3', '穿搭打卡', '竖版拼贴+氛围文案', 'sample2',
    [
      new PlogElement('a', 'TEXT', 'OOTD', 60, 20, 1, '#1B5E20', 32, ''),
      new PlogElement('b', 'PHOTO', 'sample2', 8, 28, 1, '#000000', 0, ''),
      new PlogElement('c', 'HASHTAG', '#通勤穿搭', 8, 6, 1, '#8BC34A', 16, ''),
    ]);
  return [t1, t2, t3];
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

/**
 * 模拟照片分析结果：废片筛选 + 分类 + 机位建议。
 * 真实实现应接入视觉语言模型（VLM）返回图像描述与构图建议。
 */
export function analyzePhotos(samples: PhotoItem[]): PhotoItem[] {
  const out: PhotoItem[] = [];
  for (let i = 0; i < samples.length; i++) {
    const s = samples[i];
    if (s.name.indexOf('sample4') >= 0) {
      s.isWaste = true;
      s.category = '废片';
      s.desc = '全黑/模糊，亮度极低，建议删除';
    } else if (s.name.indexOf('sample1') >= 0) {
      s.isWaste = false;
      s.category = '景物';
      s.desc = '日落海面，暖色调，适合做封面';
    } else if (s.name.indexOf('sample2') >= 0) {
      s.isWaste = false;
      s.category = '人物';
      s.desc = '草地绿意人物场景，适合穿搭Plog';
    } else if (s.name.indexOf('sample3') >= 0) {
      s.isWaste = false;
      s.category = '文案';
      s.desc = '咖啡杯特写，氛围感强，可配文字';
    } else {
      s.isWaste = false;
      s.category = '未知';
      s.desc = '已加入，等待大模型描述';
    }
    out.push(s);
  }
  return out;
}

export function getCameraTips(): CameraTip[] {
  return [
    new CameraTip('人物', '仰拍', '仰拍显腿长、显气场，适合全身照、站姿Plog。', '🙆'),
    new CameraTip('人物', '俯拍', '俯拍适合坐姿、桌面场景，突出居家的轻松感。', '🙇'),
    new CameraTip('景物', '平拍', '平拍视线与主体齐平，适合食物、咖啡等特写。', '🍰'),
    new CameraTip('景物', '45°斜拍', '45°斜上方拍摄静物最有层次，构图更高级。', '📸'),
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
