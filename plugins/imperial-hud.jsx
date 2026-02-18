import React, { useState, useEffect } from 'react';

export default function ImperialHUD() {
  const [health, setHealth] = useState(100);
  const [stamina, setStamina] = useState(80);
  const [ammo, setAmmo] = useState(28);
  const [ammoReserve, setAmmoReserve] = useState(120);
  const [isReloading, setIsReloading] = useState(false);
  const [overheat, setOverheat] = useState(0);
  const [fireMode, setFireMode] = useState('AUTO');
  const [compass, setCompass] = useState(245);
  const [defcon, setDefcon] = useState(3);
  const [hasWeapon, setHasWeapon] = useState(true);
  const [inSquad, setInSquad] = useState(true);
  const [radioActive, setRadioActive] = useState(false);
  const [hasPriorityOrder, setHasPriorityOrder] = useState(false);
  const [hasObjective, setHasObjective] = useState(true);
  const [commsMenuOpen, setCommsMenuOpen] = useState(false);
  const [currentChannel, setCurrentChannel] = useState('8858.0');

  // Demo controls
  const [showControls, setShowControls] = useState(true);

  const commsChannels = [
    { freq: '8858.0', name: 'COMMAND NET', encrypted: true },
    { freq: '4521.5', name: 'SQUAD COMMS', encrypted: true },
    { freq: '7799.2', name: 'LOGISTICS', encrypted: false },
    { freq: '3366.8', name: 'EMERGENCY', encrypted: true },
  ];

  const defconData = {
    1: { color: '#FF2D2D', label: 'MAXIMUM READINESS', desc: 'Imminent threat - combat stations' },
    2: { color: '#FF8C1A', label: 'HIGH ALERT', desc: 'Hostile contact probable' },
    3: { color: '#FFD91A', label: 'ELEVATED WATCH', desc: 'Increased security measures' },
    4: { color: '#4A9EFF', label: 'STANDARD ALERT', desc: 'Normal defensive posture' },
    5: { color: '#7FFF7F', label: 'PEACETIME', desc: 'Minimal threat level' }
  };

  const squadMembers = [
    { name: 'CT-7734', rank: 'Sergeant', health: 95, status: 'ACTIVE' },
    { name: 'CT-2891', rank: 'Corporal', health: 72, status: 'ENGAGED' },
    { name: 'CT-5512', rank: 'Trooper', health: 38, status: 'WOUNDED' }
  ];

  const handleReload = () => {
    if (!isReloading && ammoReserve > 0) {
      setIsReloading(true);
      setTimeout(() => {
        const reloadAmount = Math.min(30, ammoReserve);
        setAmmo(reloadAmount);
        setAmmoReserve(ammoReserve - reloadAmount);
        setIsReloading(false);
      }, 2000);
    }
  };

  const handleFire = () => {
    if (ammo > 0 && !isReloading) {
      setAmmo(prev => prev - 1);
      setOverheat(prev => Math.min(100, prev + 8));
    }
  };

  useEffect(() => {
    if (overheat > 0) {
      const timer = setTimeout(() => setOverheat(prev => Math.max(0, prev - 2)), 100);
      return () => clearTimeout(timer);
    }
  }, [overheat]);

  const getHealthColor = () => {
    if (health > 60) return '#7FFF7F';
    if (health > 30) return '#FFD91A';
    return '#FF2D2D';
  };

  const getOverheatColor = () => {
    if (overheat < 50) return '#4A9EFF';
    if (overheat < 80) return '#FFD91A';
    return '#FF2D2D';
  };

  return (
    <div className="relative w-full h-screen bg-black overflow-hidden" style={{ fontFamily: 'monospace' }}>
      {/* Background (simulated gameplay view) */}
      <div className="absolute inset-0 bg-gradient-to-b from-gray-900 via-gray-800 to-gray-900 opacity-50" />

      {/* DEMO CONTROLS - Moved to bottom center to avoid compass */}
      {showControls && (
        <div className="absolute bottom-24 left-1/2 transform -translate-x-1/2 bg-black bg-opacity-90 border border-gray-600 p-4 rounded z-50 text-xs">
          <div className="text-gray-300 mb-2 text-center font-bold">DEMO CONTROLS</div>
          <div className="grid grid-cols-3 gap-2">
            <button onClick={() => setHealth(Math.max(0, health - 20))} className="bg-red-900 hover:bg-red-800 text-white px-2 py-1 rounded">-20 HP</button>
            <button onClick={() => setHealth(Math.min(100, health + 20))} className="bg-green-900 hover:bg-green-800 text-white px-2 py-1 rounded">+20 HP</button>
            <button onClick={handleFire} className="bg-blue-900 hover:bg-blue-800 text-white px-2 py-1 rounded">Fire</button>
            
            <button onClick={handleReload} className="bg-yellow-900 hover:bg-yellow-800 text-white px-2 py-1 rounded">Reload</button>
            <button onClick={() => setFireMode(fireMode === 'AUTO' ? 'SEMI' : fireMode === 'SEMI' ? 'BURST' : 'AUTO')} className="bg-purple-900 hover:bg-purple-800 text-white px-2 py-1 rounded">Fire Mode</button>
            <button onClick={() => setDefcon(defcon === 5 ? 1 : defcon + 1)} className="bg-orange-900 hover:bg-orange-800 text-white px-2 py-1 rounded">DEFCON</button>
            
            <button onClick={() => setHasWeapon(!hasWeapon)} className="bg-gray-700 hover:bg-gray-600 text-white px-2 py-1 rounded text-[10px]">Weapon: {hasWeapon ? 'ON' : 'OFF'}</button>
            <button onClick={() => setInSquad(!inSquad)} className="bg-gray-700 hover:bg-gray-600 text-white px-2 py-1 rounded text-[10px]">Squad: {inSquad ? 'ON' : 'OFF'}</button>
            <button onClick={() => setRadioActive(!radioActive)} className="bg-gray-700 hover:bg-gray-600 text-white px-2 py-1 rounded text-[10px]">Radio: {radioActive ? 'ON' : 'OFF'}</button>
            <button onClick={() => setCommsMenuOpen(!commsMenuOpen)} className="bg-cyan-700 hover:bg-cyan-600 text-white px-2 py-1 rounded text-[10px]">Comms Menu</button>
            
            <button onClick={() => setHasPriorityOrder(!hasPriorityOrder)} className="bg-red-800 hover:bg-red-700 text-white px-2 py-1 rounded text-[10px] col-span-2">Priority Order</button>
            <button onClick={() => setHasObjective(!hasObjective)} className="bg-amber-800 hover:bg-amber-700 text-white px-2 py-1 rounded text-[10px]">Objective: {hasObjective ? 'ON' : 'OFF'}</button>
            <button onClick={() => setShowControls(false)} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 rounded text-[10px]">Hide</button>
          </div>
        </div>
      )}
      
      {!showControls && (
        <button onClick={() => setShowControls(true)} className="absolute bottom-8 right-1/2 transform translate-x-1/2 bg-black bg-opacity-60 border border-gray-600 px-3 py-1 rounded text-xs text-gray-400 hover:text-gray-200 z-50">
          Show Controls
        </button>
      )}

      {/* TOP CENTER - COMPASS & WAYPOINTS */}
      <div className="absolute top-6 left-1/2 transform -translate-x-1/2 flex flex-col items-center gap-2">
        {/* Compass */}
        <div className="flex items-center gap-3 bg-black bg-opacity-60 border border-gray-700 px-4 py-2">
          <div className="text-gray-500 text-xs tracking-wider">BEARING</div>
          <div className="text-amber-400 text-2xl font-bold tracking-widest" style={{ fontFamily: 'Courier New, monospace' }}>
            {compass.toString().padStart(3, '0')}°
          </div>
          <div className="flex gap-1 text-[10px] text-gray-400">
            <span className={compass >= 315 || compass < 45 ? 'text-amber-400' : ''}>N</span>
            <span className={compass >= 45 && compass < 135 ? 'text-amber-400' : ''}>E</span>
            <span className={compass >= 135 && compass < 225 ? 'text-amber-400' : ''}>S</span>
            <span className={compass >= 225 && compass < 315 ? 'text-amber-400' : ''}>W</span>
          </div>
        </div>
        
        {/* Waypoint */}
        <div className="bg-black bg-opacity-60 border border-blue-700 px-3 py-1 text-xs text-blue-400">
          <span className="text-gray-400">TARGET:</span> CHECKPOINT-7 <span className="text-gray-500 ml-2">145M</span>
        </div>
      </div>

      {/* TOP LEFT - PRIORITY HIERARCHY: Priority Order > Current Objective > DEFCON */}
      <div className="absolute top-6 left-6">
        {hasPriorityOrder ? (
          // Priority Order - Highest Priority, replaces everything
          <div className="bg-red-950 bg-opacity-90 border-2 border-red-500 px-4 py-3 animate-pulse">
            <div className="flex items-center gap-2 mb-1">
              <div className="w-2 h-2 bg-red-500 animate-pulse" />
              <div className="text-red-400 text-xs font-bold tracking-widest">PRIORITY TRANSMISSION</div>
            </div>
            <div className="text-red-200 text-sm font-bold">SECURE HANGAR BAY 3</div>
            <div className="text-red-300 text-xs mt-1">Hostile infiltration detected</div>
            <div className="text-gray-400 text-[10px] mt-2">ISS VENGEANCE // CMDR TARKIN</div>
          </div>
        ) : hasObjective ? (
          // Current Objective - replaces DEFCON when active
          <div className="bg-black bg-opacity-80 border border-amber-700 px-4 py-2">
            <div className="text-amber-400 text-xs tracking-wider mb-1">CURRENT OBJECTIVE</div>
            <div className="text-white text-sm">Patrol Sector 7-G</div>
            <div className="text-gray-400 text-xs">Report anomalies</div>
          </div>
        ) : (
          // DEFCON Status - shown only when no objective and no priority order
          <div className="bg-black bg-opacity-70 border px-4 py-2" style={{ borderColor: defconData[defcon].color }}>
            <div className="flex items-center gap-3">
              <div className="text-xs text-gray-400 tracking-wider">DEFCON</div>
              <div className="text-3xl font-bold tracking-wider" style={{ color: defconData[defcon].color }}>
                {defcon}
              </div>
            </div>
            <div className="text-xs mt-1" style={{ color: defconData[defcon].color }}>
              {defconData[defcon].label}
            </div>
            <div className="text-[10px] text-gray-500 mt-0.5">
              {defconData[defcon].desc}
            </div>
          </div>
        )}
      </div>

      {/* RIGHT MID-TOP - RADIO/COMMS with expandable channel selector */}
      {radioActive && (
        <div className="absolute right-6 top-32">
          {/* Main Comms Display */}
          <div 
            className="bg-black bg-opacity-70 border border-cyan-700 px-3 py-2 cursor-pointer hover:bg-opacity-80 transition-all"
            onClick={() => setCommsMenuOpen(!commsMenuOpen)}
          >
            <div className="flex items-center justify-between gap-4 mb-2">
              <div className="flex items-center gap-2">
                <div className="w-1.5 h-1.5 bg-cyan-400 rounded-full animate-pulse" />
                <div className="text-cyan-400 text-xs tracking-wider">COMMS ACTIVE</div>
              </div>
              <div className="text-gray-400 text-xs">{commsMenuOpen ? '▲' : '▼'}</div>
            </div>
            <div className="flex items-center gap-3 mb-1">
              <div className="w-10 h-10 bg-gray-800 border border-gray-700 flex items-center justify-center">
                <div className="text-gray-500 text-xs">IMG</div>
              </div>
              <div>
                <div className="text-white text-xs font-bold">CT-5597</div>
                <div className="text-gray-400 text-[10px]">Corporal</div>
              </div>
            </div>
            <div className="text-cyan-300 text-xs mt-2">FREQ: {currentChannel}</div>
            <div className="text-gray-500 text-[10px]">
              {commsChannels.find(ch => ch.freq === currentChannel)?.encrypted ? 'ENCRYPTED // SCRAMBLE-4' : 'UNENCRYPTED'}
            </div>
          </div>

          {/* Channel Selector - Extends below */}
          {commsMenuOpen && (
            <div className="bg-black bg-opacity-90 border border-cyan-700 border-t-0">
              <div className="border-t border-cyan-900 px-3 py-2">
                <div className="text-cyan-400 text-xs tracking-wider mb-2">SELECT CHANNEL</div>
                {commsChannels.map((channel, i) => (
                  <div
                    key={i}
                    onClick={(e) => {
                      e.stopPropagation();
                      setCurrentChannel(channel.freq);
                      setCommsMenuOpen(false);
                    }}
                    className={`px-2 py-2 mb-1 last:mb-0 cursor-pointer border transition-all ${
                      currentChannel === channel.freq
                        ? 'bg-cyan-900 bg-opacity-40 border-cyan-500'
                        : 'bg-gray-900 bg-opacity-40 border-gray-700 hover:border-cyan-700'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-1">
                      <div className="text-white text-xs font-bold">{channel.freq}</div>
                      {channel.encrypted && (
                        <div className="text-cyan-400 text-[9px]">🔒</div>
                      )}
                    </div>
                    <div className="text-gray-400 text-[10px]">{channel.name}</div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* LEFT MID - SQUAD STATUS (positioned in middle to avoid vitals overlap) */}
      {inSquad && (
        <div className="absolute left-6 top-1/3 bg-black bg-opacity-70 border border-gray-700 px-3 py-2">
          <div className="text-gray-400 text-xs tracking-wider mb-2 border-b border-gray-700 pb-1">FIRETEAM AUREK</div>
          {squadMembers.map((member, i) => (
            <div key={i} className="flex items-center gap-3 mb-2 last:mb-0">
              <div className="w-8 h-8 bg-gray-800 border border-gray-700" />
              <div className="flex-1">
                <div className="text-white text-xs">{member.name}</div>
                <div className="text-gray-500 text-[10px]">{member.rank}</div>
              </div>
              <div className="flex flex-col items-end gap-0.5">
                <div className="w-12 h-1.5 bg-gray-800 border border-gray-700">
                  <div 
                    className="h-full transition-all" 
                    style={{ 
                      width: `${member.health}%`,
                      backgroundColor: member.health > 60 ? '#7FFF7F' : member.health > 30 ? '#FFD91A' : '#FF2D2D'
                    }}
                  />
                </div>
                <div className="text-[9px]" style={{ 
                  color: member.status === 'ACTIVE' ? '#7FFF7F' : member.status === 'ENGAGED' ? '#FFD91A' : '#FF2D2D' 
                }}>
                  {member.status}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* BOTTOM LEFT - HEALTH & STAMINA */}
      <div className="absolute bottom-6 left-6 flex flex-col gap-3">
        {/* Player Identity */}
        <div className="bg-black bg-opacity-70 border border-gray-700 px-3 py-1.5">
          <div className="text-white text-sm font-bold">CT-9247 "Winton"</div>
          <div className="text-gray-400 text-xs">2nd Lieutenant // 501st Legion</div>
        </div>

        {/* Health */}
        <div className="bg-black bg-opacity-70 border border-gray-700 px-4 py-2">
          <div className="flex items-center justify-between mb-1">
            <div className="text-gray-400 text-xs tracking-wider">VITALS</div>
            <div className="text-lg font-bold" style={{ color: getHealthColor() }}>
              {health}%
            </div>
          </div>
          <div className="w-48 h-2 bg-gray-900 border border-gray-700">
            <div 
              className="h-full transition-all duration-300" 
              style={{ width: `${health}%`, backgroundColor: getHealthColor() }}
            />
          </div>
          {health < 30 && (
            <div className="text-red-400 text-[10px] mt-1 animate-pulse">CRITICAL - MEDICAL ATTENTION REQUIRED</div>
          )}
        </div>

        {/* Stamina */}
        <div className="bg-black bg-opacity-70 border border-gray-700 px-4 py-2">
          <div className="flex items-center justify-between mb-1">
            <div className="text-gray-400 text-xs tracking-wider">STAMINA</div>
            <div className="text-sm text-cyan-400">{stamina}%</div>
          </div>
          <div className="w-48 h-1.5 bg-gray-900 border border-gray-700">
            <div 
              className="h-full transition-all bg-cyan-400" 
              style={{ width: `${stamina}%` }}
            />
          </div>
        </div>
      </div>

      {/* BOTTOM RIGHT - AMMO & WEAPON INFO */}
      {hasWeapon && (
        <div className="absolute bottom-6 right-6 flex flex-col items-end gap-3">
          {/* Fire Mode */}
          <div className="bg-black bg-opacity-70 border border-purple-700 px-3 py-1">
            <div className="text-purple-400 text-xs tracking-widest">{fireMode}</div>
          </div>

          {/* Ammo Display */}
          <div className="bg-black bg-opacity-70 border border-gray-700 px-4 py-3">
            {isReloading ? (
              <div className="flex flex-col items-center">
                <div className="text-yellow-400 text-sm tracking-wider mb-2">RELOADING</div>
                <div className="w-32 h-1.5 bg-gray-900 border border-gray-700 overflow-hidden">
                  <div className="h-full bg-yellow-400 animate-pulse" style={{ width: '50%' }} />
                </div>
              </div>
            ) : ammo === 0 ? (
              <div className="text-red-400 text-sm tracking-wider animate-pulse">NO AMMUNITION</div>
            ) : (
              <div className="flex items-baseline gap-2">
                <div className="text-5xl font-bold text-white" style={{ fontFamily: 'Courier New, monospace' }}>
                  {ammo.toString().padStart(2, '0')}
                </div>
                <div className="text-gray-400 text-xl">/</div>
                <div className="text-gray-400 text-2xl">{ammoReserve}</div>
              </div>
            )}
            
            {/* Overheat Indicator */}
            {overheat > 0 && (
              <div className="mt-3">
                <div className="flex items-center justify-between mb-1">
                  <div className="text-gray-400 text-[10px] tracking-wider">HEAT</div>
                  <div className="text-xs font-bold" style={{ color: getOverheatColor() }}>
                    {overheat}%
                  </div>
                </div>
                <div className="w-full h-1.5 bg-gray-900 border border-gray-700">
                  <div 
                    className="h-full transition-all" 
                    style={{ 
                      width: `${overheat}%`, 
                      backgroundColor: getOverheatColor() 
                    }}
                  />
                </div>
                {overheat >= 80 && (
                  <div className="text-red-400 text-[10px] mt-1 animate-pulse">COOLING REQUIRED</div>
                )}
              </div>
            )}

            <div className="text-gray-500 text-xs mt-2 text-center">DC-15A CARBINE</div>
          </div>
        </div>
      )}

      {/* Critical Health Overlay */}
      {health < 20 && (
        <div className="absolute inset-0 pointer-events-none border-8 border-red-500 animate-pulse opacity-30" />
      )}
    </div>
  );
}
