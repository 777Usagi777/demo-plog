import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { AIService } from '../model/LLM';

// 灵感社区仅使用本地演示数据，模板映射到现有编辑器。
interface InspirationItem {
  id: string;
  title: string;
  author: string;
  avatar: string;
  color: string;
  cover: Resource;
  category: string;
  likes: number;
  comments: number;
}

@Entry
@Component
struct Index {
  @State activeTab: number = 0;
  @State category: string = '全部';
  @State likedIds: string[] = [];
  private posts: InspirationItem[] = [
    { id: 't1', title: '把周末装进一张旅行日记', author: '小岛日记', avatar: '岛', color: '#E5A46E',
      cover: $r('app.media.demo1'), category: '旅行', likes: 1286, comments: 38 },
    { id: 't2', title: '一杯咖啡的时间 ☕', author: '拿铁不加糖', avatar: '拿', color: '#A0846C',
      cover: $r('app.media.sample3'), category: '美食', likes: 862, comments: 24 },
    { id: 't3', title: '今天也要好好穿搭', author: '阿橙的衣橱', avatar: '橙', color: '#8CA58A',
      cover: $r('app.media.demo6'), category: '穿搭', likes: 2341, comments: 67 },
    { id: 't4', title: '生日快乐，永远热烈！', author: '桃子汽水', avatar: '桃', color: '#D995A3',
      cover: $r('app.media.demo6'), category: '日常', likes: 956, comments: 42 },
    { id: 't5', title: '城市漫游 · 收集路过的风景', author: '出走的云', avatar: '云', color: '#829AB8',
      cover: $r('app.media.demo2'), category: '旅行', likes: 1768, comments: 53 },
    { id: 't6', title: '窝在家里的慢时光', author: '慢慢生活', avatar: '慢', color: '#B29F88',
      cover: $r('app.media.demo6'), category: '日常', likes: 623, comments: 19 }
  ];

  aboutToAppear(): void {
    AIService.init(getContext(this)).catch((e: Error) => {
      console.error('AI init fail', JSON.stringify(e));
    });
  }

  filteredPosts(): InspirationItem[] {
    return this.posts.filter((item: InspirationItem) => this.category === '全部' || item.category === this.category);
  }

  toggleLike(id: string): void {
    this.likedIds = this.likedIds.includes(id) ? this.likedIds.filter((value: string) => value !== id)
      : this.likedIds.concat([id]);
  }

  openTemplate(id: string): void {
    router.pushUrl({ url: 'pages/Editor', params: { 'tid': id } });
  }

  @Builder
  softBackdrop() {
    Stack() {
      Column().width('100%').height('100%')
        .linearGradient({ angle: 160, colors: [['#EAF9FF', 0], ['#F8FDFF', 0.48], ['#FFFDF7', 1]] })
      Circle().width(180).height(180).fill('#55BDEEFF').blur(40).position({ x: -54, y: 54 })
      Circle().width(220).height(220).fill('#45FFE5B8').blur(48).position({ x: 210, y: 170 })
      Circle().width(160).height(160).fill('#33A7E7FF').blur(44).position({ x: 86, y: 520 })
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
  }

  @Builder
  tabLabel(index: number, icon: string, title: string) {
    Row({ space: 8 }) {
      Text(icon).fontSize(20).fontColor(this.activeTab === index ? '#075985' : '#72808A')
      Text(title).fontSize(15).fontWeight(this.activeTab === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.activeTab === index ? '#075985' : '#415B68')
    }.layoutWeight(1).height(48).justifyContent(FlexAlign.Center).borderRadius(24)
    .backgroundColor(this.activeTab === index ? '#8FE3FF' : '#00FFFFFF')
    .border({ width: this.activeTab === index ? 1 : 0, color: '#F5FDFF' })
    .shadow({ radius: this.activeTab === index ? 14 : 0, color: '#3262CFFF', offsetY: 5 })
    .animation({ duration: 240, curve: Curve.EaseOut })
    .onClick(() => { this.activeTab = index; })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      this.softBackdrop()
      Column() {
        Tabs({ index: this.activeTab }) {
          TabContent() { this.creationPage() }
          TabContent() { this.inspirationPage() }
        }.barHeight(0).layoutWeight(1).width('100%')
        .onChange((index: number) => { this.activeTab = index; })
        Row({ space: 6 }) {
          this.tabLabel(0, '✎', '创作')
          Divider().vertical(true).height(26).color('#55BAE6F8')
          this.tabLabel(1, '✧', '灵感')
        }.width('92%').height(62).padding({ left: 7, right: 7 })
        .backgroundColor('#E8FFFFFF').borderRadius(31)
        .border({ width: 1, color: '#DFF9FF' })
        .shadow({ radius: 16, color: '#248BD3F5', offsetY: 5 })
        .margin({ top: 8, bottom: 14 })
      }.width('100%').height('100%')
    }.width('100%').height('100%').backgroundColor('#EAF9FF')
  }
  @Builder
  creationPage() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 6 }) {
          Text('创作').fontSize(29).fontWeight(FontWeight.Bold).fontColor('#22303A')
          Text('把日常的小事，变成值得收藏的故事。').fontSize(13).fontColor('#72808A')
        }.width('100%').alignItems(HorizontalAlign.Start).margin({ top: 24, bottom: 6 })

        Column({ space: 12 }) {
          Text('今天，想记录什么？').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#164E63')
          Text('选几张照片，开始你的第一篇 Plog').fontSize(13).fontColor('#527D91')
          Button('＋ 从相册开始创作').fontSize(15).fontWeight(FontWeight.Medium)
            .width('100%').height(46).backgroundColor('#8FE3FF').fontColor('#075985').border({ width: 1, color: '#F5FDFF' }).shadow({ radius: 14, color: '#3062CFFF', offsetY: 5 })
            .margin({ top: 8 }).onClick(() => this.pickPhotos())
        }.width('100%').padding(22).borderRadius(26).linearGradient({ angle: 130, colors: [['#CFF2FF', 0], ['#F2FCFF', 0.65], ['#FFF4DF', 1]] }).border({ width: 1, color: '#FFFFFF' }).shadow({ radius: 22, color: '#22A7D7F5', offsetY: 9 })
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text('创作工具').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#22303A')
          Blank()
          Text('让记录更轻松').fontSize(12).fontColor('#72808A')
        }.width('100%').margin({ top: 6 })
        Row({ space: 12 }) {
          this.featureCard('🎨', '模板拆解', '提取排版与素材，组合你的故事', 'pages/Editor')
          this.featureCard('👥', '多人协同', '和朋友一起，记录同一份快乐', 'pages/Editor')
        }.width('100%')
        Row({ space: 12 }) {
          this.featureCard('📸', '拍摄机位', '找个好角度，留下自然的瞬间', 'pages/Camera')
          this.featureCard('🗂️', '照片筛选', '批量选片，发现值得留下的照片', 'pages/Camera')
        }.width('100%')

        Row({ space: 12 }) {
          Text('✦').fontSize(26).fontColor('#1787C7')
          Column({ space: 5 }) {
            Text('AI 拆解试试看').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#22303A')
            Text('从示例中发现排版巧思').fontSize(12).fontColor('#72808A')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text('→').fontSize(20).fontColor('#1787C7')
        }.width('100%').padding(18).backgroundColor('#A6EAF7FF').borderRadius(22).border({ width: 1, color: '#FFFFFF' })
        .onClick(() => this.useAiAnalyze())

        Row({ space: 12 }) {
          Text('🤖').fontSize(24)
          Column({ space: 5 }) {
            Text('模型接入').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#22303A')
            Text('配置 API Key，启用真实 AI').fontSize(12).fontColor('#72808A')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text('去配置 ›').fontSize(13).fontColor('#1787C7')
        }.width('100%').padding(18).backgroundColor('#BFFFFFFF').borderRadius(22).border({ width: 1, color: '#DDF7FF' }).shadow({ radius: 14, color: '#18A7D7F5', offsetY: 5 })
        .onClick(() => { router.pushUrl({ url: 'pages/Settings' }); })
        Blank().height(12)
      }.width('100%').padding({ left: 20, right: 20 })
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }

  @Builder
  featureCard(icon: string, title: string, desc: string, url: string) {
    Column({ space: 8 }) {
      Text(icon).fontSize(25).width(46).height(46).textAlign(TextAlign.Center).backgroundColor('#EDFAFF').borderRadius(17).border({ width: 1, color: '#FFFFFF' })
      Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#22303A')
      Text(desc).fontSize(12).fontColor('#72808A').maxLines(2).lineHeight(18)
    }.layoutWeight(1).height(162).padding(16).backgroundColor('#BFFFFFFF').borderRadius(22).border({ width: 1, color: '#DDF7FF' }).shadow({ radius: 16, color: '#20A7D7F5', offsetY: 6 })
    .alignItems(HorizontalAlign.Start)
    .onClick(() => { router.pushUrl({ url: url }); })
  }

  @Builder
  inspirationPage() {
    Column() {
      Row() {
        Column({ space: 6 }) {
          Text('灵感').fontSize(29).fontWeight(FontWeight.Bold).fontColor('#22303A')
          Text('发现好模板，让灵感在这里相遇').fontSize(13).fontColor('#72808A')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text('PLOG\n社区').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#1787C7')
          .textAlign(TextAlign.Center).lineHeight(17).padding(10).backgroundColor('#DFF5FF').borderRadius(14)
      }.width('100%').padding({ left: 20, right: 20, top: 24, bottom: 20 })

      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 12 }) {
            Column({ space: 8 }) {
              Text('本周灵感精选').fontSize(11).fontColor('#668794')
              Text('生活没有模板\n创意可以分享').fontSize(20).fontWeight(FontWeight.Bold)
                .fontColor('#28566A').lineHeight(27)
              Text('借一份灵感，写自己的故事 ↗').fontSize(11).fontColor('#668794')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text('✧').fontSize(54).fontColor('#78CDEB').width(80).textAlign(TextAlign.Center)
          }.width('100%').padding(16).linearGradient({ angle: 120, colors: [['#D8F4FF', 0], ['#F0FAFF', 0.55], ['#FFF4DE', 1]] }).borderRadius(24).border({ width: 1, color: '#FFFFFF' }).shadow({ radius: 18, color: '#20A7D7F5', offsetY: 7 })

          Scroll() {
            Row({ space: 10 }) {
              ForEach(['全部', '旅行', '美食', '穿搭', '日常'], (label: string) => {
                Text(label).fontSize(13).fontWeight(this.category === label ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.category === label ? '#075985' : '#386276')
                  .padding({ left: 19, right: 19, top: 9, bottom: 9 })
                  .backgroundColor(this.category === label ? '#95E3FF' : '#9EFFFFFF').borderRadius(20).border({ width: 1, color: '#D0F2FF' })
                  .onClick(() => { this.category = label; })
              }, (label: string) => label)
            }
          }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)

          Row() {
            Text('大家都在创作').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#22303A')
            Blank()
            Text('社区预览 · 示例内容').fontSize(10).fontColor('#9B9EAA')
          }.width('100%')
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(this.filteredPosts(), (item: InspirationItem) => {
              this.inspirationCard(item)
            }, (item: InspirationItem) => item.id)
          }.width('100%')
          Text('灵感不止于此，下一份创意来自你').fontSize(12).fontColor('#A0A5AF')
            .margin({ bottom: 24 })
        }.width('100%').padding({ left: 16, right: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%')
  }

  @Builder
  inspirationCard(item: InspirationItem) {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Image(item.cover).width('100%').height(174).objectFit(ImageFit.Cover)
        Column({ space: 4 }) {
          Text(item.id === 't2' ? 'coffee time' : item.id === 't1' ? 'WEEKEND' : item.id === 't3' ? 'OOTD' : item.id === 't4' ? 'with friends' : item.id === 't5' ? 'CITY WALK' : 'SLOW LIFE')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            .textShadow({ radius: 8, color: '#66000000', offsetY: 2 })
          Text(item.category + ' / 生活切片').fontSize(10).fontColor('#FFFFFF')
        }.width('100%').height(174).justifyContent(FlexAlign.End).alignItems(HorizontalAlign.Start)
        .padding({ left: 14, right: 12, bottom: 14 })
        .linearGradient({ angle: 180, colors: [['#00000000', 0.35], ['#700E2630', 1]] })
        Text(item.category + '模板').fontSize(10).fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('rgba(0,0,0,0.25)').borderRadius(8).margin(10)
      }.width('100%').onClick(() => this.openTemplate(item.id))
      Column({ space: 10 }) {
        Text(item.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#22303A')
          .maxLines(2).height(40).width('100%').onClick(() => this.openTemplate(item.id))
        Row({ space: 6 }) {
          Text(item.avatar).fontSize(10).fontColor(Color.White).textAlign(TextAlign.Center)
            .width(23).height(23).backgroundColor(item.color).borderRadius(12)
          Text(item.author).fontSize(11).fontColor('#72808A').maxLines(1).layoutWeight(1)
        }.width('100%')
        Row() {
          Text((this.likedIds.includes(item.id) ? '♥ ' : '♡ ') +
            (item.likes + (this.likedIds.includes(item.id) ? 1 : 0)))
            .fontSize(12).fontColor(this.likedIds.includes(item.id) ? '#E87588' : '#72808A')
            .padding({ top: 8, bottom: 8, right: 8 }).onClick(() => this.toggleLike(item.id))
          Blank()
          Text('评论 ' + item.comments).fontSize(11).fontColor('#72808A')
        }.width('100%')
      }.width('100%').padding({ left: 12, right: 12, top: 12, bottom: 4 })
    }.width('48%').backgroundColor('#D9FFFFFF').borderRadius(22).border({ width: 1, color: '#E4F7FF' }).shadow({ radius: 16, color: '#1AA7D7F5', offsetY: 6 }).clip(true).margin({ bottom: 16 })
  }

  pickPhotos(): void {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const opt = new picker.PhotoSelectOptions();
      opt.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      opt.maxSelectNumber = 9;
      photoPicker.select(opt).then((res: picker.PhotoSelectResult) => {
        if (res.photoUris.length > 0) {
          router.pushUrl({ url: 'pages/Editor', params: { 'photos': res.photoUris.join(',') } });
        }
      }).catch((err: Error) => { console.error('pick fail', JSON.stringify(err)); });
    } catch (e) {
      console.error('picker error', JSON.stringify(e));
    }
  }

  useAiAnalyze(): void {
    router.pushUrl({ url: 'pages/Editor', params: { 'ai': '1' } });
  }
}
