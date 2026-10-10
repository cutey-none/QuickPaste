# QuickPaste

> A lightweight macOS menu bar clipboard history app — press ⌘⇧V to search and paste.

QuickPaste 是一个轻量的 macOS 菜单栏剪贴板历史工具：按 **⌘⇧V** 在屏幕中央呼出搜索面板，选中即粘贴到当前应用。

## 功能

- 自动记录复制过的纯文本和图片（截图、网页图片等），重复内容自动移到最前
- 默认保留最近 30 条，超出的旧记录连同图片文件一起删除；可在菜单栏“保留条数”中改为 10 / 30 / 50 / 100 / 200 或自定义
- 面板左侧列表显示图片缩略图，右侧预览选中的图片或完整文本；搜索“图片”可筛出所有图片
- macOS 26+ 使用原生液态玻璃面板，旧系统使用磨砂材质；默认亮色，面板右上角“深色”开关控制明暗并记住选择，不跟随系统外观；支持系统“减少透明度”“减少动态效果”设置
- 跳过密码管理器标记的敏感内容（`org.nspasteboard.ConcealedType` 等）
- 历史持久化在 `~/Library/Application Support/QuickPaste/history.json`，图片以 PNG 保存在同目录的 `images/` 中
- 仅驻留菜单栏，不占 Dock；支持开机启动

## 快捷键

| 按键 | 作用 |
|---|---|
| ⌘⇧V | 呼出 / 关闭面板 |
| 直接输入 | 搜索过滤 |
| ↑ / ↓ | 选择 |
| ↩ | 粘贴选中项 |
| ⌘1 – ⌘9 | 直接粘贴对应条目 |
| ⌘⌫ | 删除选中项 |
| esc | 关闭面板 |

## 构建与运行

环境要求：

- macOS 13+（Apple 芯片或 Intel 均可，按本机架构编译）
- Swift 5.9+：安装 Xcode，或只装命令行工具 `xcode-select --install`（只构建不跑测试时够用）

```bash
git clone https://github.com/cutey-none/QuickPaste.git
cd QuickPaste
./scripts/build-app.sh      # 生成 build/QuickPaste.app
open build/QuickPaste.app
```

启动后没有窗口也不出现在 Dock，图标在屏幕右上角的菜单栏中；按 ⌘⇧V 呼出面板。

建议把 `build/QuickPaste.app` 拖到 `/Applications`，从那里打开，再在菜单栏里开启“开机启动”。

更新到最新代码：

```bash
git pull
./scripts/build-app.sh
```

然后退出旧的 QuickPaste（菜单栏 → 退出），重新拷贝并打开。

运行测试（需要完整的 Xcode，仅装命令行工具会报 `no such module 'XCTest'`）：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   # 若之前指向了命令行工具
swift test
```

## 辅助功能权限

自动粘贴需要模拟 ⌘V，因此需要在 **系统设置 → 隐私与安全性 → 辅助功能** 中允许 QuickPaste。
未授权时，选中的内容仍会写入剪贴板，手动按 ⌘V 即可。

> 应用使用 ad-hoc 签名，每次重新构建后签名会变化，可能需要在辅助功能列表中移除旧条目后重新授权。

## 项目结构

```
Sources/
  QuickPasteCore/   历史存储（去重、上限、搜索、持久化），有单元测试
  QuickPaste/       应用：菜单栏、全局快捷键、剪贴板监听、面板 UI、粘贴
Support/Info.plist  应用 bundle 配置
scripts/            打包脚本
```

## License

MIT
