# 🚀 GitHub Actions 云打包指南

## 📦 自动构建 IPA（完全免费）

本项目已配置 GitHub Actions，可以在云端自动编译 iOS 应用，无需本地 Mac！

---

## ✨ 功能特性

- ✅ **完全免费** - 使用 GitHub 提供的 macOS 虚拟机
- ✅ **无需 Mac** - 在任何电脑上都能触发构建
- ✅ **自动构建** - 推送代码后自动编译
- ✅ **生成 IPA** - 自动打包并上传
- ✅ **创建 Release** - 自动发布新版本

---

## 🎯 使用方法

### 方法 1: 自动触发（推送代码后自动构建）

1. **推送代码到 GitHub**
   ```bash
   git add .
   git commit -m "feat: 添加新功能"
   git push origin main
   ```

2. **查看构建进度**
   - 访问: https://github.com/5488-ux/QuickUnzip/actions
   - 点击最新的 workflow run
   - 实时查看构建日志

3. **下载 IPA**
   - 构建完成后，在 Artifacts 中下载
   - 或者在 Releases 页面下载

---

### 方法 2: 手动触发（推荐）

1. **访问 Actions 页面**
   - https://github.com/5488-ux/QuickUnzip/actions

2. **选择工作流**
   - 左侧选择 "Build IPA" 或 "Simple Build"

3. **点击 "Run workflow"**
   - 右上角有个下拉按钮
   - 选择分支（main/master）
   - 点击绿色的 "Run workflow" 按钮

4. **等待构建完成**
   - 通常需要 5-15 分钟
   - 可以实时查看日志

5. **下载 IPA**
   - 构建成功后，滚动到页面底部
   - 在 "Artifacts" 区域下载 `QuickUnzip-IPA`

---

## 📁 工作流文件说明

### `build-ipa.yml` - 完整构建工作流

**触发条件:**
- 推送到 main/master 分支
- Pull Request
- 手动触发

**主要步骤:**
1. Checkout 代码
2. 设置 Xcode 环境
3. 创建缺失的文件（自动补全）
4. 构建项目
5. 生成未签名 IPA
6. 上传到 Artifacts
7. 创建 Release（可选）

**输出:**
- `QuickUnzip-unsigned.ipa` - 未签名的 IPA 文件

---

### `simple-build.yml` - 简化构建（测试用）

**触发条件:**
- 仅手动触发

**用途:**
- 测试项目是否能编译
- 调试构建问题
- 查看构建日志

---

## 📦 下载和安装 IPA

### 下载方式

#### 方式 1: 从 Artifacts 下载
1. 进入具体的 workflow run 页面
2. 滚动到底部的 "Artifacts" 区域
3. 点击 `QuickUnzip-IPA` 下载 zip
4. 解压得到 `QuickUnzip-unsigned.ipa`

#### 方式 2: 从 Releases 下载
1. 访问: https://github.com/5488-ux/QuickUnzip/releases
2. 选择最新版本
3. 下载 Assets 中的 `QuickUnzip-unsigned.ipa`

---

### 安装到 iOS 设备

⚠️ **注意**: 这是未签名版本，需要自签名才能安装！

#### 方法 1: AltStore（推荐，免费）

1. **安装 AltServer**
   - 下载: https://altstore.io/
   - 支持 Windows 和 Mac

2. **连接设备**
   - 用 USB 连接 iPhone/iPad
   - 确保信任电脑

3. **安装 AltStore 到设备**
   - 在 AltServer 菜单中选择 "Install AltStore"
   - 输入 Apple ID 和密码

4. **通过 AltStore 安装 IPA**
   - 将 IPA 传到手机（AirDrop/iCloud）
   - 在手机上打开 AltStore
   - 点击 "+" 选择 IPA 文件
   - 等待安装完成

5. **信任开发者**
   - 设置 → 通用 → VPN与设备管理
   - 信任你的 Apple ID

**优点:**
- 完全免费
- 每 7 天自动续签（需保持 AltServer 运行）
- 最多 3 个应用

---

#### 方法 2: Sideloadly（推荐，功能强大）

1. **下载 Sideloadly**
   - https://sideloadly.io/
   - 支持 Windows 和 Mac

2. **连接设备并安装**
   - USB 连接设备
   - 打开 Sideloadly
   - 拖入 IPA 文件
   - 输入 Apple ID
   - 点击 Start

3. **信任开发者**
   - 同上

**优点:**
- 界面友好
- 支持注入功能
- 支持高级选项

---

#### 方法 3: 爱思助手（中国用户）

1. **下载爱思助手**
   - https://www.i4.cn/

2. **连接设备**
   - USB 连接

3. **安装 IPA**
   - 工具箱 → IPA 签名
   - 选择 IPA 文件
   - 使用自己的证书或爱思提供的证书
   - 安装到设备

**优点:**
- 中文界面
- 简单易用
- 国内用户友好

---

#### 方法 4: iOS App Signer + Xcode（需要 Mac）

1. **下载 iOS App Signer**
   - https://dantheman827.github.io/ios-app-signer/

2. **签名 IPA**
   - 打开 iOS App Signer
   - 选择 IPA 文件
   - 选择签名证书
   - 输出新的已签名 IPA

3. **通过 Xcode 安装**
   - Xcode → Window → Devices and Simulators
   - 选择设备
   - 点击 "+" 添加 IPA
   - 安装

---

## ⚙️ 高级配置

### 添加签名证书（自动签名）

如果你有付费的 Apple Developer 账号，可以配置自动签名：

1. **导出证书和描述文件**
   ```bash
   # 在 Mac 上导出 p12 证书
   # 钥匙串访问 → 我的证书 → 右键导出
   ```

2. **转换为 Base64**
   ```bash
   base64 -i certificate.p12 -o certificate.txt
   base64 -i profile.mobileprovision -o profile.txt
   ```

3. **添加到 GitHub Secrets**
   - 仓库 Settings → Secrets and variables → Actions
   - 添加以下 secrets:
     - `BUILD_CERTIFICATE_BASE64` - 证书内容
     - `P12_PASSWORD` - 证书密码
     - `BUILD_PROVISION_PROFILE_BASE64` - 描述文件内容

4. **修改 workflow 文件**
   - 取消注释签名相关步骤
   - 重新运行构建

这样就能生成已签名的 IPA，可以直接安装！

---

## 🐛 常见问题

### Q1: 构建失败了怎么办？

**解决方案:**
1. 查看构建日志，找到错误信息
2. 常见错误:
   - 缺少文件: workflow 会自动创建
   - 编译错误: 检查代码语法
   - 签名错误: 使用无签名构建

### Q2: 下载的 IPA 无法安装？

**解决方案:**
- 确保使用了签名工具
- 检查设备是否信任开发者
- 尝试重新签名

### Q3: AltStore 显示"最多 3 个应用"？

**解决方案:**
- 免费 Apple ID 限制 3 个自签名应用
- 删除其他应用或使用付费开发者账号

### Q4: 每 7 天就过期？

**解决方案:**
- 这是免费账号的限制
- 使用 AltStore 自动续签（需保持 AltServer 运行）
- 或者购买 Apple Developer Program ($99/年)

### Q5: 构建时间太长？

**解决方案:**
- 正常情况下 5-15 分钟
- GitHub Free 账号每月 2000 分钟免费额度
- 足够个人使用

---

## 📊 GitHub Actions 配额

### 免费账号额度
- ✅ Public 仓库: **无限制**
- ✅ Private 仓库: **2000 分钟/月**
- ✅ macOS 构建: 消耗 **10x 分钟数**（1 分钟算 10 分钟）

### 实际使用
- 每次构建约 5-15 分钟
- 相当于消耗 50-150 分钟配额
- **Public 仓库完全免费，无限制！**

---

## 🎯 推荐流程

### 日常开发
1. 本地修改代码
2. 推送到 GitHub
3. 自动触发构建
4. 在 Actions 页面查看进度
5. 构建成功后下载 IPA
6. 使用 AltStore 安装测试

### 发布版本
1. 更新版本号（在代码中）
2. 创建 Git Tag
   ```bash
   git tag -a v3.0.0 -m "Release v3.0.0"
   git push origin v3.0.0
   ```
3. 自动创建 Release
4. 用户从 Releases 页面下载

---

## 💡 提示

1. **保持仓库为 Public** - 享受无限制的 Actions 时长
2. **使用手动触发** - 避免每次推送都构建
3. **查看日志** - 遇到问题先看构建日志
4. **测试分支** - 在测试分支先验证，再合并到主分支
5. **缓存依赖** - 可以配置缓存加速构建

---

## 📚 参考资源

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [AltStore 官网](https://altstore.io/)
- [Sideloadly 官网](https://sideloadly.io/)
- [iOS App Signer](https://dantheman827.github.io/ios-app-signer/)

---

## 🎉 开始使用

现在就去试试吧！

1. 访问: https://github.com/5488-ux/QuickUnzip/actions
2. 点击 "Build IPA"
3. 点击 "Run workflow"
4. 等待构建完成
5. 下载你的第一个云端构建的 IPA！

---

**QuickUnzip - 随时随地，云端构建！** ☁️📱
