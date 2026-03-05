--- Particle Effect: Disease Bleeding
-- Blood drip and splatter particle effect
-- @effect smartdisease_bleed

function EFFECT:Init(data)
    self:SetPos(data:GetOrigin())
    self:SetEntity(data:GetEntity())
    
    self.RenderGroup = RENDERGROUP_TRANSLUCENT
    self.DieTime = CurTime() + 2.0
    self.Lifetime = 2.0
    self.StartTime = CurTime()
    self.Particles = {}
    
    -- Create blood drip particles
    local owner = data:GetEntity()
    if (IsValid(owner)) then
        local pos = owner:GetPos() + owner:GetViewOffset()
        
        for i = 1, 8 do
            table.insert(self.Particles, {
                pos = pos + Vector(math.random(-10, 10), math.random(-10, 10), math.random(-20, 0)),
                vel = Vector(
                    math.random(-50, 50),
                    math.random(-50, 50),
                    -math.random(150, 300)
                ),
                life = 2.0,
                maxLife = 2.0,
                size = math.random(3, 8),
                color = Color(150, 20, 20),  -- Dark red
            })
        end
        
        -- Add some splatter particles
        for i = 1, 5 do
            local angle = math.Radian(math.random(0, 360))
            table.insert(self.Particles, {
                pos = pos + Vector(0, 0, 10),
                vel = Vector(math.cos(angle), math.sin(angle), math.random(-50, 50) / 100) * math.random(200, 400),
                life = 1.2,
                maxLife = 1.2,
                size = math.random(1, 4),
                color = Color(180, 50, 50),  -- Brighter red for splatter
            })
        end
    end
end

function EFFECT:Think()
    local elapsed = CurTime() - self.StartTime
    
    -- Update particles
    local dt = FrameTime()
    for i, p in ipairs(self.Particles) do
        p.pos = p.pos + p.vel * dt
        p.life = p.life - dt
        p.vel = p.vel * 0.98
        p.vel.z = p.vel.z - 200 * dt  -- Gravity
        
        if (p.life <= 0) then
            table.remove(self.Particles, i)
        end
    end
    
    return (elapsed < self.Lifetime)
end

function EFFECT:Render()
    if (!self.Particles or #self.Particles == 0) then return end
    
    render.SetMaterial(Material("sprites/bloodspray"))
    
    for _, p in ipairs(self.Particles) do
        local alpha = math.Clamp(p.life / p.maxLife, 0, 1) * 220
        local col = Color(p.color.r, p.color.g, p.color.b, alpha)
        
        render.DrawQuadEasy(p.pos, Vector(0, 0, 1), p.size, p.size, col, 0)
    end
end
