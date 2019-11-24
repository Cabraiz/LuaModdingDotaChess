--[[
    An Easier Physics Class
    Author:XavierCHN
    Date: 2015.02.10
]]
 
PHYSICS_DEBUG = DEBUG_MODE
 
PHYSICS_DEFAULT_ACCELERATION_OF_GRAVITY = -9.8
PHYSICS_DEFAULT_FRICTION_OF_GROUND = 1
PHYSICS_DEFAULT_UNIT_MASS = 1
PHYSICS_DEFAULT_MAX_REBOUNCE_COUNT = 0
PHYSICS_DEFAULT_REBOUNCE_AMP = 0.8
 
PHYSICS_BEHAVIOR_GRIDNAV_NONE = 0
PHYSICS_BEHAVIOR_GRIDNAV_CLIMB = 1
-- PHYSICS_BEHAVIOR_GRIDNAV_REBOUNCE = 2 -- 未完成
 
-- PHYSICS_COLLIDER_TYPE_BOX = 0
-- PHYSICS_COLLIDER_TYPE_WALL = 1
-- PHYSICS_COLLIDER_TYPE_CIRCLE =2
 
if Physics == nil then Physics = class({}) end
 

 
function Physics:Unit(unit)
    function unit:SetMass(mass)
        unit.fMass = mass
    end
    function unit:GetMass()
        return unit.fMass or PHYSICS_DEFAULT_UNIT_MASS
    end
    function unit:GetGravity()
        return unit:GetMass() * unit:GetG()
    end
    function unit:SetFriction(fFriction)
        unit.fFriction = fFriction
    end
    function unit:GetFriction()
        return unit.fFriction or PHYSICS_DEFAULT_FRICTION_OF_GROUND
    end
    function unit:IsOnGround()
        return unit:GetAbsOrigin().z <= unit:GetPhysicsGroundPosition().z
    end
    function unit:GetPhysicsGroundPosition()
        return GetGroundPosition(unit:GetAbsOrigin(),unit) + Vector(0,0,unit:GetMinHeight())
    end
    function unit:SetForce(vForce)
        unit.vForce = vForce
    end
    function unit:GetOutForce()
        return unit.vForce or Vector(0,0,0)
    end
    function unit:GetFrictionForce()
        if unit:IsOnGround() then
            return unit:GetMass() * unit:GetFriction() * (0 - unit:GetVelocity():Normalized())
        end
        return Vector(0,0,0)
    end
    function unit:GetForce()
        if unit:IsOnGround() then
            return unit:GetOutForce() + unit:GetFrictionForce()
        end
        return unit:GetOutForce() + unit:GetGravity()
    end
    function unit:AddForce(vForce)
        local l = unit.vForce or Vector(0,0,0)
        unit.vForce = l + vForce
    end
    function unit:SetMaxRebounce(nMax)
        unit.nMaxRebounce = nMax
    end
    function unit:GetMaxRebounce()
        return unit.nMaxRebounce or PHYSICS_DEFAULT_MAX_REBOUNCE_COUNT
    end
    function unit:CanUnitRebounce()
        if unit.nRebounceCount == nil then
            unit.nRebounceCount = 0
        end
        if unit.nRebounceCount < unit:GetMaxRebounce() then
            unit.nRebounceCount = unit.nRebounceCount + 1
            return true
        else
            unit.nRebounceCount = 0
            return false
        end
        return false
    end
    function unit:SetRebounceAmp(amp)
        unit.vRebounceAmp = amp
    end
    function unit:GetRebounceAmp()
        return unit.vRebounceAmp or PHYSICS_DEFAULT_REBOUNCE_AMP
    end
    function unit:SetVelocity(vVelocity)
        unit.vVelocity = vVelocity
    end
    function unit:GetVelocity()
        return unit.vVelocity or Vector(0,0,0)
    end
    function unit:GetAcceleration()
        return unit:GetForce() / unit:GetMass()
    end
    function unit:OnPhysicsFrame(func)
        unit.funcOnPhysicsFrameCallback = func
    end
    function unit:OnGroundRebounce(func)
        unit.funcOnGroundRebounceCallBack = func
    end
    function unit:SetG(g)
        unit.g = g
    end
    function unit:GetG()
        return unit.g or Physics:GetG()
    end
    function unit:SetGridNavBehavior(nBehavior)
        unit.nGridNavBehavior = nBehavior
    end
    function unit:GetGridNavBehavior()
        return unit.nGridNavBehavior or PHYSICS_BEHAVIOR_GRIDNAV_NONE
    end
    function unit:GetRealVelocity()
        return unit.vVelocityReal
    end
    function unit:SetMinHeight(height)
        unit.fMinHeight = height
    end
    function unit:GetMinHeight()
        return unit.fMinHeight or 0
    end
    function unit:SetMaxHeight(height)
        unit.fMaxHeight = height
    end
    function unit:GetMaxHeight()
        return unit.fMaxHeight
    end
    table.insert(Physics.physicsUnits, unit)
 
    -- return unit
end
function Physics:PerformCallback(unit, func)
    if unit[func] then
        local success, nextCall = pcall(unit[func], unit)
        if success then
            if not nextCall then
                unit[func] = nil
            end
        else
            tPrint("[PHYSICS] CALLBACK ERROR:"..nextCall)
        end
    end
end
function Physics:PerformPhysicsMovement(unit, dt)
    local a = unit:GetAcceleration()

    local v0 = unit:GetVelocity()
    local vt = v0 + a * dt

    if unit:IsOnGround() and vt.z < 0 then
        if unit:CanUnitRebounce() then
            vt.z = 0 - vt.z
            vt = vt * unit:GetRebounceAmp()
            self:PerformCallback(unit, "funcOnGroundRebounceCallBack")
        else
            vt.z = 0
        end
    end
 
    unit:SetVelocity(vt)

    local p0 = unit:GetAbsOrigin()
    local pt = p0 + v0 * dt * 100

    local cliff = ( not GridNav:IsTraversable(pt) ) or GridNav:IsBlocked(pt)
    if cliff then
        local b = unit:GetGridNavBehavior()
        if b == PHYSICS_BEHAVIOR_GRIDNAV_CLIMB then
            pt = unit:GetPhysicsGroundPosition()
        end
        if b == PHYSICS_BEHAVIOR_GRIDNAV_REBOUNCE then
        end
    end
    unit.vVelocityReal = ( pt - p0 ) / dt

    if pt.z < unit:GetPhysicsGroundPosition().z then pt.z = unit:GetPhysicsGroundPosition().z end
    unit:SetAbsOrigin(pt)
    if DEBUG_MODE then
        DebugDrawLine(pt, pt + vt, 255, 255, 255, true, dt)
        DebugDrawLine(pt, pt + a, 255, 0, 0, true, dt)
    end
end
function Physics:OnPhysicsFrame()
    -- 计算dt
    local now = GameRules:GetGameTime()
    if self.__tLastCall == nil then self.__tLastCall = now - 0.03 end
    local dt = now - self.__tLastCall
    self.__tLastCall = now
 
    self.nFrameCount = self.nFrameCount + 1

    for _, unit in pairs(self.physicsUnits) do
        self:PerformPhysicsMovement(unit, dt)
        self:PerformCallback(unit, "funcOnPhysicsFrameCallback")
    end
 
end
function Physics:Start()
    self.g = Vector(0,0,PHYSICS_DEFAULT_ACCELERATION_OF_GRAVITY)
 
    self.nFrameCount = 0
 
    Timers:CreateTimer(
        function()
            self:OnPhysicsFrame()
            return 0.01
        end
    )
    self.physicsUnits = {}
    self.physicsColliders = {}
 
end
function Physics:SetG(g)
    self.g = g or Vector(0,0,PHYSICS_DEFAULT_ACCELERATION_OF_GRAVITY)
end
function Physics:GetG()
    return self.g
end
 
Physics:Start()