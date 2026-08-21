# FitCoach

私人教练的课间训练记录本：打开就能延续学员上一次训练。

## MVP 主链路

1. “今天”默认展示最近学员、上次训练、剩余课时与训练提醒，并可快速切换学员。
2. 点击“沿用上次并开始”，复制动作顺序与上次实际重量/次数。
3. 每组独立记录重量、次数、RPE、备注与完成状态；完成后自动休息计时。
4. 完成课程时明确展示课时变化，保存成功后才扣课。
5. 完成页生成可编辑、可分享的简短总结。

训练现场只完整展开当前未完成组，已完成和后续组收为摘要；完成后自动聚焦下一组，休息状态与“完成当前组”固定在底部，减少训练中的滚动和视线搜索。RPE 未操作时明确显示“未记录”，不会把建议值误存为事实。教练可选开启休息结束本地提醒。另支持训练模板、体重/腰围/体脂趋势，以及包含逐组记录和课时流水的 JSON 备份。

## 技术结构

- SwiftUI + SwiftData，最低 iOS 17，当前只发布 iPhone。
- `SessionService` 集中处理复制、开始、取消、完成、撤销、续费与课时幂等。
- `CreditTransaction` 账本计算余额，计划中/暂停/取消课程不扣课。
- `WorkoutSet`、`BodyMeasurement`、`WorkoutTemplate` 提供逐组、趋势与模板数据。
- iOS 26+ 仅在训练底部控制条使用原生 Liquid Glass；内容卡保持实体表面。
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

## 当前验证

- 单元/集成：21/21，通过不追踪/暂停课时、续费流水、零完成组保护、课时只扣一次、撤销/重完成、复制上次、旧版备份重复导入去重、精确 V1 数据库原地升级、中间版本标记后的 UUID 自愈、畸形归档重复 ID 防护、体测历史、V1/V2 深合并与往返恢复。
- UI：6/6，通过启动、渐进式当前组自动推进、完整训练 9→8、强退后草稿/休息计时恢复、重量/次数/RPE/备注强退恢复、RPE 未记录语义及 AX5 首页与训练控件 frame 断言。
- 视觉：iPhone SE、iPhone 17 Pro、iPhone 17 Pro Max；浅色与暗色。
- 升级：测试资源包含由基线 `38151ee` 真机模拟器进程生成的 exact V1 SwiftData store（3 位学员、3 节课程、4 个动作）；当前版本可原地打开、修复迁移时重复 UUID、回填逐组/体测/课时流水，并在第二次打开时保持对象数、ID 与余额不变。同一模拟器覆盖安装当前 App 后也已成功进入迁移后的“今天”页。当前仍采用 SwiftData 推断式 schema 迁移；扩大正式发布系统范围前应继续补多 iOS 版本 fixture，并在下一次破坏性模型变化前冻结 `VersionedSchema`/`SchemaMigrationPlan`。

完整验收标准见 [docs/MVP_ACCEPTANCE.md](docs/MVP_ACCEPTANCE.md)。
可交互产品设计见 [docs/FitCoach_MVP_Prototype.html](docs/FitCoach_MVP_Prototype.html)，可直接用浏览器打开。
