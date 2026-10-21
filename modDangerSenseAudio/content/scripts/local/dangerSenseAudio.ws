// ============================================================================
// Mod: Danger Sense Audio Alert (战斗偷袭与远程暗箭声音预警 - 只狼“危”字时缓版)
// 适配版本: 《巫师3：狂猎》次世代版 (Next-Gen v4.00+ / v4.04)
// 特色: 
//   1. 纯净视听与触觉反馈（无任何遮挡画面的箭头 UI，完全靠只狼“危”音效、手柄震动与慢动作）
//   2. 近身提前预警（5米内近身起手提前 0.3~0.5 秒预警）
//   3. 远距离冲刺举斧静默过滤（超过 5 米的远距离举斧冲刺绝不提前误报，接近挥砍瞬间才响）
//   4. 面前正对敌人绝对静默（正前方 <= 60度绝对不触发音效与慢动作）
//   5. 盲区与背后敌人突袭触发瞬时子弹时间（Slow-Mo 0.30x，持续 0.45 秒，充裕反应时间）
//   6. 弓箭与远程投射物发射即时全方位预警
//   7. 死亡、处决镜头特写、剧情对话自动静默保护
// ============================================================================

// ----------------------------------------------------------------------------
// 一、 音效、触觉与反应窗口参数配置中心
// ----------------------------------------------------------------------------

// 1. 外部自定义 Wwise 音频包开关（已由 Wwise 2023.1 构建 Bank 150 并标准封包，正式启用）
function DangerSense_UseCustomBank() : bool
{
    return true;
}

function DangerSense_CustomBankName() : string
{
    return "danger_sense.bnk";
}

function DangerSense_CustomMeleeEvent() : string
{
    return "danger_sense_melee";
}

function DangerSense_RangedUseSekiroDangerSound() : bool
{
    return true;
}

// 2. 原版备选音效（仅在自定义包关闭时兜底使用）
function DangerSense_FallbackMeleeSound() : string
{
    return "gui_enchanting_runeword_add";
}

function DangerSense_FallbackRangedSound() : string
{
    return "gui_global_denied";
}

// 3. 战斗几何学参数
function DangerSense_FrontSafeAngleThreshold() : float
{
    return 60.0; // 正面安全锥角（度数）：攻击者与视线夹角 <= 60 度且在画面中，视为正前方可见，绝不触发预警和慢动作
}

function DangerSense_BlindSpotAngleThreshold() : float
{
    return 75.0; // 视野盲区夹角阈值（度数）：敌人与摄像机朝向夹角大于 75 度时判定为侧后方偷袭
}

function DangerSense_MaxMeleeRange() : float
{
    return 5.0; // 近战有效警戒距离（米）：
                // 设为 5.0 米可彻底杜绝远距离敌人举斧冲刺时过早误鸣！
                // 远处的冲刺敌人在奔跑接近到 5 米以内真正挥击砍下时，才会在近身瞬间精准触发。
}

function DangerSense_MaxVerticalDelta() : float
{
    return 3.0; // 最大垂直高低差（米）：防止楼上/楼下悬崖敌人误触
}

function DangerSense_CooldownSeconds() : float
{
    return 0.8; // 防重叠冷却时间（秒）：防止群怪同帧挥刀炸耳
}

// 4. 《只狼》风格的子弹时间反应窗口参数
function DangerSense_SlowMoEnabled() : bool
{
    return true; // 是否开启偷袭/暗箭瞬时慢动作反应窗口
}

function DangerSense_SlowMoScale() : float
{
    return 0.30; // 慢动作倍率（0.30 = 减速至正常速度的 30%，节奏更舒缓清晰）
}

function DangerSense_SlowMoDuration() : float
{
    return 0.45; // 慢动作持续现实时间（秒，给玩家充裕的闪避/破招时间）
}


// ----------------------------------------------------------------------------
// 二、 几何计算、视线盲区与敌意判定辅助函数
// ----------------------------------------------------------------------------

// 计算目标点相对于摄像机当前视线朝向的水平偏角（返回 0.0 ~ 180.0 度的绝对夹角）
function DangerSense_GetAngleToCamera(targetPos : Vector) : float
{
    var toTarget : Vector;
    var camHeading : float;
    var targetHeading : float;

    toTarget = targetPos - thePlayer.GetWorldPosition();
    camHeading = theCamera.GetCameraHeading();
    targetHeading = VecHeading(toTarget);

    return AbsF(AngleDistance(targetHeading, camHeading));
}

// 计算目标点相对于玩家身体朝向的水平偏角（返回 0.0 ~ 180.0 度的绝对夹角）
function DangerSense_GetAngleToPlayer(targetPos : Vector) : float
{
    var toTarget : Vector;
    var playerHeading : float;
    var targetHeading : float;

    toTarget = targetPos - thePlayer.GetWorldPosition();
    playerHeading = thePlayer.GetHeading();
    targetHeading = VecHeading(toTarget);

    return AbsF(AngleDistance(targetHeading, playerHeading));
}

// 判定近战攻击者是否符合“偷袭/盲区突袭”条件
function DangerSense_IsMeleeAmbush(attacker : CActor) : bool
{
    var attackerPos : Vector;
    var playerPos : Vector;
    var camAngle : float;
    var playerAngle : float;
    var dist : float;

    if (!attacker)
    {
        return false;
    }

    // 1. 过滤非敌对 NPC（防止友军或卫兵挥刀误触）
    if (attacker.GetAttitude(thePlayer) != AIA_Hostile)
    {
        return false;
    }

    attackerPos = attacker.GetWorldPosition();
    playerPos = thePlayer.GetWorldPosition();

    // 2. 距离与高低差过滤（超过 5 米的远距离冲刺绝对不提前报警，防止空挥与奔跑误报）
    dist = VecDistance(attackerPos, playerPos);
    if (dist > DangerSense_MaxMeleeRange())
    {
        return false;
    }
    if (AbsF(attackerPos.Z - playerPos.Z) > DangerSense_MaxVerticalDelta())
    {
        return false;
    }

    camAngle = DangerSense_GetAngleToCamera(attackerPos);
    playerAngle = DangerSense_GetAngleToPlayer(attackerPos);

    // 3. 【核心排除：面前绝对安全区】
    // 若攻击者处于摄像机正前方（夹角 <= 60度）且在画面内，这属于正面可预见的攻击，绝对不触发音效与慢动作！
    if (camAngle <= DangerSense_FrontSafeAngleThreshold() && thePlayer.WasVisibleInScaledFrame(attacker, 0.90, 0.90))
    {
        return false;
    }

    // 4. 引擎原生画面视野检测：如果攻击者在屏幕视野外（Out-of-Frame），直接判定为视野外偷袭
    if (!thePlayer.WasVisibleInScaledFrame(attacker, 0.95, 0.95))
    {
        return true;
    }

    // 5. 摄像机盲区夹角判定（侧后方 > 75度）
    if (camAngle > DangerSense_BlindSpotAngleThreshold())
    {
        return true;
    }

    // 6. 身体背向判定（敌人在杰洛特正后方 > 90度）
    if (playerAngle > 90.0)
    {
        return true;
    }

    return false;
}


// ----------------------------------------------------------------------------
// 三、 玩家状态扩展与预警触发执行中心
// ----------------------------------------------------------------------------

@addField(CR4Player)
public var dangerSenseLastAlertTime : float;

@addField(CR4Player)
public var dangerSenseSlowMoActive : bool;

// 确保自定义音频包在开启时按需加载
function DangerSense_EnsureBankLoaded()
{
    if (DangerSense_UseCustomBank())
    {
        if (!theSound.SoundIsBankLoaded(DangerSense_CustomBankName()))
        {
            theSound.SoundLoadBank(DangerSense_CustomBankName(), false);
        }
    }
}

// 玩家生成/读档时预载配置
@wrapMethod(CR4Player)
function OnSpawned(spawnData : SEntitySpawnData)
{
    wrappedMethod(spawnData);
    dangerSenseLastAlertTime = 0.0;
    dangerSenseSlowMoActive = false;

    if (DangerSense_UseCustomBank())
    {
        if (!theSound.SoundIsBankLoaded(DangerSense_CustomBankName()))
        {
            theSound.SoundLoadBank(DangerSense_CustomBankName(), true);
        }
    }
}

// 慢动作结束计时器回调
@addMethod(CR4Player)
timer function DangerSense_EndSlowMo(timeDelta : float, id : int)
{
    theGame.RemoveTimeScale('DangerSenseSlowMo');
    dangerSenseSlowMoActive = false;
}

// 启动慢动作反应窗口
@addMethod(CR4Player)
function DangerSense_TriggerSlowMo()
{
    var slowScale : float;
    var duration : float;

    if (!DangerSense_SlowMoEnabled() || dangerSenseSlowMoActive)
    {
        return;
    }

    slowScale = DangerSense_SlowMoScale();
    duration = DangerSense_SlowMoDuration();

    dangerSenseSlowMoActive = true;
    theGame.SetTimeScale(slowScale, 'DangerSenseSlowMo', 15, false, true);

    // 游戏时间处于减速状态，计时器需乘以时间缩放倍率以保持真实秒数
    RemoveTimer('DangerSense_EndSlowMo');
    AddTimer('DangerSense_EndSlowMo', duration * slowScale, false);
}

// 预警核心触发函数：负责音频、震动、慢动作与状态防护
@addMethod(CR4Player)
function TriggerDangerSenseAlert(isRanged : bool, attacker : CActor, optional force : bool)
{
    var now : float;
    var cooldown : float;

    // 死亡、处决特写镜头中、或剧情对话过场中自动静默（强制测试除外）
    if (!force && (!IsAlive() || IsPerformingFinisher() || theGame.IsDialogOrCutscenePlaying()))
    {
        return;
    }

    now = theGame.GetEngineTimeAsSeconds();
    cooldown = DangerSense_CooldownSeconds();

    if (now < dangerSenseLastAlertTime)
    {
        dangerSenseLastAlertTime = 0.0;
    }

    // 冷却判定：防止多敌人同帧起手炸耳
    if (!force && (now - dangerSenseLastAlertTime < cooldown))
    {
        return;
    }

    dangerSenseLastAlertTime = now;

    // 1. 声音提示调度（只狼“危”字音效）
    if (isRanged)
    {
        if (DangerSense_UseCustomBank())
        {
            DangerSense_EnsureBankLoaded();
            if (DangerSense_RangedUseSekiroDangerSound())
            {
                theSound.SoundEvent(DangerSense_CustomMeleeEvent());
            }
            else
            {
                theSound.SoundEvent(DangerSense_FallbackRangedSound());
            }
        }
        else
        {
            theSound.SoundEvent(DangerSense_FallbackRangedSound());
        }

        // 远程暗箭：轻度震动 (0.20秒)
        theGame.VibrateControllerLight(0.20);
    }
    else
    {
        if (DangerSense_UseCustomBank())
        {
            DangerSense_EnsureBankLoaded();
            theSound.SoundEvent(DangerSense_CustomMeleeEvent());
        }
        else
        {
            theSound.SoundEvent(DangerSense_FallbackMeleeSound());
        }

        // 近战偷袭：结实重度震动 (0.25秒)
        theGame.VibrateControllerHard(0.25);
    }

    // 2. 触发慢动作子弹时间（只狼风格“危”字反应窗口）
    DangerSense_TriggerSlowMo();
}

@addMethod(CR4Player)
function ResetDangerSenseCooldown()
{
    dangerSenseLastAlertTime = 0.0;
}


// ----------------------------------------------------------------------------
// 四、 核心挂载点 1：近身敌方行为树起手攻击提前判定 (<= 5米内提前 0.3~0.5 秒预警)
// ----------------------------------------------------------------------------

@wrapMethod(CBTTaskAttack)
function OnActivate() : EBTNodeStatus
{
    var res : EBTNodeStatus;
    var npc : CNewNPC;
    var target : CNode;

    res = wrappedMethod();

    npc = GetNPC();
    if (npc)
    {
        if (useCombatTarget)
        {
            target = GetCombatTarget();
        }
        else
        {
            target = GetActionTarget();
        }

        // 目标指向玩家，且攻击者处于 5 米近身范围内的偷袭盲区时，立即在起手瞬间发出预警与慢动作
        if (target == thePlayer || (CActor)target == (CActor)thePlayer || npc.GetTarget() == thePlayer)
        {
            if (DangerSense_IsMeleeAmbush(npc))
            {
                thePlayer.TriggerDangerSenseAlert(false, npc);
            }
        }
    }

    return res;
}


// ----------------------------------------------------------------------------
// 五、 核心挂载点 2：动画 PreAttack 事件挂载点 (远距离冲刺敌人接近斩下瞬间精准触发)
// ----------------------------------------------------------------------------

@wrapMethod(CNewNPC)
function OnPreAttackEvent(animEventName : name, animEventType : EAnimationEventType, data : CPreAttackEventData, animInfo : SAnimationEventAnimInfo)
{
    var currentTarget : CActor;

    wrappedMethod(animEventName, animEventType, data, animInfo);

    if (animEventType == AET_DurationStart)
    {
        currentTarget = (CActor)GetTarget();
        if (currentTarget == (CActor)thePlayer)
        {
            // 当远距离冲刺的敌人在接近至 5 米以内真正下劈挥刀瞬间，触发盲区突袭判定
            if (DangerSense_IsMeleeAmbush(this))
            {
                thePlayer.TriggerDangerSenseAlert(false, this);
            }
        }
    }
}


// ----------------------------------------------------------------------------
// 六、 核心挂载点 3：弓箭与投射物发射 Hook (远程暗箭发射瞬间全方位预警)
// ----------------------------------------------------------------------------

@wrapMethod(W3AdvancedProjectile)
function OnProjectileShot(targetCurrentPosition : Vector, optional target : CNode)
{
    var shooter : CActor;

    wrappedMethod(targetCurrentPosition, target);

    shooter = (CActor)caster;
    // 确保发射者是敌方实体（排除玩家自己发射的弩箭/炸弹，且确认敌对状态）
    if (shooter && shooter != (CActor)thePlayer && shooter.GetAttitude(thePlayer) == AIA_Hostile)
    {
        // 判定条件：无论弓箭手处于正面还是背面，只要箭矢以玩家为目标或落点朝向玩家，立即预警
        if (target == thePlayer || shooter.GetTarget() == thePlayer || VecDistance2D(targetCurrentPosition, thePlayer.GetWorldPosition()) <= 4.0)
        {
            thePlayer.TriggerDangerSenseAlert(true, shooter);
        }
    }
}


// ----------------------------------------------------------------------------
// 七、 便捷控制台测试与自检指令 (游戏内按 ~ 唤出控制台即可使用)
// ----------------------------------------------------------------------------

// 1. 测试近战偷袭预警（即刻播放只狼“危”音效 + 手柄重震 + 0.45秒慢动作反应窗口）
exec function testDangerMelee()
{
    if (thePlayer)
    {
        thePlayer.TriggerDangerSenseAlert(false, NULL, true);
    }
}

// 2. 测试远程暗箭预警（即刻播放只狼“危”音效 + 手柄轻震 + 0.45秒慢动作反应窗口）
exec function testDangerRanged()
{
    if (thePlayer)
    {
        thePlayer.TriggerDangerSenseAlert(true, NULL, true);
    }
}

// 3. 单独测试慢动作子弹时间
exec function testDangerSlowMo()
{
    if (thePlayer)
    {
        thePlayer.DangerSense_TriggerSlowMo();
    }
}

// 4. 自定义音频包状态自检
exec function testDangerBank()
{
    var isLoaded : bool;

    theSound.SoundLoadBank("danger_sense.bnk", false);
    isLoaded = theSound.SoundIsBankLoaded("danger_sense.bnk");

    if (isLoaded)
    {
        if (thePlayer)
        {
            thePlayer.DisplayHudMessage("【DangerSense】恭喜！只狼音效包 danger_sense.bnk 挂载成功！");
        }
        theSound.SoundEvent("danger_sense_melee");
        theGame.VibrateControllerHard(0.25);
    }
    else
    {
        if (thePlayer)
        {
            thePlayer.DisplayHudMessage("【DangerSense】未检测到 danger_sense.bnk，请确认 soundspc.cache 路径。");
        }
    }
}

// 5. 任意原版音效测试工具
exec function testDangerSound(soundName : string)
{
    theSound.SoundEvent(soundName);
}
