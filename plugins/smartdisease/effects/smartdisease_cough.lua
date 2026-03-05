--- Particle Effect: Disease Cough
-- Simple particle spray effect for cough symptoms
-- @effect smartdisease_cough

function EFFECT:Init(data)
    self:SetPos(data:GetOrigin())
    self:SetEntity(data:GetEntity())
    
    self.RenderGroup = RENDERGROUP_TRANSLUCENT
    self.DieTime = CurTime() + 0.8
    self.Lifetime = 0.8
    self.StartTime = CurTime()
    self.Particles = {}
    
    -- Create spray particles
    local owner = data:GetEntity()
    if (IsValid(owner)) then
        local pos = owner:GetPos() + owner:GetViewOffset() + owner:GetAimVector() * 20
        
        for i = 1, 8 do
            local angle = math.Radian(math.random(0, 360))
            local spread = math.random(50, 150)
            
            table.insert(self.Particles, {
                pos = pos,
                vel = (owner:GetAimVector() + Vector(math.cos(angle) * spread / 100, math.sin(angle) * spread / 100, math.random(10, 50) / 100)):Normalize() * 400,
                life = 0.8,
                maxLife = 0.8,
                size = math.random(3, 8),
                color = Color(200, 200, 200, 100),
            })
        end
    end
end

function EFFECT:Think()
    local elapsed = CurTime() - self.StartTime
    local progress = math.Clamp(elapsed / self.Lifetime, 0, 1)
    
    -- Update particles
    local dt = FrameTime()
    for i, p in ipairs(self.Particles) do
        p.pos = p.pos + p.vel * dt
        p.life = p.life - dt
        p.vel = p.vel * 0.95  -- Air resistance
        
        if (p.life <= 0) then
            table.remove(self.Particles, i)
        end
    end
    
    return (elapsed < self.Lifetime)
end

function EFFECT:Render()
    if (!self.Particles or #self.Particles == 0) then return end
    
    render.SetMaterial(Material("sprites/smoke"))
    
    for _, p in ipairs(self.Particles) do
        local alpha = math.Clamp(p.life / p.maxLife, 0, 1) * 150
        local col = Color(p.color.r, p.color.g, p.color.b, alpha)
        
        render.DrawQuadEasy(p.pos, Vector(0, 0, 1), p.size, p.size, col, 0)
    end
end
