# FlowDo UI Kit

新增界面优先复用本 UI Kit，不在页面中直接写颜色、圆角和动画时长。

## 主题

四套账号级主题定义在 `app/lib/theme/app_palette.dart` / `app_theme.dart`：

- `mint`：闲云（默认）
- `hazeBlue`：远山
- `warmOrange`：归途
- `lightPurple`：微光

页面使用 `Theme.of(context).colorScheme`；FlowDo 特有颜色使用
`context.flowColors`。不要直接使用 `Colors.white` 或固定 hex。

优先级色（低饱和）：高 `#B86B6B`、中 `#C4895A`、低 `#7A8694`。
`TaskCard` 用优先级浅渐变铺底；按下不显示 splash / highlight。

## Token

`app/lib/theme/app_tokens.dart` 提供：

- `AppSpacing`：4 / 8 / 12 / 16 / 24 / 32 / 48
- `AppRadii`：8 / 12 / 12 / 16 / pill
- `AppMotion`：150ms、200ms、1200ms（庆祝）及统一曲线
- `AppLayout`：内容与阅读区最大宽度

## 字体与图标

- 正文：Noto Sans SC（思源黑体）
- 品牌标题/少量空状态：ZCOOL KuaiLe（站酷快乐体）
- 图标优先使用 Material Rounded/Outlined，放入 `FlowDoIconTile` 时使用
  主色浅底 + 发丝描边

## 图形标

图形标是一个对勾，两臂带轻微弧度、圆头圆角收笔。应用内由 `FlowDoLogo` 直接
绘制，描边取 `colorScheme.primary`，所以切换主题时图形标会一起变色。

## 组件

- `FlowDoLogo`：品牌图形标
- `SplashScreen`：冷启动开屏（logo + 随随办办）
- `FlowDoCard`：发丝描边扁平卡片
- `FlowDoIconTile`：圆角浅色图标底座
- `SectionHeader`：设置和内容分区标题
- `ResponsiveContent`：桌面端最大宽度约束
- `TaskCard`：任务标题、优先级和状态提示
- `TaskInteractable`：左右滑归类（任务池左滑删除），离场淡出
- `SwipeAway` / `SwipeToPop`：右滑离开
- `FlowDoPageRoute`：设置 / 归档 / 详情等子页路由
- `AddTaskFab`：可拖动贴边的加号；点按文字、长按语音
- `MonthReviewCalendar`：月完成日历
- `EmptyState`：轻量空状态
- `showFlowDoConfirmDialog` / `showFlowDoCelebration`

## 交互规则

- 常规过渡 150–200ms；减少动态效果时跳过庆祝动画。
- 点击区域至少 44×44；优先级不能只用颜色表达。
- 卡片间距 12px；页面边距移动端 16px。
- 底栏三个入口同等大小，不做聚焦突出。
