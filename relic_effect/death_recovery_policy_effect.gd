## 装备期间改变死亡回收数量：-1回收全部，正数随机回收指定件数。
## 死亡结算读取穿戴装备中的本效果，效果自身不写仓库、不监听死亡信号。
## 仍受拾荒仓库解锁、容量、锁定装备保护规则限制；多件来源取最强规则，不重复回收。
class_name DeathRecoveryPolicyEffect
extends RelicEffect

@export_range(-1, 99, 1) var recovery_count: int = -1


## 0表示不改变默认回收规则。临时装备由仓库收集入口统一排除。
func get_death_recovery_limit() -> int:
	return maxi(recovery_count, -1)
