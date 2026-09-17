/**
 * 模型接入配置页：填入各厂商 API Key，保存后即启用真实模型；留空则用内置模拟。
 */
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AIService } from '../model/LLM';

@Entry
@Component
struct Settings {
  @State deepseek: string = '';
  @State dashscope: string = '';
  @State baiduAk: string = '';
  @State baiduSk: string = '';

  aboutToAppear(): void {
    const k = AIService.getKeys();
    this.deepseek = k.deepseek;
    this.dashscope = k.dashscope;
    this.baiduAk = k.baiduAk;
    this.baiduSk = k.baiduSk;
  }

  async save(): Promise<void> {
    const ok = await AIService.saveKeys({
      deepseek: this.deepseek,
      dashscope: this.dashscope,
      baiduAk: this.baiduAk,
      baiduSk: this.baiduSk
    });
    promptAction.showToast({
      message: ok ? '已保存，真实模型已启用（未填的项继续用模拟）' : '保存失败，请重试'
    });
  }

  @Builder
  keyInput(title: string, url: string, hint: string, value: string, onChange: (v: string) => void) {
    Column() {
      Row() {
        Column() {
          Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
          Text(url).fontSize(10).fontColor('#8A8A8A').margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      TextInput({ placeholder: hint, text: value })
        .width('100%')
        .height(44)
        .fontSize(13)
        .margin({ top: 8 })
        .type(InputType.Normal)
        .onChange((v: string) => onChange(v))
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(14)
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(16).fontColor('#3A7BFF').onClick(() => router.back())
        Blank()
        Text('模型接入').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
        Blank()
        Text('').width(48)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })

      Scroll() {
        Column({ space: 12 }) {
          Text('接入后自动替换内置模拟结果；不填 Key 或调用失败时自动回退模拟，不影响功能使用。')
            .fontSize(12).fontColor('#8A8A8A').lineHeight(18)
            .width('100%')

          // 功能映射说明
          Column({ space: 4 }) {
            Text('功能 → 模型').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            Text('· 拍摄建议/照片描述文字 → DeepSeek').fontSize(12).fontColor('#5D5D5D')
            Text('· 模板拆解/照片分类筛选/人物检测 → 通义千问 (qwen-vl-plus)').fontSize(12).fontColor('#5D5D5D')
            Text('· 姿态骨架 → 百度人体关键点').fontSize(12).fontColor('#5D5D5D')
            Text('· 长按抠图 → 百度人像分割').fontSize(12).fontColor('#5D5D5D')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFF7E6')
          .borderRadius(14)
          .alignItems(HorizontalAlign.Start)

          this.keyInput('DeepSeek API Key', 'platform.deepseek.com',
            'sk-...（用于拍摄建议、照片文字描述）',
            this.deepseek, (v: string) => { this.deepseek = v; })

          this.keyInput('通义千问 DashScope Key', 'bailian.console.aliyun.com',
            'sk-...（用于模板拆解、照片筛选分类、人物检测）',
            this.dashscope, (v: string) => { this.dashscope = v; })

          this.keyInput('百度智能云 API Key', 'console.bce.baidu.com',
            'API Key（用于人体姿态骨架 + 人像抠图）',
            this.baiduAk, (v: string) => { this.baiduAk = v; })

          this.keyInput('百度智能云 Secret Key', 'console.bce.baidu.com',
            'Secret Key（与上方 API Key 配套）',
            this.baiduSk, (v: string) => { this.baiduSk = v; })

          Button('保存并启用')
            .width('100%')
            .height(48)
            .backgroundColor('#3A7BFF')
            .fontColor(Color.White)
            .borderRadius(24)
            .onClick(() => this.save())

          Blank().height(20)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6FA')
  }
}
