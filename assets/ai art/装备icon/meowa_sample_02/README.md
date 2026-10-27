# 第二批装备图标候选

来源：Meowa API 任务 `job_b0864a3dfb3441229845293fe93df412`，2026-10-08。
使用 object_1 模板默认配置，一次提交成功，收费 20 点，没有重试收费请求。
本次追加预算为最多 50 点，已使用 20 点；上一轮剩余 10 点另行保留。

提示词保存在 `custom_resource/meowa_relic_icons_sample_02.json`。
核心要求：结合装备名称与效果生成电风扇、太阳能发电板、激励项圈、吸铁石、碎甲锤，
每种三个候选，32×32、透明背景、有限色板、轮廓清晰、无文字和场景。

| 装备 | 候选文件 | 已绑定文件 |
| --- | --- | --- |
| 电风扇 | sprite_00.png、sprite_05.png、sprite_10.png | sprite_00.png |
| 太阳能发电板 | sprite_01.png、sprite_06.png、sprite_11.png | sprite_01.png |
| 激励项圈 | sprite_02.png、sprite_07.png、sprite_12.png | sprite_02.png |
| 吸铁石 | sprite_03.png、sprite_08.png、sprite_13.png | sprite_03.png |
| 碎甲锤 | sprite_04.png、sprite_09.png、sprite_14.png | sprite_14.png |

preview.png 为服务方输出的整批预览；所有 PNG 均为直接下载的原图，未修改像素。
已按上表绑定五件装备的 icon；其余候选保留，未覆盖已有素材或修改装备效果。
提交后 Godot 在退出时发生引擎崩溃，但服务端任务正常完成，后续仅进行了免费状态查询和下载。
