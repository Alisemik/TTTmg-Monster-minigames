if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_monster.vmt")--角色使用的图标路径
end

local walkspeed = CreateConVar("ttt2_monster_walkspeed", 1.2, {FCVAR_ARCHIVE, FCVAR_NOTIFY})

roles.InitCustomTeam(ROLE.name, {
	icon = "vgui/ttt/dynamic/roles/icon_monster",
	color = Color(0, 100, 0, 255)
})



function ROLE:PreInitialize()
	self.color = Color(0, 100, 0, 255)        -- 角色的颜色

	self.abbr = "MONSTER"                       -- 简称（必须英文）
	self.survivebonus = 1                       -- 根据存活时长来给予点数（分钟计算）
	self.preventFindCredits = false             -- 是否可以从尸体上摸取点数（关闭是false）（启用是true）
	self.preventKillCredits = false		        -- 是否可以因击杀获取点数（关闭是false）（启用是true）
	self.preventTraitorAloneCredits = false	    -- 是否没有点数（关闭是false）（启用是true）
	self.isOmniscientRole = true                -- 是否可以知道未被查询的玩家死亡（关闭是false）（启用是true）
	self.preventWin = false                     -- 除非他变化角色否则他无法获胜（关闭是false）（启用是true）
	self.scoreKillsMultiplier       = 2         -- 杀死其他的敌人可获得的积分
	self.scoreTeamKillsMultiplier   = -8        -- 杀死队友会失去的积分
	self.defaultEquipment = INNO_EQUIPMENT      -- 在这里，您可以设置自己的默认设备
	self.disableSync = false 			        -- 不告知玩家他自己的角色（关闭是false）（启用是true）
	
	-- 此角色团队交互的设置
    self.unknownTeam = false                    -- 不知情自己队友身份，有团队也隐藏自己的团队语音（关闭是false）（启用是true）
	self.defaultTeam = TEAM_MONSTER             -- 这个角色的团队阵营

	-- ULX 的设置
	self.conVarData = {
		pct = 0.17,                             -- 因为玩家人数随机这个角色存在的百分比
		maximum = 1,                            -- 刚开局后可出现的身份数量
		minPlayers = 8,                         -- 最少有多少玩家才会出现这个角色
		credits = 0,                            -- 该角色的起始点数
		traitorButton = 1,                      -- 是否可用叛徒机关（1是可以）（0是不可以）
		creditsAwardDeadEnable = 0,             -- 是否因场上玩家死亡人数获得点数（1是可以）（0是不可以）
		creditsAwardKillEnable = 0,             -- 是否可以因击杀关键人物获得点数（1是可以）（0是不可以）
		shopFallback = SHOP_DISABLED,           -- 设置该角色是否有商店，用的什么商店？
		togglable = true,                       -- 是否可以在F1中设置该角色的设置 (F1 menu)
		random = 0 		                    -- 这个角色出现的概率（100是百分百）
	}
end

if SERVER then

    
    -- 给予角色装备和武器
    function ROLE:GiveRoleLoadout(ply, isRoleChange)
        -- 移除普通玩家的装备和武器
        ply:StripWeapons()
        

        -- 给予怪物爪子
        ply:GiveEquipmentWeapon("weapon_thr_bonecharm")
        -- 给予护甲
        ply:GiveArmor(GetConVar("ttt2_monster_armor"):GetInt())
        -- 设置生命值
        ply:SetHealth(GetConVar("ttt2_monster_hp"):GetInt())
    end

    -- 移除角色装备和武器
    function ROLE:RemoveRoleLoadout(ply, isRoleChange)
        -- 还原普通玩家的装备和武器
        ply:GiveEquipmentWeapon("weapon_zm_improvised")
        ply:GiveEquipmentWeapon("weapon_zm_carry")
        ply:GiveEquipmentWeapon("weapon_ttt_unarmed")
        -- 移除怪物爪子
        ply:StripWeapon("weapon_thr_bonecharm")


      
    end
end



--防止小丑获胜
hook.Add("TTT2PreventJesterWinstate", "MONSTERJesterWinstate", function(killer)
    if IsValid(killer) and killer:GetSubRole() == ROLE_MONSTER then
        return true
    end
end)

hook.Add("TTT2UpdateSubrole", "UpdateMONSTERRoleSelect", function(ply, oldSubrole, newSubrole)
    if newSubrole == ROLE_MONSTER then
        ply:SetSubRoleModel("models/player/zombie_classic.mdl")
    elseif oldSubrole == ROLE_MONSTER then
        ply:SetSubRoleModel(nil)
    end
end)

-- 防止僵尸捡起非法武器
hook.Add("PlayerCanPickupWeapon", "MONSTERModifyPickupWeapon", function(ply, wep)
    if not IsValid(wep) or not IsValid(ply) or ply:GetSubRole() ~= ROLE_MONSTER or ply:IsSpec() and ply.IsGhost and ply:IsGhost() then
        return
    end

    if WEPS.GetClass(wep) ~= "weapon_thr_bonecharm" then
        return false
    end
end)

if SERVER then
    -- 定义感染怪物角色的属性
    local infectionMonster = {}
    infectionMonster.infectionSound = "npc/headcrab_poison/ph_hiss1.wav" -- 感染时播放的声音(好像没奏效)
    infectionMonster.infectionDelay = 3 -- 感染延迟时间

    -- 在玩家死亡时感染并改变身份为怪物
    hook.Add("PlayerDeath", "InfectAndChangeRole", function(victim, inflictor, attacker)
        -- 确保受害者和攻击者都是玩家，并且攻击者是怪物
        if victim:IsPlayer() and attacker:IsPlayer() and attacker:GetRole() == ROLE_MONSTER then
            -- 检查受害者是否已经是怪物
            if victim:GetRole() == ROLE_MONSTER then
                return -- 如果受害者已经是怪物，直接返回，不执行感染并改变身份的操作
            end
            
            local victimPos = victim:GetPos() -- 获取受害者的位置

            -- 在延迟后复活受害者并改变身份为怪物
            victim:Revive(infectionMonster.infectionDelay,
                function(p)
                    -- 将受害者复活在死亡时的位置
                    p:SetPos(victimPos)
                    -- 将受害者改变为怪物身份
                    p:SetRole(ROLE_MONSTER) -- 假设有名为 "Monster" 的角色
                    -- 向所有客户端发送完整的游戏状态更新
                    SendFullStateUpdate()

                end,
                nil,
                true, -- true表示是被动复活，不会显示复活动画
                REVIVAL_BLOCK_ALL -- 阻止玩家在复活时看到界面的任何变化
            )
        end
    end)
end

   -- 在玩家受到伤害时的钩子函数
   hook.Add("EntityTakeDamage", "PreventFallDamage", function(target, dmg)
    -- 如果受伤的实体是玩家，并且受伤原因是摔落伤害
    if target:IsPlayer() and dmg:IsFallDamage() then
        -- 如果受伤的玩家的角色是 Monster
        if target:IsRole(ROLE_MONSTER) then
            -- 防止玩家受到摔落伤害
            dmg:ScaleDamage(0)
        end
    end
end)

hook.Add("TTTPlayerSpeedModifier", "MONSTERModifySpeed", function(ply, _, _, noLag)
	if not IsValid(ply) or ply:GetSubRole() ~= ROLE_MONSTER then return end

	noLag[1] = noLag[1] * GetGlobalFloat(walkspeed:GetName(), 1.2)
end)

if CLIENT then
	function ROLE:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_roles_additional")

		form:MakeSlider({
			serverConvar = "ttt2_monster_hp",
			label = "label_monster_maxhealth_new_monster",
			min = 10,
			max = 500,
			decimal = 0
		})

		form:MakeSlider({
			serverConvar = "ttt2_monster_walkspeed",
			label = "label_monster_walkspeed",
			min = 0,
			max = 5,
			decimal = 2
		})
        form:MakeSlider({
            serverConvar = "ttt2_monster_armor",
            label = "label_monster_armor",
            min = 0,
            max = 500,
            decimal = 0
        })
	end
end