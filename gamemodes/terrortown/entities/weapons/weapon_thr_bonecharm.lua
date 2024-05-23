-- 将该文件添加到客户端下载列表中
AddCSLuaFile()

-- 引入必要的全局变量和函数
local IsValid = IsValid
local math = math
local util = util

-- 如果是服务器端，添加网络字符串
if SERVER then
    util.AddNetworkString("TTT_ZombieLeapStart")
    util.AddNetworkString("TTT_ZombieLeapEnd")
end

-- 如果是客户端
if CLIENT then
    -- 设置武器名称和装备菜单数据
    SWEP.PrintName = "Claws"
    SWEP.EquipMenuData = {
        type = "Weapon",
        desc = "Left click to attack. Right click to leap. Press reload to spit."
    };

    SWEP.Slot = 8 -- add 1 to get the slot number key
    SWEP.ViewModelFOV = 54
    SWEP.ViewModelFlip = false
end

-- 设置武器基类和角色类别
SWEP.Base = "weapon_tttbase"
SWEP.Category = WEAPON_CATEGORY_ROLE

-- 设置握持类型和图标
SWEP.HoldType = "fist"
SWEP.Icon = "vgui/ttt/icon_thr.vtf"

-- 设置视图模型和世界模型
SWEP.ViewModel = Model("models/weapons/c_arms.mdl")
SWEP.WorldModel = ""

-- 设置攻击距离
SWEP.HitDistance = 250

-- 设置主要攻击参数
SWEP.Primary.Damage = 65
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.7

-- 设置次要攻击参数
SWEP.Secondary.ClipSize = 5
SWEP.Secondary.DefaultClip = 5
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 2

-- 设置额外攻击参数
SWEP.Tertiary = {}
SWEP.Tertiary.Damage = 25
SWEP.Tertiary.NumShots = 1
SWEP.Tertiary.Recoil = 5
SWEP.Tertiary.Cone = 0.02
SWEP.Tertiary.Delay = 3

-- 设置武器类型和可以购买的角色
SWEP.Kind = WEAPON_ROLE
SWEP.CanBuy = { }

-- 设置是否使用手部模型、是否允许丢弃、是否静音
SWEP.UseHands = true
SWEP.AllowDrop = false
SWEP.IsSilent = false

-- 设置下次装填时间
SWEP.NextReload = CurTime()

-- 设置部署速度
SWEP.DeploySpeed = 2
-- 设置单次攻击音效
local sound_single = Sound("Weapon_Crowbar.Single")

-- 创建游戏模式变量
local zombie_leap_enabled = CreateConVar("ttt_zombie_leap_enabled", "1", FCVAR_REPLICATED)
local zombie_spit_enabled = CreateConVar("ttt_zombie_spit_enabled", "1", FCVAR_REPLICATED)
local zombie_prime_attack_damage = CreateConVar("ttt_zombie_prime_attack_damage", "65", FCVAR_REPLICATED, "The amount of a damage a prime zombie (e.g. player who spawned as a zombie originally) does with their claws. Server or round must be restarted for changes to take effect", 1, 100)
local zombie_thrall_attack_damage = CreateConVar("ttt_zombie_thrall_attack_damage", "45", FCVAR_REPLICATED, "The amount of a damage a zombie thrall (e.g. non-prime zombie) does with their claws. Server or round must be restarted for changes to take effect", 1, 100)
local zombie_prime_attack_delay = CreateConVar("ttt_zombie_prime_attack_delay", "0.7", FCVAR_REPLICATED, "The amount of time between claw attacks for a prime zombie (e.g. player who spawned as a zombie originally). Server or round must be restarted for changes to take effect", 0.1, 3)
local zombie_thrall_attack_delay = CreateConVar("ttt_zombie_thrall_attack_delay", "1.4", FCVAR_REPLICATED, "The amount of time between claw attacks for a zombie thrall (e.g. non-prime zombie). Server or round must be restarted for changes to take effect", 0.1, 3)

-- 设置握持类型函数
function SWEP:SetWeaponHoldType(t)
    self.BaseClass.SetWeaponHoldType(self, t)

    -- 健全性检查，这应该是由上面的 BaseClass.SetWeaponHoldType 调用设置的
    if not self.ActivityTranslate then
        self.ActivityTranslate = {}
    end

    -- 设置动作翻译
    self.ActivityTranslate[ACT_MP_STAND_IDLE]                  = ACT_HL2MP_IDLE_ZOMBIE
    self.ActivityTranslate[ACT_MP_WALK]                        = ACT_HL2MP_WALK_ZOMBIE_01
    self.ActivityTranslate[ACT_MP_RUN]                         = ACT_HL2MP_RUN_ZOMBIE
    self.ActivityTranslate[ACT_MP_CROUCH_IDLE]                 = ACT_HL2MP_IDLE_CROUCH_ZOMBIE
    self.ActivityTranslate[ACT_MP_CROUCHWALK]                  = ACT_HL2MP_WALK_CROUCH_ZOMBIE_01
    self.ActivityTranslate[ACT_MP_ATTACK_STAND_PRIMARYFIRE]    = ACT_GMOD_GESTURE_RANGE_ZOMBIE
    self.ActivityTranslate[ACT_MP_ATTACK_CROUCH_PRIMARYFIRE]   = ACT_GMOD_GESTURE_RANGE_ZOMBIE
    self.ActivityTranslate[ACT_RANGE_ATTACK1]                  = ACT_GMOD_GESTURE_RANGE_ZOMBIE
end

-- 播放动画函数
function SWEP:PlayAnimation(sequence, anim)
    local owner = self:GetOwner()
    local vm = owner:GetViewModel()
    vm:SendViewModelMatchingSequence(vm:LookupSequence(anim))
    owner:SetAnimation(sequence)
end

-- 主要攻击函数
function SWEP:PrimaryAttack()
    -- 设置下次主要攻击时间
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- 进行玩家模拟
    if owner.LagCompensation then 
        owner:LagCompensation(true)
    end

    -- 随机选择攻击动作
    local anim = math.random() < 0.5 and "fists_right" or "fists_left"
    self:PlayAnimation(PLAYER_ATTACK1, anim)
    owner:ViewPunch(Angle( 4, 4, 0 ))

    local spos = owner:GetShootPos()
    local sdest = spos + (owner:GetAimVector() * 70)
    local kmins = Vector(1,1,1) * -10
    local kmaxs = Vector(1,1,1) * 10

    local tr_main = util.TraceHull({start=spos, endpos=sdest, filter=owner, mask=MASK_SHOT_HULL, mins=kmins, maxs=kmaxs})
    local hitEnt = tr_main.Entity

    -- 发出攻击声音
    self:EmitSound(sound_single)

    if IsValid(hitEnt) or tr_main.HitWorld then
        self:SendWeaponAnim(ACT_VM_HITCENTER)

        if not (CLIENT and (not IsFirstTimePredicted())) then
            local edata = EffectData()
            edata:SetStart(spos)
            edata:SetOrigin(tr_main.HitPos)
            edata:SetNormal(tr_main.Normal)
            edata:SetSurfaceProp(tr_main.SurfaceProps)
            edata:SetHitBox(tr_main.HitBox)
            edata:SetEntity(hitEnt)

            if hitEnt:IsPlayer() or hitEnt:GetClass() == "prop_ragdoll" then
                util.Effect("BloodImpact", edata)
                owner:LagCompensation(false)
                owner:FireBullets({ Num = 1, Src = spos, Dir = owner:GetAimVector(), Spread = vector_origin, Tracer = 0, Force = 1, Damage = 40 })
            else
                util.Effect("Impact", edata)
            end
        end
    else
        self:SendWeaponAnim(ACT_VM_MISSCENTER)
    end
end

-- 次要攻击函数
function SWEP:SecondaryAttack()
    -- 如果不允许跳跃，返回
    if not zombie_leap_enabled:GetBool() then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- 如果无法次要攻击或者玩家不在地面上，返回
    if not self:CanSecondaryAttack() or not owner:IsOnGround() then return end

    -- 设置下次次要攻击时间
    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

    -- 如果是服务器端
    if SERVER then
        local jumpsounds = { "npc/fast_zombie/leap1.wav", "npc/zombie/zo_attack2.wav", "npc/fast_zombie/fz_alert_close1.wav", "npc/zombie/zombie_alert1.wav" }
        owner:SetVelocity(owner:GetForward() * 200 + Vector(0,0,400))
        owner:EmitSound(jumpsounds[math.random(#jumpsounds)], 100, 100)
    end

    -- 使用跳跃动画
    self.ActivityTranslate[ACT_MP_JUMP] = ACT_ZOMBIE_LEAPING

    -- 让它看起来像玩家在跳跃
    hook.Run("DoAnimationEvent", owner, PLAYERANIMEVENT_JUMP)

    -- 将此跳跃覆盖同步到其他玩家，以便他们也可以看到它
    if SERVER then
        net.Start("TTT_ZombieLeapStart")
            net.WritePlayer(owner)
        net.Broadcast()
    end
end

-- Think 函数
function SWEP:Think()
    if self.ActivityTranslate[ACT_MP_JUMP] == nil then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or owner.m_bJumping then return end

    -- 当玩家撞到地面或落在水中时，将动画重置为正常
    if owner:IsOnGround() or owner:WaterLevel() > 0 then
        self.ActivityTranslate[ACT_MP_JUMP] = nil

        -- 将清除覆盖也同步到其他玩家
        if SERVER then
            net.Start("TTT_ZombieLeapEnd")
                net.WritePlayer(owner)
            net.Broadcast()
        end
    end
end

-- 吐痰攻击函数
function SWEP:Reload()
    -- 如果不允许吐痰，返回
    if not zombie_spit_enabled:GetBool() then return end
    if self.NextReload > CurTime() then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self.NextReload = CurTime() + self.Tertiary.Delay
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    if SERVER then
        self:CSShootBullet(self.Tertiary.Damage, self.Tertiary.Recoil, self.Tertiary.NumShots, self.Tertiary.Cone)
        owner:EmitSound("npc/fast_zombie/wake1.wav", 100, 100)
    end
    self:SendWeaponAnim(ACT_VM_MISSCENTER)

    -- 如果你玩一个假序列，拳头会以比使用“fists_holster”时更快、更干净的方式隐藏起来
    self:PlayAnimation(PLAYER_ATTACK1, "ThisIsAFakeSequence")
    -- 稍作延迟后，将拳头收回
    timer.Simple(0.25, function()
        if not IsValid(self) then return end
        if not IsValid(owner) then return end

        local vm = owner:GetViewModel()
        vm:SendViewModelMatchingSequence(vm:LookupSequence("fists_draw"))
    end)
end

-- 射击子弹函数
function SWEP:CSShootBullet(dmg, recoil, numbul, cone)
    numbul = numbul or 1
    cone = cone or 0.01

    local owner = self:GetOwner()
    local bullet = {}
    bullet.Attacker      = owner
    bullet.Num           = numbul
    bullet.Src           = owner:GetShootPos()    -- Source
    bullet.Dir           = owner:GetAimVector()   -- Dir of bullet
    bullet.Spread        = Vector(cone, 0, 0)     -- Aim Cone
    bullet.Tracer        = 1
    bullet.TracerName    = "acidtracer"
    bullet.Force         = 55
    bullet.Damage        = dmg
    bullet.Callback      = function(attacker, tr, dmginfo)
        dmginfo:SetInflictor(self)
    end

    owner:FireBullets(bullet)

    if owner:IsNPC() then return end

    -- 自定义后坐力，有时向上，有时向下
    local recoilDirection = 1
    if math.random(2) == 1 then
        recoilDirection = -1
    end

    owner:ViewPunch(Angle(recoilDirection * recoil, 0, 0))
end

-- 武器丢弃函数
function SWEP:OnDrop()
    self:Remove()
end

-- 武器收起函数
function SWEP:Holster(weap)
    if CLIENT and IsValid(weap) then
        local owner = weap:GetOwner()
        if not IsPlayer(owner) then return end

        local vm = owner:GetViewModel()
        if not IsValid(vm) or vm:GetColor() == COLOR_WHITE then return end

        vm:SetColor(COLOR_WHITE)
    end
    return true
end

-- 如果是客户端
if CLIENT then
    -- 接收跳跃开始网络消息
    net.Receive("TTT_ZombieLeapStart", function()
        local ply = net.ReadPlayer()
        if not IsPlayer(ply) then return end

        hook.Run("DoAnimationEvent", ply, PLAYERANIMEVENT_JUMP)

        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and WEPS.GetClass(wep) == "weapon_zom_claws" and wep.ActivityTranslate then
            wep.ActivityTranslate[ACT_MP_JUMP] = ACT_ZOMBIE_LEAPING
        end
    end)

    -- 接收跳跃结束网络消息
    net.Receive("TTT_ZombieLeapEnd", function()
        local ply = net.ReadPlayer()
        if not IsPlayer(ply) then return end

        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and WEPS.GetClass(wep) == "weapon_zom_claws" and wep.ActivityTranslate then
            wep.ActivityTranslate[ACT_MP_JUMP] = nil
        end
    end)

    -- 僵尸颜色设置为绿色
    local zombie_color = Color(70, 100, 25, 255)

    -- 设置视图模型颜色为僵尸颜色
    function SWEP:PreDrawViewModel(vm, wep, ply)
        if vm:GetColor() ~= zombie_color then
            vm:SetColor(zombie_color)
        end
    end

    function SWEP:OnRemove()
        local owner = self:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then
            local vm = owner:GetViewModel()
            if IsValid(vm) then
                vm:SetColor(Color(255, 255, 255, 255)) -- 恢复默认颜色
            end
        end
    end
end


