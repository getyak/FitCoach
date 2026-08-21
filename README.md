# FitCoach

私人教练的课间训练记录本：打开就能延续学员上一次训练。

## MVP 主链路

1. “今天”默认展示最近学员、上次训练、剩余课时与训练提醒，并可快速切换学员。
2. 点击“沿用上次并开始”，复制动作顺序与上次实际重量/次数。
3. 每组独立记录重量、次数、RPE、备注与完成状态；完成后自动休息计时。
4. 完成课程时明确展示课时变化，保存成功后才扣课。
5. 完成页生成可编辑、可分享的简短总结。

底部固定“完成当前组”让训练中单手操作更直接；教练可选开启休息结束本地提醒。另支持训练模板、体重/腰围/体脂趋势，以及包含逐组记录和课时流水的 JSON 备份。

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

UI 测试使用 `-uiTesting -resetStore` 注入确定性场景，不影响正常用户数据。

## 当前验证

- 单元/集成：不追踪课时、续费流水、零完成组保护、课时只扣一次、撤销/重完成、复制上次、旧数据幂等回填、体测历史、V1/V2 备份恢复。
- UI：启动、完整训练 9→8、强退后草稿/休息计时恢复、AX5 首页与训练控件布局断言。
- 视觉：iPhone SE、iPhone 17 Pro、iPhone 17 Pro Max；浅色与暗色。
- 升级：在独立模拟器安装基线旧版并创建真实 SwiftData store，覆盖安装当前版本后成功启动；旧档案保留并生成初始体测历史。

完整验收标准见 [docs/MVP_ACCEPTANCE.md](docs/MVP_ACCEPTANCE.md)。
可交互产品设计见 [docs/FitCoach_MVP_Prototype.html](docs/FitCoach_MVP_Prototype.html)，可直接用浏览器打开。
