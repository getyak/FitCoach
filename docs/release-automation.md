# FitCoach 自动化发布

## 合并策略

日常改动进入短生命周期分支，经 Pull Request 合并到 `main`。仓库启用自动合并后，只有 `iOS verification / test` 成功的 PR 才自动 squash merge；不允许机器人直接把未验证代码提交到 `main`。

## TestFlight

`.github/workflows/testflight.yml` 是手动发布入口。它会：

1. 校验商店资料与截图；
2. 在临时钥匙串导入 Apple Distribution 证书；
3. 生成工程并归档；
4. 用 App Store Connect API key 上传；
5. 留存与 commit 绑定的发布证据。

需要在 GitHub `testflight` environment 配置以下 secrets：

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_PRIVATE_KEY`（完整 `.p8` 文本）
- `DISTRIBUTION_CERTIFICATE_BASE64`（`.p12` 的 Base64）
- `DISTRIBUTION_CERTIFICATE_PASSWORD`

这些凭据不得写进仓库。正式启用前，在 GitHub 中把 `main` 设为唯一可部署分支；如果账户套餐支持，再为 `testflight` environment 增加人工审批。

## 推荐仓库规则

- 私有仓库；
- `main` 禁止 force push 与删除；
- 合并前要求 `iOS verification / test`；
- 要求分支保持最新；
- 仅允许 squash merge，并启用自动删除已合并分支；
- Dependabot 仅按月更新 GitHub Actions，避免频繁噪音。

App 内的休息 Live Activity 继续保持为训练计时的窄投影；它不是独立业务事实源，上传流程会同时验证主 App、扩展、隐私清单和 dSYM。
