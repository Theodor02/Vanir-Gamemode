import React, { useState, useEffect } from 'react';

export default function ImperialHUDFinal() {
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
  const [connectedChannels, setConnectedChannels] = useState(['COMMAND NET', 'SQUAD COMMS']); // Can connect to 2 channels
  const [activeTransmission, setActiveTransmission] = useState(null); // { speaker, channel, encrypted, freq }
  const [commsMenuOpen, setCommsMenuOpen] = useState(false);
  const [hasRadio, setHasRadio] = useState(true); // Whether player has radio equipment
  const [hasPriorityOrder, setHasPriorityOrder] = useState(false);
  const [hasObjective, setHasObjective] = useState(true);
  const [lastDamageDirection, setLastDamageDirection] = useState(null);
  const [showControls, setShowControls] = useState(true);

  const commsChannels = [
    { id: 'cmd', name: 'COMMAND NET', freq: '8858.0', encrypted: true },
    { id: 'sqd', name: 'SQUAD COMMS', freq: '4521.5', encrypted: true },
    { id: 'log', name: 'LOGISTICS', freq: '7799.2', encrypted: false },
    { id: 'emg', name: 'EMERGENCY', freq: '3366.8', encrypted: true },
  ];

  const defconData = {
    1: { label: 'MAXIMUM READINESS', desc: 'Station lockdown - All personnel to combat stations', threat: 'CRITICAL' },
    2: { label: 'HIGH ALERT', desc: 'Hostile contact probable - Weapons hot', threat: 'SEVERE' },
    3: { label: 'ELEVATED WATCH', desc: 'Increased security measures active', threat: 'ELEVATED' },
    4: { label: 'STANDARD ALERT', desc: 'Normal defensive posture maintained', threat: 'GUARDED' },
    5: { label: 'PEACETIME', desc: 'Minimal threat - Standard operations', threat: 'LOW' }
  };

  const squadMembers = [
    { name: 'CT-7734', rank: 'SGT', health: 95, status: 'ACTIVE', distance: 12, bearing: 45 },
    { name: 'CT-2891', rank: 'CPL', health: 72, status: 'ENGAGED', distance: 8, bearing: 120 },
    { name: 'CT-5512', rank: 'PVT', health: 38, status: 'WOUNDED', distance: 23, bearing: 280 }
  ];

  const handleReload = () => {
    if (!isReloading && ammoReserve > 0 && ammo < 30) {
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

  const simulateDamage = (amount) => {
    setHealth(Math.max(0, health - amount));
    const directions = ['top', 'right', 'bottom', 'left'];
    const randomDir = directions[Math.floor(Math.random() * directions.length)];
    setLastDamageDirection(randomDir);
    setTimeout(() => setLastDamageDirection(null), 200);
  };

  const toggleChannelConnection = (channelName) => {
    if (connectedChannels.includes(channelName)) {
      // Disconnect if already connected
      setConnectedChannels(connectedChannels.filter(c => c !== channelName));
    } else {
      // Connect if not at max (2 channels)
      if (connectedChannels.length < 2) {
        setConnectedChannels([...connectedChannels, channelName]);
      } else {
        // Replace oldest channel
        setConnectedChannels([connectedChannels[1], channelName]);
      }
    }
  };

  const simulateTransmission = () => {
    const channel = connectedChannels[Math.floor(Math.random() * connectedChannels.length)];
    const channelData = commsChannels.find(c => c.name === channel);
    setActiveTransmission({
      speaker: 'CT-7734',
      channel: channel,
      encrypted: channelData.encrypted,
      freq: channelData.freq
    });
    
    // Auto-clear after 3 seconds
    setTimeout(() => setActiveTransmission(null), 3000);
  };

  useEffect(() => {
    if (overheat > 0) {
      const timer = setTimeout(() => setOverheat(prev => Math.max(0, prev - 2)), 100);
      return () => clearTimeout(timer);
    }
  }, [overheat]);

  const getBearingIndicator = (bearing) => {
    const diff = ((bearing - compass + 180 + 360) % 360) - 180;
    if (Math.abs(diff) < 20) return '↑';
    if (diff > 20 && diff < 70) return '↗';
    if (diff >= 70 && diff < 110) return '→';
    if (diff >= 110 && diff < 160) return '↘';
    if (diff >= 160) return '↓';
    if (diff < -20 && diff > -70) return '↖';
    if (diff <= -70 && diff > -110) return '←';
    if (diff <= -110 && diff > -160) return '↙';
    return '↓';
  };

  return (
    <div className="relative w-full h-screen bg-black overflow-hidden" style={{ 
      fontFamily: "'Georgia', 'Times New Roman', serif"
    }}>
      <style>{`
        @keyframes damage-pulse {
          0%, 100% { opacity: 0; }
          50% { opacity: 0.3; }
        }
        
        @keyframes transmission-pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
        
        .damage-flash {
          animation: damage-pulse 0.2s ease-out;
        }

        .transmission-active {
          animation: transmission-pulse 1s ease-in-out infinite;
        }

        .terminal-text {
          font-family: 'Courier New', monospace;
          letter-spacing: 0.5px;
        }

        .stat-bar-fill {
          background: linear-gradient(90deg, #B8860B 0%, #DAA520 50%, #B8860B 100%);
        }

        .stat-bar-danger {
          background: linear-gradient(90deg, #8B0000 0%, #DC143C 50%, #8B0000 100%);
        }

        .stat-bar-caution {
          background: linear-gradient(90deg, #B8860B 0%, #FFD700 50%, #B8860B 100%);
        }

        .readable-text {
          text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.8);
        }
      `}</style>

      {/* Background - simulated 3D view */}
      <div className="absolute inset-0 bg-gradient-to-b from-gray-900 via-gray-800 to-gray-900" />

      {/* Damage direction flash */}
      {lastDamageDirection && (
        <div className={`absolute damage-flash pointer-events-none ${
          lastDamageDirection === 'top' ? 'top-0 left-0 right-0 h-32' :
          lastDamageDirection === 'right' ? 'top-0 right-0 bottom-0 w-32' :
          lastDamageDirection === 'bottom' ? 'bottom-0 left-0 right-0 h-32' :
          'top-0 left-0 bottom-0 w-32'
        }`} style={{
          background: lastDamageDirection === 'top' || lastDamageDirection === 'bottom'
            ? 'linear-gradient(to bottom, rgba(139, 0, 0, 0.4), transparent)'
            : 'linear-gradient(to right, rgba(139, 0, 0, 0.4), transparent)',
          transform: lastDamageDirection === 'bottom' ? 'rotate(180deg)' :
                     lastDamageDirection === 'right' ? 'rotate(0deg)' :
                     lastDamageDirection === 'left' ? 'rotate(180deg)' : 'none'
        }} />
      )}

      {/* DEMO CONTROLS */}
      {showControls && (
        <div className="absolute bottom-20 left-1/2 transform -translate-x-1/2 bg-black bg-opacity-90 border border-gray-700 p-3 z-50">
          <div className="text-gray-400 text-xs mb-2 text-center font-bold terminal-text">DEMO CONTROLS</div>
          <div className="grid grid-cols-4 gap-1 text-[10px] terminal-text">
            <button onClick={() => simulateDamage(20)} className="bg-red-900 hover:bg-red-800 text-white px-2 py-1 border border-red-700">-20 HP</button>
            <button onClick={() => setHealth(Math.min(100, health + 20))} className="bg-green-900 hover:bg-green-800 text-white px-2 py-1 border border-green-700">+20 HP</button>
            <button onClick={handleFire} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">FIRE</button>
            <button onClick={handleReload} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">RELOAD</button>
            
            <button onClick={() => setFireMode(fireMode === 'AUTO' ? 'SEMI' : fireMode === 'SEMI' ? 'BURST' : 'AUTO')} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">MODE</button>
            <button onClick={() => setDefcon(defcon === 5 ? 1 : defcon + 1)} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">DEFCON</button>
            <button onClick={() => setCompass((compass + 45) % 360)} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">ROTATE</button>
            <button onClick={() => setStamina(Math.max(0, stamina - 20))} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">-STAM</button>
            
            <button onClick={() => setHasWeapon(!hasWeapon)} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">WEAPON</button>
            <button onClick={() => setInSquad(!inSquad)} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">SQUAD</button>
            <button onClick={() => setHasRadio(!hasRadio)} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">RADIO</button>
            <button onClick={() => setCommsMenuOpen(!commsMenuOpen)} className="bg-cyan-900 hover:bg-cyan-800 text-white px-2 py-1 border border-cyan-700">MENU</button>
            
            <button onClick={simulateTransmission} className="bg-cyan-900 hover:bg-cyan-800 text-white px-2 py-1 border border-cyan-700">TX</button>
            <button onClick={() => setConnectedChannels([])} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">DISC ALL</button>
            
            <button onClick={() => setHasPriorityOrder(!hasPriorityOrder)} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600 col-span-2">PRIORITY</button>
            <button onClick={() => setHasObjective(!hasObjective)} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">OBJECTIVE</button>
            <button onClick={() => setShowControls(false)} className="bg-gray-800 hover:bg-gray-700 text-white px-2 py-1 border border-gray-600">HIDE</button>
          </div>
        </div>
      )}
      
      {!showControls && (
        <button onClick={() => setShowControls(true)} className="absolute bottom-6 left-1/2 transform -translate-x-1/2 bg-black bg-opacity-70 border border-gray-600 px-3 py-1 text-xs text-gray-400 hover:text-white z-50 terminal-text">
          SHOW CONTROLS
        </button>
      )}

      {/* TOP CENTER - NAVIGATION */}
      <div className="absolute top-4 left-1/2 transform -translate-x-1/2">
        <div className="text-center">
          <div className="flex items-baseline justify-center gap-3 mb-2">
            <div className="text-gray-400 text-xs terminal-text readable-text">BRG</div>
            <div className="text-amber-300 text-4xl font-bold terminal-text readable-text" style={{
              textShadow: '2px 2px 4px rgba(0, 0, 0, 0.9)'
            }}>
              {compass.toString().padStart(3, '0')}°
            </div>
            <div className="flex gap-2 text-xs text-gray-500 terminal-text readable-text">
              <span className={compass >= 315 || compass < 45 ? 'text-amber-300' : ''}>N</span>
              <span className={compass >= 45 && compass < 135 ? 'text-amber-300' : ''}>E</span>
              <span className={compass >= 135 && compass < 225 ? 'text-amber-300' : ''}>S</span>
              <span className={compass >= 225 && compass < 315 ? 'text-amber-300' : ''}>W</span>
            </div>
          </div>
          
          <div className="space-y-1">
            <div className="text-xs terminal-text readable-text" style={{ textShadow: '1px 1px 3px rgba(0, 0, 0, 0.9)' }}>
              <span className="text-gray-500">TGT:</span> <span className="text-amber-300">CHECKPOINT-7</span>
              <span className="text-gray-600 mx-2">//</span>
              <span className="text-amber-300">145M {getBearingIndicator(63)}</span>
            </div>
            <div className="text-xs terminal-text readable-text" style={{ textShadow: '1px 1px 3px rgba(0, 0, 0, 0.9)' }}>
              <span className="text-gray-500">THR:</span> <span className="text-red-400">HOSTILE-ALPHA</span>
              <span className="text-gray-600 mx-2">//</span>
              <span className="text-red-400">89M {getBearingIndicator(245)}</span>
            </div>
          </div>
        </div>
      </div>

      {/* TOP LEFT - MISSION STATUS */}
      <div className="absolute top-4 left-4 flex flex-col gap-2" style={{ maxWidth: '320px' }}>
        {hasPriorityOrder && (
          <div className="border-l-4 border-red-600 bg-black bg-opacity-70 pl-3 pr-4 py-2">
            <div className="text-red-400 text-[10px] font-bold tracking-wider terminal-text mb-1 readable-text">
              PRIORITY TRANSMISSION
            </div>
            <div className="text-red-200 text-sm font-semibold mb-1 readable-text">SECURE HANGAR BAY 3</div>
            <div className="text-gray-400 text-xs readable-text">Hostile infiltration - Code Black</div>
            <div className="text-gray-600 text-[10px] terminal-text mt-1 readable-text">
              ISS VENGEANCE // CMDR TARKIN
            </div>
          </div>
        )}
        
        {hasObjective && (
          <div className="border-l-4 border-amber-600 bg-black bg-opacity-60 pl-3 pr-4 py-2">
            <div className="text-amber-400 text-[10px] font-bold tracking-wider terminal-text mb-1 readable-text">
              CURRENT OBJECTIVE
            </div>
            <div className="text-white text-sm readable-text">Patrol Sector 7-G</div>
            <div className="text-gray-400 text-xs readable-text">Report anomalies to command</div>
          </div>
        )}
        
        <div className={`border-l-4 border-gray-600 bg-black bg-opacity-50 pl-3 pr-4 py-2 transition-opacity ${
          (hasObjective || hasPriorityOrder) ? 'opacity-50' : 'opacity-100'
        }`}>
          <div className="flex items-center gap-3">
            <div className="text-4xl font-bold text-amber-300" style={{ 
              fontFamily: "'Georgia', serif",
              textShadow: '2px 2px 4px rgba(0, 0, 0, 0.9)'
            }}>
              {defcon}
            </div>
            <div>
              <div className="text-amber-300 text-[10px] font-bold terminal-text readable-text">
                DEFCON {defconData[defcon].threat}
              </div>
              <div className="text-white text-xs readable-text">{defconData[defcon].label}</div>
            </div>
          </div>
        </div>
      </div>

      {/* RIGHT SIDE - COMMS (Always accessible when player has radio) */}
      {hasRadio && (
        <div className="absolute right-4 top-4">
          {/* Connected Channels Display OR Menu Access Button */}
          {connectedChannels.length > 0 ? (
            <div className="border-l-4 border-cyan-600 bg-black bg-opacity-60 pl-3 pr-4 py-2 mb-2">
              <div 
                className="flex items-center justify-between mb-2 cursor-pointer"
                onClick={() => setCommsMenuOpen(!commsMenuOpen)}
              >
                <div className="text-cyan-400 text-[10px] font-bold tracking-wider terminal-text readable-text">
                  COMMS {commsMenuOpen ? '▼' : '▶'}
                </div>
                <div className="text-cyan-600 text-[9px] terminal-text readable-text">
                  {connectedChannels.length}/2
                </div>
              </div>
              
              {/* Show both connected channels */}
              <div className="space-y-1.5">
                {connectedChannels.map((channelName, idx) => {
                  const channelData = commsChannels.find(c => c.name === channelName);
                  const isActive = activeTransmission?.channel === channelName;
                  
                  return (
                    <div 
                      key={idx}
                      className={`${isActive ? 'transmission-active' : ''}`}
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-1.5">
                          {isActive && (
                            <div className="w-1.5 h-1.5 bg-cyan-400 rounded-full transmission-active" />
                          )}
                          <div className={`text-xs font-semibold readable-text ${
                            isActive ? 'text-cyan-300' : 'text-white'
                          }`}>
                            {channelName}
                          </div>
                        </div>
                        {channelData?.encrypted && (
                          <div className="text-cyan-500 text-[9px]">🔒</div>
                        )}
                      </div>
                      <div className="text-gray-500 text-[9px] terminal-text readable-text ml-3">
                        {channelData?.freq} MHZ
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ) : (
            /* No channels connected - Show access button */
            <div 
              className="border-l-4 border-gray-600 bg-black bg-opacity-60 pl-3 pr-4 py-2 mb-2 cursor-pointer hover:border-cyan-600 hover:bg-opacity-70 transition-all"
              onClick={() => setCommsMenuOpen(!commsMenuOpen)}
            >
              <div className="text-gray-400 text-[10px] font-bold tracking-wider terminal-text readable-text">
                COMMS {commsMenuOpen ? '▼' : '▶'}
              </div>
              <div className="text-gray-500 text-xs readable-text mt-1">
                No active channels
              </div>
              <div className="text-gray-600 text-[9px] terminal-text readable-text">
                Click to connect
              </div>
            </div>
          )}

          {/* Active Transmission Panel - Shows when someone is talking */}
          {activeTransmission && (
            <div className="border-l-4 border-cyan-400 bg-black bg-opacity-80 pl-3 pr-4 py-2 mb-2 transmission-active">
              <div className="text-cyan-400 text-[10px] font-bold tracking-wider terminal-text mb-1 readable-text">
                ACTIVE TRANSMISSION
              </div>
              <div className="flex items-center gap-2 mb-1">
                <div className="w-8 h-8 bg-gray-900 bg-opacity-70 border border-cyan-700 flex items-center justify-center">
                  <div className="text-cyan-400 text-xs font-bold terminal-text">CT</div>
                </div>
                <div>
                  <div className="text-white text-sm font-semibold readable-text">{activeTransmission.speaker}</div>
                  <div className="text-cyan-400 text-xs terminal-text readable-text">{activeTransmission.channel}</div>
                </div>
              </div>
              <div className="text-gray-500 text-[9px] terminal-text readable-text border-t border-cyan-950 pt-1">
                {activeTransmission.encrypted ? '🔒 ENCRYPTED' : '🔓 UNSECURE'} // {activeTransmission.freq} MHZ
              </div>
            </div>
          )}

          {/* Channel Selection Menu */}
          {commsMenuOpen && (
            <div className="bg-black bg-opacity-85 border border-gray-700">
              <div className="border-b border-gray-800 px-3 py-1.5 bg-black bg-opacity-50">
                <div className="text-gray-400 text-[10px] font-bold terminal-text">CHANNEL SELECT (MAX 2)</div>
              </div>
              {commsChannels.map((channel) => {
                const isConnected = connectedChannels.includes(channel.name);
                const canConnect = connectedChannels.length < 2 || isConnected;
                
                return (
                  <div
                    key={channel.id}
                    onClick={() => canConnect && toggleChannelConnection(channel.name)}
                    className={`px-3 py-2 border-b border-gray-800 last:border-b-0 ${
                      !canConnect 
                        ? 'opacity-40 cursor-not-allowed' 
                        : isConnected
                        ? 'bg-cyan-900 bg-opacity-30 cursor-pointer'
                        : 'hover:bg-gray-900 hover:bg-opacity-50 cursor-pointer'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-0.5">
                      <div className="flex items-center gap-2">
                        <div className={`w-1.5 h-1.5 rounded-full ${
                          isConnected ? 'bg-cyan-400' : 'bg-gray-700'
                        }`} />
                        <div className="text-white text-xs font-semibold readable-text">{channel.name}</div>
                      </div>
                      {channel.encrypted && <div className="text-cyan-400 text-[10px]">🔒</div>}
                    </div>
                    <div className="text-gray-500 text-[10px] terminal-text readable-text ml-4">
                      {channel.freq} MHZ {isConnected && '• CONNECTED'}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* LEFT MID - FIRETEAM */}
      {inSquad && (
        <div className="absolute left-4" style={{ top: '33%' }}>
          <div className="border-l-4 border-green-700 bg-black bg-opacity-60 pl-3 pr-4 py-2">
            <div className="text-green-400 text-[10px] font-bold tracking-wider terminal-text mb-2 readable-text">
              FIRETEAM AUREK
            </div>
            <div className="space-y-2">
              {squadMembers.map((member, i) => (
                <div key={i} className="flex items-center gap-2">
                  <div className="w-6 h-6 bg-gray-900 bg-opacity-70 border border-gray-700 flex-shrink-0 flex items-center justify-center">
                    <div className="text-gray-400 text-[8px] font-bold terminal-text">{member.rank}</div>
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-white text-xs readable-text">{member.name}</div>
                    <div className="flex items-center gap-1.5">
                      <div className="flex-1 h-1 bg-gray-900 bg-opacity-70 border border-gray-800">
                        <div 
                          className="h-full transition-all" 
                          style={{ 
                            width: `${member.health}%`,
                            background: member.health > 60 
                              ? 'linear-gradient(90deg, #B8860B 0%, #DAA520 50%, #B8860B 100%)'
                              : member.health > 30 
                              ? 'linear-gradient(90deg, #B8860B 0%, #FFD700 50%, #B8860B 100%)'
                              : 'linear-gradient(90deg, #8B0000 0%, #DC143C 50%, #8B0000 100%)'
                          }}
                        />
                      </div>
                      <div className="text-[9px] terminal-text readable-text" style={{ 
                        color: member.status === 'ACTIVE' ? '#B8860B' : 
                               member.status === 'ENGAGED' ? '#DAA520' : '#8B0000'
                      }}>
                        {member.status}
                      </div>
                    </div>
                    <div className="text-gray-500 text-[9px] terminal-text readable-text">
                      {member.distance}M // {member.bearing}° {getBearingIndicator(member.bearing)}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* BOTTOM LEFT - PLAYER VITALS */}
      <div className="absolute bottom-4 left-4">
        <div className="mb-2">
          <div className="text-white text-sm font-semibold readable-text" style={{
            textShadow: '2px 2px 4px rgba(0, 0, 0, 0.9)'
          }}>
            CT-9247 "Winton"
          </div>
          <div className="text-gray-400 text-xs readable-text" style={{
            textShadow: '1px 1px 3px rgba(0, 0, 0, 0.9)'
          }}>
            2nd Lieutenant // 501st Legion
          </div>
        </div>

        <div className="mb-2">
          <div className="flex items-baseline gap-2 mb-1">
            <div className="text-gray-400 text-xs terminal-text readable-text">VITALS</div>
            <div className="text-2xl font-bold terminal-text readable-text" style={{ 
              color: health > 60 ? '#DAA520' : health > 30 ? '#FFD700' : '#DC143C',
              textShadow: '2px 2px 4px rgba(0, 0, 0, 0.9)'
            }}>
              {health}%
            </div>
          </div>
          <div className="w-56 h-2.5 bg-black bg-opacity-60 border border-gray-800">
            <div 
              className="h-full transition-all duration-300" 
              style={{ 
                width: `${health}%`,
                background: health > 60 
                  ? 'linear-gradient(90deg, #B8860B 0%, #DAA520 50%, #B8860B 100%)'
                  : health > 30 
                  ? 'linear-gradient(90deg, #B8860B 0%, #FFD700 50%, #B8860B 100%)'
                  : 'linear-gradient(90deg, #8B0000 0%, #DC143C 50%, #8B0000 100%)'
              }}
            />
          </div>
          {health < 30 && (
            <div className="text-red-400 text-[10px] terminal-text mt-1 readable-text">
              WARNING: MEDICAL ATTENTION REQUIRED
            </div>
          )}
        </div>

        <div>
          <div className="flex items-baseline gap-2 mb-1">
            <div className="text-gray-400 text-xs terminal-text readable-text">STAMINA</div>
            <div className="text-sm text-amber-300 terminal-text readable-text">{stamina}%</div>
          </div>
          <div className="w-56 h-1.5 bg-black bg-opacity-60 border border-gray-800">
            <div 
              className="h-full transition-all stat-bar-fill" 
              style={{ width: `${stamina}%` }}
            />
          </div>
        </div>
      </div>

      {/* BOTTOM RIGHT - WEAPON INFO */}
      {hasWeapon && (
        <div className="absolute bottom-4 right-4">
          <div className="flex items-center justify-end gap-3 mb-2">
            <div className="text-gray-400 text-xs terminal-text readable-text">DC-15A CARBINE</div>
            <div className="text-amber-300 text-xs terminal-text font-bold px-2 py-0.5 border border-amber-300 bg-black bg-opacity-50 readable-text">
              {fireMode}
            </div>
          </div>
          
          <div className="text-right mb-2">
            {isReloading ? (
              <div>
                <div className="text-amber-300 text-sm terminal-text mb-1 readable-text">RELOADING...</div>
                <div className="w-48 h-2 bg-black bg-opacity-60 border border-gray-800 inline-block">
                  <div className="h-full stat-bar-fill" style={{ width: '60%' }} />
                </div>
              </div>
            ) : ammo === 0 ? (
              <div className="text-red-400 text-sm terminal-text font-bold readable-text">
                NO AMMUNITION
              </div>
            ) : (
              <div className="flex items-baseline gap-2 justify-end">
                <div className="text-5xl font-bold text-white terminal-text readable-text" style={{
                  textShadow: '3px 3px 6px rgba(0, 0, 0, 0.9)'
                }}>
                  {ammo.toString().padStart(2, '0')}
                </div>
                <div className="text-gray-600 text-xl terminal-text">/</div>
                <div className="text-gray-500 text-2xl terminal-text readable-text">{ammoReserve}</div>
              </div>
            )}
          </div>
          
          <div className="text-right">
            <div className="flex items-baseline justify-end gap-2 mb-1">
              <div className="text-gray-400 text-[10px] terminal-text readable-text">HEAT</div>
              <div className="text-xs terminal-text readable-text" style={{ 
                color: overheat < 50 ? '#DAA520' : overheat < 80 ? '#FFD700' : '#DC143C'
              }}>
                {overheat}%
              </div>
            </div>
            <div className="w-48 h-1.5 bg-black bg-opacity-60 border border-gray-800 inline-block">
              <div 
                className="h-full transition-all" 
                style={{ 
                  width: `${overheat}%`,
                  background: overheat < 50 
                    ? 'linear-gradient(90deg, #B8860B 0%, #DAA520 50%, #B8860B 100%)'
                    : overheat < 80 
                    ? 'linear-gradient(90deg, #B8860B 0%, #FFD700 50%, #B8860B 100%)'
                    : 'linear-gradient(90deg, #8B0000 0%, #DC143C 50%, #8B0000 100%)'
                }}
              />
            </div>
            {overheat >= 80 && (
              <div className="text-red-400 text-[10px] terminal-text mt-1 readable-text">
                WARNING: COOLING REQUIRED
              </div>
            )}
          </div>
        </div>
      )}

      {/* Critical Health Indicator */}
      {health < 20 && (
        <div className="absolute inset-0 pointer-events-none border-2 border-red-900" style={{ opacity: 0.3 }} />
      )}
    </div>
  );
}
