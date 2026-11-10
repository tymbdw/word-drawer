# 交接文档

## 拖动时实时磨砂（2026-10-18）
- 原来用 `DragMove()`（阻塞消息循环），拖动中玻璃是静止的，松手才刷新。
- 改为手动拖拽 + **整屏缓存板**：按下时 `Opacity=0` → `Dispatcher.Invoke(...Render)` → `ScreenBackdrop.CaptureScreen()`（2560×1440 一次 BitBlt，约 14.7 MB）→ 恢复不透明度。之后每个 `MouseMove` 只从这块板子上裁出窗口所在矩形，走 `Cropplate()` + `ComposeFrom()`，不再碰屏幕。
- `ScreenBackdrop` 拆成四段：`Compose(rect,…)`（抓屏+合成，兼容旧调用）、`CaptureRegion`、`CaptureScreen`、`Cropplate`、`ComposeFrom`。
- 拖动帧率节流 12 ms（≈83 fps），松手后仍走一次精确采样（`FloatInPlace` / `RevealWithFreshBackdrop`）。
- 实测：合成拖拽（24 步、每步 28 ms）后窗口跟随到 480,308 并停在原地（自由放置）；拖动中截图确认玻璃里是背后编辑器的真实文字被模糊，**没有自身残影**。
- 已知取舍：板子是拖动开始那一刻的，拖动期间背后若有视频/动画不会更新；按下瞬间有一帧窗口不可见（用于避免把自己拍进去）。

## 品牌 / 图标（2026-10-18）
- 用户从 4 个方案里选了 **B「一道缝的光」**：深海军蓝圆角方（#22344A→#0E1B28 斜向渐变）+ 一条自右上到左下的发光斜缝（#7FE3FF→#2899D6，圆头，9/96 宽）+ 2.4/96 的亮芯线（#BFF0FF）。
- 生成器 `output/verify/make-logo.ps1`：GDI+ 在 1024 画布绘制后高质量缩放到 16/24/32/48/64/128/256 → `Assets/logo-*.png`；`output/verify/make-ico.py` 打成 PNG-compressed ICO（7 尺寸，38 KB）→ `Assets/worddrawer.ico`。
- 接入：csproj 的 `<ApplicationIcon>` + `<Resource>`；XAML `Icon="Assets/worddrawer.ico"`；头图改用 `Assets/logo-256.png`（原来的蓝底白 W 已删）；托盘 `LoadAppIcon()` 从资源流读同一 ico，失败回退 `SystemIcons.Application`。
- `ShowInTaskbar` 由 False 改 True；标题英文名 `WORD DRAWER` → **Window Word**。
- 托盘被 Win11 默认折叠进 ^：给 `HKCU\Control Panel\NotifyIconSettings` 中两个 WordDrawer 条目写 `IsPromoted=1`，并删除已卸载测试目录的残留条目。
- 实测：`ExtractAssociatedIcon` 取到 48x48 新图标；任务栏截图可见新图标；界面头图清晰。
- **未完成**：用户要求暂停打包，安装版仍是旧图标/旧文案。

## 安装包（2026-10-17 第十八轮）
- 工具：**Inno Setup 6.7.3**，由 winget 安装在 `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`（没有中文语言包，向导界面为英文，但应用名/快捷方式/卸载项是中文）。
- 发布：`dotnet publish src/WordDrawer.App -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o build/publish` → 单文件 157 MB（含 .NET 运行时，目标机无需装 .NET）。
- 打包：`ISCC.exe installer\WordDrawer.iss` → `build/dist/WordDrawer-Setup-0.1.0.exe`（50 MB，lzma2/max，编译 30 s）。
- 安装位置 `%LOCALAPPDATA%\Programs\WordDrawer`（**per-user，不弹 UAC**）；任务：桌面快捷方式（默认不勾）、开机自启（默认不勾，写 HKCU Run `WordDrawer`）。
- 数据仍写 `%LOCALAPPDATA%\WordDrawer\worddrawer.db`，**与安装目录分离，卸载不删**。
- **实测**：静默装到 `D:\WordDrawerTest` → 文件齐全、Run 键带引号正确、开始菜单与桌面快捷方式生成、装好的 exe 能启动；卸载后目录/Run 键/快捷方式全部清除；最后已静默安装到默认位置并从该路径启动成功（PID 15072，窗口 1912,228）。
- **坑**：测试时用 `/DIR=<repo>uild	est-install`（含空格）传参被拆成两个，装到了 `D:\Window`。Inno 的 {app} 因此截断、Run 值变成 `"D:\Window\WordDrawer.App.exe"`。测带空格的路径要么用响应文件，要么直接用无空格目录。

# 词隙（Word Drawer）项目交接说明

> 更新日期：2026-10-17  
> 项目目录：`<repo>`  
> 当前阶段：首页已完成第二轮视觉校正（文字对比度、卡片材质、主按钮、底部导航），编译 0 警告 0 错误、14/14 测试通过，截图实测差距已收敛。

## 最新停工点（重要）

- **截图验收方法已修正，旧图不可用。** WPF 主窗口是 `AllowsTransparency=True` 的分层窗口，`PrintWindow` 会把半透明内容压到黑底上（实测输出图 alpha 全 255、背景被压成 (109,116,119) 灰），`output\wpf\current-native-ui.png` 因此发暗，属采集假象。
- 正确方法见 `output\verify\capture-v5.ps1`：先铺一块与原型同色的背景板 → 把词隙窗口 `HWND_TOPMOST` → `CopyFromScreen` 抓真实合成结果 → 存 `output\wpf\<tag>-real.png`。配套脚本：`compare.ps1`（并排对比）、`zoom.ps1`（2× 局部放大）、`sample-compare.ps1`（逐点取色）、`final-check.ps1`（文字最深处亮度）、`edge-check.ps1`（边缘像素剖面）。
- 本轮对 `MainWindow.xaml` 的改动：`TextPrimary` 改 `#FF182633`、`TextSecondary` 改 `#FF5B7185`（原为 95% / 69% 半透明，实测文字比原型淡 36–50 个亮度级）；`PrimaryButton` 改全不透明 `#FF182633` 并加模糊投影；首页窗口底色 `#38E7F5FD` 对齐原型 `--glass` 的 .22；卡片改为 145° 渐变 + 模糊描边环投影（实心阴影矩形会透过半透明卡片，CSS 的 box-shadow 只画在 border-box 外）；动作行高 47、导航高 86 并补 6px 间距、对应行高 58→57。
- 实测收敛：主文字最深 L37（原型 L33），次要文字 L111（原型 L99），卡片区均值 (197,221,235)（原型 (205,221,231)），卡片填充差 −16（所用合成背景本身差 −14）。
- **尚未解决（架构级）**：窗口外投影 `0 28px 80px` 缺失（`Border` 铺满 360×520，没有留给阴影的边距）；WPF 无 letter-spacing 属性，原型的问候语 −0.52px、数字 −1.44px 未实现。
- **磨砂模糊已实现（2026-10-17 第三轮，第三轮的 XAML 分层做法已被第四轮取代，见下条）**：Win11 25H2 build 26200 上 `ACCENT_ENABLE_ACRYLICBLURBEHIND` 会卡顿、`DWMWA_SYSTEMBACKDROP_TYPE` 要求关掉 `AllowsTransparency`（会丢掉 28px 圆角），因此改为自合成：`BitBlt` 抓窗口背后桌面 → 降采样 → 模糊 → 当玻璃底图。刷新时机：启动时（此时窗口还在默认位置，不会拍到自己）、每次收起后滑出前（窗口在屏幕外）、换边/拖拽结束/托盘切换时先移出屏幕再抓。收起状态右侧 8px 自身触发条会用相邻像素抹掉。
- 雾面浓度由 `WORDDRAWER_GLASS_ALPHA`（0–255，默认 `0x62` ≈ 38%）控制，`ApplyGlassTint()` 读取；仅用于对比调档，正式版按默认值。实测 28% / 38% / 48% 三档，38% 在"看得出背后有内容"和"界面不被干扰"之间最平衡。
- **圆角已修（2026-10-17 第四轮）**：`Border.CornerRadius` **只裁它自己的 Background，不裁子元素**。之前把磨砂底图、雾面层、渐变层、高光椭圆都当子元素叠在 `Border` 里，所以四个角是方的（左上角"看着圆"只是因为背后是黑桌面、糊出来也是黑的，属于误判）。现在 `ScreenBackdrop.Compose` 把模糊底图 + 雾面 + 对角高光 + 右上 radial 高光一次性合成一张位图，直接赋给 `GlassSurface.Background`（`ImageBrush`），由 `Border` 自己带抗锯齿地裁圆。实测四角：对角线上首个不透明像素 7–9px（理论 0.293×R），边缘有 3px 抗锯齿过渡带（44→91→138→151），非硬切。同时也去掉了 XAML 里的 `BlurEffect`（模糊改在 GDI+ 里做：1/10 降采样 + 两遍 box blur + 双三次放大）。
- **离屏幕边缘 28px 悬空（2026-10-17 第五轮）**：之前窗口贴死屏幕边，右侧圆角和投影被显示器边界切掉。`DrawerLayout.VisibleLeft` 增加 `edgeGap` 参数（`DefaultEdgeGap = 28`），`MainWindow` 可见位置与 `RefreshBackdrop` 的采样矩形都传入该值；收起状态不变，仍是 `HiddenLeft` 留 8px 触发条贴屏幕边。实测右侧空隙 42 物理像素（= 28 DIP @150%），四角全部可见。`WordDrawer.Core.Tests` 新增 4 个用例，总计 18 个测试。
- **更正**：此前记录的"启动时贴哪块屏不确定、会跑到非主显示器"是**误判**。本机只有一块屏（DISPLAY1 2560×1440）；x=2548 是收起状态的位置（2560 − 8×1.5 = 2548），抓图时抽屉正好缩着，并非多屏问题。
- **窗口外投影（2026-10-17 第六轮）**：窗口尺寸由 360×520 改为 448×608，四周各留 44 DIP（`ShadowInset`）给阴影；内容仍是 360×520，所有布局坐标改用 `ContentWidth/ContentHeight` 计算后再减去 `ShadowInset`。阴影用两层 `Border` + `BlurEffect`（远光晕 blur 26 / 下移 10 / 不透明度 .34，近光晕 blur 7 / 下移 3 / .20）。收起时和抓磨砂底图前必须把它们设为 `Collapsed`：光晕会伸出 8px 触发条之外，也会被 `BitBlt` 拍进磨砂底图。实测收起后窗口 x=2482（玻璃条正好贴在屏幕边 2548），屏幕边缘 60px 内亮度全为 13（无光晕漏出），悬停触发条后回到 x=1912 展开。
- **核心功能已实现（2026-10-17 第七轮）：FSRS-5 + 复习队列**
  - 算法：`WordDrawer.Review/FsrsParameters.cs` + 重写的 `ReviewScheduler.cs`，实现 FSRS-5（19 个默认权重取自 FSRS wiki 原文，不是估的）：`S0(G)=w[G-1]`、`D0(G)=w4-e^(w5(G-1))+1`、难度线性阻尼 + 均值回归、`R(t,S)=(1+19/81·t/S)^-0.5`、成功/遗忘/同日三条稳定性公式，难度夹在 [1,10]，稳定性夹在 [0.1, 36500]。两个按钮映射 Again(1)/Good(3)。`BuildQueue` 保留"积压不限 + 新释放封顶 200"，并修正为**当天已释放的卡也计入队列但不再占用释放额度**。
  - 数据层 schema v1→v2：`StudyStates` 增加 `Difficulty`、`Repetitions`，用 `PRAGMA table_info` 做原地迁移。新增 `GetDueReviewItemsAsync`、`MarkReleasedAsync`（`ReleasedDate` 以前从没被写过，每日上限形同虚设）、`GetCardAsync`、`CountUnstudiedWordsAsync`、`GetDailyNewWordTargetAsync/Set...`（默认 50）。
  - UI：会话模型改为 `List<SessionEntry(Word, Card?)>`，学习与复习共用一条流程。「去复习」真正建队列 → 落库释放 → 开会话；反馈写库带 FSRS 的 stability/difficulty/repetitions；状态栏显示"已保存：认识 · MM-dd 再复习"；队列走完回首页报完成数。
  - 验证：29 个测试全过（Core 10 / Review 11 / Data 8）。真机端到端：点「开始学习」→「认识」→「不认识」，库内 meticulous S=3.173 D=5.2824 到期 10-20、resilient S=0.40255 D=7.1949 到期 10-18，与公式一致；点「去复习」→「认识」，二次复习走同日公式，S 由 3.173 推到 4.46686、到期 10-21，证明读的是库里已有状态而不是从头调度。
  - 端到端脚本：`output\verify\e2e.ps1`（UIA `InvokePattern` 点按钮 + 查库）。注意：**合成鼠标 `mouse_event` 会一次点击记两条**，自动化必须用 UIA Invoke。
- **词书已接入（2026-10-17 第八轮）**
  - 数据来源：**ECDICT**（https://github.com/skywind3000/ECDICT，MIT 协议），取 `tag` 含 `ky`（考研）的词条 4801 条，清洗后 **4796 词**。没有使用任何红宝书 / Anki 牌组的未授权数据。
  - 清洗规则：`translation` 按 `\n` 切段，丢弃 `[医][经][化]` 这类专业词典标记，取带词性标记的那一段；提取并规范化词性（`a.`→`adj.`、`ad.`→`adv.`）；把英文逗号换成中文逗号；同一义项去重（ECDICT 有"发生，发生，恰巧"这类重复）；超过 44 字在逗号处截断加省略号。
  - 排序：按 ECDICT `frq`（词频排名）升序，`frq=0` 视为无排名排到最后。这样先学最高频的词。
  - 打包：`src\WordDrawer.App\Assets\kaoyan-2027.json`（341 KB，`EmbeddedResource`），由 `KaoyanWordBook.Load()` 反序列化。
  - 写入策略：`CountWordsInActiveBookAsync() < 100` 才写入，避免每次启动重插 4796 条；实测首次写入 **1.2 秒**，库文件 0.54 MB。`SeedWordBookAsync` 已改为复用一条参数化命令（原来每个词都新建 command）。
  - 来源署名写在 `WordBooks.Source` 字段：`ECDICT (MIT) — tag: ky; 词性/释义为公开数据整理`。**分发时必须保留 MIT 署名**。
  - 已知差异：大纲约 5500 词，ECDICT 的 `ky` 标签只覆盖单词头词，短语和部分派生词不在内（4796 条）。
- **设置页与学习计划页（2026-10-17 第九轮）**
  - `SettingsView`：吸附位置（左/右）、开机启动（写 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 的 `WordDrawer` 值）、鼠标离开后收起（`_autoHide`）、每日新增到期上限（50–500，步长 50）、材质预览（雾银 / 冰蓝 / 夜蓝禁用）。
  - `PlanView`：每日新词（10–200，步长 10）、剩余未学、预计完成天数（`ceil(剩余/每日)`）。
  - 持久化：`AppSettings` 键 `DockSide` / `Theme` / `ReleaseLimit` / `AutoHide` / `Startup`；每日新词走 `DailyPlans`（按日期取最近一条）。新增 `GetSettingAsync` / `SetSettingAsync`。
  - 材质实现：只换磨砂雾面颜色（雾银 `#E7F5FD`、冰蓝 `#D1EDFB`），文字配色不动。**夜蓝未接**：它需要一套深色文字/边框配色，硬接现有浅色文字会看不清，留到深色主题单独一轮（按钮已置灰并带提示）。
  - 换主题/换边时用 `RevealWithFreshBackdrop()` 重新采样，避免把窗口自己拍进磨砂底图。
  - 顺手修了一个统计 bug：`GetDashboardAsync` 之前统计全部 `StudyStates`，会把已停用词书的进度算进来（换词书后首页显示"已学 5"但新书一个没学）。现在两处统计都 join 了 `WordBooks.IsActive = 1`。
  - 验证：真机 UIA 点击 → 设置页四项渲染正常；点「冰蓝」后 `Theme=ice`、点「左侧」后 `DockSide=Left` 且状态栏变成"左侧贴边"、点「+」后 `ReleaseLimit=250`；计划页显示 每日新词 50 / 剩余 4796 / 预计 96 天（4796÷50 向上取整）。29 个测试仍全过。
  - **测试脚本注意**：PowerShell 5.1 读 `.ps1` 按 ANSI 解码，含中文的脚本必须以 **UTF-8 with BOM** 保存，否则引号会被截断报 ParserError。用 `python -c "io.open(p,encoding='utf-8').read() → write with utf-8-sig"` 转换。
  - **回归修复（同轮）**：`ApplyTheme()` 只设置纯色刷作为兜底，但 `LoadSettingsAsync()` 在 `RefreshBackdrop()` 之后又调了它，把磨砂 `ImageBrush` 覆盖掉，导致启动后窗口变成一块没有模糊的纯色板。修法：`LoadSettingsAsync()` 末尾统一调 `RevealWithFreshBackdrop()` 重新采样；同时把 `Loaded` 里的提前 `DockToCurrentSide` 去掉，窗口一直停在屏幕外，等主题应用+底图采样完成后才滑入，避免"先出现纯色再跳一下"。`InitializeDataAsync` 的 catch 分支补了 `DockToCurrentSide`，否则数据库报错时窗口会永远停在屏幕外。
  - **规则**：任何时候改了 `GlassSurface.Background` 都必须在窗口位于屏幕外时重新 `RefreshBackdrop()`，否则纯色兜底刷会留在界面上。
- **夜蓝深色主题（2026-10-17 第十轮）**
  - 把写死在 XAML 里的颜色抽成可切换的画刷资源：`TextPrimary`/`TextSecondary`/`Accent`/`StrokeStrong`/`StrokeSoft`/`Divider`/`ButtonFill`/`PanelFill`/`PanelStroke`/`TrackFill`/`PrimaryFill`/`PrimaryText`/`CardSurface`，全部改用 `DynamicResource`，由 `ApplyTheme()` 在运行时替换（用 python 脚本批量替换的，共 18+15+5 处引用）。
  - 夜蓝配色：文字 `#E8F2FA`／次要 `#C6DCEA`，强调色 `#5BC8F5`，卡片深色渐变，主按钮反相成浅底深字（原型夜间就是这样）。
  - **关键坑**：深色玻璃不能沿用浅色主题的雾面浓度。31% 的深色雾面盖在亮桌面上仍然是浅灰底，白字直接糊掉。`EffectiveGlassAlpha` 让夜蓝至少 0xB0（≈69%）。
  - 夜蓝按钮已在设置页启用（原来置灰）。
  - 验证：夜览三套材质截图，夜蓝下顶栏/标题/卡片数字/主按钮/底部导航全部可读；最弱的仍是 9px 小字（页脚、副标签），与浅色主题同一水平。29 个测试仍全过。
- **液态玻璃边缘（2026-10-17 第十一轮，已按用户要求回退）**：`DrawLiquidRim` 曾在合成底图时加三层——放大 1.18× 的折射环带（22 DIP）、45° 渐变的镜面高光、内轮廓阴影。**用户评价「太奇怪了」，已整体删除**（`ScreenBackdrop.cs` 里相关方法与调用均已移除），回到纯磨砂玻璃。不要再主动加回来，除非用户明确要求。
- （历史记录）液态玻璃的实现在下一行已废弃：：`ScreenBackdrop.DrawLiquidRim` 在合成底图时加三层——① 边缘环带内画一份放大 1.18× 的桌面抓图（不透明度 85%），制造折射/透镜感；② 沿外轮廓描一道 45° 渐变镜面高光（左上白 94% → 右下淡蓝 22%），宽度 2.2×DPI；③ 内轮廓一道 2.4×DPI 的内阴影做深度。环带宽度 22 DIP。注意：**高光在浅色背景上几乎不可见**（白线叠白底），深色窗口上才明显；这是物理正确行为，不是没生效。
- **词书页 / 学习成果页（2026-10-17 第十二轮）**
  - 新增 `WordBookView`（书名、来源、总词数/已学、进度条）与 `ResultsView`（累计学习、今日完成、近 7 天柱状图）。首页底部三个入口现在都通，`NavigationPlaceholder_Click` 改成 switch 分发。
  - 数据层新增 `GetRecentDailyStatsAsync(endDate, days)` + `DailyStat` 记录；柱高按 7 天内峰值归一，空白日有轨道垫底（`Divider` 色），不会只剩 2px 细线。
  - **清理了脏数据**：库里还留着早期「开发演示词书」(Id=1, IsActive=0) 和它在 `StudyStates` 里的 5 条记录，导致「今日完成 5 / 累计学习 0」——因为 dashboard 的累计只统计**活跃词书**的词，而今日计数来自 `DailyStats`（按日期累加，不看词书）。已删除演示词书及其 Words/StudyStates/ReviewEvents 和 `DailyStats`。
  - 教训：以后 `DailyStats` 的写入必须和 dashboard 的统计口径一致（要么都按活跃词书过滤，要么都不过滤）。当前唯一词书是「2027 考研英语大纲词汇」(Id=8)。
- **为什么别的应用挡着就唤不出来（2026-10-17 第十三轮，已修）**
  - 原因一：`MainWindow` 从来没设过 `Topmost`。抽屉停靠时是普通 z-order 窗口，任何最大化窗口都盖住右边缘那 8 DIP 触发条。
  - 原因二：唤出只靠 WPF 的 `MouseEnter`，它依赖**命中测试**——上层窗口把鼠标事件吃掉，`MouseEnter` 永远不触发。
  - 修法：① XAML 加 `Topmost="True"`（已用 `GetWindowLong(GWL_EXSTYLE)` 验证 `WS_EX_TOPMOST` 位为真）；② 新增 `_edgeTimer`（180ms）轮询 `Control.MousePosition`，换算成 DIP 后判断是否落在窗口矩形内，收起时启动、展开时停止。轮询不依赖 z-order，即使被别的 topmost 窗口（播放器、OBS）盖住也能唤出。
  - 自动测试：`output/verify/test-edge-over-app.ps1` 能验证 TOPMOST 位与「收起→悬停→滑出」（`SLID_OUT=True`）；但本机 `Start-Process notepad` 与 PowerShell 控制台都拿不到 `MainWindowHandle`，**"被别的应用盖住时唤出"这一条没能自动复现**，需人工用最大化浏览器验证。
- **阴影：用户要的是「重阴影」（2026-10-17 第十四轮，已按用户澄清修正）**
  - 过程：用户先说「刚刚的颜色较深、阴影较重，截图里这个更好」，我误读为「要更轻」，把远影 0.34→0.12、近影 0.20→0.05、模糊 26→22。用户随即澄清「我是想要重阴影」。
  - 现状（用户「再重一点」后）：`WindowShadowFar` 不透明度 **0.55**、`BlurEffect` **44**、`Margin=44,44,44,50`、`TranslateTransform Y=14`；`WindowShadowNear` **0.22**、`Margin=48,48,48,54`。
  - **关键坑**：阴影 Border 的矩形如果比玻璃面板**大**（原先 Margin=38 < 玻璃的 44），模糊后的核心边缘正好露在面板外沿，会形成一圈贴边的暗线（"脏边"）。把 Margin 收到 ≥44 让核心藏到面板底下，只留弥散尾部，暗线明显减弱。
  - 重阴影的固有代价：只要不透明度够高，面板外沿近处的密度梯度就必然存在，看起来像一道浅暗边；想彻底干净只能降不透明度或加宽模糊。视觉验收：宽而深的蓝灰光晕、下方最重、边缘平滑无banding。
  - 教训：**用户说的「某个效果更好」指的是他附带的截图，不是我的最近一版**；遇到方向不明的对比，先确认「要重还是轻」再动手。
  - `AppSettings.GlassAlpha` 已复位为 78（31%）——此前是 8（3%，多轮自动测试点「−」留下的）。
  - 用户反馈「颜色较深、阴影较重」，对照其截图后调整：`WindowShadowFar` 不透明度 0.34 → **0.12**、`BlurEffect` 26 → **22**；`WindowShadowNear` 0.20 → **0.05**。实测视觉从「厚重光晕」变为「轻浮薄影」，面板与底色仍有分离度。
  - 数据库 `AppSettings.GlassAlpha` 当时是 **8（3%）**（滑档下限，多轮自动测试留下的），雾面几乎不含浅色 veil，面板比 31% 时还暗约 5 个亮度级（L215 vs L220，同为假文档底图）。已复位为 **78（31%）**。
  - 参考数据（`mean-rgb.ps1` 采样，同一假文档背景，540×780 玻璃区）：alpha=8 → 面板 L215.2 / 卡片 L229.1；alpha=78 → L220.2 / L230.6；用户截图（白底）面内 L240.2。
- **学习计时 + 空闲暂停（2026-10-17 第十五轮）**
  - `WordDrawer.Core/StudyClock.cs`：`Advance(elapsed, sinceLastInput)`，`sinceLastInput > 3 分钟` 时判为空闲、该 tick 不计数；`DefaultIdleThreshold` 可注入。4 个单测覆盖计数/暂停/恢复/重置。
  - App 侧：`_studyTimer`（1s）在 `BeginSession` 启动、`FinishSession`/`BackHome_Click` 停止并 `FlushStudyTime()` 写入 `DailyStats.EffectiveSeconds`（`WordDrawerDatabase.AddEffectiveSecondsAsync`，UPSERT 累加）。
  - 空闲判定用 `GetLastInputInfo`（全系统键鼠），用户切窗口也算活动；P/Invoke 在 `MainWindow` 内。
  - 学习成果页「近 7 天」右侧显示 `今日有效 X 分钟`（`ResultTimeText`），`FormatDuration()` 输出 秒/分钟/小时。
  - 测试钩子：环境变量 `WORDDRAWER_IDLE_SECONDS` 覆盖空闲阈值。
  - **实测**：`e2e-clock.ps1` 6 秒活动 → `DailyStats=('2026-10-18',0,6)`；`e2e-idle.ps1`（阈值设 5 秒，12 秒静默 + 3 秒活动 + UI 等待）→ 只记 **11 秒**，静默段被扣掉，证明暂停生效。结果页实测文案「今日有效 6 秒」。测试总数 33（Core 14 / Review 11 / Data 8）。
- **自由放置（2026-10-17 第十六轮）**
  - 拖动标题栏后不再强制回到左右侧：`DrawerLayout.SnapTarget()` 判断落点距工作区左右边是否 ≤ `DefaultSnapDistance=48` DIP，是则贴边，否则 `FloatInPlace()` 原地保留。
  - 浮动模式：`_isFloating=true`，不自动收起（`Window_MouseLeave` 跳过）、不参与边缘轮询、`RevealWithFreshBackdrop()` 只刷新磨砂不移动。
  - **磨砂采样（已修正）**：曾用 `Opacity=0` + `Thread.Sleep(45)` 让窗口"隐身"再抓屏——**不成立**：Sleep 在 UI 线程上，消息循环被阻塞，窗口根本不会重绘，抓到的仍是窗口自己，表现为玻璃里有一层自己的残影（用户截图反馈）。正确做法 `RefreshFloatingBackdrop()`：先把窗口 `MoveTo` 到工作区左侧屏外 → `RefreshBackdrop(targetRect)` 采样目标矩形 → 再移回原位。因为合成在 UI 线程同步执行、中途不泵消息，屏幕不会呈现中间位置，无闪烁。
  - 位置持久化：`AppSettings` 的 `DockMode`(free/docked)、`FreeX`、`FreeY`；启动时读回并用 `ClampWithin` 夹进工作区。拖到边缘或点 ⇄ 会清掉 free。
  - **实测**（`test-placement.ps1`，150% DPI）：默认 → `1912,228`（右侧贴边）；Free(100,300) → `84,384`；Free(700,300) → `984,384`，均等于 `(x-44)*1.5`，Y 同样精确。测试总数 38（Core 19 / Review 11 / Data 8）。
- **首页目标环（2026-10-17 第十七轮）**
  - 任务卡底部的 4px `ProgressBar` 换成 72px 圆环：`Ellipse` 轨道（`#2E425D70`，6px）+ `ProgressArc`（`Accent`，`StrokeStart/EndLineCap=Round`，`RotateTransform -90`）。卡头右侧显示 `目标 50`，环心显示今日完成数。
  - **关键坑 1**：WPF 的 `StrokeDashArray` 单位是 **StrokeThickness 的倍数**，不是像素。周长换算 `units = π * 72 / 6 ≈ 37.7`，弧长写 `fraction * units`，缺口填 `units`。
  - **关键坑 2**：`fraction = 0` 时 dash 长度为 0，但 `LineCap=Round` 仍会画出一个圆点，看起来像"0 也有一点进度"。修法：`ProgressArc.Visibility = fraction > 0.0005 ? Visible : Collapsed`。
  - 实测：12/50 → 环心 12、弧从 12 点顺时针约 24%；0/50 → 只剩轨道，无圆点（放大裁切确认环内无强调色笔画；卡右上那道青色弧是卡片原有的装饰椭圆，不是残留）。
- 已知取舍：底图在抽屉滑出时抓一次，若用户在抽屉打开期间大幅移动背后的窗口，磨砂画面会略微过时；再次收起滑出即刷新。
- 用户要求本轮只做纯 XAML 那批，模糊与外阴影另开一轮；当前没有调试进程运行。

## 1. 项目目标

为用户制作一款仅在本地运行的 Windows 背单词软件。软件像电脑 QQ 的贴边抽屉：平时缩至屏幕边缘，鼠标触碰边缘后滑出。核心体验应当轻量、安静、适合碎片化学习，不需要账号、云同步或联网服务。

当前临时产品名为「词隙」，英文标识为 `WORD DRAWER`。名称和图标尚未正式确认，后续可以更换。

## 2. 用户已经确认的产品需求

### 平台与交付

- 仅支持 Windows。
- 正式交付为 Windows 安装版。
- 应完全本地运行，不需要账号和云端服务。
- 推荐技术路线暂定 `.NET 8 + WPF`，本地数据使用 SQLite。
- Windows 11 可优先使用原生 DWM/Acrylic 类背景能力；Windows 10 需要准备可接受的模糊透明降级方案。

### 窗口与抽屉行为

- 窗口逻辑尺寸固定为 `360 × 520`。
- 支持吸附在屏幕左侧或右侧，并可在设置中切换。
- 收起后只露出约 6–8px 的蓝色玻璃触发边。
- 鼠标碰到触发边后窗口平滑滑出。
- 鼠标离开一段时间后自动收回，原型文案暂定延迟 1.2 秒。
- 提供“固定窗口”功能，固定后不自动收回。
- 后续正式客户端需要托盘图标和可选开机启动。
- 多显示器场景需要在开发阶段补充测试：窗口应吸附到当前所在显示器的边缘。

### 视觉风格

- 高透明磨砂玻璃风格，允许隐约看到下层窗口轮廓与内容块。
- 透明玻璃为主，带微弱冰蓝反光、细边缘高光和柔和阴影。
- 当前原型包含三种材质：雾银、冰蓝、夜蓝。
- 用户特别要求界面比初版更加透明，当前原型已降低填充不透明度与模糊强度。
- 避免紫色科技渐变、emoji 和廉价的装饰性卡片堆叠。
- “开始学习”和“去复习”按钮字体已经根据用户反馈调整：使用更克制的中等字重、较宽字距以及独立的小字层级。

### 首页

首页需要显示：

- 当前日期与简单问候。
- 今日仍需学习的新词数量。
- 今日待复习/积压复习数量。
- 开始学习。
- 去复习。
- 词书入口。
- 学习计划入口。
- 学习成果入口。
- 当前学习进度。

### 词书

- 用户最初想要“2027 考研红宝书”，但该出版物的完整词条、中文释义和编排存在版权风险。
- 用户已经接受替代方案：内置名为「2027 考研英语大纲词汇」的词书。
- 词条只需要：英文单词、词性、中文释义。
- 不需要例句，不需要发音。
- 第一版只内置这一册词书，不支持用户导入 Excel/CSV。
- 原型仍保留“词书”入口，为以后增加合法词库留出位置。
- 下一位开发者必须从来源明确、允许使用的公开考研英语大纲词汇整理数据，不要直接打包网络上的未授权红宝书/Anki 数据。

### 学习计划

- 用户可以设置每日学习的新词数量。
- 根据剩余未学词数和每日计划，计算预计还需多少天完成词书。
- 原型范围为每日 10–200 个新词，步长 10；正式版是否保留该范围可再确认。

### 学习成果

- 显示累计学习单词数。
- 累计单词只统计首次进入学习流程的不同单词；复习不能重复计数。
- 显示总有效学习时长。
- 无操作超过一定时间应暂停计时，原型说明暂定 3 分钟。
- 原型中的 `1,248`、`18h 42m` 和七日柱状图均为演示数据，不是真实记录。

### 背词页面

- 第一行居中显示英文单词，必须保持单行；长单词自动缩小字号，不能换行。
- 第二部分显示词性和中文释义，释义可以换行。
- 保留“认识”和“不认识”两档反馈。
- 点击“认识”：记录认识，安排较长的下次复习间隔，然后进入下一个单词。
- 点击“不认识”：记录不认识，安排较短的复习间隔，然后进入下一个单词。
- 屏幕左右箭头及键盘方向键都需要可用。

用户最后确认的方向键规则非常重要：

- `←`：仅切换到上一个单词，不记录任何熟悉度。
- `→`：把当前单词直接标记为“认识”，更新任务数量，然后进入下一个单词。
- 当前 HTML 原型中，屏幕上的左右箭头按钮也采用同样规则。
- 学习队列和复习队列都采用这套规则。

### 复习队列

- 只使用“认识/不认识”两档反馈。
- 可以采用 FSRS 或等价的间隔重复算法，将“认识”映射为成功记忆，将“不认识”映射为遗忘。
- 考试频率可作为新词初始优先级，但复习优先级主要由到期时间、遗忘次数和熟悉程度决定。
- 每天最多让 200 个“新到期”的单词进入复习队列。
- 这个 200 只是每日新增释放上限，不是复习队列总上限。
- 当天未完成的复习必须继续积压。
- 例：今天积压 80 个，明天又释放 200 个，明天应显示 280 个待复习。
- 优先处理逾期、多次“不认识”和较薄弱的单词。
- 原型在高级设置中展示了内部上限 200，正式版可以保持可配置但不占首页空间。

## 3. 当前文件

### 核心文件

- `Word Drawer Prototype.html`  
  自包含的高保真交互原型，无外部依赖。可以直接双击打开。

- `design-spec.md`  
  当前视觉、产品定位和核心流程设计规格。

- `HANDOFF.md`  
  本交接文档。

- `WordDrawer.sln`  
  正式 Windows 客户端解决方案。当前包含 WPF 主程序、核心层、数据层、复习层和两组测试项目。

- `src\WordDrawer.App`  
  可运行的 WPF 客户端骨架。已实现 360×520 无边框透明窗口、首页、学习演示流程、左右贴边、延迟收起、触边展开、固定窗口、系统托盘、多显示器工作区换算和方向键规则。新词学习反馈已接入 SQLite；复习按钮暂时禁用，等待到期队列读取接线。

- `src\WordDrawer.Core`  
  当前包含词条模型、左右贴边枚举以及可测试的抽屉坐标计算。

- `src\WordDrawer.Review`  
  当前包含两档反馈、复习卡模型、每日新到期释放上限和简化间隔调度。它是第一版可测试算法，不是完整 FSRS。

- `src\WordDrawer.Data`  
  SQLite 数据层。使用 `Microsoft.Data.Sqlite 8.0.32`，已包含数据库初始化、7 张核心表、WAL/外键/索引、词书种子写入、顺序取新词、反馈事件、唯一学习计数和首页统计查询。

- `tests\WordDrawer.Core.Tests`、`tests\WordDrawer.Review.Tests`、`tests\WordDrawer.Data.Tests`  
  当前共 14 个自动化测试。数据层测试会使用独立临时 SQLite 文件，不接触用户真实数据。

### 验收截图

位于 `output\playwright\`：

- `transparent-home.png`：当前高透明首页效果。
- `transparent-night.png`：高透明夜蓝效果。
- `refined-buttons.png`：调整后的“开始学习/去复习”按钮字体。
- `study.png`：背词页面。
- `plan.png`：学习计划页面。
- `collapsed-left.png`：左侧收起状态。
- `hover-open-left.png`：鼠标触边唤出状态。
- 目录中还可能存在其他早期验收截图。

项目根目录可能存在 `.playwright-cli`，这是 Playwright CLI 自动产生的测试会话记录，不属于产品代码。

原生 WPF 运行截图位于 `output\wpf\`：

- `current-native-ui.png`：旧版 WPF 首页截图，已被用户否定且源码已重做，不再代表当前界面。
- `native-home-125dpi.png`：Windows 150% 缩放下的完整 360×520 逻辑像素首页，物理像素为 540×780。
- `native-home-window.png`：早期窗口捕获，仅覆盖 360×520 物理像素，因此在高 DPI 下会被裁切，不应用作视觉验收。
- `native-home.png`：普通屏幕抓取没有包含 WPF 分层透明窗口，只能看到下层内容，不应用作视觉验收。

运行时持久化验收数据库位于 `output\runtime-test\worddrawer-integration.db`。它仅含 5 个开发演示词和一次“认识”反馈，不是产品词库，也不是用户正式数据。

## 4. HTML 原型目前已经实现的交互

- 360×520 应用窗口。
- 左右吸附切换。
- 模拟收起与鼠标触边展开。
- 固定按钮的视觉反馈。
- 首页、学习、复习、词书、计划、成果和设置页面。
- 雾银、冰蓝、夜蓝三种材质切换。
- 计划滑块及完成天数计算。
- 学习与复习的“认识/不认识”反馈。
- 左方向键只切换，不改变计数。
- 右方向键记录“认识”、改变计数并进入下一词。
- 屏幕左右箭头按钮与键盘采用相同规则。
- 长英文单词根据长度自动缩小字号。
- 演示数据标识。
- 下层模拟文档，用于观察真实透明度。
- 无障碍按钮名称和基本键盘焦点样式。

## 5. 已完成的浏览器验证

使用 Playwright CLI 在 Chromium 中验证过：

- 页面能正常加载，控制台 0 错误、0 警告。
- `.app-window` 的实际尺寸为 360×520。
- 左右吸附、收起和触边唤出可用。
- 学习页按一次左方向键后，待学习数量保持 32，不记录反馈。
- 随后按一次右方向键，待学习数量从 32 变为 31，并出现“已记录认识”。
- 复习页左键不改变积压数量；右键使积压从 86 变为 85，并出现“已安排下次复习”。
- 计划滑块从 50 调至 200 时，预计完成天数由 90 变为 23。
- 三种材质可切换。

## 5.1 已完成的正式客户端验证

2026-10-17 已完成第一轮 WPF 骨架验证：

- 安装并使用 Microsoft `.NET SDK 8.0.426 x64`。
- `dotnet build WordDrawer.sln --configuration Debug`：成功，0 警告、0 错误。
- `dotnet test WordDrawer.sln --configuration Debug --no-build`：14 个测试全部通过。
- 原生进程可正常启动并保持响应，窗口标题为“词隙”。
- 当前系统缩放为 150%，WPF 窗口保持 360×520 逻辑像素，对应 540×780 物理像素。
- 使用 `PrintWindow` 完成分层透明窗口捕获，首页没有布局溢出。
- 托盘版客户端运行后保持响应；枚举顶层窗口可同时看到“词隙”窗口和 WinForms/GDI+ 托盘消息窗口，说明托盘初始化成功。
- 窗口已改为根据当前窗口句柄选择所在显示器的 `WorkingArea`，并将物理像素换算为 WPF 逻辑单位；拖动结束后会自动吸附到当前显示器较近的一侧。
- 自动测试已覆盖左右贴边坐标、收起后保留 8px 触发条、每日 200 个新到期释放上限、积压不受上限影响、逾期优先以及认识/不认识间隔变化。
- SQLite 测试已覆盖重复初始化、词书按顺序读取，以及同一单词学习/复习多次时“唯一已学单词”只累计一次、反馈事件仍完整保留。
- SQLite 测试还覆盖全新数据库在没有 `DailyStats` 行时，首页统计必须返回 0 而不是 `NULL`。
- 已使用隔离数据库完成真实 UI 自动化验证：点击“开始学习”后按右方向键，`meticulous` 被保存为“认识”，界面切换到 `pragmatic`；重启同一数据库后首页剩余数保持为 4，证明进度不是内存假数据。
- 开发/自动化测试可通过环境变量 `WORDDRAWER_DATA_PATH` 指定隔离数据库；未设置时正式路径为 `%LocalAppData%\WordDrawer\worddrawer.db`。

当前构建命令：

```powershell
& 'C:\Program Files\dotnet\dotnet.exe' build 'WordDrawer.sln' --configuration Debug
& 'C:\Program Files\dotnet\dotnet.exe' test 'WordDrawer.sln' --configuration Debug --no-build
```

当前调试程序：

```text
src\WordDrawer.App\bin\Debug\net8.0-windows\WordDrawer.App.exe
```

## 6. 当前版本的限制

- WPF 正式客户端目前仍是骨架，不是可交付安装版；HTML 原型仍用于完整页面和视觉参照。
- WPF 已按当前窗口所在显示器读取 `WorkingArea` 并处理 DPI 换算，但尚未在真实双屏、不同缩放比例和各类任务栏位置组合下人工验收。
- WPF 已实现托盘菜单（显示、左贴、右贴、固定、退出），尚未实现开机启动、三套主题和完整页面导航。
- WPF 新词学习流程已经写入 SQLite；复习到期词读取、每日 200 个新释放词的持久化标记尚未接入 UI，因此当前“去复习”按钮主动保持禁用。
- 当前单词数组只有少量演示词条，不是完整词库。
- 已实现每日释放/积压规则的可测试骨架和简化间隔算法，但尚未实现完整 FSRS，也尚未与持久化队列连接。
- 尚未实现学习计时、空闲检测、数据备份和恢复。
- 尚未实现安装程序、自动更新或卸载数据策略。
- 尚未完成 Windows 10/11、不同 DPI、多显示器和任务栏位置测试。

## 7. 推荐后续开发顺序

### 阶段 A：请用户最终确认原型

状态：视觉方向已由用户以“感觉不错”确认，可以继续开发。产品名称、默认主题、200 上限是否允许在高级设置中修改，仍可在后续设置页阶段确认，不阻塞客户端骨架。

继续让用户确认以下内容：

1. “词隙”是否作为正式名称。
2. 当前高透明程度是否合适。
3. 雾银、冰蓝、夜蓝是否全部保留，默认使用哪一种。
4. 首页、背词页和两档反馈是否还需要改动。
5. 每日新增到期复习上限是否固定为 200，还是在高级设置中允许修改。

在用户明确确认视觉效果前，不建议直接大规模编写正式客户端。

### 阶段 B：创建 Windows 客户端骨架

状态：进行中。解决方案、各层项目、无边框透明窗口、左右贴边/自动隐藏、固定按钮、托盘、多显示器工作区换算、首页与背词演示流程已经完成；原生模糊材质、设置入口、三套主题、完整导航和更多真实设备验收尚未完成。

建议结构：

```text
src/
  WordDrawer.App/          # WPF 应用、窗口、页面与样式
  WordDrawer.Core/         # 学习计划、队列与领域模型
  WordDrawer.Data/         # SQLite、词库导入、迁移与仓储
  WordDrawer.Review/       # FSRS/复习调度算法
tests/
  WordDrawer.Core.Tests/
  WordDrawer.Review.Tests/
installer/
```

优先完成：

1. 无边框 360×520 主窗口。
2. Windows 缩放/DPI 感知。
3. 左右贴边与隐藏状态机。
4. 托盘菜单、固定、退出和设置入口。
5. 透明背景与 Windows 10 降级效果。
6. 页面导航和设计 token，尽量复刻 HTML 原型。

### 阶段 C：数据库与词库

状态：进行中。数据库版本 1 和基础仓储已完成，固定使用 `Microsoft.Data.Sqlite 8.0.32`。WPF 启动时会初始化 `%LocalAppData%\WordDrawer\worddrawer.db`，新词反馈已用事务持久化，重启验证通过。下一步是接入到期复习队列，并准备来源与授权明确的完整考研大纲词库。

建议基础表：

- `WordBooks`
- `Words`
- `StudyStates`
- `ReviewEvents`
- `DailyPlans`
- `DailyStats`
- `AppSettings`

重要字段建议：

- 单词唯一 ID、词书 ID、顺序号、英文、词性、中文释义。
- 是否首次学过、首次学习时间、最后复习时间、下次到期时间。
- 认识/不认识次数、连续认识次数、难度、稳定度等算法字段。
- 每次反馈必须以事件形式保存，便于修复算法或重算队列。

不要仅保存一个“是否认识”的布尔值，否则无法实现可靠的间隔重复。

### 阶段 D：计划与复习算法

先用单元测试固定以下规则：

1. 新词按词书顺序学习。
2. 同一个单词只在首次学习时增加累计单词数。
3. 复习不会重复增加累计单词数。
4. 认识/不认识分别产生正确的下次到期时间。
5. 每日最多释放 200 个新到期单词。
6. 前一天未完成项不受 200 限制，继续积压。
7. 排序优先级：严重逾期与薄弱词优先。
8. 左方向键不写入 `ReviewEvents`。
9. 右方向键写入一条“认识”事件并切换下一词。

### 阶段 E：统计、备份与安装程序

- 有效学习时长与空闲暂停。
- 唯一已学单词数量。
- 日/周学习统计。
- 本地数据库备份和恢复。
- 安装与卸载。
- 可选开机启动。
- 首次运行初始化词库。

## 8. 正式客户端的验收重点

- 在 100%、125%、150%、175% DPI 下保持 360×520 的正确逻辑尺寸和清晰文字。
- 左右边缘收起后不影响其他窗口点击。
- 鼠标误碰时不要频繁弹出，可增加极短悬停阈值。
- 展开窗口时尽量不要抢走用户当前应用的输入焦点；当用户点击背词按钮后再正常获得焦点。
- 全屏游戏/视频和演示模式下考虑暂停自动弹出。
- 任务栏位于顶部、左侧或右侧时不能错误覆盖。
- 多显示器之间移动后要重新计算工作区边界。
- 数据库异常、升级失败或词库初始化失败时不得丢失用户进度。
- 安装版需要测试覆盖安装、卸载保留数据和彻底清除数据的不同路径。

## 9. 交接给下一位 AI 的建议开场任务

可以直接给下一位 AI 以下指令：

> 请先阅读 `HANDOFF.md`、`design-spec.md` 和 `Word Drawer Prototype.html`，不要立即重做视觉设计。先向我确认原型是否已经定稿；如果我确认定稿，请按交接文档的阶段 B 创建 `.NET 8 + WPF` Windows 客户端骨架，优先实现 360×520 无边框窗口、左右贴边隐藏、鼠标触边唤出、固定窗口和托盘。保留现有工作区文件，不要删除 HTML 原型，并在每个阶段完成后运行测试和展示实际效果。

## 10. 不要遗漏的关键决策

- 仅 Windows。
- 安装版。
- 360×520。
- 左右两侧均支持。
- 高透明蓝色磨砂玻璃。
- 本地 SQLite，无账号无云端。
- 第一版只有「2027 考研英语大纲词汇」。
- 不需要例句和发音。
- 不支持用户导入词书。
- 两档反馈：认识/不认识。
- 每日新到期复习释放上限 200，未完成项可无限累积。
- 右方向键＝认识并进入下一词。
- 左方向键＝仅返回上一词，不写反馈。
- 累计学习单词数只统计唯一新学词，不重复统计复习。

