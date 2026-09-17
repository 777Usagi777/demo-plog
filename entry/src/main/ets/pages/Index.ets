import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { getTemplates, Template } from '../model/Data';
import { AIService } from '../model/LLM';

@Entry
@Component
struct Index {
  @State templates: Template[] = getTemplates();
  @State picked: string[] = [];

  aboutToAppear(): void {
    AIService.init(getContext(this)).catch((e: Error) => {
      console.error('AI init fail', JSON.stringify(e));
    });
  }

  build() {
    Column() {
      // 顶部
      Column() {
        Text('Plog 助手')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Text('拆解 · 协同 · 机位 · 筛选，一站式记录生活')
          .fontSize(13)
          .fontColor('#8A8A8A')
          .margin({ top: 6 })
      }
      .width('100%')
      .padding({ top: 20, bottom: 16 })
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 20 })

      Scroll() {
        Column({ space: 12 }) {
          // 功能卡片
          Row({ space: 12 }) {
            this.featureCard('🎨', '模板拆解', '多图导入·长按抠图·素材库·编辑组合·BGM/MP3', 'pages/Editor')
            this.featureCard('👥', '多人协同', '微信邀请·同图写画拖拽·元素锁定防冲突', 'pages/Editor')
          }
          .width('100%')

          Row({ space: 12 }) {
            this.featureCard('📸', '拍摄机位', '多人骨架姿态参考+摄影师文字建议', 'pages/Camera')
            this.featureCard('🗂️', '照片筛选', '批量上传·好片废片分组拖拽·人物/生日分类', 'pages/Camera')
          }
          .width('100%')

          // 从相册选择
          Button('从相册选图创建 Plog')
            .width('100%')
            .height(48)
            .backgroundColor('#3A7BFF')
            .fontColor(Color.White)
            .borderRadius(24)
            .onClick(() => this.pickPhotos())

          // 模型接入
          Row() {
            Text('🤖 模型接入').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
            Text('配置 API Key，启用真实 AI').fontSize(11).fontColor('#8A8A8A')
            Blank()
            Text('去配置 →').fontSize(13).fontColor('#3A7BFF')
          }
          .width('100%')
          .height(52)
          .padding({ left: 16, right: 16 })
          .backgroundColor(Color.White)
          .borderRadius(16)
          .onClick(() => {
            router.pushUrl({ url: 'pages/Settings' });
          })

          // 模板库
          Row() {
            Text('模板库').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            Blank()
            Text('AI拆解').fontSize(13).fontColor('#3A7BFF')
              .onClick(() => this.useAiAnalyze())
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })

          ForEach(this.templates, (t: Template) => {
            this.templateCard(t)
          }, (t: Template) => t.id)

          Blank().height(30)
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }

  @Builder
  featureCard(icon: string, title: string, desc: string, url: string) {
    Column() {
      Text(icon).fontSize(26)
      Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A').margin({ top: 8 })
      Text(desc).fontSize(11).fontColor('#8A8A8A').margin({ top: 4 }).maxLines(2)
    }
    .layoutWeight(1)
    .height(150)
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      router.pushUrl({ url: url });
    })
  }

  uriOrRes(p: string): Resource | string {
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

  @Builder
  templateCard(t: Template) {
    Row({ space: 12 }) {
      Image(this.uriOrRes(t.cover))
        .width(90)
        .height(110)
        .borderRadius(10)
        .objectFit(ImageFit.Cover)
      Column({ space: 6 }) {
        Text(t.name).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
        Text(t.desc).fontSize(12).fontColor('#8A8A8A').maxLines(2)
        Text('点击编辑 →').fontSize(12).fontColor('#3A7BFF')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .onClick(() => {
      router.pushUrl({ url: 'pages/Editor', params: { 'tid': t.id } });
    })
  }

  pickPhotos(): void {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const opt = new picker.PhotoSelectOptions();
      opt.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      opt.maxSelectNumber = 9;
      photoPicker.select(opt).then((res: picker.PhotoSelectResult) => {
        if (res.photoUris.length > 0) {
          const uris = res.photoUris.join(',');
          router.pushUrl({ url: 'pages/Editor', params: { 'photos': uris } });
        }
      }).catch((err: Error) => {
        console.error('pick fail', JSON.stringify(err));
      });
    } catch (e) {
      console.error('picker error', JSON.stringify(e));
    }
  }

  useAiAnalyze(): void {
    router.pushUrl({ url: 'pages/Editor', params: { 'ai': '1' } });
  }
}
