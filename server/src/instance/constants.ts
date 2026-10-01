export const INSTANCE_ID = 'default';

/// 全新安装的初始密码。部署时可用环境变量 FLOWDO_INITIAL_PASSWORD 覆盖；
/// 首次登录后会被要求立刻修改。
export const DEFAULT_PASSWORD =
  process.env.FLOWDO_INITIAL_PASSWORD?.trim() || 'FlowDo#321Init';
export const DEFAULT_SPACE_NAME = '默认';
