# NovelAI 账号密码登录功能开发计划

## 核心目标
为NAI Launcher添加账号密码登录功能，实现与现有Token登录并存的成熟登录系统。

## 技术方案
1. **认证流程**：邮箱+密码 → Argon2哈希 → Access Key → /user/login → Access Token
2. **UI设计**：支持登录模式切换（邮箱密码/Token），现代化UI设计
3. **多账号支持**：混合账号类型管理，自动登录

## 实施阶段
1. 数据层（模型扩展、加密服务）
2. 认证服务层（登录逻辑、状态管理）
3. UI界面开发（登录表单、账号切换）
4. 测试与完善

## 参考项目
- Aedial/novelai-api (Python认证实现)
- wbrown/novelai-research-tool (Go认证实现)
- YILING0013/XianyunApp (WPF UI参考)

请运行 /start-work 开始执行！
