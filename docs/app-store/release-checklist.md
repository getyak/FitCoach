# App Store Connect 发布清单

## 已由仓库和 Archive 证明

- Bundle ID：`com.sasawang.FitCoach2026`
- 版本：1.0（2）
- iPhone only，最低 iOS 17
- App + Live Activity Extension
- `PrivacyInfo.xcprivacy`：不跟踪、不收集数据；UserDefaults required-reason `CA92.1`
- 主 App 与 Extension：`ITSAppUsesNonExemptEncryption=false`
- App Icon、dSYM、签名结构和二进制内嵌 Git commit 由 `scripts/release_evidence.sh` 核验

## App Privacy 回答草案

- Tracking：No
- Data collected：No
- 第三方广告或分析 SDK：无
- 本地通知：仅设备内休息提醒
- Live Activity：只读休息结束时间与课程 UUID，不含学员姓名或健康数据
- 用户主动导出的 JSON：由用户选择分享目的地，FitCoach 不自动上传

## 需要账户持有人完成

- 接受 Apple Developer 最新协议
- 在 App Store Connect 创建 app record，并选择 Bundle ID
- 填写 SKU、主类别、年龄分级和销售地区
- 填写真实审核联系人与 Support URL 联系信息
- 发布 App Privacy 回答并填写 Privacy Policy URL
- 使用 Apple Distribution / App Store profile 导出并上传
- 等待 build processing 完成，检查警告与出口合规状态
- 配置内部 TestFlight 测试员

## 真机发布门槛

- 锁屏收到一次本地休息通知
- 灵动岛/锁屏 Live Activity 点击精确回到对应训练
- 跳过、撤销、取消、完成课程后通知和 Live Activity 均清理
- VoiceOver 完成一组 → 休息 → 下一组的焦点顺序走查
- Reduce Motion、Reduce Transparency、Increase Contrast 各走一次主链
