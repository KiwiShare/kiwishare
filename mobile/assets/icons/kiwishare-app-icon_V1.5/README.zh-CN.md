# KiwiShare 应用图标素材包 v1.0

本素材包以已确认的 KiwiShare 标志为唯一母版：奇异鸟剪影位于循环/分享箭头之中，顶部以叶片收束。图形概念和整体比例没有重新设计，仅进行了边缘净化、平台安全区适配、颜色分层和尺寸导出。

## 品牌色

| 色彩 | 色值 | 用途 |
|---|---:|---|
| Kiwi Green | `#076348` | 浅色背景上的主标志 |
| Deep Forest | `#0D2620` | 深色图标背景 |
| Warm Cream | `#FAF5EA` | 默认/浅色图标背景 |
| Soft Ivory | `#E2EDE1` | 深色背景上的标志 |

图形在不使用颜色时仍可凭轮廓辨认，因此不会只依赖绿色传达含义。浅色与深色版本均保留强对比度及同一剪影。

## 文件夹说明

- `master/`：4096 px 无损母版，以及透明背景标志。
- `ios/modern/`：iOS 默认、深色、着色模式的 1024 px 源图。
- `ios/legacy/`：当前 Flutter iOS Asset Catalog 所需的旧版文件名和尺寸。
- `android/adaptive/`：Android 自适应图标前景、背景、单色层和 XML 示例。
- `android/adaptive-dark-reference/`：深色视觉参考，不会被 Android 启动器自动切换。
- `android/legacy/`：48、72、96、144、192 px 启动图标。
- `android/play-store/`：512 px Google Play 图标。
- `previews/`：整套风格预览和小尺寸可识别性预览。
- `palette/`：机器可读的颜色 Token。

## iOS 接入

当前项目可把 `ios/legacy/` 中的同名文件替换到：

`mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/`

保留仓库现有的 `Contents.json`。如果之后迁移到新版 Xcode Asset Catalog，则使用 `ios/modern/` 中的 Default、Dark 和 Tinted 文件。

不要预先裁圆角，也不要添加外部阴影；iOS 会负责最终遮罩和系统展示效果。

## Android 接入

把 `android/legacy/` 中的 PNG 复制到项目对应的：

`mobile/android/app/src/main/res/mipmap-*/ic_launcher.png`

若启用自适应和主题图标，请使用 `android/adaptive/` 中的前景、背景和单色层，并按照项目资源结构调整 XML 示例。Android 版标志看起来会比 iOS 略小，这是为了保证循环箭头和叶片在圆形、圆角方形、Squircle、泪滴形等系统遮罩下都不会被裁切。

单色文件是一张形状蒙版。Android 13 及以上的启动器会根据用户壁纸和主题决定最终颜色，因此源文件使用白色是正常的。

## 设计与无障碍规则

- 必须完整保留圆形箭头、奇异鸟、眼睛、喙、脚和叶片。
- 不添加文字、微小装饰、渐变、摄影纹理或第二个符号。
- 不提前裁圆角。
- 保持已确认的正负色搭配。
- 必须检查 48 px 的效果，不能只看 1024 px 母版。
- 至少在一张浅色和一张深色桌面壁纸上验证。
- Android 自适应图标需要检查圆形、Squircle、圆角方形和泪滴形遮罩。
- 无障碍朗读名称来自应用名称；图标内部不承载必要文字信息。

本次交付以 4096 px 无损 PNG 为应用工程母版。若未来用于超大幅印刷，可再补做真正的矢量重绘；iOS 和 Android 应用发布本身不依赖矢量文件。

