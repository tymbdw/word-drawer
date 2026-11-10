# 词隙 · Window Word

一块贴在屏幕边缘的磨砂玻璃，用来背单词。Windows 11 桌面端，.NET 8 + WPF。

不是网页壳子，也没有 Electron：窗口是 WPF 的分层窗口（`AllowsTransparency`），玻璃效果是自己做的——抓取窗口背后的桌面、高斯模糊、再叠雾面和光泽，合成一张位图当作窗口背景。

## 功能

- **真实磨砂玻璃**：毛玻璃背后的内容是真的（拖动时实时重采样），支持透明度滑档、雾银/冰蓝/夜蓝三套材质
- **贴边抽屉**：可停靠左右侧自动收起、悬停唤出；也可以拖到屏幕任意位置固定，位置会记住
- **三本内置词书**：四级 3847 词 / 六级 5402 词 / 考研 4796 词，可随时切换，进度分开统计
- **FSRS-5 复习调度**：认识的词按记忆曲线排下次复习，点「不认识」的词会在 3 个词后重考一次，不计入今日已学
- **学习计时**：只有键鼠有动静才计时，静默 3 分钟自动暂停
- **贡献热力图**：最近 90 天的学习密度，点格子看当天数据
- **离线朗读**：内置 Piper 神经 TTS（`en_US-lessac-medium`），不依赖系统语音，任何机器装完都能读

## 目录

```
src/WordDrawer.App         WPF 界面、玻璃合成、托盘
src/WordDrawer.Core        布局计算、学习计时（纯逻辑，有单测）
src/WordDrawer.Data        SQLite 数据层（词书、学习状态、每日统计）
src/WordDrawer.Review      FSRS-5 调度器
tests/                     33 个单元测试
installer/                 Inno Setup 脚本
tools/                     词书生成脚本
```

## 构建

需要 .NET 8 SDK 和 Windows 10 1607+ / 11。

```bash
dotnet build WordDrawer.sln -c Debug
dotnet test WordDrawer.sln -c Debug
```

发布单文件并打安装包：

```bash
dotnet publish src/WordDrawer.App -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o build/publish
ISCC.exe /DAppVersion=$(cat version.txt) installer/WordDrawer.iss
```

## 两个不在仓库里的大文件

**语音引擎**（`src/WordDrawer.App/piper/`，约 98MB）。安装包会把它装到
`%LOCALAPPDATA%\WordDrawer\piper` —— 放这里不是随便选的：Piper 内部的 espeak-ng
读不了中文路径（`Illegal byte sequence`），而安装目录默认是 `D:\词隙`。

```bash
# 引擎
curl -L -o piper.zip https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_windows_amd64.zip
# 模型（HuggingFace 在国内可用 hf-mirror.com 镜像）
curl -L -o en_US-lessac-medium.onnx \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx
```

**ECDICT 词典**（`ecdict.csv`，65MB）。词书是用它的标签子集生成的，脚本在
`tools/extract_books.py`，产物（三本 JSON）已提交在 `Assets/` 下：

```bash
cd tools && python extract_books.py cet4 cet4-2027.json
```

## 数据

学习记录在 `%LOCALAPPDATA%\WordDrawer\worddrawer.db`，和安装目录分离，卸载重装不丢。

## 许可

- 词库数据来自 [ECDICT](https://github.com/skywind3000/ECDICT)（MIT），只保留了词条、词性和精简释义
- 语音引擎 [Piper](https://github.com/rhasspy/piper)（MIT）
- 应用本身代码：MIT，见 LICENSE；第三方组件的完整许可文本见 THIRD-PARTY.md
