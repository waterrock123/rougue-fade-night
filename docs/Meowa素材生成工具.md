# Meowa 素材生成工具

这是独立的开发期工具，不挂载游戏场景，不修改装备、技能或游戏主流程。协议依据你提供的 2026-10-08 本地 API 文档。原工具支持像素与高清生成；另有下文独立的帧动画V2工具。音频和其他特殊工作流暂未接入。

## 密钥配置（只需做一次）

在 Windows 搜索“编辑账户的环境变量”，在当前用户的环境变量中新增：

- 变量名：`MEOWA_API_KEY`
- 变量值：你在 Meowa 创建的真实 Key

设置后完全退出并重新打开 Codex/终端，使其继承新变量。不要把 Key 发到聊天、写入 JSON、脚本、project.godot 或提交 Git。该环境变量并非加密保险箱，本机同用户进程可读取；不要分享环境变量截图。

## 使用

在项目目录的 PowerShell 先设置两个不含密钥的临时变量：

```powershell
$godot = 'E:\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64.exe'
$tool = 'res://scripts/utils/meowa_asset_tool.gd'
```

查看官方公开模板（不生成素材、不扣生成点数）：

```powershell
& $godot --headless --path . --script $tool -- templates --kind=pixel
& $godot --headless --path . --script $tool -- templates --kind=hd
```

示例需求 `custom_resource/meowa_icon_request.example.json` 已选用从官方公开列表实测存在的 `24px_icon` 模板，配置为单个图标、标准抠图。该模板当前标记为 beta；可按测试效果换成其他真实模板 ID。模板列表默认简要显示，加 `--full` 可查看全部字段，完整参数也会缓存到本机用户目录。提示词由我按素材用途整理。参考图可选，仅接受 `res://assets/` 内的 PNG/JPEG/WebP，最大 16MB；上传前确认愿意将此图发送给 Meowa。

```powershell
# 仅检查并显示需求，没有任何网络请求
& $godot --headless --path . --script $tool -- plan --request=res://custom_resource/meowa_icon_request.example.json

# 只有这一步提交收费生成，执行前确认模型、模板与抠图费用
& $godot --headless --path . --script $tool -- submit --request=res://custom_resource/meowa_icon_request.example.json --confirm-spend

# 把 JOB_ID 换成提交返回的 ID；高清任务加 --kind=hd
& $godot --headless --path . --script $tool -- status --job=JOB_ID
& $godot --headless --path . --script $tool -- wait --job=JOB_ID
& $godot --headless --path . --script $tool -- download --job=JOB_ID --preview
& $godot --headless --path . --script $tool -- download --job=JOB_ID

# 多产物任务按索引下载
& $godot --headless --path . --script $tool -- download --job=JOB_ID --output=0
```

`wait` 每 5 秒查询一次，最多 10 分钟，只查询、不重新提交。POST 超时或网络中断时提交结果可能未知，请先执行 `history --kind=pixel` 或 `history --kind=hd` 确认，避免重复扣点。真实费用以官方与提交响应的 `credit_cost` 为准，本工具不提供预扣费查询；`--confirm-spend` 是显式同意本次收费，不是服务端预算上限。

## 结果与安全

结果保存在 `user://meowa/类别/任务ID/`，下载后打印绝对路径。保留需求与任务记录，文件名含时间标记，不覆盖已有图片。ZIP 不自动解压。结果需预览确认后再由我们导入 assets；不自动修改任何场景引用。

密钥只发往 `https://api.meowa.ai/`，下载重定向到其他域名时不附带 Key。网络请求有超时与 32MB 响应上限，不关闭 TLS 校验。用户目录中的记录可能含提示词、参考图路径、任务结果链接，分享前应检查隐私。

## 验证

```powershell
# 不启动游戏主场景，纯本地校验
& $godot --headless --path . --script $tool -- self-test
```

编辑器扫描和离线自检不能代替真实服务测试。首次实际生成还需验证账号权限、模板字段、生成质量及下载结果；在你确认测试素材和预算前不提交收费请求。

## 帧动画V2

`scripts/utils/meowa_animation_tool.gd` 使用已有HTTP客户端，首张图只允许来自项目assets内，最长边不超过320像素；不启动游戏。每次收费提交前再次调用 `prepare_only` 核实费用，超过 `--max-cost` 或费用未知时拒绝提交，不自动重试。预算是每次提交的本机检查，不是服务端全任务总预算，累计费用仍需单独核对。

```powershell
$godot = 'E:\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe'
$tool = 'res://scripts/utils/meowa_animation_tool.gd'
& $godot --headless --path . --script $tool -- plan --request=res://custom_resource/meowa_zombie_idle.json
# plan保存时间线与报价；看完后使用prepared文件，不重新生成另一份动作时间线。
& $godot --headless --path . --script $tool -- submit --request=res://custom_resource/meowa_zombie_idle.json.prepared.json --max-cost=15 --confirm-spend
& $godot --headless --path . --script $tool -- status --job=JOB_ID
& $godot --headless --path . --script $tool -- wait --job=JOB_ID
& $godot --headless --path . --script $tool -- download --job=JOB_ID --out=res://assets/enemy/zombie/idle_v2.webp.source
```

WebP原始动画必须先离线解码成PNG逐帧图集和 `.frames.json`（width、height、durations_ms）。不要直接给Godot静态纹理导入器处理动画WebP。输出PNG不缩放、不逐帧重新裁切，保留透明画布与时长；之后可用 `import_meowa_sprite_frames.gd` 在编辑器模式生成四种动画的SpriteFrames。首次提交网络结果不明时先查询服务端历史，不重复POST。

动画工具的 `wait` 每30秒免费查询一次，最多10分钟，不会重试收费请求。
已加入开发期离线辅助工具 `scripts/utils/meowa_sprite_process.py`（需要 Pillow），可用
`decode 原始.webp.source 输出前缀` 拆出 PNG 图集、时长元数据和仅供预览的 GIF/JPG。
辅助工具不联网、不修改既有素材、不逐帧裁切，也不是游戏运行时依赖。
