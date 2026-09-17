import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import {
  PhotoItem, CameraTip, PhotoAdvice, SkeletonPose,
  analyzePhotos, getCameraTips, getCategories, buildAdvice, buildSkeletons, getBones
} from '../model/Data';

@Entry
@Component
struct CameraPage {
  @State photos: PhotoItem[] = [
    new PhotoItem('sample1', 'sample1', true, false, '待分析', ''),
    new PhotoItem('sample2', 'sample2', true, false, '待分析', ''),
    new PhotoItem('sample3', 'sample3', true, false, '待分析', ''),
    new PhotoItem('sample4', 'sample4', true, true, '待分析', '全黑模糊废片示例'),
    new PhotoItem('demo1', 'demo1', true, false, '待分析', ''),
    new PhotoItem('demo2', 'demo2', true, false, '待分析', ''),
    new PhotoItem('demo3', 'demo3', true, false, '待分析', ''),
    new PhotoItem('demo4', 'demo4', true, false, '待分析', ''),
    new PhotoItem('demo5', 'demo5', true, false, '待分析', ''),
    new PhotoItem('demo6', 'demo6', true, false, '待分析', ''),
    new PhotoItem('demo7', 'demo7', true, false, '待分析', ''),
  ];
  @State filter: string = '全部'; // 全部/保留/废片
  @State category: string = '全部'; // 分类筛选
  @State analyzed: boolean = false;
  @State poseMode: boolean = false; // 姿态/机位参考模式
  @State groupView: boolean = false; // 分组拖拽视图
  @State tips: CameraTip[] = getCameraTips();
  @State advice: PhotoAdvice[] = [];
  private adviceMap: Map<string, PhotoAdvice> = new Map<string, PhotoAdvice>();
  private skelCache: Map<string, Array<SkeletonPose>> = new Map<string, Array<SkeletonPose>>();
  private cellCtxs: Map<string, CanvasRenderingContext2D> = new Map<string, CanvasRenderingContext2D>();
  private cellAreas: Map<string, Area> = new Map<string, Area>();
  private subjectCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

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

  filtered(): PhotoItem[] {
    let list = this.photos;
    if (this.filter === '保留') {
      list = list.filter((p: PhotoItem) => !p.isWaste);
    } else if (this.filter === '废片') {
      list = list.filter((p: PhotoItem) => p.isWaste);
    }
    if (this.category !== '全部') {
      list = list.filter((p: PhotoItem) => p.category === this.category);
    }
    return list;
  }

  goodList(): PhotoItem[] {
    return this.filtered().filter((p: PhotoItem) => !p.isWaste);
  }

  wasteList(): PhotoItem[] {
    return this.filtered().filter((p: PhotoItem) => p.isWaste);
  }

  // 分组拖拽：跨组移动时按最终位置重新归属好片/废片
  onMove(from: number, to: number): void {
    const list = this.filtered();
    const total = list.length;
    if (from < 0 || from >= total || to < 0 || to >= total || from === to) {
      return;
    }
    const arr = list.slice();
    const item = arr.splice(from, 1)[0];
    arr.splice(to, 0, item);
    const boundary = list.filter((x: PhotoItem) => !x.isWaste).length;
    const out = this.photos.slice();
    for (let i = 0; i < arr.length; i++) {
      const idx = out.findIndex((x: PhotoItem) => x.uri === arr[i].uri && x.name === arr[i].name);
      if (idx >= 0) {
        const src = out[idx];
        const isWaste = i >= boundary;
        const c = new PhotoItem(src.uri, src.name, src.isResource, isWaste, src.category, src.desc,
          src.hasPerson, src.personCount);
        out[idx] = c;
        // 同步被拍摄者建议（有/无人）
        if (this.analyzed) {
          this.adviceMap.set(src.uri + src.name, buildAdvice(c));
        }
      }
    }
    this.photos = out;
    this.refreshAdvice();
  }

  toggleWaste(p: PhotoItem): void {
    const idx = this.photos.findIndex((x: PhotoItem) => x.uri === p.uri && x.name === p.name);
    if (idx < 0) {
      return;
    }
    const src = this.photos[idx];
    const copy = new PhotoItem(src.uri, src.name, src.isResource, !src.isWaste, src.category, src.desc,
      src.hasPerson, src.personCount);
    const arr = this.photos.slice();
    arr[idx] = copy;
    this.photos = arr;
    if (this.analyzed) {
      this.adviceMap.set(src.uri + src.name, buildAdvice(copy));
    }
    this.refreshAdvice();
  }

  refreshAdvice(): void {
    if (!this.analyzed) {
      return;
    }
    const arr: PhotoAdvice[] = [];
    for (const p of this.photos) {
      if (!p.isWaste) {
        const key = p.uri + p.name;
        if (!this.adviceMap.has(key)) {
          this.adviceMap.set(key, buildAdvice(p));
        }
        arr.push(this.adviceMap.get(key)!);
      }
    }
    this.advice = arr;
  }

  async onAnalyze(): Promise<void> {
    this.photos = analyzePhotos(this.photos);
    this.analyzed = true;
    this.adviceMap.clear();
    this.skelCache.clear();
    this.refreshAdvice();
  }

  async onAdd(): Promise<void> {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const opt = new picker.PhotoSelectOptions();
      opt.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      opt.maxSelectNumber = 20;
      const res = await photoPicker.select(opt);
      const add: PhotoItem[] = [];
      for (let i = 0; i < res.photoUris.length; i++) {
        add.push(new PhotoItem(res.photoUris[i], 'upload' + (i + 1), false, false, '待分析', ''));
      }
      this.photos = this.photos.concat(add);
    } catch (e) {
      console.error('add photos fail', JSON.stringify(e));
    }
  }

  // ---- 姿态骨架 ----
  skeletonsOf(p: PhotoItem): Array<SkeletonPose> {
    const key = p.uri + p.name;
    if (!this.skelCache.has(key)) {
      const idx = this.photos.findIndex((x: PhotoItem) => x.uri === p.uri && x.name === p.name);
      this.skelCache.set(key, buildSkeletons(Math.max(1, idx), p.personCount));
    }
    return this.skelCache.get(key)!;
  }

  cellCtx(p: PhotoItem): CanvasRenderingContext2D {
    const key = p.uri + p.name;
    if (!this.cellCtxs.has(key)) {
      this.cellCtxs.set(key, new CanvasRenderingContext2D(new RenderingContextSettings(true)));
    }
    return this.cellCtxs.get(key)!;
  }

  vp2px(n: number): number {
    return this.getUIContext().vp2px(n);
  }

  drawCellPose(p: PhotoItem): void {
    const a = this.cellAreas.get(p.uri + p.name);
    if (!a || a.width === undefined || a.height === undefined) {
      return;
    }
    this.drawPose(p, this.cellCtx(p), this.vp2px(a.width as number), this.vp2px(a.height as number));
  }

  drawPose(p: PhotoItem, ctx: CanvasRenderingContext2D, w: number, h: number): void {
    ctx.clearRect(0, 0, w, h);
    if (!this.poseMode || !p.hasPerson || !this.analyzed || w <= 0 || h <= 0) {
      return;
    }
    const skels = this.skeletonsOf(p);
    for (const sk of skels) {
      this.drawSkel(ctx, sk, w, h);
    }
  }

  drawSkel(ctx: CanvasRenderingContext2D, sk: SkeletonPose, w: number, h: number): void {
    ctx.lineWidth = 2;
    ctx.strokeStyle = sk.color;
    ctx.lineCap = 'round';
    const bones = getBones();
    for (const b of bones) {
      const a = sk.joints[b[0]];
      const c = sk.joints[b[1]];
      ctx.beginPath();
      ctx.moveTo(a[0] * w, a[1] * h);
      ctx.lineTo(c[0] * w, c[1] * h);
      ctx.stroke();
    }
    ctx.fillStyle = sk.color;
    for (const j of sk.joints) {
      ctx.beginPath();
      ctx.arc(j[0] * w, j[1] * h, 3, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  subjectPhoto(): PhotoItem | undefined {
    for (const p of this.photos) {
      if (!p.isWaste && p.hasPerson && p.category !== '待分析') {
        return p;
      }
    }
    return undefined;
  }

  // ==================== UI ====================

  @Builder
  chip(label: string, active: boolean, onClick: () => void, activeColor: string = '#3A7BFF') {
    Text(label)
      .fontSize(12)
      .fontColor(active ? Color.White : '#333')
      .backgroundColor(active ? activeColor : Color.White)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .borderRadius(14)
      .onClick(onClick)
  }

  @Builder
  photoCell(p: PhotoItem) {
    Column() {
      Stack() {
        Image(this.uriOrRes(p.uri))
          .width('100%')
          .height(120)
          .objectFit(ImageFit.Cover)
          .borderRadius(10)
          .opacity(p.isWaste ? 0.35 : 1)
        if (this.poseMode && p.hasPerson) {
          Canvas(this.cellCtx(p))
            .width('100%')
            .height(120)
            .borderRadius(10)
            .onReady(() => this.drawCellPose(p))
            .onAreaChange((oldValue: Area, newValue: Area) => {
              this.cellAreas.set(p.uri + p.name, newValue);
              this.drawCellPose(p);
            })
        }
        if (p.isWaste) {
          Text('废片').fontSize(11).fontColor('#E53935')
            .backgroundColor('rgba(255,255,255,0.85)')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8)
        } else if (p.category !== '待分析' && p.category !== '') {
          Text(p.category).fontSize(10).fontColor(Color.White)
            .backgroundColor('#3A7BFF')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8)
        }
        if (this.poseMode && p.hasPerson && this.analyzed) {
          Text('🦴' + p.personCount + '人姿态').fontSize(10).fontColor(Color.White)
            .backgroundColor('rgba(0,0,0,0.5)')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8)
            .position({ x: 6, y: 6 })
        }
      }
      .width('100%')
      .height(120)
      .onClick(() => this.toggleWaste(p))
      if (this.analyzed && p.desc !== '') {
        Text(p.desc).fontSize(9).fontColor('#8A8A8A').maxLines(2).margin({ top: 2 })
      }
    }
    .width('48%')
  }

  @Builder
  groupRow(p: PhotoItem) {
    Row({ space: 10 }) {
      Image(this.uriOrRes(p.uri))
        .width(64).height(64).objectFit(ImageFit.Cover).borderRadius(8)
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(p.name).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
          if (p.isWaste) {
            Text('废片').fontSize(9).fontColor('#E53935')
          } else if (p.category !== '待分析' && p.category !== '') {
            Text(p.category).fontSize(9).fontColor('#3A7BFF')
          }
        }
        Text(p.desc !== '' ? p.desc : '点击切换 好片/废片').fontSize(10).fontColor('#8A8A8A').maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(p.isWaste ? '⟵ 拖到好片' : '⟵ 拖到废片').fontSize(10).fontColor('#3A7BFF')
    }
    .width('100%')
    .padding(8)
    .backgroundColor(Color.White)
    .borderRadius(10)
    .onClick(() => this.toggleWaste(p))
  }

  @Builder
  tipCard(t: CameraTip) {
    Row({ space: 10 }) {
      Text(t.icon).fontSize(24)
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(t.subject).fontSize(13).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Text(t.angle).fontSize(12).fontColor('#3A7BFF')
            .backgroundColor('#E8F0FF').padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(8)
        }
        Text(t.desc).fontSize(11).fontColor('#8A8A8A').maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .margin({ bottom: 8 })
  }

  @Builder
  adviceCard(a: PhotoAdvice, name: string) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Text(name).fontSize(11).fontColor('#8A8A8A')
        Text(a.angle).fontSize(12).fontColor('#3A7BFF')
          .backgroundColor('#E8F0FF').padding({ left: 6, right: 6, top: 2, bottom: 2 }).borderRadius(8)
      }
      if (a.hasPerson && a.subjectText !== '') {
        Text(a.subjectText).fontSize(11).fontColor('#5D5D5D').lineHeight(17)
      }
      Text(a.photoText).fontSize(11).fontColor('#5D5D5D').lineHeight(17)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(14)
    .margin({ bottom: 8 })
  }

  @Builder
  subjectPanel(sp: PhotoItem) {
    if (sp !== undefined) {
      Row() {
        Text('⛹ 被拍摄者姿态参考（火柴人骨架）').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
        Blank()
        Text('多人骨架').fontSize(11).fontColor('#8A8A8A')
      }
      .width('100%')
      .margin({ top: 20, bottom: 8 })

      Row({ space: 12 }) {
        Stack() {
          Image(this.uriOrRes(sp.uri))
            .width(180).height(230).objectFit(ImageFit.Cover).borderRadius(12)
          Canvas(this.subjectCtx)
            .width(180).height(230)
            .onReady(() => this.drawPose(sp, this.subjectCtx, this.vp2px(180), this.vp2px(230)))
        }
        Column({ space: 4 }) {
          Text('照着骨架摆 pose').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
          Text('关节连线 = 火柴人骨架（多人时每个颜色代表一个人）')
            .fontSize(10).fontColor('#8A8A8A').lineHeight(15)
          Text('🦴 检测到 ' + sp.personCount + ' 人')
            .fontSize(11).fontColor('#FF6B6B').margin({ top: 6 })
          Text('被拍者照着参考图摆姿，摄影师看下方文字建议调整机位。')
            .fontSize(10).fontColor('#8A8A8A').lineHeight(15).margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#E8F0FF')
      .borderRadius(14)

      if (this.adviceMap.get(sp.uri + sp.name) !== undefined
        && (this.adviceMap.get(sp.uri + sp.name) as PhotoAdvice).subjectText !== '') {
        Text((this.adviceMap.get(sp.uri + sp.name) as PhotoAdvice).subjectText)
          .fontSize(12).fontColor('#5D5D5D').lineHeight(18)
          .width('100%').padding(12).backgroundColor('#FFF7E6').borderRadius(12).margin({ top: 8 })
      }
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).fontColor('#3A7BFF').onClick(() => router.back())
        Blank()
        Text('智能选片 & 机位 & 姿态').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
        Blank()
        Text('＋批量').fontSize(15).fontColor('#3A7BFF').onClick(() => this.onAdd())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 })

      // 操作行
      Row({ space: 10 }) {
        Button(this.analyzed ? '重新 AI 分析' : '🤖 AI 分析：去废片+分类+人物检测')
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.analyzed ? '#20C997' : '#3A7BFF')
          .fontColor(Color.White)
          .borderRadius(20)
          .onClick(() => this.onAnalyze())
        Button(this.poseMode ? '🦴 关闭姿态参考' : '🦴 姿态&机位参考')
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.poseMode ? '#FF6B6B' : '#FF9800')
          .fontColor(Color.White)
          .borderRadius(20)
          .onClick(() => this.poseMode = !this.poseMode)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4 })

      if (this.groupView) {
        // ====== 分组拖拽视图 ======
        Row({ space: 8 }) {
          this.chip('网格视图', !this.groupView, () => this.groupView = false)
          this.chip('分组拖拽(好片/废片)', this.groupView, () => this.groupView = true, '#20C997')
          Blank()
          Text(this.goodList().length + '好 / ' + this.wasteList().length + '废').fontSize(11).fontColor('#8A8A8A')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10 })

        Scroll() {
          Row({ space: 6 }) {
            ForEach(getCategories(), (c: string) => {
              this.chip(c, this.category === c, () => this.category = c)
            }, (c: string) => c)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ top: 6 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .height(34)

        Text('拖动照片跨过分界线即可更改组别（点击也可切换）')
          .fontSize(10).fontColor('#8A8A8A').width('100%')
          .padding({ left: 16, right: 16, top: 6 })

        List() {
          ListItem() {
            Text('✅ 好片（保留） · ' + this.goodList().length + ' 张')
              .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#20C997')
              .width('100%').padding({ left: 16, top: 8, bottom: 8 })
          }

          ForEach(this.goodList(), (p: PhotoItem) => {
            ListItem() {
              this.groupRow(p)
            }
            .padding({ left: 12, right: 12, bottom: 6 })
          }, (p: PhotoItem) => 'g' + p.uri + p.name + p.isWaste)

          ListItem() {
            Text('🗑 废片（可手动移回好片） · ' + this.wasteList().length + ' 张')
              .fontSize(13).fontWeight(FontWeight.Bold).fontColor('#E53935')
              .width('100%').padding({ left: 16, top: 12, bottom: 8 })
          }

          ForEach(this.wasteList(), (p: PhotoItem) => {
            ListItem() {
              this.groupRow(p)
            }
            .padding({ left: 12, right: 12, bottom: 6 })
          }, (p: PhotoItem) => 'w' + p.uri + p.name + p.isWaste)
        }
        .enableEditMode(true)
        .onItemMove((from: number, to: number): boolean => {
          this.onMove(from, to);
          return true;
        })
        .layoutWeight(1)
        .scrollBar(BarState.Auto)

        Blank().height(10)
      } else {
        // ====== 网格视图 ======
        Scroll() {
          Column() {
            Row({ space: 8 }) {
              this.chip('网格视图', !this.groupView, () => this.groupView = false)
              this.chip('分组拖拽(好片/废片)', this.groupView, () => this.groupView = true, '#20C997')
              Blank()
              Text(this.filtered().length + ' 张').fontSize(12).fontColor('#8A8A8A')
            }
            .width('100%')
            .margin({ top: 10 })

            // 筛选
            Row({ space: 8 }) {
              ForEach(['全部', '保留', '废片'], (f: string) => {
                this.chip(f, this.filter === f, () => this.filter = f)
              }, (f: string) => f)
              Blank()
            }
            .width('100%')
            .margin({ top: 8 })

            // 分类
            Scroll() {
              Row({ space: 6 }) {
                ForEach(getCategories(), (c: string) => {
                  this.chip(c, this.category === c, () => this.category = c)
                }, (c: string) => c)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
            .margin({ top: 6 })

            if (this.analyzed) {
              Text('废片(全黑/太模糊)已识别可手动移回 · 分类支持 人物/景物/生日派对/文案/夜景/自拍')
                .fontSize(10)
                .fontColor('#8A8A8A')
                .width('100%')
                .margin({ top: 8 })
            }

            // 照片网格
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              ForEach(this.filtered(), (p: PhotoItem) => {
                this.photoCell(p)
              }, (p: PhotoItem) => p.uri + p.name + p.isWaste + this.poseMode)
            }
            .width('100%')
            .margin({ top: 8 })

            // 被拍摄者姿态参考
            if (this.poseMode && this.analyzed && this.subjectPhoto() !== undefined) {
              this.subjectPanel(this.subjectPhoto()!)
            }

            // 摄影师建议
            if (this.analyzed && this.advice.length > 0) {
              Row() {
                Text('📷 摄影师文字建议（大模型生成）').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                Blank()
                Text('每张好片一条').fontSize(11).fontColor('#8A8A8A')
              }
              .width('100%')
              .margin({ top: 20, bottom: 8 })

              ForEach(this.advice, (a: PhotoAdvice, idx: number) => {
                this.adviceCard(a, '好片' + (idx + 1))
              }, (a: PhotoAdvice, idx: number) => a.angle + idx)
            }

            // 通用机位知识
            Row() {
              Text('📸 通用拍摄机位参考').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
              Blank()
              Text('来自优质Plog构图分析').fontSize(11).fontColor('#8A8A8A')
            }
            .width('100%')
            .margin({ top: 20, bottom: 8 })

            ForEach(this.tips, (t: CameraTip) => {
              this.tipCard(t)
            }, (t: CameraTip) => t.subject + t.angle)

            Text('姿态&机位说明：检测到人→提取多人骨架（不同颜色=不同的人），给被拍摄者摆姿参考，同时给摄影师生成机位/光线文字建议；'
                + '无人物时只给摄影师构图建议。')
              .fontSize(11)
              .fontColor('#5D5D5D')
              .lineHeight(17)
              .width('100%')
              .padding(12)
              .backgroundColor('#FFF7E6')
              .borderRadius(12)
              .margin({ top: 4 })

            Blank().height(30)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }
}
