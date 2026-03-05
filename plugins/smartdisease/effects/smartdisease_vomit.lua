--- Particle Effect: Disease Vomit
-- Downward spray particle effect for vomiting
-- @effect smartdisease_vomit

function EFFECT:Init(data)
    self:SetPos(data:GetOrigin())
    self:SetEntity(data:GetEntity())
    
    self.RenderGroup = RENDERGROUP_TRANSLUCENT
    self.DieTime = CurTime() + 1.5
    self.Lifetime = 1.5
    self.StartTime = CurTime()
    self.Particles = {}
    
    -- Create downward spray particles
    local owner = data:GetEntity()
    if (IsValid(owner)) then
        local pos = owner:GetPos() + owner:GetViewOffset() + Vector(0, 0, -20)
        
        for i = 1, 15 do
            local angle = math.Radian(math.random(0, 360))
            local spread = math.random(50, 100)
            
            table.insert(self.Particles, {
                pos = pos,
                vel = Vector(
                    math.cos(angle) * spread / 50,
                    math.sin(angle) * spread / 50,
                    -math.random(300, 500)  -- Downward velocity
                ),
                life = 1.5,
                maxLife = 1.5,
                size = math.random(5, 15),
                color = Color(180, 150, 100, 140),  -- Greenish-brown
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
        p.vel = p.vel * 0.85
        p.vel.z = p.vel.z - 300 * dt  -- Strong gravity
        
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
        local alpha = math.Clamp(p.life / p.maxLife, 0, 1) * 200
        local col = Color(p.color.r, p.color.g, p.color.b, alpha)
        
        render.DrawQuadEasy(p.pos, Vector(1, 0, 0), p.size, p.size, col, 0)
    end
end
