# QuickPaste logo

`logo.png` 是由内置 imagegen 工具生成的原图，透明背景。README 使用原图，应用使用由它转换的 `QuickPaste.icns`。

生成提示词：

> Use case: logo-brand. Asset type: production macOS application icon for QuickPaste, a lightweight clipboard history and instant paste utility. Create a single polished icon, square canvas, centered macOS rounded-square tile with transparent outer corners and modest safe margins. A simple white clipboard combined with a swift folded paper/lightning-like paste gesture, bold readable silhouette at 32 pixels, tasteful cool blue to teal glass finish, restrained dimensional depth, crisp smooth edges. No text, no letters, no watermark, no extra objects or mockup. Export one icon only.

更新原图后，在仓库根目录运行 `./scripts/build-icon.sh`，用 macOS 自带的 `sips` 与 `iconutil` 生成 16–1024 像素的图标并合成为 ICNS。`build-app.sh` 也会自动运行这一步，并在签名前将图标放入应用资源目录。
