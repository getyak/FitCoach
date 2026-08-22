# FitCoach

私人教练的课间训练记录本：打开就能延续学员上一次训练。

## MVP 主链路

1. “今天”默认展示最近学员、上次训练、剩余课时与训练提醒，并可快速切换学员。
2. 点击“沿用上次并开始”，复制动作顺序与上次实际重量/次数。
3. 每组独立记录重量、次数、RPE、备注与完成状态；完成后自动休息计时。
4. 完成课程时明确展示课时变化，保存成功后才扣课。
5. 完成页生成可编辑、可分享的简短总结。

训练现场只完整展开当前未完成组，已完成和后续组收为摘要；完成后自动聚焦下一组。训练时底部只保留“完成当前组”，休息时切换为单行倒计时与“跳过”，减少滚动、视线搜索和误触。RPE 未操作时明确显示“未记录”，首次增减分别落到 7.5/6.5，不会把建议值误存为事实。休息倒计时会以无学员隐私的 Live Activity 投影到锁屏与灵动岛，本地通知仍负责准点提醒；跳过、撤销、取消和完成课程都会结束系统活动。另支持训练模板、体重/腰围/体脂趋势，以及包含逐组记录和课时流水的 JSON 备份。

## 技术结构

- SwiftUI + SwiftData，最低 iOS 17，当前只发布 iPhone。
- `SessionService` 集中处理复制、开始、取消、完成、撤销、续费与课时幂等。
- `CreditTransaction` 账本计算余额，计划中/暂停/取消课程不扣课。
- `WorkoutSet`、`BodyMeasurement`、`WorkoutTemplate` 提供逐组、趋势与模板数据。
- iOS 26+ 仅在训练底部控制条使用原生 Liquid Glass；内容卡保持实体表面。
- `FitCoachLiveActivity` Widget Extension 只读展示 `restEndsAt`；不使用 App Group、APNs 或频繁更新权限。
- XcodeGen 的 `project.yml` 是工程配置源。

## 构建与测试

```bash
xcodegen generate
xcodebuild \
  -project FitCoach.xcodeproj \
  -scheme FitCoach \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test CODE_SIGNING_ALLOWED=NO
```

UI 测试使用 `-uiTesting -resetStore` 注入确定性场景，不影响正常用户数据；`-uiTestAX5` 是测试专用启动参数，用于注入 SwiftUI AX5 字号，避免 iOS 26 旧 UIKit 字号参数造成假通过。

发布候选 Archive 应传入当前提交并生成可追溯证据：

```bash
xcodebuild archive \
  -project FitCoach.xcodeproj \
  -scheme FitCoach \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/FitCoach.xcarchive \
  FITCOACH_GIT_COMMIT="$(git rev-parse HEAD)"
scripts/release_evidence.sh /tmp/FitCoach.xcresult /tmp/FitCoach.xcarchive
```

证据脚本会拒绝脏工作树、提交号不匹配、失败或跳过的测试、缺少扩展/隐私清单/dSYM，以及签名或 UUID 不一致的产物；开发签名不会被误报为 App Store 分发证明。

Xcode 登录具备分发权限的账号后，可复现地导出并验证 App Store IPA：

```bash
scripts/export_app_store.sh /tmp/FitCoach.xcarchive /tmp/FitCoach-AppStore
```

导出脚本使用自动签名的 `app-store-connect` 配置，并拒绝 Apple Development 签名或仍含 `get-task-allow=true` 的 IPA。上传和 App Store Connect 服务端 processing 仍是独立发布门槛。

## 当前验证

- 单元/集成：32 项，覆盖不追踪/暂停课时、续费流水、零完成组保护、课时只扣一次、未填写 RPE 保持未记录、撤销/重完成、复制上次、旧版备份重复导入去重、精确 V1 数据库原地升级、中间版本标记后的 UUID 自愈、畸形归档重复 ID 防护、跨学员父级 UUID 归属校验、体测历史、V1/V2 深合并与往返恢复、系统训练深链格式校验、文件型草稿保存 P95 帧预算，以及 start/stop 任务尚未启动时也由最后一次休息操作获胜。
- UI：12/12，通过启动、渐进式当前组自动推进、休息归零自动回到下一组、完整训练 9→8、强退后草稿/休息计时恢复、全字段恢复、数值调整后立即终止恢复、直接数值输入、精确训练深链热/冷启动、Today/训练页与学员/趋势/模板/我的/备份全旅程系统无障碍审计，以及 AX5 当前组/休息栏 frame 断言。
- 全套目标：44 项（32 个单元/集成 + 12 个 UI）；发布候选必须由同一提交的一次 `xcodebuild test` 全部通过，并由证据脚本核验。
- 系统休息计时：模拟器 ActivityKit 日志实测 `active → dismissed`；灵动岛紧凑态显示真实倒计时，跳过休息后立即结束。
- 视觉：iPhone SE、iPhone 17 Pro、iPhone 17 Pro Max；浅色与暗色。
- Archive：含 Live Activity Extension 的 Release device archive 构建、嵌入校验与深度签名验证通过；隐私清单位于最终 App bundle。
- 出口合规：当前仅使用 SHA-256 做本地备份收据去重，不实现非豁免加密；最终包显式声明 `ITSAppUsesNonExemptEncryption=false`，证据脚本会核验该值。
- 并发边界：休息 Live Activity 由独立 actor 串行管理，不占用 SwiftUI 主执行器；工程在 `SWIFT_STRICT_CONCURRENCY=complete` 下构建通过。
- 升级：测试资源包含由基线 `38151ee` 真机模拟器进程生成的 exact V1 SwiftData store（3 位学员、3 节课程、4 个动作）；当前版本可原地打开、修复迁移时重复 UUID、回填逐组/体测/课时流水，并在第二次打开时保持对象数、ID 与余额不变。同一模拟器覆盖安装当前 App 后也已成功进入迁移后的“今天”页。当前仍采用 SwiftData 推断式 schema 迁移；扩大正式发布系统范围前应继续补多 iOS 版本 fixture，并在下一次破坏性模型变化前冻结 `VersionedSchema`/`SchemaMigrationPlan`。

完整验收标准见 [docs/MVP_ACCEPTANCE.md](docs/MVP_ACCEPTANCE.md)。
可交互产品设计见 [docs/FitCoach_MVP_Prototype.html](docs/FitCoach_MVP_Prototype.html)，可直接用浏览器打开。

发布资料已在仓库中准备：[隐私政策](docs/privacy.html)、[支持页面](docs/support.html)、[简体中文商店文案](docs/app-store/zh-Hans) 与 [App Store Connect 发布清单](docs/app-store/release-checklist.md)。公开 URL、真实审核联系人、分发签名和上传仍需对应账户权限。
