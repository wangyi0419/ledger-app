# 记账同步 App · 使用与部署指引

本应用为**原生 Flutter** 跨平台记账软件，同一份代码可编译为 **安卓 App / iPhone App / Web 网页版**。数据经 **AES-256 加密**后同步到你名下的 **GitHub 私有仓库**，多端一方更新、另一方自动同步。

- **安卓**：装原生 APK（CI 自动打包，无需本机环境）。
- **iPhone**：推荐用**网页版**（Safari「添加到主屏幕」当 App 用，**免 $99 苹果开发者账号、免 Mac**）；若坚持原生体验，也可走 Mac 构建方案（见附录）。

---

## 一、准备两个仓库

在你的 GitHub 新建两个仓库（数据仓库必须 **Private**，App 仓库可公开）：

| 仓库名 | 用途 | 可见性 |
|--------|------|--------|
| `ledger-app` | 存放应用源码 + 自动打包/部署配置（CI） | 公开即可（代码无密钥） |
| `ledger-data` | 只存放加密后的数据文件 `data/ledger.enc` | **必须 Private** |

> 新建：GitHub 右上角 **+ → New repository** → 填名 →（数据仓库选 **Private**）→ Create。
> 数据文件无需手动建，App 首次同步会自动创建。

---

## 二、生成 Personal Access Token（PAT）

App 通过 Token 读写私有仓库。

1. GitHub 头像 → **Settings → Developer settings → Personal access tokens → Tokens (classic)**。
2. **Generate new token (classic)**。
3. 勾选权限：**`repo`**（整项，含私有仓库读写）。
4. 过期时间按需（建议 1 年或无过期）。
5. 生成后**复制保存好**（只显示一次）。

> 安全：Token 在原生端存于系统安全存储（Keychain/Keystore）；在网页端存于浏览器本地存储。无论哪种，他人拿到 Token 也只能读到**加密后**的数据，没有主密码无法解密。

---

## 三、把源码推到 `ledger-app`

```bash
cd ledger_sync_app
git init
git remote add origin https://github.com/<你的用户名>/ledger-app.git
git add .
git commit -m "init ledger app"
git branch -M main
git push -u origin main
```

---

## 四、安卓安装（原生 APK，自动打包）

1. 推完代码后，进入 `ledger-app` 仓库 → **Actions** → `Build Android APK` 自动运行。
2. 运行完成 → 该次运行的 **Artifacts** → 下载 `app-release.apk`。
3. 传到手机安装（允许"未知来源"）。之后每次推代码都会自动重新打包。

---

## 五、iPhone 用网页版（推荐）

### 5.1 部署网页到 GitHub Pages（自动化，零本机环境）

1. 仓库 **Settings → Pages → Source** 选择 **GitHub Actions**。
2. 把代码推到 `main` 分支（第三步已完成即会触发）。
3. Actions 中 `Deploy Web (PWA)` 工作流自动：`flutter create --platforms=web` → 构建 → 注入 PWA 标签 → 部署。
4. 稍等片刻，访问 `https://<你的用户名>.github.io/ledger-app/`。

> 想更私密：`ledger-app` 设为 **Private** 时，GitHub Pages 仅登录你的账号可见（iPhone 需 Safari 处于 GitHub 登录态）。设为公开则任何人可打开网页，但**数据仍在私有仓库且已加密**，无泄露风险——推荐公开以便 iPhone 直接访问。

### 5.2 或本地构建 + 任意静态托管（Netlify / Vercel / Cloudflare Pages）

```bash
flutter create --platforms=web .      # 生成 web 目录（首次）
flutter pub get
flutter build web --release           # 生成 build/web
python3 tools/inject_pwa.py           # 注入 iPhone 安装所需 PWA 标签
# 把 build/web 整个目录部署到 Netlify / Vercel / Cloudflare Pages 等
```
自定义域名时去掉上面的 `--base-href` 参数即可。

### 5.3 在 iPhone 上"添加到主屏幕"

1. iPhone 用 **Safari** 打开上面的网页地址。
2. 点底部 **分享** 按钮 → 下滑找到 **「添加到主屏幕」** → 命名（如"记账"）→ 添加。
3. 桌面出现图标，点开即以**无浏览器边框**的独立 App 形态运行，体验接近原生。
4. iOS 16.4+ 支持标准 PWA 安装；更早版本用上述分享方式同样可用。

> 提示：网页端数据与原生端**完全互通**（同一加密仓库）。在 iPhone 记一笔，安卓打开会同步过来。

---

## 六、App 内配置（首次使用，各端通用）

1. 打开 App / 网页 → 首次运行**设置主密码**（至少 6 位，**请牢记，忘记无法恢复数据**）。
2. 进入「设置」页，填写：
   - **GitHub 用户名**：你的账号名
   - **数据仓库名（私有）**：填 `ledger-data`
   - **Personal Access Token**：第二步复制的 Token
   - **仓库内文件路径**：默认 `data/ledger.enc`
3. 点「测试连接」确认 → 点「保存并同步」。
4. 「记录」页点 **+** 添加收支，保存后自动加密同步；另一端打开会自动拉取合并。

---

## 七、同步与加密原理（简版）

- 每条记录带唯一 id 与更新时间；多端合并时**同 id 以较新者胜**，不同 id 并集。
- 本地与仓库数据均为 **AES-256-CBC** 加密（主密码派生密钥，PBKDF2-HMAC-SHA256 10 万次拉伸）。
- 打开 App、回到前台、每 60 秒自动与仓库对账；**主密码与仓库不一致时绝不覆盖远端**，避免清空白数据。

---

## 八、常见问题

- **同步失败 / 401**：Token 无效或权限不足，重生成并勾选 `repo`。
- **主密码错误**：本地已加密数据无法解密；确已遗忘需清除本地数据后重设（原数据不可恢复）。
- **两端数据对不上**：检查两边仓库名 / 路径 / Token 是否指向同一个 `ledger-data`。
- **网页端 Token 安全性**：网页 Token 存浏览器本地存储（弱于原生 Keychain），建议 iPhone 设锁屏密码；数据本身已加密，风险可控。

---

## 附录：iPhone 原生 App（需自备 Mac + 开发者账号）

iOS 无法像安卓直接装 APK，必须在 Mac 构建并签名：

1. Mac 装 **Xcode** + 加入 **Apple Developer Program（$99/年）**。
2. 装 Flutter：https://docs.flutter.dev/get-started/install/macos
3. 连接 iPhone 并信任；Xcode 配置你的开发者签名（Team）。
4. 命令行：
   ```bash
   flutter create --platforms=ios .
   flutter pub get
   flutter build ios --release
   ```
5. Xcode 打开 `ios/Runner.xcworkspace`，通过**数据线**或 **TestFlight** 安装到 iPhone。

> 这是苹果生态限制，我无法替你上架或签名，仅能提供完整源码与步骤。网页版可完全替代此方案。
