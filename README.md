# Plog 制作助手（HarmonyOS Demo）

适配 **HarmonyOS NEXT / 鸿蒙 OS 26（API 26）**，目标机型 **华为 Mate 80 Pro**。

一个"Plog 记录 + AI 智能辅助"的创作工具 Demo，覆盖四大能力：

| 能力 | 说明 | 对应页面 |
|------|------|---------|
| ① 模板拆解与复用 | 从优质 Plog 截图提取元素/排版（模拟大模型），模板可**拖拽平移、双指缩放、增删、改文字**，全部可编辑 | 编辑器 Editor |
| ② 多人协同记录 | 共同编辑（模拟协作者光标）、**版本记录与回退**、文字/语音/ BGM 记录、标签分类、时间节点 | 编辑器 Editor |
| ③ 拍摄机位参考 | 人物/景物机位建议：仰拍、俯拍、平拍、45° 斜拍 + 人物姿态建议 | 智能选片 Camera |
| ④ 批量选片 | 上传/相册批量选图，**识别全黑/模糊废片**（可手动保留氛围感照片），按人物/景物/描述初步分类 | 智能选片 Camera |

---

## 运行方法（Mate 80 Pro 真机）

### 前提
- 电脑安装 **DevEco Studio 26**（本机路径 `D:\deveco\DevEco Studio`，SDK 为 HarmonyOS 26.0.0 / API 26）
- 真机 **Mate 80 Pro** 开启 **开发者模式 + USB 调试**
  - 设置 → 关于本机 → 连点"版本号"7 次开启开发者模式
  - 设置 → 系统与更新 → 开发人员选项 → 打开 **USB 调试**
- USB 连接电脑，手机弹窗选"允许调试"

### 方式 A：DevEco Studio 一键运行（推荐，自动签名）
1. DevEco Studio → `File > Open` 选择目录 `D:\project\gewu-demo`
2. 首次打开等待同步（`ohpm install` 自动执行，本工程无三方依赖，很快）
3. `File > Project Structure > Signing Configs` → 勾选 **Automatically generate signature**（需登录华为账号，首次会自动生成调试证书）
4. 顶部 Run 设备的列表选择你的 `Mate 80 Pro`
5. 点绿色 ▶ Run，自动安装并启动

### 方式 B：命令行构建
```
D:\deveco\DevEco Studio\tools\ohpm\bin\ohpm.bat install
D:\deveco\DevEco Studio\tools\hvigor\bin\hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`
命令行产物未签名，仍需要按方式 A 在 DevEco 里配置一次签名后，可用 `hdc install` 安装：
```
D:\deveco\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe install entry\build\default\outputs\default\entry-default-signed.hap
```

### 真机设备
当前已检测到设备：`5SM0125728000193`（可 `hdc list targets` 确认）。

---

## 功能操作指引

- **首页**：四个功能卡片入口；`从相册选图创建 Plog`（拉起系统相册，最多 9 张）；模板库 3 套内置模板（旅行/咖啡/穿搭）。
- **编辑器**：
  - 画布内元素：**单指拖拽**移动，**双指捏合**缩放，选中后可用下方 `＋/－/编辑/删除` 调整
  - `＋文字` 新增文字元素
  - `👥协同` 显示协作者在线状态与操作；`🕘版本` 查看历史版本并回退；`🎵` 选择 BGM；`🎙️语音` 模拟语音记录（真实接入见下）；标签可多选
  - 底部模板缩略图点击即"复用"成当前画布（可继续编辑）
  - `保存` 生成新版本记录
- **智能选片**：
  - `🤖 AI 分析`：内置演示把 sample4（全黑模糊）标为废片并灰度显示，其余按 人物/景物/文案 打标 + 描述
  - 点击照片可切换"废片/保留"（保留有氛围感的模糊照片）
  - 筛选：全部/保留/废片
  - `＋批量` 从相册批量加图（上限 20 张）
  - 下方为机位参考卡片 + 人物姿态建议

---

## 真实 AI 能力接入点（当前为本地模拟数据）

工程刻意保持结构简单，模拟数据集中在 `entry/src/main/ets/model/Data.ets`，替换为真实模型只需改这几个函数：

| 函数 | 真实替代方案 |
|------|-------------|
| `aiAnalyzeTemplate()` 拆解模板 | 视觉大模型（如 Qwen2.5-VL / GLM-4V / 华为盘古 CV）：截图 → 输出元素框+文字+排版参数 |
| `analyzePhotos()` 选片/分类 | 亮度直方图阈值判全黑 + 拉普拉斯方差判模糊 + VLM 生成分类与描述 |
| `getCameraTips()` 机位建议 | VLM 构图分析/姿态估计模型输出机位与姿势参数 |
| 协同编辑 | 云端：WebSocket/协同 CRDT 服务 + 服务端版本快照（OT/CRDT） |
| 语音记录 | `@kit.AudioKit` AudioCapturer 录音 → 语音转文字大模型 → 存储心情笔记 |
| BGM | 本地资源播放 + 版权音乐库 API |

大模型调用统一走 `@ohos.net.http` / `@kit.NetworkKit` 请求网关（本项目已声明 `INTERNET` 权限）。

---

## 工程结构

```
gewu-demo/
├── AppScope/                  # 应用级配置（icon、label）
├── entry/src/main/
│   ├── module.json5           # 模块与权限声明
│   ├── ets/
│   │   ├── entryability/EntryAbility.ets
│   │   ├── pages/Index.ets    # 首页：入口 + 相册选图 + 模板库
│   │   ├── pages/Editor.ets   # 编辑器：拖拽/缩放/复用/协同/版本/BGM/标签/语音
│   │   ├── pages/Camera.ets   # 智能选片 + 机位参考
│   │   └── model/Data.ets     # 数据模型 + 模拟 AI 逻辑（扩展点）
│   └── resources/             # 字符串/颜色/图标/示例照片
├── build-profile.json5        # 工程配置（API 26）
└── hvigor/                    # 构建配置
```

---

## 已知边界（Demo 范围）

- AI 能力为**本地规则模拟**，非真实模型调用（接入方式见上表）
- 协同/版本为前端模拟，无后端
- 语音记录为占位，未真正采集音频
- 相册选图使用系统 PhotoViewPicker（API 26 有更新 API，当前用兼容写法，仅告警不影响运行）
