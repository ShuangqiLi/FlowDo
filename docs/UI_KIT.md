# FlowDo UI Kit

新增界面优先复用本 UI Kit，不在页面中直接写颜色、圆角和动画时长。
客户端只有网页端，一套界面同时照顾手机浏览器和桌面浏览器：手势和鼠标拖动都要能用。

## 主题

主题定义在 `app/lib/theme/app_palette.dart` / `app_theme.dart`：

- `mint`：闲云（默认）
- `hazeBlue`：远山
- `warmOrange`：归途（可可褐，避开中优先级杏橙）
- `lightPurple`：微光
- `willowOlive`：柳烟
- `nightIndigo`：夜泊
- `mistPlum`：雾梅

页面使用 `Theme.of(context).colorScheme`；FlowDo 特有颜色使用
`context.flowColors`。不要直接使用 `Colors.white` 或固定 hex。

优先级色跨主题固定、低饱和：高 `#B0686C`（玫红）、中 `#C4895A`（杏橙）、低 `#3E8288`（青绿）、无 `#85827C`（灰白）、提醒 `#C4A86C`（浅橙黄）。
五种色相分开，并避开七套主题主色。
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
- 两套字体都打进产物，网页端首屏要下载十几兆；加字体前先想清楚值不值
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
- `TaskInteractable`：左右滑归类（任务池左滑删除；提醒任务不能右滑进聚焦），离场淡出
- `SwipeAway` / `SwipeToPop`：右滑离开
- `FlowDoPageRoute`：设置 / 归档 / 详情等子页路由
- `AddTaskFab`：可拖动贴边的加号；点按文字、长按语音（浏览器不支持语音时只提示打字）
- `MonthReviewCalendar` / `SwipeMonthCalendar`：月历。格子两行日期（公历 + 稍小的农历）；过去只显示完成（点 / 星 / 皇冠），今天提醒小旗在上、完成在下，未来只显示提醒；颜色跟当前空间主题
- `showReminderTimePicker`：中文周一日历；时分加减或点数字键盘输入（0–23 / 0–59）；循环含 crontab 与农历
- `EmptyState`：轻量空状态
- `showFlowDoConfirmDialog` / `showFlowDoCelebration`

## 交互规则

- 常规过渡 150–200ms；减少动态效果时跳过庆祝动画。
- 点击区域至少 44×44；优先级不能只用颜色表达。
- 卡片间距 12px；页面边距移动端 16px。
- 底栏（`FocusDock`）任务池 / 聚焦 / 完成三等分平铺，聚焦坐中间、图标更大；选中反馈只落在图标上，不框文字。
- 提醒进聚焦后排在列表最前，在任务池里排在最后。提醒任务不能从任务池滑进聚焦，到点后自动进入。仅一次的提醒到点后任务池立刻拿走，聚焦里是同一件。

## 提醒

提醒选择器不要用转盘。日历中文、周一起。复杂循环用五段 crontab；农历开关只对仅一次 / 每月 / 每年有意义。今日看看格子的农历日期字号小于公历日号，单独占一行。今天这一格提醒排在完成上面。今日看看只看当前任务空间。仅一次的提醒卡片直接写时间；勾了农历的提醒，时间写成农历日期。通知弹出层只列任务标题和触发时间；空状态写「暂无通知」；清空是红色胶囊按钮。
