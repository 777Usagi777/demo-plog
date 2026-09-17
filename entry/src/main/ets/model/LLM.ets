/**
 * 模型接入层：DeepSeek（文本）/ 通义千问 DashScope（视觉）/ 百度智能云（人体关键点+人像分割）
 * 所有请求均带超时与异常兜底，调用方无 Key 或失败时自动回退内置模拟。
 */
import { http } from '@kit.NetworkKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { PhotoItem, SkeletonPose } from './Data';

export interface AIKeys {
  deepseek: string;   // https://platform.deepseek.com
  dashscope: string;  // https://bailian.console.aliyun.com 通义千问
  baiduAk: string;    // https://console.bce.baidu.com
  baiduSk: string;
}

export const VISION_MODEL = 'qwen-vl-plus';
export const TEXT_MODEL = 'deepseek-chat';

const DEEPSEEK_URL = 'https://api.deepseek.com/chat/completions';
const DASHSCOPE_URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
const BAIDU_TOKEN_URL = 'https://aip.baidubce.com/oauth/2.0/token';
const BAIDU_POSE_URL = 'https://aip.baidubce.com/rest/2.0/image-classify/v1/body_keypoint';
const BAIDU_CUTOUT_URL = 'https://aip.baidubce.com/rest/2.0/image-classify/v1/body_seg';

interface ChatMsg {
  role: string;
  content: string;
}

interface MsgChoice {
  message: ChatMsg;
}

interface DeepseekResp {
  choices: Array<MsgChoice>;
}

interface DashResp {
  choices: Array<MsgChoice>;
}

interface TokenResp {
  access_token: string;
}

interface BaiduPart {
  part_name: string;
  x: number;
  y: number;
}

interface BaiduPerson {
  body_parts: Array<BaiduPart>;
}

interface BaiduPoseResp {
  person_info: Array<BaiduPerson>;
}

interface BaiduCutResp {
  foreground: string;
}

interface ImageSize {
  w: number;
  h: number;
}

interface ChatReq {
  model: string;
  messages: Array<ChatMsg>;
  temperature: number;
  max_tokens: number;
}

interface ImageUrlPart {
  url: string;
}

interface ContentPart {
  type: string;
  text?: string;
  image_url?: ImageUrlPart;
}

interface VisionMsg {
  role: string;
  content: Array<ContentPart>;
}

interface VisionReq {
  model: string;
  messages: Array<VisionMsg>;
  temperature: number;
  max_tokens: number;
}

export class AIService {
  private static ctx: Context | null = null;
  private static prefs: preferences.Preferences | null = null;
  private static keys: AIKeys = { deepseek: '', dashscope: '', baiduAk: '', baiduSk: '' };
  private static baiduToken = '';
  private static baiduTokenExpire = 0;
  private static inited = false;

  static async init(ctx: Context): Promise<void> {
    if (AIService.inited) {
      return;
    }
    AIService.inited = true;
    AIService.ctx = ctx;
    try {
      AIService.prefs = await preferences.getPreferences(ctx, 'plog_ai_keys');
      const d = AIService.prefs.getSync('deepseek', '') as string;
      const v = AIService.prefs.getSync('dashscope', '') as string;
      const ak = AIService.prefs.getSync('baiduAk', '') as string;
      const sk = AIService.prefs.getSync('baiduSk', '') as string;
      AIService.keys = { deepseek: d, dashscope: v, baiduAk: ak, baiduSk: sk };
    } catch (e) {
      console.error('AIService init fail', JSON.stringify(e));
    }
  }

  static getKeys(): AIKeys {
    return { deepseek: AIService.keys.deepseek, dashscope: AIService.keys.dashscope,
      baiduAk: AIService.keys.baiduAk, baiduSk: AIService.keys.baiduSk };
  }

  static hasDeepseek(): boolean {
    return AIService.keys.deepseek.trim().length > 0;
  }

  static hasDashscope(): boolean {
    return AIService.keys.dashscope.trim().length > 0;
  }

  static hasBaidu(): boolean {
    return AIService.keys.baiduAk.trim().length > 0 && AIService.keys.baiduSk.trim().length > 0;
  }

  static async saveKeys(k: AIKeys): Promise<boolean> {
    try {
      if (AIService.prefs === null && AIService.ctx !== null) {
        AIService.prefs = await preferences.getPreferences(AIService.ctx, 'plog_ai_keys');
      }
      if (AIService.prefs === null) {
        return false;
      }
      AIService.prefs.putSync('deepseek', k.deepseek.trim());
      AIService.prefs.putSync('dashscope', k.dashscope.trim());
      AIService.prefs.putSync('baiduAk', k.baiduAk.trim());
      AIService.prefs.putSync('baiduSk', k.baiduSk.trim());
      await AIService.prefs.flush();
      AIService.keys = { deepseek: k.deepseek.trim(), dashscope: k.dashscope.trim(),
        baiduAk: k.baiduAk.trim(), baiduSk: k.baiduSk.trim() };
      AIService.baiduToken = '';
      AIService.baiduTokenExpire = 0;
      return true;
    } catch (e) {
      console.error('saveKeys fail', JSON.stringify(e));
      return false;
    }
  }

  // ---------- 图片读取 ----------
  private static b64Helper(): util.Base64Helper {
    return new util.Base64Helper();
  }

  /** 资源名 -> base64（app.media.<name>） */
  static async resBase64(name: string): Promise<string> {
    if (AIService.ctx === null) {
      throw new Error('AIService not init');
    }
    const data = await AIService.ctx.resourceManager.getMediaContent($r('app.media.' + name));
    const buf = new ArrayBuffer(data.length);
    const view = new Uint8Array(buf);
    for (let i = 0; i < data.length; i++) {
      view[i] = data[i];
    }
    return AIService.b64Helper().encodeToStringSync(new Uint8Array(buf));
  }

  /** file:// 或沙箱路径 -> base64 */
  static async fileBase64(path: string): Promise<string> {
    let real = path;
    if (real.startsWith('file://')) {
      real = real.slice(7);
    }
    const file = fs.openSync(real, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(real);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, new Uint8Array(buf));
      return AIService.b64Helper().encodeToStringSync(new Uint8Array(buf));
    } finally {
      fs.closeSync(file);
    }
  }

  /** 自动识别：file:// 走文件，否则按资源名 */
  static base64Of(source: string): Promise<string> {
    if (source.startsWith('file://')) {
      return AIService.fileBase64(source);
    }
    return AIService.resBase64(source);
  }

  /** base64 -> PixelMap（用于真实抠图素材显示） */
  static async b64ToPixelMap(b64: string): Promise<image.PixelMap> {
    const decode = AIService.b64Helper().decodeSync(b64);
    const src = image.createImageSource(decode.buffer as ArrayBuffer);
    const pm = await src.createPixelMap();
    await src.release();
    return pm;
  }

  /** 图片尺寸（file 或资源名） */
  static async imageSizeOf(source: string): Promise<ImageSize> {
    let src: image.ImageSource;
    if (source.startsWith('file://')) {
      src = image.createImageSource(source.slice(7));
    } else {
      if (AIService.ctx === null) {
        throw new Error('AIService not init');
      }
      const data = await AIService.ctx.resourceManager.getMediaContent($r('app.media.' + source));
      const buf = new ArrayBuffer(data.length);
      const view = new Uint8Array(buf);
      for (let i = 0; i < data.length; i++) {
        view[i] = data[i];
      }
      src = image.createImageSource(buf);
    }
    const info = await src.getImageInfo();
    await src.release();
    const size: ImageSize = { w: info.size.width, h: info.size.height };
    return size;
  }

  // ---------- HTTP 基础 ----------
  private static async postJson(url: string, token: string, body: string, timeout: number): Promise<string> {
    const client = http.createHttp();
    try {
      const header: Record<string, string> = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + token
      };
      const resp = await client.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: body,
        connectTimeout: timeout,
        readTimeout: timeout
      });
      if (resp.responseCode !== 200) {
        throw new Error('HTTP ' + resp.responseCode);
      }
      return resp.result as string;
    } finally {
      client.destroy();
    }
  }

  // ---------- DeepSeek 文本 ----------
  static async chat(system: string, user: string): Promise<string> {
    const msgs: Array<ChatMsg> = [
      { role: 'system', content: system },
      { role: 'user', content: user }
    ];
    const req: ChatReq = { model: TEXT_MODEL, messages: msgs, temperature: 0.7, max_tokens: 800 };
    const body = JSON.stringify(req);
    const raw = await AIService.postJson(DEEPSEEK_URL, AIService.keys.deepseek, body, 45000);
    const obj = JSON.parse(raw) as DeepseekResp;
    if (!obj.choices || obj.choices.length === 0) {
      throw new Error('empty choices');
    }
    return obj.choices[0].message.content;
  }

  // ---------- DashScope 视觉 ----------
  static async vision(imageB64: string, prompt: string): Promise<string> {
    const imgUrl: ImageUrlPart = { url: 'data:image/png;base64,' + imageB64 };
    const parts: Array<ContentPart> = [
      { type: 'image_url', image_url: imgUrl },
      { type: 'text', text: prompt }
    ];
    const visionMsgs: Array<VisionMsg> = [
      { role: 'user', content: parts }
    ];
    const req: VisionReq = { model: VISION_MODEL, messages: visionMsgs, temperature: 0.3, max_tokens: 1500 };
    const body = JSON.stringify(req);
    const raw = await AIService.postJson(DASHSCOPE_URL, AIService.keys.dashscope, body, 90000);
    const obj = JSON.parse(raw) as DashResp;
    if (!obj.choices || obj.choices.length === 0) {
      throw new Error('empty choices');
    }
    return obj.choices[0].message.content;
  }

  // ---------- 百度 Token ----------
  private static async fetchBaiduToken(): Promise<string> {
    const now = Date.now() / 1000;
    if (AIService.baiduToken !== '' && now < AIService.baiduTokenExpire - 60) {
      return AIService.baiduToken;
    }
    const url = BAIDU_TOKEN_URL + '?grant_type=client_credentials&client_id=' +
      AIService.keys.baiduAk + '&client_secret=' + AIService.keys.baiduSk;
    const client = http.createHttp();
    try {
      const resp = await client.request(url, {
        method: http.RequestMethod.POST,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (resp.responseCode !== 200) {
        throw new Error('token HTTP ' + resp.responseCode);
      }
      const obj = JSON.parse(resp.result as string) as TokenResp;
      if (!obj.access_token) {
        throw new Error('no token');
      }
      AIService.baiduToken = obj.access_token;
      AIService.baiduTokenExpire = now + 2592000; // 30 天
      return obj.access_token;
    } finally {
      client.destroy();
    }
  }

  private static async postBaiduForm(url: string, imageB64: string): Promise<string> {
    const token = await AIService.fetchBaiduToken();
    const client = http.createHttp();
    try {
      const resp = await client.request(url + '?access_token=' + token, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded' } as Record<string, string>,
        extraData: 'image=' + encodeURIComponent(imageB64),
        connectTimeout: 60000,
        readTimeout: 90000
      });
      if (resp.responseCode !== 200) {
        throw new Error('baidu HTTP ' + resp.responseCode);
      }
      return resp.result as string;
    } finally {
      client.destroy();
    }
  }

  // ---------- 百度人体关键点 ----------
  /**
   * 返回: persons x 14 joints x [x,y]，坐标归一化 0-1（基于 imgW/imgH）。
   * 关节索引同 Data.ets SkeletonPose：0头 1颈 2左肩 3右肩 4左肘 5右肘 6左腕 7右腕 8左髋 9右髋 10左膝 11右膝 12左踝 13右踝
   */
  static async baiduPose(imageB64: string, imgW: number, imgH: number): Promise<Array<Array<Array<number>>>> {
    const raw = await AIService.postBaiduForm(BAIDU_POSE_URL, imageB64);
    const obj = JSON.parse(raw) as BaiduPoseResp;
    const persons: Array<Array<Array<number>>> = [];
    if (!obj.person_info) {
      return persons;
    }
    for (const person of obj.person_info) {
      const pts: Map<string, Array<number>> = new Map<string, Array<number>>();
      for (const part of person.body_parts) {
        pts.set(part.part_name, [part.x / Math.max(1, imgW), part.y / Math.max(1, imgH)]);
      }
      const get = (n: string): Array<number> => {
        const v = pts.get(n);
        return v !== undefined ? v : [0.5, 0.5];
      };
      const ls = get('left_shoulder');
      const rs = get('right_shoulder');
      const neck: Array<number> = [(ls[0] + rs[0]) / 2, (ls[1] + rs[1]) / 2];
      const joints: Array<Array<number>> = [
        get('nose'),                     // 0 头
        neck,                            // 1 颈
        ls,                              // 2 左肩
        rs,                              // 3 右肩
        get('left_elbow'),               // 4 左肘
        get('right_elbow'),              // 5 右肘
        get('left_wrist'),               // 6 左腕
        get('right_wrist'),              // 7 右腕
        get('left_hip'),                 // 8 左髋
        get('right_hip'),                // 9 右髋
        get('left_knee'),                // 10 左膝
        get('right_knee'),               // 11 右膝
        get('left_ankle'),               // 12 左踝
        get('right_ankle')               // 13 右踝
      ];
      persons.push(joints);
    }
    return persons;
  }

  // ---------- 百度人像分割（抠图） ----------
  /** 返回前景透明 PNG 的 base64；失败抛异常 */
  static async baiduCutout(imageB64: string): Promise<string> {
    const raw = await AIService.postBaiduForm(BAIDU_CUTOUT_URL, imageB64);
    const obj = JSON.parse(raw) as BaiduCutResp;
    if (!obj.foreground) {
      throw new Error('no foreground');
    }
    return obj.foreground;
  }

  // ---------- 工具 ----------
  /** 从模型输出中提取 JSON（去 ``` 围栏与前后杂文） */
  static extractJson(text: string): string {
    const t = text.trim();
    const fence = t.indexOf('```');
    if (fence >= 0) {
      const f2 = t.indexOf('```', fence + 3);
      if (f2 >= 0) {
        let inner = t.substring(fence + 3, f2);
        const nl = inner.indexOf('\n');
        if (nl >= 0) {
          inner = inner.substring(nl + 1);
        }
        const s = inner.indexOf('{');
        const e = inner.lastIndexOf('}');
        if (s >= 0 && e > s) {
          return inner.substring(s, e + 1);
        }
        return inner;
      }
    }
    const s = t.indexOf('{');
    const e = t.lastIndexOf('}');
    if (s >= 0 && e > s) {
      return t.substring(s, e + 1);
    }
    return t;
  }

  // ---------- 照片级封装：姿态骨架 ----------
  /** 真机姿态骨架：图片 -> 百度关键点 -> SkeletonPose 列表；失败返回空 */
  static async realSkeletons(p: PhotoItem): Promise<Array<SkeletonPose>> {
    try {
      const src = p.uri.startsWith('file://') ? p.uri : (p.uri.length > 0 ? p.uri : p.name);
      const b64 = await AIService.base64Of(src);
      const size = await AIService.imageSizeOf(src);
      const persons = await AIService.baiduPose(b64, size.w, size.h);
      const colors: string[] = ['#3A7BFF', '#FF6B6B', '#FF9800', '#20C997', '#9C27B0'];
      const out: Array<SkeletonPose> = [];
      for (let i = 0; i < persons.length; i++) {
        out.push(new SkeletonPose(persons[i], colors[i % colors.length]));
      }
      return out;
    } catch (e) {
      console.error('realSkeletons fail', JSON.stringify(e));
      return [];
    }
  }
}
