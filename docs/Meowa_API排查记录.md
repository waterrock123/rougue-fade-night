# Meowa API 排查与兼容方式

## 结论

2026-10-08 已实测 API 可以生成素材，密钥、地址和 Godot 提交链路可用。

同一个 `object_1` 模板、相同装备提示词及比例，携带
`template_config: {"target_count": 5, "remove_bg_method": "standard"}`
时生成失败，移除整个 `template_config` 后生成成功。
独立 Python multipart 客户端发送原配置也失败，因此不是只有 Godot 会出现的问题。

目前只能定位到这组自定义配置相关，尚不能区分是数量、抠图方式、组合兼容问题或服务端偶发问题；没有宣称修复服务端。

## 使用方式

工具新增显式 `--template-defaults` 选项，对 plan 与 submit 同样生效。
它仅省略 template_config，保留提示词、模板和其他字段，不修改原需求文件。

```powershell
$godot = 'E:\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe'
& $godot --headless --path . --script res://scripts/utils/meowa_asset_tool.gd -- plan --request=res://custom_resource/meowa_relic_icons_sample_01.json --template-defaults
# 以下命令收费，必须确认预算后才能执行。
& $godot --headless --path . --script res://scripts/utils/meowa_asset_tool.gd -- submit --request=res://custom_resource/meowa_relic_icons_sample_01.json --template-defaults --confirm-spend
```

注意：默认配置不保证原先指定的数量与价格。本次 object_1 默认生成了 15 个输出，收费 20 点，并非 5 个输出或 15 点。提示词中的数量不是输出数量保证。
不加此选项时仍按需求文件原配置提交；工具不会自动切换配置，不会自动重试收费请求。

## 实测记录与预算

| 请求 | 任务 ID | 结果 | 净花费 |
| --- | --- | --- | --- |
| 独立客户端原装备配置 | job_b00fdf77dde14b2c91b4ba8e4b64eaf6 | 失败，15 点已返还 | 0 |
| template5x5 最小请求 | job_1ecdca07fd234faeab14f140ee6752d4 | 成功，15 个输出 | 20 |
| object_1 原提示词、不带 template_config | job_c5f25ad59c1344c0aaf040a998a6a762 | 成功，15 个输出 | 20 |

此前装备样例失败请求的 15 点也已返还。本轮累计净花费 40 / 50 点，剩余 10 点，不再进行收费试验。

## 错误反馈改进

- HTTP 错误保留状态码和服务方提供的 detail、message、error_code、error_id 等字段，并遮蔽当前密钥；不回显 HTML 错误页面。
- 失败任务额外查询免费通用任务接口，将诊断记录写入本机 user://meowa 对应任务目录，便于给服务方提供错误编号。
- 网络中断与服务端任务失败分开报告，提交结果不明时先查历史，不自动重试 POST，避免重复扣点。
- 20 项离线自检已通过。引擎退出时仍有项目既有资源泄漏提示与石头 manifest UID 警告，不属于 API 生成失败原因。

成功样例只用于预览，未自动覆盖或绑定任何装备图标。
