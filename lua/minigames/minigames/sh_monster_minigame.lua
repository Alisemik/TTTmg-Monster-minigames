if SERVER then
  AddCSLuaFile()
end

MINIGAME.author = "Ailesmik"
MINIGAME.contact = "813521717qq"

if CLIENT then
  MINIGAME.lang = {
    name = {
      English = "Monster invasion！",
	  zh_hans = "怪物入侵！",
      zh_tw   = "怪物入侵！"
    },
    desc = {
      English = "Some people have become monsters...",
	  zh_hans = "有的人变成了怪物...",
      zh_tw   = "有些人變成了怪物..."
	  
    }
  }
end

if SERVER then
    local minigameActive = false -- 添加一个标记，表示小游戏是否处于激活状态

    local function AssignRoles()
        if not minigameActive then return end -- 如果小游戏未激活，直接返回

        hook.Add("TTTKarmaGivePenalty", "DisableKarmaSystem", function(ply, penalty, victim)
            return true -- 始终返回 true，以防止 karma 惩罚
        end)

        local players = player.GetAll()
        local numPlayers = #players

        -- 计算怪物数量，至少有一个
        local numMonsters = math.max(math.ceil(numPlayers / 4), 1)

        -- 随机选择怪物
        local monsterIndexes = {}
        for i = 1, numMonsters do
            local randomIndex = math.random(1, numPlayers)
            table.insert(monsterIndexes, randomIndex)
        end

        -- 计算无辜者数量
        local numInnocents = numPlayers - numMonsters

        -- 如果无辜者人数大于每五分之一，将一个无辜者变为探长
        if numInnocents > math.floor(numPlayers / 5) then
            local randomInnocentIndex = math.random(1, numPlayers)
            while table.HasValue(monsterIndexes, randomInnocentIndex) do
                randomInnocentIndex = math.random(1, numPlayers)
            end
            local detectivePlayer = players[randomInnocentIndex]
            detectivePlayer:SetRole(ROLE_DETECTIVE)

            -- 给探长玩家增加一个积分
            detectivePlayer:AddCredits(1)
        end
        -- 额外选一个无辜者作为怪物
        if numInnocents > 4 * numMonsters then
            local randomInnocentIndex = math.random(1, numPlayers)
            while table.HasValue(monsterIndexes, randomInnocentIndex) do
                randomInnocentIndex = math.random(1, numPlayers)
            end
            local monsterPlayer = players[randomInnocentIndex]
            monsterPlayer:SetRole(ROLE_MONSTER)
        end

        -- 防止队友伤害
        hook.Add("PlayerShouldTakeDamage", "PreventTeamDamage", function(victim, attacker)
            -- 如果受害者或攻击者不是玩家，直接允许伤害
            if not (IsValid(victim) and victim:IsPlayer() and IsValid(attacker) and attacker:IsPlayer()) then
                return true
            end
      
            -- 如果受害者和攻击者不在同一队伍，允许伤害
            if victim:GetRole() ~= attacker:GetRole() then
                return true
            end
      
            -- 如果受害者和攻击者都是无辜者或都是探长，则阻止伤害
            if victim:GetRole() == ROLE_INNOCENT and attacker:GetRole() == ROLE_INNOCENT then
                return false
            elseif victim:GetRole() == ROLE_DETECTIVE and attacker:GetRole() == ROLE_DETECTIVE then
                return false
            end

            -- 否则，允许伤害
            return true
        end)

        -- 分配角色并设置生命值为100
        for i, ply in ipairs(players) do
            -- 检查玩家是否为怪物
            local isMonster = false
            for _, monsterIndex in ipairs(monsterIndexes) do
                if i == monsterIndex then
                    isMonster = true
                    break
                end
            end

            -- 分配角色
            if isMonster then
                ply:SetRole(ROLE_MONSTER)
            else
                if ply:GetRole() ~= ROLE_DETECTIVE then
                    ply:SetRole(ROLE_INNOCENT)
                    -- 除怪物外的其他玩家生命值设置为100
                    ply:SetHealth(100)
                end
            end
        end
    end

    -- 在回合开始时分配角色
    hook.Add("TTTBeginRound", "AssignRoles", AssignRoles)

    function MINIGAME:OnActivation()
        -- 设置小游戏激活标记为真
        minigameActive = true
    end

    function MINIGAME:OnDeactivation()
        -- 设置小游戏激活标记为假
        minigameActive = false
        -- 移除添加的钩子函数
        hook.Remove("TTTKarmaGivePenalty", "DisableKarmaSystem")
        hook.Remove("PlayerShouldTakeDamage", "PreventTeamDamage")
    end
end