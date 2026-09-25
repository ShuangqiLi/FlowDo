# FlowDo UI Kit

FlowDo 的视觉关键词是：松弛、轻盈、笃定、亲和。新增界面应优先复用本
UI Kit，不在页面中直接写颜色、圆角和动画时长。

## 主题

四套账号级主题定义在 `app/lib/theme/app_palette.dart`：

- `mint`：薄荷绿（默认）
- `hazeBlue`：雾霾蓝
- `warmOrange`：暖橘色
- `lightPurple`：淡紫色

页面使用 `Theme.of(context).colorScheme`；FlowDo 特有颜色使用
`context.flowColors`。不要直接使用 `Colors.white` 或固定 hex。

## Token

`app/lib/theme/app_tokens.dart` 提供：

- `AppSpacing`：4 / 8 / 12 / 16 / 24 / 32 / 48
- `AppRadii`：8 / 12 / 20 / pill
- `AppMotion`：180ms、250ms、700ms 及统一曲线
- `AppLayout`：内容与阅读区最大宽度

## 字体与图标

- 正文：Noto Sans SC（思源黑体）
- 品牌标题/少量空状态：ZCOOL KuaiLe（站酷快乐体）
- 图标优先使用 Material Rounded/Outlined，放入 `FlowDoIconTile` 时使用
  主色 12% 透明度背景

字体均随应用打包，许可证位于 `app/assets/fonts/`。

## 图形标

图形标是一个对勾，两臂带轻微弧度、圆头圆角收笔。应用内由 `FlowDoLogo` 直接
绘制，描边取 `colorScheme.primary`，所以切换主题时图形标会一起变色。

源文件在 `app/assets/branding/`：`flowdo_mark.svg` 为单独图形标，
`flowdo_app_icon.svg` 带圆角底，`flowdo_app_icon.png` 由它渲染得到，
供 `dart run flutter_launcher_icons` 生成各平台图标。对勾的路径同时存在于
`flowdo_logo.dart` 和这两个 SVG 里，改动时三处都要同步。

## 组件

- `FlowDoLogo` / `FlowDoBrand`：品牌图形与组合标
- `FlowDoCard`：统一卡片容器
- `FlowDoIconTile`：圆角浅色图标底座
- `SectionHeader`：设置和内容分区标题
- `ResponsiveContent`：桌面端最大宽度约束
- `TaskCard`：任务标题、优先级、状态提示和操作
- `QuickAddField`：任务池快速添加
- `EmptyState`：轻量空状态
- `showFlowDoConfirmDialog`：统一确认对话框
- `showFlowDoCelebration`：任务完成正反馈

## 交互规则

- 常规过渡使用 200–300ms，不堆叠多个抢眼动画。
- 完成动画只在服务端确认状态更新成功后播放。
- 点击区域至少 44×44，不能只用颜色表达优先级或状态。
- 系统启用“减少动态效果”时，不播放庆祝动画。
- 卡片间距 12px；页面边距移动端 16px，桌面端保持最大内容宽度。
