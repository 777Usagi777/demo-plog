import { router } from '@kit.ArkUI';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';
import {
  getTemplates, Template, PlogElement, CollabUser, VersionRecord, MaterialItem, CropRegion,
  Stroke, AudioItem, getCollabUsers, getVersionRecords, aiAnalyzeTemplate, getPresetAudios
} from '../model/Data';
import { AIService } from '../model/LLM';

interface AiTplElement {
  type: string;
  text: string;
  x: number;
  y: number;
  scale: number;
  color: string;
  fontSize: number;
}

interface AiTplResp {
  name: string;
  desc: string;
  elements: Array<AiTplElement>;
}

@Entry
@Component
struct Editor {
  @State elements: PlogElement[] = [];
  @State bgImage: string = 'sample1';
  @State templates: Template[] = getTemplates();
  @State users: CollabUser[] = getCollabUsers();
  @State versions: VersionRecord[] = getVersionRecords();
  @State showCollab: boolean = false;
  @State collabMode: boolean = false; // 协同会话中：元素锁定生效
  @State selectedId: string = '';
  @State canvasW: number = 320;
  @State canvasH: number = 480;
  @State bgm: string = '无BGM';
  @State tags: string[] = [];
  @State voiceNote: string = '';
  @State savedAt: string = '';
  @State editText: string = '';
  @State showEditDialog: boolean = false;
  @State showVersionDlg: boolean = false;
  @State showBgmSheet: boolean = false;
  @State showCutSheet: boolean = false;
  @State showInviteDlg: boolean = false;
  @State cutTargetId: string = '';
  @State cutInfo: string = '';
  @State materials: MaterialItem[] = [];
  @State paintMode: boolean = false;
  @State penColor: string = '#FF6B6B';
  @State strokes: Stroke[] = [];
  @State audioList: AudioItem[] = getPresetAudios();
  @State playing: boolean = false;
  @State playStatus: string = '';
  @State inviteInfo: string = '';
  private pinchBase: Map<string, number> = new Map<string, number>();
  private pixelMaps: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();
  private curStroke: Array<Array<number>> = [];
  private curDrawId: string = '';
  private player: media.AVPlayer | undefined = undefined;
  private audioIdx: number = 0;
  private paintCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private mine: string = '我';

  aboutToAppear(): void {
    AIService.init(getContext(this)).catch((e: Error) => {
      console.error('AI init fail', JSON.stringify(e));
    });
    const p = router.getParams() as Record<string, string>;
    let tid = '';
    let photos = '';
    let ai = '';
    if (p) {
      tid = p['tid'] ?? '';
      photos = p['photos'] ?? '';
      ai = p['ai'] ?? '';
    }
    if (ai === '1') {
      this.runAiAnalyze();
    } else if (tid !== '') {
      const t = this.templates.find((item: Template) => item.id === tid);
      if (t) {
        this.bgImage = t.cover;
        this.elements = t.elements.slice();
      } else {
        this.loadSample();
      }
    } else if (photos !== '') {
      const list = photos.split(',');
      // 多图导入：第一张为背景，其余作为可拖拽元素铺在画布上
      this.bgImage = list[0];
      const els: PlogElement[] = [];
      const n = Math.min(list.length, 9);
      for (let i = 0; i < n; i++) {
        els.push(new PlogElement('p' + i, 'PHOTO', list[i],
          6 + (i % 3) * 26, 22 + (i % 3) * 22, 1, '#000000', 0, ''));
      }
      els.push(new PlogElement('t', 'TEXT', '记录今日份美好', 8, 8, 1, '#FFFFFF', 24, ''));
      els.push(new PlogElement('h', 'HASHTAG', '#今日Plog', 8, 90, 1, '#FFD54A', 16, ''));
      this.elements = els;
    } else {
      this.loadSample();
    }
    // 内置演示素材（示例图可作素材导入演示）
    this.materials = [
      new MaterialItem('m0', '咖啡杯', 'IMAGE', 'demo4', undefined),
      new MaterialItem('m1', '纪念碑', 'IMAGE', 'demo2', undefined),
      new MaterialItem('m2', '沙发', 'IMAGE', 'demo6', undefined),
      new MaterialItem('m3', '气球', 'STICKER', '🎈', undefined),
      new MaterialItem('m4', '蛋糕', 'STICKER', '🎂', undefined),
    ];
  }

  aboutToDisappear(): void {
    this.stopAudio();
  }

  // ---- AI 模板拆解：优先视觉大模型，无 Key/失败回退模拟 ----
  async runAiAnalyze(): Promise<void> {
    if (AIService.hasDashscope()) {
      try {
        const demoImgs: string[] = ['demo1', 'demo2', 'demo3', 'demo4', 'demo5', 'demo6'];
        const pick = demoImgs[Math.floor(Math.random() * demoImgs.length)];
        const b64 = await AIService.resBase64(pick);
        const prompt = '你是一个Plog排版设计师。分析这张图片的版式，提取其中的标题文字、副标题、标签、贴纸装饰、说明文案及其位置与颜色。' +
          '只返回JSON：{"name":"模板名","desc":"一句话描述","elements":[{"type":"TEXT|STICKER|HASHTAG|CAPTION",' +
          '"text":"具体内容","x":0到100,"y":0到100,"scale":1,"color":"#RRGGBB","fontSize":16-40}]}。' +
          '不要把照片当元素。只输出JSON，不要其他文字。';
        const content = await AIService.vision(b64, prompt);
        const obj = JSON.parse(AIService.extractJson(content)) as AiTplResp;
        const els: PlogElement[] = [];
        for (const e of obj.elements) {
          const t = e.text.trim();
          if (t.length === 0) {
            continue;
          }
          els.push(new PlogElement('ai' + els.length, e.type, t,
            Math.min(96, Math.max(2, e.x)), Math.min(94, Math.max(2, e.y)),
            Math.max(0.6, Math.min(2, e.scale)), e.color, e.fontSize, ''));
        }
        if (els.length === 0) {
          throw new Error('empty elements');
        }
        this.bgImage = pick;
        this.elements = els;
        this.savedAt = '🤖 已用通义千问拆解模板：' + (obj.name || '');
        return;
      } catch (e) {
        console.error('ai analyze real fail', JSON.stringify(e));
      }
    }
    const t = aiAnalyzeTemplate();
    this.bgImage = t.cover;
    this.elements = t.elements.slice();
    this.savedAt = '模板拆解（模拟）：' + t.name;
  }

  loadSample(): void {
    this.bgImage = 'sample1';
    this.elements = [
      new PlogElement('bg', 'PHOTO', 'sample1', 8, 26, 1, '#000000', 0, ''),
      new PlogElement('t1', 'TEXT', 'Weekend Trip', 8, 8, 1, '#FFFFFF', 30, ''),
      new PlogElement('s1', 'STICKER', '✦', 84, 6, 1, '#FFD54A', 0, 'sparkle'),
      new PlogElement('c1', 'CAPTION', '海风、日落、还有你', 8, 60, 1, '#FFFFFF', 18, ''),
      new PlogElement('h1', 'HASHTAG', '#日落 #海边', 8, 88, 1, '#FFD54A', 16, ''),
    ];
  }

  uriOrRes(p: string): Resource | string {
    if (p.startsWith('file://') || p.startsWith('content://')) {
      return p;
    }
    if (p === 'sample2') {
      return $r('app.media.sample2');
    }
    if (p === 'sample3') {
      return $r('app.media.sample3');
    }
    if (p === 'sample4') {
      return $r('app.media.sample4');
    }
    if (p.indexOf('demo') === 0) {
      return $r('app.media.' + p);
    }
    return $r('app.media.sample1');
  }

  ownerColor(name: string): string {
    if (name === '我') {
      return '#3A7BFF';
    }
    if (name === '晓琳') {
      return '#FF6B6B';
    }
    if (name === '阿哲') {
      return '#20C997';
    }
    return '#8A8A8A';
  }

  // ---- 元素渲染源：支持抠图 PixelMap ----
  elSrc(el: PlogElement): Resource | string {
    if (el.text.startsWith('px:')) {
      const pm = this.pixelMaps.get(el.text.slice(3));
      if (pm !== undefined) {
        return el.text; // 占位，实际走 pmSrc 分支
      }
    }
    return this.uriOrRes(el.text);
  }

  pmSrc(el: PlogElement): image.PixelMap | undefined {
    if (el.text.startsWith('px:')) {
      return this.pixelMaps.get(el.text.slice(3));
    }
    return undefined;
  }

  // ---- 协同：元素是否可被"我"拖动 ----
  canMove(el: PlogElement): boolean {
    if (!this.collabMode) {
      return true;
    }
    return el.owner === '' || el.owner === this.mine;
  }

  select(el: PlogElement): void {
    this.selectedId = el.id;
  }

  onPan(el: PlogElement, ev: PanGestureEvent): void {
    if (!this.canMove(el)) {
      return;
    }
    const idx = this.elements.findIndex((e: PlogElement) => e.id === el.id);
    if (idx < 0 || this.canvasW <= 0 || this.canvasH <= 0) {
      return;
    }
    const nx = el.x + ev.offsetX / this.canvasW * 100;
    const ny = el.y + ev.offsetY / this.canvasH * 100;
    const copy = new PlogElement(el.id, el.type, el.text,
      Math.max(-8, Math.min(108, nx)), Math.max(-8, Math.min(108, ny)),
      el.scale, el.color, el.fontSize, el.sticker, el.owner);
    const arr = this.elements.slice();
    arr[idx] = copy;
    this.elements = arr;
  }

  onPinch(el: PlogElement, ev: GestureEvent): void {
    const idx = this.elements.findIndex((e: PlogElement) => e.id === el.id);
    if (idx < 0) {
      return;
    }
    const base = this.pinchBase.get(el.id) ?? 1;
    const s = Math.max(0.3, Math.min(4, base * ev.scale));
    const copy = new PlogElement(el.id, el.type, el.text, el.x, el.y, s, el.color, el.fontSize, el.sticker, el.owner);
    const arr = this.elements.slice();
    arr[idx] = copy;
    this.elements = arr;
  }

  selectedEl(): PlogElement | undefined {
    return this.elements.find((e: PlogElement) => e.id === this.selectedId);
  }

  scaleSelected(delta: number): void {
    const sel = this.selectedEl();
    if (!sel) {
      return;
    }
    const s = Math.max(0.3, Math.min(4, sel.scale + delta));
    const idx = this.elements.findIndex((e: PlogElement) => e.id === sel.id);
    if (idx < 0) {
      return;
    }
    const copy = new PlogElement(sel.id, sel.type, sel.text, sel.x, sel.y, s, sel.color, sel.fontSize, sel.sticker, sel.owner);
    const arr = this.elements.slice();
    arr[idx] = copy;
    this.elements = arr;
  }

  deleteSelected(): void {
    if (this.selectedId === '') {
      return;
    }
    this.elements = this.elements.filter((e: PlogElement) => e.id !== this.selectedId);
    this.selectedId = '';
  }

  addText(): void {
    const id = 'txt' + this.elements.length;
    const el = new PlogElement(id, 'TEXT', '双击我改文字', 30, 30, 1, '#FFFFFF', 22, '');
    this.elements = this.elements.concat([el]);
    this.selectedId = id;
  }

  // ---- 长按抠图提取 ----
  onLongPressCut(el: PlogElement): void {
    this.cutTargetId = el.id;
    let info = '将把「' + (el.type === 'PHOTO' || el.type === 'CUTOUT' ? '图片' : el.text) +
      '」抠图提取到下方素材库';
    if (el.type !== 'PHOTO' && el.type !== 'CUTOUT') {
      info += '（图形/文字将生成贴纸素材）';
    }
    this.cutInfo = info;
    this.showCutSheet = true;
  }

  async confirmCut(): Promise<void> {
    const el = this.selectedEl();
    if (!el) {
      this.showCutSheet = false;
      return;
    }
    const mid = 'cut' + this.materials.length + '_' + new Date().getTime();
    let aiCutted = false;
    if (el.type === 'PHOTO' || el.type === 'CUTOUT') {
      aiCutted = await this.tryAICutout(mid, el);
      if (!aiCutted) {
        if (el.text.startsWith('file://') && this.canvasW > 0 && this.canvasH > 0) {
          // 真抠图：按元素所在区域裁剪原图（无 Key 时的模拟抠图）
          const ok = await this.cropToMaterial(mid, el);
          if (ok) {
            this.materials = this.materials.concat([new MaterialItem(mid, '抠图素材', 'CUTOUT', 'px:' + mid,
              this.lastRegion)]);
          } else {
            this.materials = this.materials.concat([new MaterialItem(mid, '抠图素材', 'IMAGE', el.text, undefined)]);
          }
        } else {
          this.materials = this.materials.concat([new MaterialItem(mid, '图片素材', 'IMAGE', el.text, undefined)]);
        }
      }
    } else if (el.type === 'STICKER') {
      this.materials = this.materials.concat([new MaterialItem(mid, '贴纸', 'STICKER', el.text, undefined)]);
    } else {
      this.materials = this.materials.concat([new MaterialItem(mid, '文字素材', 'TEXT', el.text, undefined)]);
    }
    this.showCutSheet = false;
    if (!aiCutted) {
      this.savedAt = '已提取素材到素材库，点击素材可拖到画布上编辑';
    }
  }

  /** 百度人像分割真抠图：成功返回 true 且已加入素材库 */
  async tryAICutout(mid: string, el: PlogElement): Promise<boolean> {
    if (!AIService.hasBaidu() || el.text.startsWith('px:')) {
      return false;
    }
    try {
      const b64 = await AIService.base64Of(el.text);
      const fg = await AIService.baiduCutout(b64);
      const pm = await AIService.b64ToPixelMap(fg);
      this.pixelMaps.set(mid, pm);
      this.materials = this.materials.concat([new MaterialItem(mid, 'AI人像分割抠图', 'CUTOUT', 'px:' + mid, undefined)]);
      this.savedAt = '🤖 已用百度人像分割抠出主体到素材库';
      return true;
    } catch (e) {
      console.error('ai cutout fail', JSON.stringify(e));
      return false;
    }
  }

  private lastRegion: CropRegion | undefined = undefined;

  async cropToMaterial(mid: string, el: PlogElement): Promise<boolean> {
    try {
      const path = el.text;
      const src = image.createImageSource(path);
      const info = await src.getImageInfo();
      const full = await src.createPixelMap();
      const sw = info.size.width;
      const sh = info.size.height;
      const kw = sw / this.canvasW;
      const kh = sh / this.canvasH;
      const cw = 150 * el.scale * kw;
      const ch = 170 * el.scale * kh;
      const cx = el.x / 100 * sw;
      const cy = el.y / 100 * sh;
      const left = Math.max(0, Math.floor(cx - cw / 2));
      const top = Math.max(0, Math.floor(cy - ch / 2));
      const width = Math.min(sw - left, Math.floor(cw));
      const height = Math.min(sh - top, Math.floor(ch));
      if (width <= 4 || height <= 4) {
        src.release();
        full.release();
        return false;
      }
      const region: image.Region = { x: left, y: top, size: { width: width, height: height } };
      const cropped = await full.createCroppedAndScaledPixelMap(region, width, height);
      this.pixelMaps.set(mid, cropped);
      this.lastRegion = new CropRegion(left, top, width, height);
      src.release();
      full.release();
      return true;
    } catch (e) {
      console.error('crop fail', JSON.stringify(e));
      return false;
    }
  }

  // ---- 素材库 ----
  async onImportMaterial(): Promise<void> {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const opt = new picker.PhotoSelectOptions();
      opt.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      opt.maxSelectNumber = 9;
      const res = await photoPicker.select(opt);
      const add: MaterialItem[] = [];
      for (let i = 0; i < res.photoUris.length; i++) {
        add.push(new MaterialItem('imp' + this.materials.length + '_' + i,
          '导入素材' + (i + 1), 'IMAGE', res.photoUris[i], undefined));
      }
      this.materials = this.materials.concat(add);
      if (add.length > 0) {
        this.savedAt = '已导入 ' + add.length + ' 个素材，点击可加到画布（可拖拽/缩放）';
      }
    } catch (e) {
      console.error('import material fail', JSON.stringify(e));
    }
  }

  addMaterialToCanvas(m: MaterialItem): void {
    const id = 'mat' + this.elements.length + '_' + new Date().getTime();
    let el: PlogElement;
    if (m.kind === 'CUTOUT') {
      el = new PlogElement(id, 'CUTOUT', 'px:' + m.id, 30, 30, 1, '#000000', 0, '');
    } else if (m.kind === 'IMAGE') {
      el = new PlogElement(id, 'PHOTO', m.source, 30, 30, 1, '#000000', 0, '');
    } else if (m.kind === 'STICKER') {
      el = new PlogElement(id, 'STICKER', m.source, 30, 30, 1, '#FF7043', 0, '');
    } else {
      el = new PlogElement(id, 'TEXT', m.source, 30, 30, 1, '#FFFFFF', 20, '');
    }
    this.elements = this.elements.concat([el]);
    this.selectedId = id;
  }

  // ---- 协同邀请（微信） ----
  inviteContent(): string {
    return '邀请你加入 Plog 协同编辑：一起在一张图上写写画画、拖素材，每个元素同一时间只能由一人操作。' +
      '（演示链接）https://plog.demo/invite?room=abc123';
  }

  async copyInvite(): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.inviteContent());
      await pasteboard.getSystemPasteboard().setData(data);
      this.inviteInfo = '邀请链接已复制，去微信粘贴发送给好友';
    } catch (e) {
      this.inviteInfo = '复制失败，请重试';
    }
  }

  async shareToWeChat(): Promise<void> {
    try {
      const sd = new systemShare.SharedData({
        utd: 'general.plain-text',
        content: this.inviteContent(),
        title: 'Plog 协同编辑邀请'
      });
      const ctl = new systemShare.ShareController(sd);
      await ctl.show(getContext(this) as common.UIAbilityContext, {});
      this.inviteInfo = '已打开系统分享，选择微信发送即可邀请好友';
    } catch (e) {
      this.inviteInfo = '系统分享不可用，已复制到剪贴板（可发微信）';
      this.copyInvite();
    }
  }

  simulatePeerJoin(): void {
    this.collabMode = true;
    this.users = [
      new CollabUser('我', '#3A7BFF', true, '正在编辑'),
      new CollabUser('晓琳', '#FF6B6B', false, '已通过微信邀请加入'),
    ];
    this.showInviteDlg = false;
    this.showCollab = true;
    this.inviteInfo = '晓琳已加入协同：元素锁定生效，每人同一时间只能拖动一个元素';
  }

  // 锁定：把选中的元素锁定给某个协作者（仅 owner 可拖动）
  lockTo(name: string): void {
    const sel = this.selectedEl();
    if (!sel) {
      return;
    }
    const idx = this.elements.findIndex((e: PlogElement) => e.id === sel.id);
    if (idx < 0) {
      return;
    }
    const copy = new PlogElement(sel.id, sel.type, sel.text, sel.x, sel.y, sel.scale, sel.color, sel.fontSize,
      sel.sticker, name);
    const arr = this.elements.slice();
    arr[idx] = copy;
    this.elements = arr;
    this.savedAt = '元素已锁定给「' + name + '」，只有 TA 能拖动';
  }

  unlockSelected(): void {
    const sel = this.selectedEl();
    if (!sel) {
      return;
    }
    const idx = this.elements.findIndex((e: PlogElement) => e.id === sel.id);
    if (idx < 0) {
      return;
    }
    const copy = new PlogElement(sel.id, sel.type, sel.text, sel.x, sel.y, sel.scale, sel.color, sel.fontSize,
      sel.sticker, '');
    const arr = this.elements.slice();
    arr[idx] = copy;
    this.elements = arr;
    this.savedAt = '元素已解锁，所有人都可拖动';
  }

  // ---- 画笔涂鸦（多人可一起画） ----
  togglePaint(): void {
    this.paintMode = !this.paintMode;
    if (this.paintMode) {
      this.savedAt = '画笔已开启：直接在图面上画，协同时可多人一起画';
    } else {
      this.savedAt = '画笔已关闭';
    }
  }

  onPaintTouch(ev: TouchEvent): void {
    if (!this.paintMode || this.canvasW <= 0 || this.canvasH <= 0) {
      return;
    }
    const t = ev.touches[0];
    if (ev.type === TouchType.Down) {
      this.curDrawId = 's' + new Date().getTime();
      this.curStroke = [[t.x / this.canvasW, t.y / this.canvasH]];
    } else if (ev.type === TouchType.Move) {
      this.curStroke.push([t.x / this.canvasW, t.y / this.canvasH]);
      this.drawStrokes();
    } else if (ev.type === TouchType.Up || ev.type === TouchType.Cancel) {
      if (this.curStroke.length >= 2) {
        const s = new Stroke(this.curDrawId, this.penColor, 4, this.mine, this.curStroke.slice());
        this.strokes = this.strokes.concat([s]);
      }
      this.curStroke = [];
      this.drawStrokes();
    }
  }

  simulatePeerDraw(): void {
    const w = this.canvasW;
    const h = this.canvasH;
    if (w <= 0 || h <= 0) {
      return;
    }
    const pts: Array<Array<number>> = [];
    for (let i = 0; i <= 12; i++) {
      pts.push([0.2 + i * 0.05 + Math.random() * 0.02, 0.35 + Math.sin(i * 0.5) * 0.06]);
    }
    const s = new Stroke('peer' + new Date().getTime(), '#FF6B6B', 5, '晓琳', pts);
    this.strokes = this.strokes.concat([s]);
    this.drawStrokes();
    this.savedAt = '👥 晓琳画了一笔（两人可同时在图上写写画画）';
  }

  drawStrokes(): void {
    const ctx = this.paintCtx;
    if (!ctx || this.canvasW <= 0 || this.canvasH <= 0) {
      return;
    }
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);
    for (const s of this.strokes) {
      ctx.beginPath();
      ctx.lineWidth = s.width;
      ctx.strokeStyle = s.color;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      for (let i = 0; i < s.points.length; i++) {
        const x = s.points[i][0] * this.canvasW;
        const y = s.points[i][1] * this.canvasH;
        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.stroke();
    }
    if (this.curStroke.length >= 1 && this.paintMode) {
      ctx.beginPath();
      ctx.lineWidth = 4;
      ctx.strokeStyle = this.penColor;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      for (let i = 0; i < this.curStroke.length; i++) {
        const x = this.curStroke[i][0] * this.canvasW;
        const y = this.curStroke[i][1] * this.canvasH;
        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.stroke();
    }
  }

  // ---- BGM / MP3 ----
  setBgmByName(name: string): void {
    const item = this.audioList.find((a: AudioItem) => a.name === name);
    if (item) {
      this.selectAudio(item);
    }
    this.showBgmSheet = false;
  }

  async selectAudio(item: AudioItem): Promise<void> {
    this.bgm = item.name;
    if (item.path === '') {
      this.stopAudio();
      this.playing = false;
      this.playStatus = '内置音轨演示：' + item.name;
      return;
    }
    try {
      const av: media.AVPlayer = await media.createAVPlayer();
      this.player = av;
      av.on('stateChange', (state: media.AVPlayerState) => {
        if (state === 'prepared') {
          av.play();
          this.playing = true;
          this.playStatus = '正在播放：' + item.name;
        }
      });
      av.url = 'file://' + item.path;
      av.prepare();
    } catch (e) {
      this.playStatus = '播放失败，可换一首试试';
      console.error('play fail', JSON.stringify(e));
    }
  }

  togglePlay(): void {
    const item = this.audioList.find((a: AudioItem) => a.name === this.bgm);
    if (!item || item.path === '') {
      return;
    }
    const av = this.player;
    if (!av) {
      return;
    }
    if (this.playing) {
      av.pause();
      this.playing = false;
      this.playStatus = '已暂停';
    } else {
      av.play();
      this.playing = true;
      this.playStatus = '继续播放：' + item.name;
    }
  }

  stopAudio(): void {
    const av = this.player;
    if (av) {
      try {
        av.stop();
        av.release();
      } catch (e) {
        console.error('stop fail', JSON.stringify(e));
      }
      this.player = undefined;
    }
    this.playing = false;
  }

  async importAudio(): Promise<void> {
    try {
      const audioPicker = new picker.AudioViewPicker();
      const opt = new picker.AudioSelectOptions();
      opt.maxSelectNumber = 5;
      const uris: string[] = await audioPicker.select(opt);
      for (let i = 0; i < uris.length; i++) {
        const uri = uris[i];
        const name = '导入音频' + (i + 1);
        let dest = '';
        try {
          const f = fs.openSync(uri, fs.OpenMode.READ_ONLY);
          dest = getContext(this).filesDir + '/bgm_' + this.audioIdx + '.mp3';
          this.audioIdx++;
          fs.copyFileSync(f.fd, dest);
          fs.closeSync(f.fd);
        } catch (e) {
          console.error('copy audio fail', JSON.stringify(e));
          dest = '';
        }
        this.audioList = this.audioList.concat([new AudioItem(name, dest, false, '🎵')]);
        if (i === 0 && dest !== '') {
          this.selectAudio(this.audioList[this.audioList.length - 1]);
        }
      }
      this.showBgmSheet = true;
      this.bgm = this.bgm;
    } catch (e) {
      console.error('import audio fail', JSON.stringify(e));
    }
  }

  reuseTemplate(t: Template): void {
    this.bgImage = t.cover;
    this.elements = t.elements.slice();
    this.selectedId = '';
  }

  pushVersion(): void {
    const now = new Date();
    const vn = 'v' + (this.versions.length + 1);
    this.versions = [
      new VersionRecord(vn,
        now.getFullYear() + '-' + (now.getMonth() + 1) + '-' + now.getDate() + ' ' +
        now.getHours() + ':' + now.getMinutes(),
        '我', this.tags.length > 0 ? '记录：' + this.tags.join(' / ') : '保存当前版本'),
    ].concat(this.versions);
  }

  rollback(v: VersionRecord): void {
    // Demo：回退到历史版本（真实场景从云端拉取版本快照）
    this.savedAt = '已回退到 ' + v.version + ' (' + v.time + ')';
    this.showVersionDlg = false;
  }

  toggleTag(tag: string): void {
    if (this.tags.indexOf(tag) >= 0) {
      this.tags = this.tags.filter((t: string) => t !== tag);
    } else {
      this.tags = this.tags.concat([tag]);
    }
  }

  recordVoice(): void {
    // Demo：语音记录。真实场景使用 AudioCapturer + 语音转文字大模型
    const d = new Date();
    this.voiceNote = '🎙️ 语音已记录 ' + (d.getHours() < 10 ? '0' : '') + d.getHours() +
      ':' + (d.getMinutes() < 10 ? '0' : '') + d.getMinutes() + ' · 00:12';
  }

  save(): void {
    this.pushVersion();
    this.savedAt = '已保存 ' + (new Date().getHours()) + ':' + (new Date().getMinutes());
  }

  onEditText(): void {
    const sel = this.selectedEl();
    if (!sel) {
      return;
    }
    this.editText = sel.text;
    this.showEditDialog = true;
  }

  confirmEditText(): void {
    const sel = this.selectedEl();
    if (sel) {
      const idx = this.elements.findIndex((e: PlogElement) => e.id === sel.id);
      if (idx >= 0) {
        const copy = new PlogElement(sel.id, sel.type, this.editText, sel.x, sel.y, sel.scale, sel.color,
          sel.fontSize, sel.sticker, sel.owner);
        const arr = this.elements.slice();
        arr[idx] = copy;
        this.elements = arr;
      }
    }
    this.showEditDialog = false;
  }

  // ==================== UI ====================

  @Builder
  collabOverlay() {
    if (this.showCollab) {
      Column({ space: 6 }) {
        ForEach(this.users, (u: CollabUser) => {
          Row({ space: 4 }) {
            Text(u.name.charAt(0)).fontSize(10).fontColor(Color.White)
              .width(18).height(18).textAlign(TextAlign.Center)
              .backgroundColor(this.ownerColor(u.name)).borderRadius(9)
            Text(u.action).fontSize(10).fontColor(this.ownerColor(u.name))
          }
        }, (u: CollabUser) => u.name)
        if (this.collabMode) {
          Text('🔒 元素锁定：一人一动，防冲突').fontSize(9).fontColor('#E53935')
        }
      }
      .padding(8)
      .backgroundColor('rgba(255,255,255,0.85)')
      .borderRadius(10)
      .position({ x: 8, y: 120 })
    }
  }

  @Builder
  chip(label: string, active: boolean, onClick: () => void) {
    Text(label)
      .fontSize(12)
      .fontColor(active ? Color.White : '#333333')
      .backgroundColor(active ? '#3A7BFF' : Color.White)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .onClick(onClick)
  }

  @Builder
  materialCell(m: MaterialItem) {
    Column({ space: 2 }) {
      if (m.kind === 'STICKER' || m.kind === 'TEXT') {
        Text(m.source).fontSize(26).width(52).height(52).textAlign(TextAlign.Center)
          .backgroundColor('#F0F2F7').borderRadius(10)
      } else {
        if (m.kind === 'CUTOUT' && this.pixelMaps.has(m.id)) {
          Image(this.pixelMaps.get(m.id) as image.PixelMap)
            .width(52).height(52).objectFit(ImageFit.Cover).borderRadius(10)
        } else {
          Image(this.uriOrRes(m.source))
            .width(52).height(52).objectFit(ImageFit.Cover).borderRadius(10)
        }
      }
      Text(m.name).fontSize(9).fontColor('#666').maxLines(1)
    }
    .onClick(() => this.addMaterialToCanvas(m))
  }

  @Builder
  elView(el: PlogElement) {
    Stack() {
      if (el.type === 'PHOTO' || el.type === 'CUTOUT') {
        if (el.text.startsWith('px:')) {
          Image(this.pixelMaps.get(el.text.slice(3)) as image.PixelMap)
            .width(150)
            .height(170)
            .objectFit(ImageFit.Cover)
            .borderRadius(10)
        } else {
          Image(this.uriOrRes(el.text))
            .width(150)
            .height(170)
            .objectFit(ImageFit.Cover)
            .borderRadius(10)
        }
      } else if (el.type === 'STICKER') {
        Text(el.text)
          .fontSize(40 * el.scale)
          .fontColor(el.color)
      } else {
        Text(el.text)
          .fontSize(el.fontSize * el.scale)
          .fontColor(el.color)
          .fontWeight(el.type === 'HASHTAG' ? FontWeight.Normal : FontWeight.Bold)
          .textShadow({ radius: 3, color: 'rgba(0,0,0,0.5)', offsetX: 0, offsetY: 1 })
      }
      if (this.collabMode && el.owner !== '') {
        Text('🔒' + el.owner)
          .fontSize(9).fontColor(Color.White)
          .backgroundColor(this.ownerColor(el.owner))
          .padding({ left: 5, right: 5, top: 2, bottom: 2 })
          .borderRadius(6)
          .position({ x: 0, y: -20 })
      }
    }
    .border({
      width: this.selectedId === el.id ? 1.5 : 0,
      color: '#3A7BFF'
    })
    .position({ x: this.canvasW * el.x / 100, y: this.canvasH * el.y / 100 })
    .gesture(
      PanGesture({ fingers: 1 })
        .onActionStart(() => this.select(el))
        .onActionUpdate((ev: PanGestureEvent) => this.onPan(el, ev))
    )
    .gesture(
      PinchGesture()
        .onActionStart(() => this.pinchBase.set(el.id, el.scale))
        .onActionUpdate((ev: GestureEvent) => this.onPinch(el, ev))
    )
    .gesture(
      LongPressGesture()
        .onActionEnd(() => this.onLongPressCut(el))
    )
  }

  @Builder
  materialBar() {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text('🧰 素材库').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
        Text('长按画布元素可抠图提取 · 点击素材添加到画布').fontSize(10).fontColor('#8A8A8A')
        Blank()
        Text('＋导入素材').fontSize(13).fontColor('#3A7BFF').onClick(() => this.onImportMaterial())
      }
      .width('100%')

      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.materials, (m: MaterialItem) => {
            this.materialCell(m)
          }, (m: MaterialItem) => m.id)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .padding({ top: 12 })
  }

  build() {
    Stack() {
      Column() {
        // 顶栏
        Row() {
          Text('‹ 返回').fontSize(16).fontColor('#3A7BFF')
            .onClick(() => router.back())
          Blank()
          Text('Plog 编辑器').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Blank()
          Text('保存').fontSize(16).fontColor('#3A7BFF').onClick(() => this.save())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        Scroll() {
          Column() {
            // 画布
            Stack() {
              Image(this.uriOrRes(this.bgImage))
                .width('100%')
                .height(520)
                .objectFit(ImageFit.Cover)
              ForEach(this.elements, (el: PlogElement) => {
                this.elView(el)
              }, (el: PlogElement) => el.id)
              if (this.paintMode) {
                Canvas(this.paintCtx)
                  .width('100%')
                  .height(520)
                  .onReady(() => this.drawStrokes())
                  .onTouch((ev: TouchEvent) => this.onPaintTouch(ev))
              }
            }
            .width('100%')
            .height(520)
            .backgroundColor('#1A1A1A')
            .borderRadius(16)
            .clip(true)
            .margin({ top: 4 })
            .onAreaChange((oldValue: Area, newValue: Area) => {
              this.canvasW = newValue.width as number;
              this.canvasH = newValue.height as number;
              this.drawStrokes();
            })
            .overlay(this.collabOverlay())

            // 选中元素操作条
            if (this.selectedEl() !== undefined) {
              Row({ space: 8 }) {
                Button('＋') .onClick(() => this.scaleSelected(0.2)).height(32)
                Button('－') .onClick(() => this.scaleSelected(-0.2)).height(32)
                Button('编辑') .onClick(() => this.onEditText()).height(32)
                Button('删除') .onClick(() => this.deleteSelected()).height(32)
                if (this.collabMode) {
                  Button('🔒锁定') .height(32).backgroundColor('#FF6B6B')
                    .onClick(() => this.lockTo('我'))
                    .enabled(this.selectedEl()?.owner !== '我')
                  Button('🔓解锁') .height(32).backgroundColor('#8A8A8A')
                    .onClick(() => this.unlockSelected())
                    .enabled(this.selectedEl()?.owner !== '')
                }
              }
              .margin({ top: 8 })
              if (this.collabMode) {
                Text('锁定后只有对应的人能拖动该元素，避免多人冲突').fontSize(10).fontColor('#8A8A8A')
                  .width('100%').margin({ top: 2 })
              }
            }

            // 素材库
            this.materialBar()

            // 功能条
            Row({ space: 6 }) {
              this.chip('👥协同', this.showCollab, () => {
                if (!this.collabMode) {
                  this.showInviteDlg = true;
                } else {
                  this.showCollab = !this.showCollab;
                }
              })
              this.chip('🎨画笔', this.paintMode, () => this.togglePaint())
              this.chip('🕘版本', false, () => this.showVersionDlg = true)
              this.chip('🎵' + this.bgm, this.bgm !== '无BGM', () => this.showBgmSheet = true)
              this.chip('🎙️语音', this.voiceNote !== '', () => this.recordVoice())
              this.chip('＋文字', false, () => this.addText())
            }
            .width('100%')
            .margin({ top: 12 })

            if (this.paintMode && this.collabMode) {
              Row({ space: 8 }) {
                Text('👥 让晓琳画一笔').fontSize(12).fontColor('#3A7BFF')
                  .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                  .backgroundColor('#E8F0FF').borderRadius(14)
                  .onClick(() => this.simulatePeerDraw())
                Text('笔色').fontSize(12).fontColor('#333').padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor(Color.White).borderRadius(14)
                  .onClick(() => {
                    this.penColor = this.penColor === '#FF6B6B' ? '#20C997' : '#FF6B6B';
                  })
                if (this.playing) {
                  Text('⏸ 暂停').fontSize(12).fontColor('#3A7BFF')
                    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                    .backgroundColor('#E8F0FF').borderRadius(14)
                    .onClick(() => this.togglePlay())
                }
              }
              .width('100%')
              .margin({ top: 8 })
            } else if (this.playing) {
              Row({ space: 8 }) {
                Text('⏸ 暂停').fontSize(12).fontColor('#3A7BFF')
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor('#E8F0FF').borderRadius(14)
                  .onClick(() => this.togglePlay())
                Text(this.playStatus).fontSize(11).fontColor('#8A8A8A')
              }
              .width('100%')
              .margin({ top: 8 })
            }

            // 标签
            Row({ space: 6 }) {
              ForEach(['旅行', '美食', '穿搭', '生日派对', '纪念碑', '家居'], (tag: string) => {
                this.chip('#' + tag, this.tags.indexOf(tag) >= 0, () => this.toggleTag(tag))
              }, (tag: string) => tag)
            }
            .width('100%')
            .margin({ top: 8 })

            // 状态提示
            Column({ space: 2 }) {
              if (this.voiceNote !== '') {
                Text(this.voiceNote).fontSize(12).fontColor('#8A8A8A')
              }
              if (this.savedAt !== '') {
                Text(this.savedAt).fontSize(12).fontColor('#20C997')
              }
              if (this.playStatus !== '' && this.playStatus.indexOf('暂停') < 0 && !this.playing && this.bgm !== '无BGM') {
                Text(this.playStatus).fontSize(11).fontColor('#8A8A8A')
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ top: 6 })

            // 模板复用
            Text('复用模板（可编辑）').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
              .width('100%')
              .margin({ top: 16 })
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.templates, (t: Template) => {
                  Column({ space: 4 }) {
                    Image(this.uriOrRes(t.cover))
                      .width(72).height(92).objectFit(ImageFit.Cover).borderRadius(8)
                    Text(t.name).fontSize(11).fontColor('#333')
                  }
                  .onClick(() => this.reuseTemplate(t))
                }, (t: Template) => t.id)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')

            Blank().height(30)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F6FA')

      // 弹层：编辑文字
      if (this.showEditDialog) {
        this.maskLayer()
        Column() {
          Text('编辑文字内容').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          TextInput({ text: this.editText })
            .width('100%')
            .margin({ top: 12 })
            .onChange((v: string) => this.editText = v)
          Row({ space: 12 }) {
            Button('取消').layoutWeight(1).backgroundColor('#E5E5E5').fontColor('#333')
              .onClick(() => this.showEditDialog = false)
            Button('确定').layoutWeight(1).backgroundColor('#3A7BFF')
              .onClick(() => this.confirmEditText())
          }
          .width('100%')
          .margin({ top: 16 })
        }
        .width('85%')
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius(16)
      }

      // 弹层：长按抠图提取
      if (this.showCutSheet) {
        this.maskLayer()
        Column() {
          Text('✂️ 抠图提取到素材库').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Text(this.cutInfo).fontSize(12).fontColor('#666').margin({ top: 10 })
          Text('（演示为区域裁剪模拟，接入分割大模型后输出透明底抠图）')
            .fontSize(10).fontColor('#8A8A8A').margin({ top: 4 })
          Row({ space: 12 }) {
            Button('取消').layoutWeight(1).backgroundColor('#E5E5E5').fontColor('#333')
              .onClick(() => this.showCutSheet = false)
            Button('提取到素材库').layoutWeight(1).backgroundColor('#3A7BFF')
              .onClick(() => this.confirmCut())
          }
          .width('100%')
          .margin({ top: 16 })
        }
        .width('85%')
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius(16)
      }

      // 弹层：协同邀请（微信）
      if (this.showInviteDlg) {
        this.maskLayer()
        Column() {
          Text('👥 邀请微信好友协同编辑').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Text(this.inviteContent()).fontSize(11).fontColor('#666').lineHeight(16).margin({ top: 10 })
          Text('好友通过链接进入后，两人可在一张图上一起写写画画、拖素材；每个元素同一时间只能由一个人操作。')
            .fontSize(10).fontColor('#8A8A8A').lineHeight(15).margin({ top: 8 })
          Button('分享到微信（系统分享面板）')
            .width('100%').margin({ top: 14 }).backgroundColor('#07C160')
            .onClick(() => this.shareToWeChat())
          Row({ space: 12 }) {
            Button('复制邀请链接').layoutWeight(1).backgroundColor('#E5E5E5').fontColor('#333')
              .onClick(() => this.copyInvite())
            Button('演示：晓琳加入').layoutWeight(1).backgroundColor('#3A7BFF')
              .onClick(() => this.simulatePeerJoin())
          }
          .width('100%')
          .margin({ top: 12 })
          if (this.inviteInfo !== '') {
            Text(this.inviteInfo).fontSize(11).fontColor('#20C997').margin({ top: 8 })
          }
        }
        .width('85%')
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius(16)
      }

      // 弹层：版本记录
      if (this.showVersionDlg) {
        this.maskLayer()
        Column() {
          Text('版本记录（点击回退）').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Column({ space: 8 }) {
            ForEach(this.versions, (v: VersionRecord) => {
              Row() {
                Column({ space: 2 }) {
                  Text(v.version + ' · ' + v.author).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
                  Text(v.time + ' · ' + v.note).fontSize(11).fontColor('#8A8A8A')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text('回退').fontSize(13).fontColor('#3A7BFF').onClick(() => this.rollback(v))
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#F5F6FA')
              .borderRadius(8)
            }, (v: VersionRecord) => v.version)
          }
          .width('100%')
          .margin({ top: 12 })
          Button('关闭').width('100%').backgroundColor('#E5E5E5').fontColor('#333')
            .onClick(() => this.showVersionDlg = false)
            .margin({ top: 12 })
        }
        .width('85%')
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius(16)
      }

      // 弹层：BGM / MP3 选择
      if (this.showBgmSheet) {
        this.maskLayer()
        Column() {
          Row() {
            Text('选择背景音乐 (BGM)').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            Blank()
            Text('＋导入MP3').fontSize(13).fontColor('#3A7BFF').onClick(() => this.importAudio())
          }
          .width('100%')
          Column({ space: 8 }) {
            ForEach(this.audioList, (a: AudioItem) => {
              Row({ space: 8 }) {
                Text(a.icon).fontSize(14)
                Text(a.name).fontSize(14)
                  .fontColor(this.bgm === a.name ? '#3A7BFF' : '#333')
                  .layoutWeight(1)
                if (a.path !== '' && this.bgm === a.name) {
                  Text(this.playing ? '⏸' : '▶').fontSize(14).onClick(() => this.togglePlay())
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.bgm === a.name ? '#E8F0FF' : '#F5F6FA')
              .borderRadius(10)
              .onClick(() => this.setBgmByName(a.name))
            }, (a: AudioItem) => a.name + a.path)
          }
          .width('100%')
          .margin({ top: 12 })
          if (this.playStatus !== '') {
            Text(this.playStatus).fontSize(11).fontColor('#20C997').margin({ top: 6 })
          }
          Button('关闭').width('100%').backgroundColor('#E5E5E5').fontColor('#333')
            .onClick(() => this.showBgmSheet = false)
            .margin({ top: 12 })
        }
        .width('85%')
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius(16)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  maskLayer() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.4)')
      .onClick(() => {
        this.showEditDialog = false;
        this.showVersionDlg = false;
        this.showBgmSheet = false;
        this.showCutSheet = false;
        this.showInviteDlg = false;
      })
  }
}
