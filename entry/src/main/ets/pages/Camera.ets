import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import {
  PhotoItem, CameraTip, analyzePhotos, getCameraTips
} from '../model/Data';

@Entry
@Component
struct CameraPage {
  @State photos: PhotoItem[] = [
    new PhotoItem('sample1', 'sample1', true, false, '待分析', ''),
    new PhotoItem('sample2', 'sample2', true, false, '待分析', ''),
    new PhotoItem('sample3', 'sample3', true, false, '待分析', ''),
    new PhotoItem('sample4', 'sample4', true, true, '待分析', '全黑模糊废片示例'),
  ];
  @State filter: string = '全部'; // 全部/保留/废片
  @State analyzed: boolean = false;
  @State tips: CameraTip[] = getCameraTips();

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

  filtered(): PhotoItem[] {
    if (this.filter === '保留') {
      return this.photos.filter((p: PhotoItem) => !p.isWaste);
    }
    if (this.filter === '废片') {
      return this.photos.filter((p: PhotoItem) => p.isWaste);
    }
    return this.photos;
  }

  toggleWaste(p: PhotoItem): void {
    const idx = this.photos.findIndex((x: PhotoItem) => x.uri === p.uri && x.name === p.name);
    if (idx < 0) {
      return;
    }
    const copy = new PhotoItem(p.uri, p.name, p.isResource, !p.isWaste, p.category, p.desc);
    const arr = this.photos.slice();
    arr[idx] = copy;
    this.photos = arr;
  }

  async onAnalyze(): Promise<void> {
    this.photos = analyzePhotos(this.photos);
    this.analyzed = true;
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
        add.push(new PhotoItem(res.photoUris[i], 'upload' + i, false, false, '待分析', ''));
      }
      this.photos = this.photos.concat(add);
    } catch (e) {
      console.error('add photos fail', JSON.stringify(e));
    }
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

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).fontColor('#3A7BFF').onClick(() => router.back())
        Blank()
        Text('智能选片 & 机位参考').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
        Blank()
        Text('＋批量').fontSize(15).fontColor('#3A7BFF').onClick(() => this.onAdd())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 })

      Scroll() {
        Column() {
          // AI 分析操作
          Row({ space: 10 }) {
            Button(this.analyzed ? '重新 AI 分析' : '🤖 AI 分析：去废片 + 分类')
              .layoutWeight(1)
              .height(42)
              .backgroundColor(this.analyzed ? '#20C997' : '#3A7BFF')
              .fontColor(Color.White)
              .borderRadius(21)
              .onClick(() => this.onAnalyze())
            Button('拍照机位参考')
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#FF6B6B')
              .fontColor(Color.White)
              .borderRadius(21)
              .onClick(() => this.scrollToTips())
          }
          .width('100%')
          .margin({ top: 4 })

          if (this.analyzed) {
            Text('分析说明：废片(全黑/太模糊)已识别并可手动保留 · 保留有"氛围感"的模糊照片')
              .fontSize(11)
              .fontColor('#8A8A8A')
              .width('100%')
              .margin({ top: 8 })
          }

          // 筛选
          Row({ space: 8 }) {
            ForEach(['全部', '保留', '废片'], (f: string) => {
              Text(f)
                .fontSize(12)
                .fontColor(this.filter === f ? Color.White : '#333')
                .backgroundColor(this.filter === f ? '#3A7BFF' : Color.White)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .borderRadius(14)
                .onClick(() => this.filter = f)
            }, (f: string) => f)
            Blank()
            Text(this.filtered().length + ' 张').fontSize(12).fontColor('#8A8A8A')
          }
          .width('100%')
          .margin({ top: 12 })

          // 照片网格
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(this.filtered(), (p: PhotoItem) => {
              this.photoCell(p)
            }, (p: PhotoItem) => p.uri + p.name + p.isWaste)
          }
          .width('100%')
          .margin({ top: 8 })

          // 机位参考
          Row() {
            Text('📸 拍摄机位参考').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            Blank()
            Text('来自优质Plog构图分析').fontSize(11).fontColor('#8A8A8A')
          }
          .width('100%')
          .margin({ top: 20, bottom: 8 })

          ForEach(this.tips, (t: CameraTip) => {
            this.tipCard(t)
          }, (t: CameraTip) => t.subject + t.angle)

          Text('人物姿态建议：站姿全身照建议平行或轻微仰拍；坐姿/桌面场景用俯拍突出生活感；'
              + '摆拍前先确定光线方向，逆光时人脸自动提亮。')
            .fontSize(12)
            .fontColor('#5D5D5D')
            .lineHeight(18)
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
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  scrollToTips(): void {
    // Demo：机位建议在页面下方，滚动到底部
    this.tips = this.tips.slice();
  }
}
