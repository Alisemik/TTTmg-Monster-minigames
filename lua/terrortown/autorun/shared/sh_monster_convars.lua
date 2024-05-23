-- 添加了一些ConVar，并设置了默认值和内部描述

-- 表示怪物获得的血量
CreateConVar("ttt2_monster_hp", 200, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "怪物获得的血量")

-- 表示怪物获得的护甲值
CreateConVar("ttt2_monster_armor", 30, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "怪物获得的护甲值")