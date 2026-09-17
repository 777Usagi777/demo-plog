import { router } from '@kit.ArkUI';
import {
  getTemplates, Template, PlogElement, CollabUser, VersionRecord,
  getCollabUsers, getVersionRecords, aiAnalyzeTemplate
} from '../model/Data';

@Entry
@Component
struct Editor {
  @State elements: PlogElement[] = [];
  @State bgImage: string = 'sample1';
  @State templates: Template[] = getTemplates();
  @State users: CollabUser[] = getCollabUsers();
  @State versions: VersionRecord[] = getVersionRecords();
  @State showCollab: boolean = false;
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
  private pinchBase: Map<string, number> = new Map<string, number>();

  aboutToAppear(): void {
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
      const t = aiAnalyzeTemplate();
      this.bgImage = t.cover;
      this.elements = t.elements.slice();
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
      this.bgImage = list[0];
      this.elements = [
        new PlogElement('p', 'PHOTO', list[0], 26, 26, 1, '#000000', 0, ''),
        new PlogElement('t', 'TEXT', '记录今日份美好', 8, 8, 1, '#FFFFFF', 24, ''),
        new PlogElement('h', 'HASHTAG', '#今日Plog', 8, 86, 1, '#FFD54A', 16, ''),
      ];
    } else {
      this.loadSample();
    }
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
    return $r('app.media.sample1');
  }

  select(el: PlogElement): void {
    this.selectedId = el.id;
  }

  onPan(el: PlogElement, ev: PanGestureEvent): void {
    const idx = this.elements.findIndex((e: PlogElement) => e.id === el.id);
    if (idx < 0 || this.canvasW <= 0 || this.canvasH <= 0) {
      return;
    }
    const nx = el.x + ev.offsetX / this.canvasW * 100;
    const ny = el.y + ev.offsetY / this.canvasH * 100;
    const copy = new PlogElement(el.id, el.type, el.text,
      Math.max(-8, Math.min(108, nx)), Math.max(-8, Math.min(108, ny)),
      el.scale, el.color, el.fontSize, el.sticker);
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
    const copy = new PlogElement(el.id, el.type, el.text, el.x, el.y, s, el.color, el.fontSize, el.sticker);
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
    const copy = new PlogElement(sel.id, sel.type, sel.text, sel.x, sel.y, s, sel.color, sel.fontSize, sel.sticker);
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
        const copy = new PlogElement(sel.id, sel.type, this.editText, sel.x, sel.y, sel.scale, sel.color, sel.fontSize, sel.sticker);
        const arr = this.elements.slice();
        arr[idx] = copy;
        this.elements = arr;
      }
    }
    this.showEditDialog = false;
  }

  setBgm(name: string): void {
    this.bgm = name;
    this.showBgmSheet = false;
  }

  @Builder
  collabOverlay() {
    if (this.showCollab) {
      Column({ space: 8 }) {
        ForEach(this.users, (u: CollabUser) => {
          Row({ space: 4 }) {
            Text(u.name.charAt(0)).fontSize(10).fontColor(Color.White)
              .width(18).height(18).textAlign(TextAlign.Center)
              .backgroundColor(u.color).borderRadius(9)
            Text(u.action).fontSize(10).fontColor(u.color)
          }
        }, (u: CollabUser) => u.name)
      }
      .padding(8)
      .backgroundColor('rgba(255,255,255,0.85)')
      .borderRadius(10)
      .position({ x: 8, y: 8 })
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
  elView(el: PlogElement) {
    Stack() {
      if (el.type === 'PHOTO') {
        Image(this.uriOrRes(el.text))
          .width(150)
          .height(170)
          .objectFit(ImageFit.Cover)
          .borderRadius(10)
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
            })
            .overlay(this.collabOverlay())

            // 选中元素操作条
            if (this.selectedEl() !== undefined) {
              Row({ space: 10 }) {
                Button('＋') .onClick(() => this.scaleSelected(0.2)).height(34)
                Button('－') .onClick(() => this.scaleSelected(-0.2)).height(34)
                Button('编辑') .onClick(() => this.onEditText()).height(34)
                Button('删除') .onClick(() => this.deleteSelected()).height(34)
              }
              .margin({ top: 8 })
            }

            // 协同/版本/BGM/语音条
            Row({ space: 6 }) {
              this.chip('👥协同', this.showCollab, () => this.showCollab = !this.showCollab)
              this.chip('🕘版本', false, () => this.showVersionDlg = true)
              this.chip('🎵' + this.bgm, this.bgm !== '无BGM', () => this.showBgmSheet = true)
              this.chip('🎙️语音', this.voiceNote !== '', () => this.recordVoice())
              this.chip('＋文字', false, () => this.addText())
            }
            .width('100%')
            .margin({ top: 12 })

            // 标签
            Row({ space: 6 }) {
              ForEach(['旅行', '美食', '穿搭', 'OOTD'], (tag: string) => {
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
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ top: 6 })

            // 模板复用
            Text('复用模板（可编辑）').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
              .width('100%')
              .margin({ top: 16 })
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

      // 弹层：BGM 选择
      if (this.showBgmSheet) {
        this.maskLayer()
        Column() {
          Text('选择背景音乐 (BGM)').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Column({ space: 8 }) {
            ForEach(['🎵 轻音乐', '🌊 海边白噪音', '🎷 爵士', '🔇 无BGM'], (b: string) => {
              Text(b)
                .fontSize(14)
                .fontColor(this.bgm === b ? '#3A7BFF' : '#333')
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(12)
                .backgroundColor(this.bgm === b ? '#E8F0FF' : '#F5F6FA')
                .borderRadius(10)
                .onClick(() => this.setBgm(b))
            }, (b: string) => b)
          }
          .width('100%')
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
      })
  }
}
