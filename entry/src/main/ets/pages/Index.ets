import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { getTemplates, Template } from '../model/Data';

@Entry
@Component
struct Index {
  @State templates: Template[] = getTemplates();
  @State picked: string[] = [];

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
            this.featureCard('🎨', '模板拆解', 'AI提取优质Plog的元素与排版，可编辑复用', 'pages/Editor')
            this.featureCard('👥', '多人协同', '共同编辑、版本记录、语音/BGM记录', 'pages/Editor')
          }
          .width('100%')

          Row({ space: 12 }) {
            this.featureCard('📸', '拍摄机位', '人物/景物机位参考、仰拍俯拍姿势建议', 'pages/Camera')
            this.featureCard('🗂️', '照片筛选', '批量上传去废片、按人物/描述分类', 'pages/Camera')
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

  @Builder
  templateCard(t: Template) {
    Row({ space: 12 }) {
      Image(t.cover === 'sample1' ? $r('app.media.sample1') :
        t.cover === 'sample2' ? $r('app.media.sample2') : $r('app.media.sample3'))
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
