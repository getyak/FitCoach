# FitCoach — 私教学员管理 App

一个跑在 iPhone 上的私人教练管理工具，用 SwiftUI + SwiftData 写成，数据全部保存在手机本地（无需联网、无需后端）。

## 功能

1. **学员档案**：姓名、性别、年龄、运动经验、首次体测（体重/身高/体脂率）、运动目标、备注。
2. **训练计划**：为学员新建一次训练课程，添加多个动作（力量/有氧/拉伸/核心/HIIT），填写计划的组数、次数、组间间歇、预计时长。
3. **实际完成记录**：训练结束后，在学员档案里打开该次课程，逐个动作填写实际完成的组数、次数、间歇、实际用时。
4. **卡路里自动计算**：根据每个动作实际训练时长 × 动作类型对应的 MET（代谢当量）× 学员体重，自动算出该动作消耗的卡路里，并汇总出本次训练总消耗。

## 打开方式

1. 用 Xcode 打开 `FitCoach.xcodeproj`。
2. 在顶部选择一台模拟器（比如 iPhone 15）或连接你自己的 iPhone。
3. 点击运行（▶️）按钮即可。

首次在真机上运行需要在 Xcode 的 Signing & Capabilities 里选择你自己的 Apple ID 作为开发者团队（免费账号即可，仅用于本机调试，无需发布到 App Store）。

## 项目结构

```
FitCoach/
  FitCoachApp.swift          入口，注册 SwiftData 数据容器
  Models/
    Student.swift            学员模型（含性别/运动经验枚举）
    WorkoutSession.swift     一次训练课程
    ExerciseEntry.swift      单个动作（计划 + 实际数据 + 卡路里计算）
  Views/
    StudentListView.swift        学员列表首页
    AddStudentView.swift         新增学员表单
    StudentDetailView.swift      学员详情 + 训练记录列表
    AddWorkoutSessionView.swift  新增训练计划（添加多个动作）
    WorkoutSessionDetailView.swift  训练详情，填写实际完成数据、查看卡路里
```

## 卡路里计算公式

```
单个动作消耗(kcal) = MET × 学员体重(kg) × 实际训练时长(小时)
```

MET 参考值（可以在 `ExerciseEntry.swift` 里自行调整）：
- 力量训练 5.0
- 有氧训练 7.0
- 拉伸/柔韧 2.5
- 核心训练 4.0
- 高强度间歇(HIIT) 8.5

## 后续可以扩展的方向

- 给学员拍照记录体测变化
- 训练历史的图表趋势（体重变化、单次课程消耗趋势）
- 常用动作库（避免每次手动输入动作名）
- iCloud 同步，多设备共享学员档案
