--- Particle Effect: Disease Sneeze
-- Larger spray pattern for sneeze symptoms
-- @effect smartdisease_sneeze

function EFFECT:Init(data)
    self:SetPos(data:GetOrigin())
    self:SetEntity(data:GetEntity())
    
    self.RenderGroup = RENDERGROUP_TRANSLUCENT
    self.DieTime = CurTime() + 1.2
    self.Lifetime = 1.2
    self.StartTime = CurTime()
    self.Particles = {}
    
    -- Create larger spray particles (sneeze is more violent)
    local owner = data:GetEntity()
    if (IsValid(owner)) then
        local pos = owner:GetPos() + owner:GetViewOffset() + owner:GetAimVector() * 25
        
        for i = 1, 12 do
            local angle = math.Radian(math.random(0, 360))
            local spread = math.random(100, 200)
            
            table.insert(self.Particles, {
                pos = pos,
                vel = (owner:GetAimVector() + Vector(math.cos(angle) * spread / 100, math.sin(angle) * spread / 100, math.random(50, 150) / 100)):Normalize() * 600,
                life = 1.2,
                maxLife = 1.2,
                size = math.random(4, 12),
                color = Color(220, 220, 220, 120),
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
        p.vel = p.vel * 0.92  -- Air resistance
        p.vel.z = p.vel.z - 100 * dt  -- Gravity
        
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
        local alpha = math.Clamp(p.life / p.maxLife, 0, 1) * 180
        local col = Color(p.color.r, p.color.g, p.color.b, alpha)
        
        render.DrawQuadEasy(p.pos, Vector(0, 0, 1), p.size, p.size, col, 0)
    end
end
