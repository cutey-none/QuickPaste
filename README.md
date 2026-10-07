# QuickPaste

> A lightweight macOS menu bar clipboard history app — press ⌘⇧V to search and paste.

QuickPaste 是一个轻量的 macOS 菜单栏剪贴板历史工具：按 **⌘⇧V** 在屏幕中央呼出搜索面板，选中即粘贴到当前应用。

## 功能

- 自动记录复制过的纯文本和图片（截图、网页图片等），最多 200 条，重复内容自动移到最前
- 面板左侧列表显示图片缩略图，右侧预览选中的图片或完整文本；搜索“图片”可筛出所有图片
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

需要 macOS 13+ 和 Xcode（或 Swift 5.9+ 工具链）。

```bash
./scripts/build-app.sh      # 生成 build/QuickPaste.app
open build/QuickPaste.app
```

可以把 `build/QuickPaste.app` 拖到 `/Applications` 后再在菜单栏里开启“开机启动”。

运行测试：

```bash
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
