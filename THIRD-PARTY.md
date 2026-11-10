# 第三方组件与数据

本项目包含或分发以下第三方作品。它们各自的许可条款如下，与项目自身的 MIT
许可（见 LICENSE）并行适用。

---

## ECDICT 词典数据

内置的三本词书（`src/WordDrawer.App/Assets/*.json`）由 ECDICT 的标签子集裁剪而成，
只保留了词条、词性和精简释义。

- 来源：https://github.com/skywind3000/ECDICT
- 许可：MIT

```
Copyright (c) 2017 skywind3000

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Piper 语音合成

安装包内附带 Piper 的 Windows 构建（`piper.exe` 及其运行库），安装后位于
`%LOCALAPPDATA%\WordDrawer\piper`。仓库本身不包含这些二进制文件，见 README。

- 来源：https://github.com/rhasspy/piper
- 许可：MIT

```
Copyright (c) 2022 Michael Hansen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### 语音模型

`en_US-lessac-medium` 由 rhasspy/piper-voices 分发，仓库不包含该模型文件，
使用前请阅读其模型卡片中的授权说明：

https://huggingface.co/rhasspy/piper-voices/tree/main/en/en_US/lessac/medium

---

## 运行库

应用以 self-contained 方式发布，内含 .NET 运行时及其附带的第三方组件
（见 https://github.com/dotnet/runtime/blob/main/LICENSE.TXT ）。这部分由
.NET 自身的许可条款约束，不因本项目的 LICENSE 而改变。
