# 记账同步 App（ledger_sync_app）

跨平台（Android / iOS / Web）记账应用，同一份 Flutter 代码可编译为三端。数据以 **AES-256** 加密后同步到你名下的 **GitHub 私有仓库**，满足"仅你可见 + 多端自动同步"。

## 功能（标准版）
- 收支记录：金额、分类、备注、日期
- 月度收支概览与按日期/月份查看
- 统计：近 6 个月收支柱状图、当月分类支出饼图
- 加密同步：本地加密缓存 + GitHub 私有仓库拉取/合并/推送，打开即同步、回前台同步、每 60 秒对账

## 技术栈
- Flutter 3.x（Dart）
- `provider` 状态管理、`http` 调 GitHub API
- `pointycastle` 做 AES-256-CBC 加密与 PBKDF2 密钥派生（Dart 3 兼容）
- `flutter_secure_storage` 安全存储 Token（原生 Keychain/Keystore；Web 端回退浏览器存储）
- `shared_preferences` 本地加密缓存（原生与 Web 通用，**不依赖 `path_provider`，故可编译为 Web**）
- `fl_chart` 图表、`intl` 日期、`uuid` 记录 id

## 目录结构
```
lib/
  main.dart                 # 入口与解锁路由
  models/txn.dart           # 记录模型 + 预置分类
  services/
    crypto_service.dart     # 主密码派生 + AES 加密/解密
    github_service.dart     # GitHub Contents API 读写
    ledger_store.dart       # 同步核心（合并/推送/自动同步）
  screens/
    unlock_screen.dart      # 主密码解锁/设置
    home_screen.dart        # 底部导航 + 生命周期同步
    list_screen.dart        # 记录列表
    add_txn_screen.dart     # 新增记录
    stats_screen.dart       # 统计图表
    settings_screen.dart    # GitHub 配置
web/
  manifest.json             # PWA 清单（iPhone 添加到主屏幕用）
  icons/Icon-192.png        # 应用图标
  icons/Icon-512.png
tools/
  inject_pwa.py             # 构建后注入 PWA 安装标签（幂等）
  make_icons.py             # 生成上述图标（纯标准库）
.github/workflows/
  build-android.yml         # 自动打包安卓 APK
  deploy-web.yml            # 构建并部署 Web 到 GitHub Pages
GUIDE.md                    # 建仓库 / 生成 Token / 安装指引
```

## 本地运行（原生端）
```bash
flutter create .           # 首次生成各平台目录
flutter pub get
flutter run                # 连接设备/模拟器
```

## 构建产物
- Android：`flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
- iOS：`flutter create --platforms=ios .` + `flutter build ios --release`（需 Mac + Xcode + 开发者账号）
- Web（iPhone 网页版）：
  ```bash
  flutter create --platforms=web .
  flutter build web --release
  python3 tools/inject_pwa.py   # 注入 PWA 标签，使 iPhone 可"添加到主屏幕"
  # 部署 build/web 到 GitHub Pages / Netlify / Vercel 等
  ```

详见 **GUIDE.md**。
