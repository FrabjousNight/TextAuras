--  text_auras - a LuaText for Pitbull4
--  events: UNIT_AURA, SKILL_LINES_CHANGED
--          (You must add the 2nd one in Modules > LuaTexts; use the "All" checkbox.)
--
--  Shows multiple auras (i.e. buffs or debuffs) & timer bars as a piece of text.
--
--  Example (resto druid): tracking Swiftmend, Wild Growth, Rejuv, Regrowth, Lifebloom
--    The text could look a bit like this:     S W J----** G---** L3------*
--
--  IMPORTANT: Must be displayed against an unchanging, single-color background.
--    I suggest creating a black "Blank Space" bar to hold this LuaText.
--
--    (WoW doesn't support transparent text, so the "invisible" parts of the
--    aura displays are simply shown in the background color to hide them.)
--    Change "bkColor" below if you are not using a black background.
--
-- v63 - Release 0.02

-- future: blink time check uses exptime-gettime(); thus currently no support for embed.blink
-- future: my '|cff' strings aren't always balanced by '|r'


-- These 3 settings are customizable.  Also see the "CUSTOMIZATION INSTRUCTIONS" below.

-- Change 'bkColor' to the color code for your background if you're not using black.
local bkColor = "000000" -- 000000 is black.  The code is RRGGBB, using hexadecimal numbers.

-- Change 'fastTick' and 'slowTick' to use different symbols for the fast and slow timer bars.
local fastTick, slowTick = '\194\183', '\226\128\162'
      -- Some small symbols you can try, if they exist in your font:
      --   '\194\183'      centered dot
      --   '\226\128\162'  bullet (bigger than the centered dot)
      --   '\226\128\185'  left single angle-quote

-- You only need to change 'cache_name' if you use multiple **different** versions of
    -- this LuaText.  Each different version needs a unique cache name.
    -- You don't need to change this if you simply repeat the same code in multiple layouts.
local cache_name = "_text_auras_cache"  -- each *different* version of this LuaText needs a unique cache name.

-- See "CUSTOMIZATION INSTRUCTIONS" below to learn how to modify the display for your class.


local cache = PitBull4.LuaTexts.ScriptEnv[cache_name]
if cache and event ~= '_new' and event ~= 'SKILL_LINES_CHANGED' then

  -- All of our precalculated info is ready, so go ahead and build the LuaText string.
  return cache.build_luatext(cache, unit)
  
else
  -- We must rebuild the cached info.

  if event=="SKILL_LINES_CHANGED" and cache then
    -- This event will fire on every frame after a spec change.  Ignore event after first time.
    -- (Note: this optimization could cause problems if both specs are in the same tree;
    --  spells only known by the new spec won't show up.  Should be rare for this to happen.)
    local newSpec = GetPrimaryTalentTree()
    if newSpec == (cache and cache.curSpec or -1) then 
      -- unit==nil in this case, so we can't build the text now.  Set a timer to force an update.
      UpdateIn(0.2)
      return
    end
  end
  
  UpdateIn(0.2) -- force an update after we rebuild the cache
  PitBull4.LuaTexts.ScriptEnv[cache_name] = { }
  cache = PitBull4.LuaTexts.ScriptEnv[cache_name]
  
  -- Colors to indicate the status of aura parts.
  -- "aura is not from me", "aura not present", "on cooldown"
  local notMineColor, inactiveColor, cooldownColor = "999999", "555555", "ff0000"

  -- This function defines the auras to be displayed.
  function cache.setup_tracked_auras(cache, playerClass, playerSpec)
    -- Define convenience variables
    local buff, buff_set = cache.buff, cache.buff_set
    local debuff, debuff_set = cache.debuff, cache.debuff_set
    local aura_static = cache.aura_static
    -- 'ally' and 'foe' hold the auras to be displayed
    local ua = cache.unit_auras
    local ally, foe, foe_alt = ua['_friend'], ua['_enemy'], ua['_enemy_alt']
    local player, pet, target, focus = ua['player'], ua['pet'], ua['target'], ua['focus']
    -- short color names
    local c = cache.colors
    local red,green,blue,cyan,magenta,yellow=c.red,c.green,c.blue,c.cyan,c.magenta,c.yellow
    local orange,violet,brown,gray,white,black=c.orange,c.violet,c.brown,c.gray,c.white,c.black
    
    -- Helper function to generate an aura that displays when unit has low percentage health.
    local function health_aura(percent, s)
      local function health_test(unit)
        local isPresent = unit and HP(unit,true)/MaxHP(unit) <= percent/100 -- 'true' prevents automatic timer updates
        return isPresent, isPresent, nil, nil, nil
      end
      local a = {name="["..percent.."% health]", bar="% ", color=cyan.vivid, isActive=health_test}
      for k,v in pairs(s or {}) do a[k]=v end
      return debuff(a)
    end
    -- Helper function to force an aura to always be on
    local function always_on() return true, true end

    
    --[[ ====================================================================================
    =========================================================================================
    
    CUSTOMIZATION INSTRUCTIONS
    
    To add an aura display to the LuaText, add the following line to the section for your class.
    Use "debuff" instead of "buff" to track a debuff.
    Use "foe" instead of "ally" to have the aura appear on enemy unit frames.
    Use "player", "pet", "target", "focus" instead of "ally" to define a group of auras only for that unit frame.
    Be sure to use braces { } as shown, not parentheses.

        ally:buff {name="aura_name", bar="A#---++  ", color=blue,}
    
    The "bar" setting defines the appearance of the aura in the LuaText.  All parts are optional.
    *  The first part is an identifying code letter (or letters) of your choice.
    *  If "#" is present, the aura's number of stacks is shown.
    *  The "---" and "++" parts determine the lengths of the fast and slow sub-bars in the timer.
       (Omitting both parts means there will be no timer.)
       Using both fast & slow lets you have quick ticks just before expiration, 
       but the overall size of the timer bar is kept small.
    *  The trailing spaces separate this aura display from the next one in the LuaText.
    
    Several optional settings can be used:
    
    * color=blue             - red, green, blue, cyan, magenta, yellow, orange, violet, brown, gray
                               Variants available:  red.vivid, red.pale, red.dark.  Also: white and black.
    * showInactive=true      - a grayed-out code letter is visible even when the aura is absent.
    * showOthers=true        - the aura is shown (grayed-out) even if the aura wasn't cast by you.
                               (To help you avoid overwriting single-copy spells like Earth Shield.)
    * ifKnown="spell_name"   - the entire aura is omitted if you don't know that spell.
    * ifSpec=1 (or 2, or 3)  - the entire aura is omitted if you aren't using that talent spec.
    * fastLen=1.0            - each fast tick lasts this many seconds.
    * slowLen=1.0            - each slow tick lasts this many seconds.  Excess duration is omitted.
                               (By default, the slow bar covers the remainder of the spell's duration.)
    * cooldown="spell_name"  - place colored brackets around the code letter while spell is on cooldown.
    * blink=5.0              - aura will blink if less than 5.0 seconds left
    
    Finally, some advanced techniques are available.
    
    * To show the spell icon, include the text "$icon:0" in the code portion of the bar.
        The "0" sets the icon size to the text height.  Use a different number to force a specific size.
        
    * To add an unchanging bit of text, use    ally:static "fixed text"
        To add a line break, use     ally:static "\n", or include it in an aura:  bar="A#---++\n"
        To control the color of this text, use    ally:static {text="my text", color=blue}
    
    * If a display should be present when any one of a set of auras is present, use
        buff_set instead of buff.  See the Shaman shield spells for a usage example.
        Note: each aura (including the parent) must have the same kinds of variable elements
        in the 'bar' setting, i.e. code, count, fast bar, slow bar.
    
    * You can embed an aura inside another one.  The embedded aura's time will be shown in the left
         part of the timer bar, followed by the remaining part of the main aura.
         See the Priest's Power Word: Shield / Weakened Soul below for an example.
         Note: if the main aura does not specify slowLen, you will see slightly funky appearance
         when the embedded aura is present without the main aura, because the tick lengths
         can only be determined when the main aura is present.  This is fixed once the main aura has been seen once.
    
    * To enable/disable an aura display based on a more complicated test than "is this aura present",
        set isActive to a custom function (see Druid Swiftmend spell for an example):
        
        local function custom_aura_test(unit)
          -- your calculation goes here
          return is_present, is_mine, duration, expiration_time, stack_count
        end
    =========================================================================================    
    =======================================================================================]]

    -- -------------------------------------------------------------------------------------
    -- -- User-customizable settings begin here.
    -- -------------------------------------------------------------------------------------

    -- Each class defines its own auras to display.
    
    
    -- DEATH KNIGHT - spec numbers: Blood=1, Frost=2, Unholy=3
    if     playerClass == "DEATHKNIGHT" then
      -- Death Knight auras for pet
      pet:buff {name="Shadow Infusion", bar="SI#  ", color=cyan, ifSpec=3, }
      
      -- Death Knight auras for allies
      
      -- Death Knight auras for enemies
      --35% health for frost?
      foe:debuff {name="Blood Plague", bar="B ", color=red, showInactive=true,}
      foe:debuff {name="Frost Fever",  bar="F ", color=cyan, showInactive=true,}
      foe:debuff {name="Ebon Plague",  bar="E ", color=yellow, showInactive=true, ifSpec=3,}
    
    
    
    -- DRUID - spec numbers: Balance=1, Feral Combat=2, Restoration=3, forms: bear=1, cat=3, moonkin=5, tree=6
    elseif playerClass == "DRUID" then 
      -- Druid auras for player
      if playerSpec==2 then
        player:buff {name="Savage Roar", bar="R+++++  ", slowLen=8.0, color=orange, } --14-42s duration
        player:buff {name="Pulverize", bar="P----++  ", color=orange, } -- 14s duration
        -- Berserk cooldown is 50334 (Berserk proc is 93622).  Both have same name, so can't just scan by name.  There is no scan by id...
        -- cat: Berserk (15s+), Tiger's Fury (6s), Savage Roar (14-42s), Dash? (15s), Survival Instincts? (12s), Barkskin? (12s)
        -- bear: Berserk (15s+), Pulverize (14s), Frenzied Regeneration? (20s), Survival Instincts? (12s), Barkskin? (12s), Enrage? (10s)
      end
      
      
      -- Druid auras for allies
      -- Swiftmend: we want the "S" to appear when Swiftmend *can be* cast, not when a "Swiftmend" aura is present:
      local function can_swiftmend(unit)
        local _,_,icon,count,_,dur,expTime,caster,_,_,id = UnitAura(unit, "Rejuvenation")
        if not expTime then
          _,_,icon,count,_,dur,expTime,caster,_,_,id = UnitAura(unit, "Regrowth")
        end
        local isPresent = expTime and true or false
        return isPresent, isPresent, nil, nil, nil
      end
      ally:buff {name="Swiftmend",    bar="S ", color=brown.vivid, ifSpec=3, cooldown="Swiftmend", isActive=can_swiftmend,}
      
      ally:buff {name="Wild Growth",  bar="W ",            color=green.vivid, ifKnown="Wild Growth",}
      ally:buff {name="Rejuvenation", bar="J---++  ",      color=magenta, showInactive=true,}
      ally:buff {name="Regrowth",     bar="G--+  ",        color=green.pale,  showInactive=true,}
      ally:buff {name="Lifebloom",    bar="L#-----++  ",   color=yellow, blink=4.0,}
      -- thorns? (specs 1/3) ... there isn't much room for it after all of the above auras.
      
      
      -- Druid auras for enemies
      -- balance
      foe:debuff {name="Insect Swarm",   bar="S----++  ", color=brown.pale,   showInactive=true, ifSpec=1,} --12s duration
      foe:debuff_set {name="[____fire]", bar="F----++  ", color=cyan,         showInactive=true, ifSpec=1, set={ -- 12s duration
        debuff {name="Moonfire",         bar="F----++  ", color=cyan,         showInactive=true, ifSpec=1,},
        debuff {name="Sunfire",          bar="F----++  ", color=yellow.vivid, showInactive=true, ifSpec=1,},
      }}
      foe:debuff {name="Entangling Roots", bar="E+++  ", color=green.dark, ifSpec=1, blink=8.0,} --30s duration
      foe:debuff {name="Entangling Roots", bar="E+++  ", color=green.dark, ifSpec=3, blink=8.0,} --30s duration
      
      -- feral (cat)
      local health25 = health_aura(25, {ifSpec=2,}); -- only show in feral spec
      foe:add(health25) -- 25% health
      
      -- Check for any +bleed-damage effect
      local bleedBonus = debuff_set {name="[+bleed dmg]", bar="M ", color=green.vivid, showInactive=true, ifSpec=2, set={
        debuff {name="Mangle",                            bar="M ", color=green.vivid, showOthers=true, ifSpec=2}, -- druid (cat/bear)
        debuff {name="Hemorrhage",                        bar="M ", color=green.vivid, showOthers=true, ifSpec=2}, -- rogue (subtlety)
        debuff {name="Trauma",                            bar="M ", color=green.vivid, showOthers=true, ifSpec=2}, -- warrior (arms)
        debuff {name="Tendon Rip",                        bar="M ", color=green.vivid, showOthers=true, ifSpec=2}, -- hunter (hyena pet)
        debuff {name="Gore",                              bar="M ", color=green.vivid, showOthers=true, ifSpec=2}, -- hunter (boar pet)
        debuff {name="Stampede",                          bar="M ", color=green.vivid, showOthers=true, ifSpec=2}, -- hunter (rhino pet)
      }}
      foe:add(bleedBonus)

      foe:debuff {name="Rake",      bar="K---++  ",   color=yellow.pale, ifSpec=2, showInactive=true, }
      foe:debuff {name="Rip",       bar="R-----++  ", color=red,         ifSpec=2, showInactive=true, }
      foe:debuff {name="Pounce",    bar="P++ ",       color=orange,      ifSpec=2,}
      
      -- all druid specs
      foe:debuff {name="Hibernate", bar="H+++ ", color=cyan.vivid, blink=10.0,} --40s duration
      
      -- feral (bear) needs a different layout than cat, so we define a special function to decide
      if GetPrimaryTalentTree()==2 then
        cache.use_alternate_enemy_layout = function()
          return GetShapeshiftForm() == 1 -- bear form
        end
      end
      foe_alt:add(health25)
      foe_alt:add(bleedBonus)
      foe_alt:debuff {name="Demoralizing Roar", bar="D ",         color=gray,         ifSpec=2, } -- check for similar effects?
      foe_alt:debuff {name="Faerie Fire",       bar="F# ",        color=violet.vivid, ifSpec=2, showOthers=true, } -- similar effects?
      foe_alt:debuff {name="Lacerate",          bar="L#----++  ", color=red,          ifSpec=2, showInactive=true, }
      foe_alt:debuff {name="Thrash",            bar="T+ ",        color=orange,       ifSpec=2, }
      foe_alt:debuff {name="Hibernate",         bar="H+++ ",      color=cyan.vivid, blink=10.0,} --40s duration
    
    
    
    -- HUNTER - spec numbers: Beast Mastery=1, Marksmanship=2, Survival=3
    elseif playerClass == "HUNTER" then
      -- Hunter auras for player
      player:buff {name="The Beast Within", bar="B----++  ", color=red, ifKnown="Bestial Wrath",}
      player:buff {name="Improved Steady Shot", bar="SS----+  ", color=cyan,} -- talent is available to all specs
      player:buff {name="Lock and Load", bar="L#  ", color=green.vivid, ifSpec=3,}
      player:buff_set {name="[aspect]",     bar="No aspect!", color=white, isActive=always_on, set={
        buff {name="Aspect of the Hawk",    bar="Hawk",       color=blue,},
        buff {name="Aspect of the Fox",     bar="Fox",        color=orange,},
        buff {name="Aspect of the Cheetah", bar="Cheetah",    color=yellow,},
        buff {name="Aspect of the Pack",    bar="Pack",       color=gray,},
        buff {name="Aspect of the Wild",    bar="Wild",       color=green,},
      }}
      
      -- Hunter auras for pet
      pet:buff {name="Mend Pet", bar="M-----+  ", color=green, blink=3.0, showInactive=true, }
      pet:buff {name="Frenzy Effect", bar="F# ", color=yellow, }
      
      -- Hunter auras for allies
      -- show a blinking "Pack" if we're in an instance and providing Aspect of the Pack
      local function pack_in_instance(unit)
        local pack = UnitAura(unit, "Aspect of the Pack", nil, "PLAYER")
        if pack then
          local _,instanceType = GetInstanceInfo()
          if instanceType == 'party' or instanceType == 'raid' then
            local t = GetTime()
            return true, true, 5.0, t+(t%2), 1 -- a trick to induce blinking
          end
        end
        return false, false, nil, nil, nil
      end
      ally:buff {name="Aspect of the Pack", bar="Pack ", color=brown.dark, blink=10.0, isActive=pack_in_instance}
      
      -- Hunter auras for enemies
      foe:add( health_aura(20) ) -- 20% health
      foe:debuff_set {name="[Mark]", bar="M ", set={
        debuff {name="Hunter's Mark",    bar="M ", color=magenta, showOthers=true,},
        debuff {name="Marked for Death", bar="M ", color=magenta.vivid, showOthers=true,},
      }}
      foe:debuff_set {name="[Sting]", bar="S-----++  ", color=green, showInactive=true, set={
        debuff {name="Serpent Sting",     bar="S-----++  ", color=green.vivid,},
        debuff {name="Wyvern Sting",      bar="S-----++  ", color=blue.pale, ifKnown="Wyvern Sting",},
      }}
      -- Piercing Shots?  (8 sec bleed, marksmanship only)
      foe:debuff {name="Freezing Trap", bar="F+++ ", color=cyan.vivid, blink=10.0,}
    

    
    -- MAGE - spec numbers: Arcane=1, Fire=2, Frost=3
    elseif playerClass == "MAGE" then
      -- Mage auras for player
      player:buff {name="Ice Barrier", bar="B+++  ", color=cyan, cooldown="Ice Barrier", ifKnown="Ice Barrier", } -- 60s duration, 30s cooldown
      player:buff {name="Mana Shield", bar="M+++  ", color=yellow, cooldown="Mana Shield", } -- 60s duration, 12s/10s cooldown
      player:buff {name="Focus Magic", bar="F ", color=blue.pale, showOthers=true, ifKnown="Focus Magic",}
      -- mirror image? (30s), arcane power? (15s, ifKnown)
      
      -- Mage auras for allies
      ally:buff {name="Focus Magic", bar="F ", color=blue.pale, showOthers=true, ifKnown="Focus Magic",}
      
      -- Mage auras for enemies
      -- arcane:  torment the weak eligibility (snares/slows)?
      foe:debuff {name="Slow",   bar="S ", color=brown.pale, ifKnown="Slow",}
      
      -- fire
      local health35 = health_aura(35, {ifSpec=2,}); -- only show in fire spec
      foe:add(health35)
      
      foe:debuff_set {name="[pyroblast]", bar="P---++  ", color=red, ifSpec=2, showInactive=true, set={
        debuff {name="Pyroblast!",        bar="P---++  ", color=red, ifSpec=2, showInactive=true,}, -- the free proc
        debuff {name="Pyroblast",         bar="P---++  ", color=red.pale, ifSpec=2, showInactive=true,},
      }}

      foe:debuff {name="Living Bomb", bar="B---  ", color=orange.vivid, ifSpec=2, showInactive=true, fastLen=4.0,}
      foe:debuff {name="Ignite",    bar="I---++  ", color=yellow, ifSpec=2, showInactive=true,}
      -- (don't bother displaying the dot from glyphed Frostfire Bolt)

      -- For Fire mage Combustion, we'd like to show two different things.
      --   * Show the Combustion debuff--if present, assume it's on cooldown, and don't do the next test.
      --   * If off cooldown and the 3 big fire dots are present, show and blink to indicate it's a good time to cast.
      local function combustion_3dots(unit)
        -- if Combustion is on cooldown, don't show the "3-dots-active" indicator
        local CDstart, CDdur = GetSpellCooldown("Combustion")
        local cooling_down = (CDdur or 0) > 1.5 -- ignore global cooldowns
        if cooling_down then
          return false, false, nil, nil, nil
        end
        -- otherwise, check the big 3 (glyphed frostfire bolt dot is not worth checking for)
        local f = "PLAYER HARMFUL" -- only the player's dots matter
        local all3 = UnitAura(unit,"Ignite",nil,f) and UnitAura(unit,"Living Bomb",nil,f) 
                     and (UnitAura(unit,"Pyroblast",nil,f) or UnitAura(unit,"Pyroblast!",nil,f)) -- free Pyro has a different name
        if all3 then
          local t = GetTime()
          return true, true, 5.0, t+(t%2), 1 -- a trick to induce blinking
        else
          return false, false, nil, nil, nil
        end
      end
      
      foe:debuff_set {name="[combustion]", bar="C ", color=magenta.pale, ifSpec=2, set={
        debuff {name="Combustion",             bar="C ", color=magenta.pale, ifSpec=2,},
        debuff {name="[combustion ready]",     bar="C ", color=cyan.vivid, ifSpec=2, blink=10.0, isActive=combustion_3dots,},
      }}

      -- frost: test for frozen or chill effects?, deep freeze(?)

      -- all mage specs
      foe:debuff {name="Polymorph", bar="Y+++ ", color=cyan.vivid, blink=10.0,}
      
      
      
    -- PALADIN - spec numbers: Holy=1, Protection=2, Retribution=3
    elseif playerClass == "PALADIN" then
      -- Paladin auras for player
      player:buff {name="Inquisition", bar="I+++  ", color=green, slowLen=4.0, } -- 4/8/12 sec
      player:buff {name="Avenging Wrath", bar="AW+++  ", color=yellow, } -- 20s
      player:buff {name="Divine Plea", bar="DP+++  ", color=red, } -- 9s
      player:buff {name="Conviction", bar="C#+++  ", color=orange, ifSpec=1, } -- 15s
      player:buff_set {name="[hand]",       bar="F+++  ", color=yellow, set={
        buff {name="Hand of Freedom",     bar="F+++  ", color=yellow,},
        buff {name="Hand of Protection",  bar="P+++  ", color=yellow.vivid,},
        buff {name="Hand of Sacrifice",   bar="S+++  ", color=yellow,},
        buff {name="Hand of Salvation",   bar="V+++  ", color=yellow,},
      }}
      player:debuff {name="Forbearance", bar="Forb.  ", color=red.vivid, showOthers=true,}
    
      -- Paladin auras for allies
      ally:buff {name="Beacon of Light", bar="B+++++  ", color=orange, fastLen=6, ifKnown="Beacon of Light"}
      ally:buff_set {name="[hand]",       bar="F+++  ", color=yellow, set={
        buff {name="Hand of Freedom",     bar="F+++  ", color=yellow,},
        buff {name="Hand of Protection",  bar="P+++  ", color=yellow.vivid,},
        buff {name="Hand of Sacrifice",   bar="S+++  ", color=yellow,},
        buff {name="Hand of Salvation",   bar="V+++  ", color=yellow,},
      }}
      ally:debuff {name="Forbearance", bar="Forb.  ", color=red.vivid, showOthers=true,}
      -- 35% health for holy's word of glory bonus?
      
      -- Paladin auras for enemies
      foe:add(health_aura(20)) -- 20% health for hammer of wrath
      -- censure? (seal of truth dot) (specs 2/3)
      foe:debuff {name="Repentance", bar="R+++ ", color=cyan.vivid, blink=10.0, ifKnown="Repentance",} --60s duration
      
      
      
    -- PRIEST - spec numbers: Discipline=1, Holy=2, Shadow=3
    elseif playerClass == "PRIEST" then
      -- Priest auras for player
      --  all specs
      player:buff_set {name="[evangelism]", bar="E#  ", color=brown.vivid, set={
        buff {name="Evangelism",            bar="E#  ", color=brown.vivid, },
        buff {name="Dark Evangelism",       bar="E#  ", color=brown.vivid, },
      }}
      --  Discipline
      player:buff {name="Borrowed Time", bar="BT----++  ", color=blue, ifSpec=1, }
      --  Holy
      player:buff_set {name="[chakra]", bar="C:none ", color=red, showInactive=true, ifActive=always_on, ifSpec=2, set={
        buff {name="Chakra: Serenity",  bar="C:ser  ", color=yellow.vivid, },
        buff {name="Chakra: Sanctuary", bar="C:sanc ", color=blue.vivid, },
        buff {name="Chakra: Chastise",  bar="C:cha  ", color=red, },
      }}
      --  Shadow
      player:buff {name="Shadow Orb", bar="Orbs:# ", color=magenta, showInactive=true, ifSpec=3, }
      player:buff {name="Empowered Shadow", bar="ES-----++  ", color=violet.vivid, showInactive=true, ifSpec=3, }
      --  all specs
      player:buff {name="Renew",              bar="R--++ ",   color=green, showInactive=true,} -- 12s duration
      player:buff {name="Power Word: Shield", bar="S----+++ ", color=white, showInactive=true, showOthers=true, -- 30s duration
        embed = debuff {name="Weakened Soul", bar="W",     color=red, showOthers=true,} -- 15sec
      }
      

      -- Priest auras for allies
      ally:buff {name="Fear Ward",          bar="F ",         color=magenta.pale, showOthers=true,}
      ally:buff {name="Glyph of Prayer of Healing", bar="P ", color=orange, } -- 6s duration
      ally:buff {name="Renew",              bar="R--++ ",   color=green, showInactive=true,} -- 12s duration
      ally:buff {name="Divine Aegis",       bar="A ",        color=gray.pale, blink=6.0, ifSpec=1, } -- 12s duration
      ally:buff {name="Power Word: Shield", bar="S----+++ ", color=white, showInactive=true, showOthers=true, -- 30s duration
        embed = debuff {name="Weakened Soul", bar="W",     color=red, showOthers=true,} -- 15sec
      }
      ally:buff {name="Prayer of Mending",  bar="M# ",       color=cyan.vivid, showOthers=true, }
      ally:buff {name="Inspiration",        bar="I ",        color=brown.pale, showOthers=true, ifSpec=1,} -- 15s duration
      ally:buff {name="Inspiration",        bar="I ",        color=brown.pale, showOthers=true, ifSpec=2,}
      ally:buff {name="Grace",              bar="G# ",       color=magenta, blink=6.0, ifSpec=1} -- 15s duration
      

      -- Priest auras for enemies
      foe:add(health_aura(25)) -- 25% health for Shadow Word: Death
      foe:debuff {name="Shadow Word: Pain", bar="P----++  ", color=violet.vivid, showInactive=true,}
      foe:debuff {name="Vampiric Touch",    bar="V---++  ",  color=brown.pale, showInactive=true, ifKnown="Vampiric Touch",}
      foe:debuff {name="Devouring Plague",  bar="D---++  ",  color=blue, showInactive=true, }
      foe:debuff {name="Shackle Undead",    bar="S+++ ",     color=white, blink=10.0}
      -- psychic horror, psychic scream?


      
    -- ROGUE - spec numbers: Assassination=1, Combat=2, Subtlety=3
    elseif playerClass == "ROGUE" then
      -- Rogue auras for player
      player:buff {name="Slice and Dice", bar="S----++  ", color=yellow, showInactive=true,}
      player:buff {name="Recuperate", bar="R+++++  ", color=green, slowLen=6.0, }
      player:buff_set {name="[bandit's guile]", bar="SI  ", color=green, showInactive=true, ifSpec=2, set={
        buff {name="Shallow Insight",           bar="SI  ", color=green, },
        buff {name="Moderate Insight",          bar="MI  ", color=yellow, },
        buff {name="Deep Insight",              bar="DI  ", color=red.vivid, },
      }}
      -- display the Cheat Death cooldown for subtlety?

      -- Rogue auras for allies
      
      -- Rogue auras for enemies
      foe:add(health_aura(35, {ifSpec=1})) -- assassination gets cheap backstab at 35% health
      foe:debuff {name="Crippling Poison",    bar="C",        color=green.pale,}
      foe:debuff {name="Mind-Numbing Poison", bar="M",        color=green.dark,}
      foe:debuff {name="Wound Poison",        bar="W",        color=green,}
      foe:debuff {name="Deadly Poison",       bar="D# ",      color=green.vivid,}
      foe:debuff {name="Hemorrhage",          bar="H ",       color=yellow.dark, ifKnown="Hemorrhage",}
      foe:debuff {name="Rupture",             bar="R---++  ", color=red, showInactive=true,} -- 8-16 sec + 4 from glyph
      foe:debuff {name="Garrote",             bar="G+ ",      color=orange,} -- 18 sec duration
      --foe:debuff {name="Blind",               bar="B++ ",     color=brown.pale, blink=3.0,} -- 10 sec duration
      -- armor debuffs?
      foe:debuff {name="Sap",      bar="S+++ ", color=cyan.vivid, blink=10.0}
      
      
      
    -- SHAMAN - spec numbers: Elemental=1, Enhancement=2, Restoration=3
    elseif playerClass == "SHAMAN" then
      -- Shaman auras for allies
      ally:buff {name="Ancestral Fortitude", bar="A ",        color=gray.pale, showOthers=true, ifSpec=3,}
      ally:buff {name="Riptide",             bar="R---+++  ",  color=blue, ifKnown="Riptide", cooldown="Riptide"}
      ally:buff {name="Earthliving",         bar="L++  ",     color=yellow, ifSpec=3}
      ally:buff_set {name="[Shield]",  bar="LS#+++  ", color=brown, showOthers=true, set= {
        buff {name="Earth Shield",     bar="ES#+++  ", color=brown, showOthers=true,},
        buff {name="Water Shield",     bar="WS#+++  ", color=blue,  },
        buff {name="Lightning Shield", bar="LS#+++  ", color=cyan,  },
      }}
      
      -- Shaman auras for enemies
      foe:debuff {name="Flame Shock", bar="F----++  ", color=red, showInactive=true} -- 18s duration
      foe:debuff {name="Searing Flames", bar="S#--++  ", color=orange.vivid, showInactive=true, ifSpec=2,}
      
      foe:debuff_set {name="[crowd control]", bar="H+++ ", color=white, set={
        debuff {name="Hex",                       bar="H+++ ", color=cyan.vivid, blink=10.0,}, -- 60s duration
        debuff {name="Bind Elemental",            bar="B+++ ", color=cyan.vivid, blink=10.0,}, -- 50s duration
      }}
      
      
      
    -- WARLOCK - spec numbers: Affliction=1, Demonology=2, Destruction=3
    elseif playerClass == "WARLOCK" then
      -- Warlock auras for player
      player:buff {name="Dark Intent", bar="DI+++  ", color=blue, showOthers=true, }
      player:buff_set {name="[ward]", bar="W+++  ", color=magenta.pale, set={
        buff {name="Shadow Ward",   bar="W+++  ", oolor=magenta.pale,}, -- 30s duration & cooldown
        buff {name="Nether Ward",   bar="W+++  ", color=green.pale,},  -- 30s duration & cooldown
      }}
      player:buff {name="Metamorphosis", bar="M----++  ", color=cyan.vivid, blink=6.0, ifKnown="Metamorphosis", }
      
      
      -- Warlock auras for allies
      ally:buff {name="Dark Intent", bar="DI+++  ", color=blue, showOthers=true, }
      
      
      -- Warlock auras for enemies
      foe:add(health_aura(25)) -- 25% health, all specs
      foe:debuff_set {name="[corr.]",      bar="C--++", color=violet.vivid, showInactive=true, set={
        debuff {name="Corruption",         bar="C--++", color=violet.vivid}, -- 18sec duration
        debuff {name="Seed of Corruption", bar="C--++", color=violet.pale},
      }}
      foe:debuff_set {name="[bane]",     bar="A+++", color=yellow, showInactive=true, set={
        debuff {name="Bane of Agony",    bar="A+++", color=yellow,}, -- 24s duration
        debuff {name="Bane of Doom",     bar="D+++", color=yellow.pale,}, -- 60s duration
        debuff {name="Bane of Havoc",    bar="H+++", color=yellow.dark,},
      }}
      -- Immolation and Unstable Affliction are mutually exclusive, so use a set.
      --   The multiple ifSpec versions are so afflic can see a 'U' when inactive, while others see 'I'.
      foe:debuff_set {name="[UA/Immo]",      bar="U---++", color=red, showInactive=true, ifSpec=1, set={
        debuff {name="Unstable Affliction",  bar="U---++", color=magenta.pale, ifKnown="Unstable Affliction",}, -- 15 sec duration
        debuff {name="Immolate",             bar="I---++", color=red,}, -- 21 sec duration
      }}
      foe:debuff {name="Immolate",       bar="I---++", color=red, showInactive=true, ifSpec=2}
      foe:debuff {name="Immolate",       bar="I---++", color=red, showInactive=true, ifSpec=3}
      
      foe:debuff {name="Haunt", bar="H---++", color=green.pale, showInactive=true, cooldown="Haunt", ifKnown="Haunt"}
      
      -- For raiding with other warlocks, it would be nice to have each curse visible as a separate letter
      -- (similar to how I have rogue poisons set up), with showOthers=true so you could see if a curse
      -- was being provided by another warlock.  However, the warlock setup here already uses a ton of
      -- horizontal space.  Adding 3 more letters uses too much room, so I'll stick with the aura_set.
      foe:debuff_set {name="[curse]",               bar="E", color=orange, showInactive=true, set={
        debuff {name="Curse of the Elements",       bar="E", color=orange},
        debuff {name="Jinx: Curse of the Elements", bar="E", color=violet.pale}, --affliction talent
        debuff {name="Curse of Tongues",            bar="T", color=orange.vivid},
        debuff {name="Curse of Weakness",           bar="W", color=orange.dark},
        debuff {name="Curse of Exhaustion",         bar="X", color=orange.pale},
      }}
      
      foe:debuff {name="Banish",   bar="B++ ", color=cyan.vivid, blink=10.0,}
      -- fear? glyphed fear as crowd control?
      -- shadowflame dot?
      -- shadow embrace(just show the stacks)
      -- destro: burning ember?
      
      
      
    -- WARRIOR - spec numbers: Arms=1, Fury=2, Protection=3; stances: battle=1, defensive=2, berserker=3
    elseif playerClass == "WARRIOR" then 
      -- Warrior auras for player
      player:buff {name="Enrage", bar="E----+  ", color=orange, }
      
      -- Warrior auras for allies
      ally:buff {name="Vigilance", bar="V+++++  ", color=brown, ifKnown="Vigilance",}
      
      -- Warrior auras for enemies
      foe:add(health_aura(20)) -- 20% health, all specs
      foe:debuff {name="Rend",   bar="R-----++  ", color=red, showInactive=true} -- 15s duration
      foe:debuff {name="Deep Wound", bar="W---  ", color=orange, fastLen=2.0,} -- 6s duration
      foe:debuff {name="Demoralizing Shout", bar="D ", color=gray, ifSpec=3, } -- 30s, check for similar effects?
      foe:debuff {name="Thunder Clap", bar="T ", color=blue.vivid, cooldown="Thunder Clap", ifSpec=3, }
      -- sunder (and similar effects)?
      
    end
    
    -- ------------------------------------------------------------------------------------------
    -- -- User-customizable settings end here.
    -- ------------------------------------------------------------------------------------------

  
  
  
    -- [the setup_tracked_auras() function continues here]

    -- Some further aura notes
    -- ToDo:  if these are single-copy spells, use showOthers:  Beacon of Light, PW:Shield
    -- ToDo:  are Inspiration and Ancestral Fortitude mutually exclusive?  If so, use an aura_set.
    
    --[[
    If we want to track major raid debuffs (e.g. on a boss), here are the aura sets for each category.
      +4% phys dmg taken:  Brittle Bones (DK), Savage Combat (rogue-combat), Blood Frenzy (warr-arms), 
                           Ravage (ravager pet), Acid Spit (worm pet)
      -12% armor: Faerie Fire (druid), Expose Armor (rogue), Sunder Armor (warr), 
                  Corrosive Spit (serpent pet), Tear Armor (raptor pet)
      +30% bleed dmg:  Mangle (druid-cat/bear), Hemorrhage (rogue-sub), Trauma (warr-arms), 
                       Tendon Rip (hyena pet), Gore (boar pet), Stampede (rhino pet)
      +8% spell dmg:  Ebon Plaguebringer (DK-unholy), Earth and Moon (druid-bal), Master Poisoner (rogue-ass), [Jinx: ]Curse of the Elements (warlock), 
                      Fire Breath (dragonhawk pet), Lightning Breath (wind serpent pet)
      
      Tanks care about these, although the first two are usually auto-applied and so don't need to be tracked:
      -attack speed:  Icy Touch (DK), Infected Wounds (druid-feral), Judgements of the Just (pal-prot), Thunder Clap (warr)
                      Tailspin (fox pet), Dust Cloud (tallstrider pet)
      -phys dmg done:  Scarlet Fever (DK), Demoralizing Roar (druid-bear), Vindication (pal-prot), Demoralizing Shout (warr-prot)
                       Demoralizing Roar (bear pet)
      -cast speed:  Slow (mage-arcane), Mind-Numbing Poison (rogue), Curse of Tongues (warlock)
                    Spore Cloud (sporebat pet), Lava Breath (core hound pet)
                      
    --]]
  
    -- build the master format strings for friendly, enemy, and specific unit frames
    ally:build_format()
    foe:build_format()
    if #foe_alt > 0 then foe_alt:build_format() end
    if #player  > 0 then player:build_format() end
    if #pet     > 0 then pet:build_format() end
    if #target  > 0 then target:build_format() end
    if #focus   > 0 then focus:build_format() end

    
  end -- end of setup_tracked_auras() function
  

  -- a debugging function to yield a manageably short time string  
  _G.mytime = function()
    local t = GetTime()
    t = t - floor(t/1000)*1000 -- 3 integer places
    return string.format("(%.2f)", t)
  end
--DEBUG  
--print(mytime(), "Update cache: ", event, "unit=", unit) --*************************
  -- Save the player's current spec so we know whether to rebuild cache after spec change.
  cache.curSpec = GetPrimaryTalentTree()
  

  -- BEGIN COLORS OBJECT ------------------------------------------------------
  cache.colors = {
    red =     {base='cc3333', vivid='ff0000', dark='883333', pale='ff7777'},
    green =   {base='33cc33', vivid='00ff00', dark='338833', pale='88ff88'},
    blue =    {base='2277ee', vivid='3399ff', dark='4444bb', pale='7777ff'},

    cyan =    {base='55dddd', vivid='00ffff', dark='338888', pale='99ffcc'},
    magenta = {base='dd55dd', vivid='ff00ff', dark='883388', pale='ee77ee'},
    yellow =  {base='dddd55', vivid='ffff00', dark='888833', pale='ffff99'},

    orange =  {base='ff9933', vivid='ff7700', dark='aa7755', pale='ffbb66'},
    violet =  {base='7744bb', vivid='aa00ff', dark='550077', pale='dd99ff'},
    brown =   {base='886600', vivid='bb7700', dark='775500', pale='bb9944'},

    gray =    {base='aaaaaa', vivid='eeeeee', dark='555555', pale='cccccc'},
    white =   {base='ffffff', vivid='ffffff', dark='ffffff', pale='ffffff'},
    black =   {base='000000', vivid='000000', dark='000000', pale='000000'},
    
    gradients = { }
  }
  local colors = cache.colors
  
  local numGradientSteps = 16
  
  function colors:parse_color(color)
    color = color:gsub("|cff", "") -- remove leading |cff if present
    local n1,n2,rtxt,gtxt,btxt = color:find("^(..)(..)(..)$")
    rtxt,gtxt,btxt = "0x"..rtxt, "0x"..gtxt, "0x"..btxt
    local r,g,b = tonumber(rtxt), tonumber(gtxt), tonumber(btxt)
    return r,g,b
  end
  
  function colors:register_gradient(color1, color2)
    local r1,g1,b1 = self:parse_color(color1)
    local r2,g2,b2 = self:parse_color(color2)
    self.gradients[color1] = self.gradients[color1] or { }
    self.gradients[color1][color2] = { }
    for i = 0,numGradientSteps do
      local r = r1 + (r2-r1)*(i/numGradientSteps)
      local g = g1 + (g2-g1)*(i/numGradientSteps)
      local b = b1 + (b2-b1)*(i/numGradientSteps)
      self.gradients[color1][color2][i] = string.format("%02x%02x%02x", r, g, b)
    end
  end
  
  -- register some standard gradients
  colors:register_gradient(bkColor, bkColor)
  colors:register_gradient(inactiveColor, inactiveColor)
  colors:register_gradient(inactiveColor, bkColor)
  colors:register_gradient(notMineColor, notMineColor)
  colors:register_gradient(notMineColor, bkColor)
  colors:register_gradient(colors.white.base, bkColor) -- default aura color

  -- get_gradient_color() - interpolates smoothly between two colors  
  --   'frac' should range from 0 to 1
  --   'bias' ranges from 0 (uniform interpolation) to 1 (always return first color)
  function colors:get_gradient_color(color1, color2, frac, bias)
    bias = bias or 0
    local index = floor(frac * numGradientSteps * (1-bias)) -- round toward the first color
--DEBUG
--if not self.gradients[color1] then print("no gradients for", color1) elseif not self.gradients[color1][color2] then print("no gradient for", color1,"-",color2) end    
    return self.gradients[color1][color2][index]
  end
  
  -- END OF COLORS OBJECT -----------------------------------------------------
  
  
  
  -- BEGIN STRING_COLLECTOR OBJECT --------------------------------------------
  -- A tool to collect the format-string fragments, with support for nested elements.
  local string_collector = { }
  function string_collector:new()
    local f = {}
    
    f.index=1
    function f:add(x) 
      tinsert(self, self.index, x); self.index=self.index+1
    end
    function f:add_if(test, x)  -- adds a placeholder "" if test is false
      tinsert(self, self.index, test and x or ""); self.index=self.index+1
    end
    function f:add_nesting(x1, x2) -- for nesting constructions like "|cff" ... "|r"
      tinsert(self, self.index, x1); self.index=self.index+1
      tinsert(self, self.index, x2) -- later calls to add() will push x2 to the right
    end
    function f:add_nesting_if(test, x1, x2)
      tinsert(self, self.index, test and x1 or ""); self.index=self.index+1
      tinsert(self, self.index, test and x2 or "")
    end
    function f:end_nesting() 
      self.index=self.index+1
    end
    function f:concat()
      return table.concat(self)
    end
    
    return f
  end
  -- END OF STRING_COLLECTOR OBJECT -------------------------------------------
  
  
  -- BEGIN AURA OBJECT --------------------------------------------------------
  -- aura - class for a single aura's settings and data
  cache.aura = {
    -- default aura settings
    name = "", -- name of aura
    color = "ffffff",
    fastLen = 1.0, -- seconds per fast tick
    slowLen = 0, -- slow ticks cover entire duration (nonzero ==> excess duration is truncated)
    showOthers = false, -- aura's presence is only shown if player cast it
    showInactive = false, -- true ==> show a dimmed code letter when aura isn't present
    ifKnown = nil, -- timer only exists if this spell is known (e.g. talent-granted spells)
    ifSpec = nil, -- timer only exists if player has this talent spec (1, 2, or 3)
    cooldown = nil, -- set to name of a spell to show if that spell is on cooldown
    isActive = nil, -- custom function to decide if aura is present
    -- these settings are usually automatically generated
    code = "!", -- a letter or other string that appears next to timer bar
    count = false, -- don't show the number of stacks
    fastNum = 0, -- max no. of fast ticks
    slowNum = 0, -- max no. of slow ticks
    sep = "  ", -- spacing shown between this aura and next one
    fmt = "", -- to control string.format
    harmful = false, -- aura assumed to be a buff
    numStringSlots = 0, -- number of dynamic segments used to assemble this aura timer
    
    -- shortcuts to things in the cache
    colors = cache.colors
  }
  local aura = cache.aura
  
  -- Constructor for aura tables.
  function aura:new(s)
    -- set up object property inheritance from the class object
    local old_s = s
    s = s or {}
    setmetatable(s, self)
    self.__index = self -- s inherits fields from self
    if old_s == nil then return s end -- todo: no longer needed??
    
    -- For efficiency (is it significant?), we hook in more complex functions only if certain settings are present.
    if s.cooldown then s:set_cooldown_hooks() end
    if s.embed then s:set_embed_hooks() end
    
    -- Set up transition colors
    if type(s.color)=='table' then s.color = s.color.base end -- allow just 'red' instead of 'red.base', etc.
    s:register_colors()

    -- Parse the bar definition string.  It looks like <code><count><fast><slow><spacing>, e.g. "L#----++  "
    local bar = s.bar or ""
    local n1,n2,code,count,fast,slow,spaces = bar:find("^(.-)(%#*)(%-*)(%+*)(%s*)$")
    if n1 then
      s.code = code:len()>0 and code or ''
      s.count = count:len() > 0
      s.fastNum = fast:len()
      s.slowNum = slow:len()
      s.sep = spaces
    end
    -- Check for $icon:size in code.
    local _,_,size = s.code:find("%$icon%:([0-9]+)")
    if size then
      local _,_,icon = GetSpellInfo(s.name)
      icon = icon or ''
      s.code = s.code:gsub("%$icon%:[0-9]+", "|T"..icon..":"..size.."|t")
    end
    
    -- Next, build the format string for this aura. (Separator spaces are done elsewhere.)
    local parts, numSlots = string_collector:new(), 0
    numSlots = numSlots + s:build_code_format(parts)
    numSlots = numSlots + s:build_count_format(parts)
    numSlots = numSlots + s:build_timer_format(parts)
    parts:add("|r")
    s.fmt = parts:concat() -- complete the format string
    s.numStringSlots = numSlots
--DEBUG
--print(mytime(), "  set up aura", s.name, (s.numStringSlots and s.numStringSlots<0) and "(DISABLED)" or "", "code=", s.code, "fmt=", s.fmt)
    return s
  end -- end of aura:new()
  
  -- Helper function to set up any gradients needed
  function aura:register_colors()
    self.colors:register_gradient(self.color, bkColor)
  end
  
  -- Helper functions to generate parts of the aura's format string.
  function aura:build_code_format(parts)
    parts:add_nesting_if(self.code, "|cff%s", "|r")
      parts:add_if(self.code, "%s")
    parts:end_nesting()
    return (self.code and 2 or 0)
  end
  
  function aura:build_count_format(parts)
    parts:add_nesting_if(self.count, "|cff%s", "|r")
      parts:add_if(self.count, "%d")
    parts:end_nesting()
    return (self.count and 2 or 0)
  end
  
  function aura:build_timer_format(parts)
    local hasFast, hasSlow = self.fastNum>0, self.slowNum>0
    local hasTimer = hasFast or hasSlow
    parts:add_if(hasTimer, "%s%s%s")  -- '|cff', color, and text for on chunk
    parts:add_if(hasTimer, "%s%s%s")  -- '|cff', color, and text for on-->off transition tick
    parts:add_if(hasTimer, "%s%s%s")  -- '|cff', color, and text for off chunk
    parts:add_if(hasTimer, "%s")      -- for the chunk that is split in two by the fast/slow boundary
    return (hasTimer and 10 or 0)
  end

  
  
  
  -- build_aura_display() - computes and collects substrings for the current aura state
  --   Accumulates the substrings in the renderer array.
  --   Returns true if periodic updates are needed, e.g. to animate a timer bar.
  function aura:build_aura_display(renderer, unit, isPresent, isMine, dur, expTime, count)
    if self.numStringSlots < 0 then return end

    local needsUpdates = false -- set to true if aura is active and animated (timer bar, or blinking)
    
    self:pre_display(renderer, unit)
    
    -- compute the appropriate mix of colors for the code and bar, based on the aura status
    local myColor = self.color
    local codeColor = self:compute_code_color(renderer, unit, myColor, inactiveColor, bkColor, isPresent, isMine, dur, expTime, count)
    local barColor  = self:compute_bar_color (renderer, unit, myColor, inactiveColor, bkColor, isPresent, isMine, dur, expTime, count)

    -- if we're blinking and it's time to turn off, set all colors to background
    local blinkOff, blinkTime = false, self.blink
    if blinkTime and expTime then
      needsUpdates = true
      local timeLeft = self:get_time_left(expTime, renderer)  -- 'renderer' only passed for embed hook to use. this is weird. change things?
      if timeLeft < blinkTime then
        local blinkPeriod = 0.5 -- 0.5 causes two blinks per second
        blinkOff = (timeLeft % blinkPeriod) > blinkPeriod/2
        if blinkOff then
          barColor = bkColor
        end
      end
    end

    local fNum, fLen, sNum, sLen  =  self.fastNum, self.fastLen, self.slowNum, self.slowLen
    local hasTimer = fNum and sNum and (fNum>0 or sNum>0)
    
    local oldNumParts = renderer:get_count() -- used to see how many parts we emitted
    
    -- emit data for the code and cooldown
    local codeNeedsUpdates = self:emit_code(renderer, isMine, codeColor, blinkOff)
    needsUpdates = needsUpdates or codeNeedsUpdates
    
    -- emit data for the count
    renderer:add_if(self.count, barColor)
    renderer:add_if(self.count, count or 1) -- default "1" (to maintain spacing) if aura not present
    
    -- emit data for the timer bar
    if hasTimer then
      local timerNeedsUpdates = (expTime ~= nil)
      needsUpdates = needsUpdates or timerNeedsUpdates
      
      local fastFragments, slowFragments = self.timer_fragments.fast, self.timer_fragments.slow -- arrays of fragments
      expTime = expTime or -1 -- dummy value for when aura is not present
      
      -- If slow tick length is zero, alter it so slow bar extends to end of duration.
      local fTot = fNum * fLen -- total length of "fast tick" part of bar
      if sLen == 0 then
        if dur then
          sLen = max(0.01, dur - fTot)/sNum
          self.slowLenAuto = sLen -- save calculated value in case someone else needs it
        else
          sLen = 5.0 -- dummy value for when aura is not present
        end
      end
      
      local startTime = GetTime()
      self:emit_timer(renderer, unit, barColor, startTime, expTime, fNum, fLen, sNum, sLen, fastFragments, slowFragments)
    end
    
    -- If a color chunk or transition tick ends at the fast-slow boundary, we'll never split any chunks.
    -- In that case, we have to emit an empty string to fill all the slots in the format-string.
    for i = (renderer:get_count() - oldNumParts + 1), self.numStringSlots do
      renderer:add('')
    end
    
    local postNeedsUpdates = self:post_display(renderer, unit)
    needsUpdates = needsUpdates or postNeedsUpdates
--DEBUG
--print(mytime(), "  build aura:", self.name, "pres=",isPresent, "mine=",isMine, "dur=",dur, "exp=",expTime, "cnt=",count, "upd=",needsUpdates)
    return needsUpdates
  end -- end of aura:build_aura_display()
  

  
  -- pre_display() & post_display
  -- Does nothing; can be hooked if special versions need to precalculate something.
  function aura:pre_display(renderer)
    -- nada
  end
  function aura:post_display(renderer)
    -- nada
  end
  
  -- get_time_left() - returns nil if argument is nil
  function aura:get_time_left(expTime, renderer)
    if not expTime then
      return nil
    else
      return expTime - GetTime()
    end
  end
  

  -- compute_code_color() and compute_bar_color()
  -- There are 4 ways to color a bar, based on the showOthers and showInactive settings:
  --   present and mine:               A#-----  (bright: code, count, bar)
  --   present, not mine, showOthers:  A#-----  (dim: code, count, bar)
  --   not present, showInactive:      A        (dim: code ; invisible: count, bar)
  --   not present:                             (invisible: all)
  function aura:compute_code_color(renderer, unit, myColor, inactiveColor, bkColor, isPresent, isMine, dur, expTime, count)
    local codeColor
    if isPresent and isMine then                codeColor = myColor
    elseif isPresent and self.showOthers then   codeColor = notMineColor
    elseif self.showInactive then               codeColor = inactiveColor
    else                                        codeColor = bkColor
    end
    return codeColor
  end
  function aura:compute_bar_color(renderer, unit, myColor, inactiveColor, bkColor, isPresent, isMine, dur, expTime, count)
    local barColor
    if isPresent and isMine then                barColor = myColor
    elseif isPresent and self.showOthers then   barColor = notMineColor
    elseif self.showInactive then               barColor = bkColor
    else                                        barColor = bkColor
    end
    return barColor
  end
  
  
  
  -- emit_code()
  -- Emits the code color and symbol.
  function aura:emit_code(renderer, isMine, codeColor, blinkOff)
    -- turn colors off if blinking
    if blinkOff then
      codeColor = bkColor
    end
    renderer:add_if(self.code,               codeColor)
    renderer:add_if(self.code,               self.code)
    return false -- no updates needed
  end

  -- emit_timer() emits the parts needed to build the entire timer bar for the aura
  function aura:emit_timer(renderer, unit, barColor, startTime, expTime, fNum, fLen, sNum, sLen, fFrags, sFrags)
    -- Emit the on chunk
    startTime, fNum, sNum  =  self:emit_timer_chunk(renderer, barColor, startTime, expTime, fNum, fLen, sNum, sLen, fFrags, sFrags)
    -- Emit the on-off transition tick
    startTime, fNum, sNum  =  self:emit_transition_tick(renderer, barColor, startTime, bkColor, expTime, fNum, fLen, sNum, sLen, fFrags, sFrags)
    -- Emit the off chunk
    startTime, fNum, sNum  =  self:emit_timer_chunk(renderer,  bkColor, startTime, 9999999, fNum, fLen, sNum, sLen, fFrags, sFrags)
  end
  
  
  -- emit_timer_chunk()
  -- Given a starting and ending time, emits as many ticks as will fit.
  -- Emits either one or two strings (unless endTime < startTime)
  -- Parameters:
  --   renderer         - an object that collects the string fragments
  --   chunkColor       - color of this chunk of the timer
  --   startTime        - the time corresponding to the start of the chunk
  --   endTime          - the time when the chunk ends
  --   fTicksLeft, fLen - the number and length of fast ticks available
  --   sTicksLeft, sLen - the number and length of slow ticks available (length is never 0)
  --   fFrags, sFrags   - arrays of string fragments
  -- Returns the following:
  --   newTime     - the time after the emitted ticks (newTime <= endTime)
  --   fTicksLeft  - number of fast ticks remaining after the chunk
  --   sTicksLeft  - number of slow ticks remaining after the chunk
  function aura:emit_timer_chunk(renderer, chunkColor, startTime, endTime, fTicksLeft, fLen, sTicksLeft, sLen, fFrags, sFrags)
  
    renderer:add('|cff')
    renderer:add(chunkColor)
  
    local fChunkTicks, sChunkTicks
    endTime = max(startTime, endTime) -- if passed a bogus endTime, treat chunk as zero length
    
    -- Emit fast ticks first.
    fChunkTicks = min(fTicksLeft, floor( (endTime - startTime) / fLen))
    if fChunkTicks > 0 then
      renderer:add(fFrags[fChunkTicks])
      startTime = startTime + fChunkTicks*fLen
      fTicksLeft = fTicksLeft - fChunkTicks
    end
    
    -- If we've used up the fast ticks, emit some slow ticks.
    if fTicksLeft == 0 then
      sChunkTicks = min(sTicksLeft, floor( (endTime - startTime) / sLen))
      if sChunkTicks > 0 then
        renderer:add(sFrags[sChunkTicks])
        startTime = startTime + sChunkTicks*sLen
        sTicksLeft = sTicksLeft - sChunkTicks
      end
    end
    
    return startTime, fTicksLeft, sTicksLeft
  end -- emit_timer_chunk()

  
  -- emit_transition_tick()
  -- Generates a single tick of a blended color.
  -- Emits the following (may be empty strings if no ticks are available):
  --   A color swap "|r|cff112233" to a color blended from startColor and endColor
  --   A single tick
  function aura:emit_transition_tick(renderer, startColor, startTime, endColor, endTime, 
                                     fTicksLeft, fLen, sTicksLeft, sLen, fFrags, sFrags)
    if endTime < startTime or (fTicksLeft==0 and sTicksLeft==0) then
      renderer:add('') -- emit 3 placeholder empty strings
      renderer:add('')
      renderer:add('')
    else
      local fracLen = endTime - startTime
      local tickLen, tickString
      if fTicksLeft > 0 then
        tickLen = fLen
        startTime = startTime + tickLen
        tickString = fFrags[1]
        fTicksLeft = fTicksLeft -1
      elseif sTicksLeft > 0 then
        tickLen = sLen
        startTime = startTime + tickLen
        tickString = sFrags[1]
        sTicksLeft = sTicksLeft - 1
      end
      
      -- emit an intermediate color and the tick
      -- we bias the intermediate color because very dark colors look like the tick has vanished
      local frac = tickLen and 1 - (fracLen / tickLen) or 0
      local c = self.colors:get_gradient_color(startColor, endColor, frac, 0.3)
      renderer:add('|cff')
      renderer:add(c)
      renderer:add(tickString)
    end
    
    return startTime, fTicksLeft, sTicksLeft
  end -- emit_transition_tick()
  
  
  
  -- scan() - see if this aura is present
  function aura:scan(unit)
    if self.isActive then
      return self.isActive(unit) -- use the custom function
    else
      local name, harmful = self.name, self.harmful
      local filterMine, filterOthers = harmful and "PLAYER HARMFUL" or "PLAYER", harmful and "HARMFUL" or "HELPFUL"
      local _,_,icon,count,_,dur,expTime,caster,_,_,id = UnitAura(unit, name, nil, filterMine)
      local isMine = true
      if not caster and self.showOthers then
        _,_,icon,count,_,dur,expTime,caster,_,_,id = UnitAura(unit, name, nil, filterOthers)
        isMine = false
      end
      local isPresent = expTime ~= nil
      return isPresent, isMine, dur, expTime, count
    end
  end -- end of aura:scan()
  
  
  -- Prebuild timer bar fragments of all lengths, so we avoid making garbage later.
  aura.timer_fragments = { fast={}, slow={} }
  for i=0,40 do
    aura.timer_fragments.fast[i] = string.rep(fastTick,i)
    aura.timer_fragments.slow[i]  = string.rep(slowTick,i)
  end
  
  -- Convenience functions for users to define buff/debuff layouts
  cache.aura_buff = aura:new()
  cache.aura_debuff = aura:new{harmful=true}
  
  cache.buff   = function(s) return cache.aura_buff:new(s)   end
  cache.debuff = function(s) return cache.aura_debuff:new(s) end
  -- END OF AURA OBJECT -------------------------------------------------------
  

  
  
  

  -- BEGIN AURA SUBCLASSES AND HOOKS ------------------------------------------
  
  -- aura_set - subclass to represent a set of mutually exclusive auras (e.g. shaman's shield spells).
  --     Extra members:  set = table of aura objects, which=index of active aura or nil
  cache.aura_set = aura:new()
  local aura_set = cache.aura_set
  -- scan() examines each aura in the set.
  function aura_set:scan(unit)
    local isPresent, isMine, dur, expTime, count
    self.which = nil
    for i,v in ipairs(self.set) do
      isPresent, isMine, dur, expTime, count = v:scan(unit)
      if isPresent then 
        self.which = i
        break 
      end
    end
    if not self.which then
      isPresent, isMine, dur, expTime, count = aura.scan(self, unit)
    end
    return isPresent, isMine, dur, expTime, count
  end
  -- build_aura_display() - uses the sub-aura found to be active, or uses self as a default.
  function aura_set:build_aura_display(renderer, unit, isPresent, isMine, dur, expTime, count)
    if self.numStringSlots < 0 then return end
    if self.which then
      return self.set[self.which]:build_aura_display(renderer, unit, isPresent, isMine, dur, expTime, count)
    else
      --return aura.build_aura_display(self, renderer, unit, false, false, nil, nil, nil)
      return aura.build_aura_display(self, renderer, unit, isPresent, isMine, dur, expTime, count)
    end
  end
  -- Convenience functions for users to define sets
  cache.aura_set_buff = aura_set:new()
  cache.aura_set_debuff = aura_set:new{harmful=true}

  cache.buff_set   = function(s) return cache.aura_set_buff:new(s)   end
  cache.debuff_set = function(s) return cache.aura_set_debuff:new(s) end
  -----------------------------------------------------------------------------
  
  -- aura_static - subclass to hold a static piece of text (in the code member)
  --     Extra members: text = the text to add
  cache.aura_static = aura:new{name="[Static text]"}
  local aura_static = cache.aura_static
  -- new() handles the text member
  function aura_static:new(s)
    if type(s)=='string' then
      s = {text=s}
    end
    s.bar = s.text -- the text will eventually be stored as the 'code' member
    -- (might screw up the display if the user's text ends with our special symbols #-+ )
    return aura.new(self, s)
  end
  -- scan() always succeeds
  function aura_static:scan(unit)
    return true, true, nil, nil, nil
  end
  -- build_aura_display() doesn't need to do anything
  function aura_static:build_aura_display(renderer, unit, isPresent, isMine, dur, expTime, count)
    renderer:add(self.color)
    renderer:add(self.code)
    return false -- no timer updates needed
  end
  
  cache.static = function(s) return cache.aura_static:new(s) end

  -- cooldown hooks -----------------------------------------------------------
  
  function aura:set_cooldown_hooks()
  
    -- register_colors() - also register gradient for cooldown/bkColor
    local register_colors__old = self.register_colors
    self.register_colors = function(self)
      register_colors__old(self)
      self.colors:register_gradient(cooldownColor, bkColor)
    end
  
    -- build_code_format() - surround the code with brackets to indicate a cooldown
    local build_code_format__old = self.build_code_format
    self.build_code_format = function(self, parts)
      local numParts = (self.cooldown and 2 or 0)
      parts:add_nesting_if(self.cooldown, "|cff%s[|r", "|cff%s]|r") -- surrounds code with [ ] if on cooldown
        numParts = numParts + build_code_format__old(self, parts) -- call the original version
      parts:end_nesting()
      return numParts
    end
    
    -- emit_code() - turn the colors for the cooldown indicators on or off
    local emit_code__old = self.emit_code
    self.emit_code = function(self, renderer, isMine, codeColor, blinkOff)
      local needsUpdates = false
      
      -- set cooldown color, if needed
      local cooldown_spell, cooling_down, cooldownStatusColor = self.cooldown, false, bkColor
      local CDstart, CDdur
      if cooldown_spell then
        CDstart, CDdur = GetSpellCooldown(cooldown_spell)
        cooling_down = (CDdur or 0) > 1.5 -- ignore global cooldowns
      end
      if cooling_down and isMine then
        local frac = (GetTime() - CDstart) / CDdur
        -- fade the cooldown color, but with bias to avoid getting too dark
        cooldownStatusColor = self.colors:get_gradient_color(cooldownColor, bkColor, frac, 0.5)
        needsUpdates = true
      end
      
      -- turn colors off if blinking
      if blinkOff then
        codeColor, cooldownStatusColor = bkColor, bkColor
      end
      
      -- emit data for the code and cooldown
      renderer:add_if(cooldown_spell, cooldownStatusColor)
      emit_code__old(self, renderer, isMine, codeColor, blinkOff) -- call the original version
      renderer:add_if(cooldown_spell, cooldownStatusColor)
      
      return needsUpdates
    end
  end

  
  -- embed hooks --------------------------------------------------------------
  
  function aura:set_embed_hooks()
  
    -- register_colors() - also register gradients for embed/on and embed/off
    local register_colors__old = self.register_colors
    self.register_colors = function(self)
      local embedColor = self.embed.color
      register_colors__old(self)
      self.colors:register_gradient(embedColor, self.color)
      self.colors:register_gradient(embedColor, notMineColor)
      self.colors:register_gradient(embedColor, inactiveColor) -- in case this becomes possible in a future version
      self.colors:register_gradient(embedColor, bkColor)
    end
  
    -- build_timer_format() - format string needs extra slots for the embed aura's timer chunk
    local build_timer_format__old = self.build_timer_format
    self.build_timer_format = function(self, parts)
      local hasFast, hasSlow = self.fastNum>0, self.slowNum>0
      local hasTimer = hasFast or hasSlow
      parts:add_if(hasTimer, "%s%s%s")  -- '|cff', color, and text for embed chunk
      parts:add_if(hasTimer, "%s%s%s")  -- '|cff', color, and text for transition tick
      local numParts = build_timer_format__old(self, parts) -- call original version
      return numParts + (hasTimer and 6 or 0)
    end
    
    -- pre_display() - scan the embed aura
    local pre_display__old = self.pre_display
    self.pre_display = function(self, renderer, unit)
      local embedPresent, embedMine, embedDur, embedExpTime, embedCount = self.embed:scan(unit)
      -- save results in the renderer for future use
      local r = renderer
      r.embedPresent,r.embedMine,r.embedDur,r.embedExpTime,r.embedCount = embedPresent,embedMine,embedDur,embedExpTime,embedCount
      -- call original version
      pre_display__old(self, renderer, unit)
    end
    
    -- get_time_left() - check both main and embed auras - need more code elsewhere to test embed's blink setting...
    -- local get_time_left__old = self.get_time_left
    -- self.get_time_left = function(self, expTime, renderer)
      -- local mainTime = get_time_left__old(expTime)
      -- local embedTime = get_time_left__old(renderer.embedExpTime)
    -- end
    
    -- compute_code_color() - code should use embed aura's color if it is active
    local compute_code_color__old = self.compute_code_color
    self.compute_code_color = function(self, renderer, unit, myColor, inactiveColor, bkColor, isPresent, isMine, dur, expTime, count)
      -- if embed aura is active, then code uses its color instead of color of main aura
      if renderer.embedPresent then
        myColor = self.embed.color
        inactiveColor = self.embed.color
      end
      return compute_code_color__old(self, renderer, unit, myColor, inactiveColor, bkColor, isPresent, isMine, dur, expTime, count)
    end
    
    -- emit_timer() - emit the embed aura chunk first, then the parent timer bar uses what's left
    local emit_timer__old = self.emit_timer
    self.emit_timer = function(self, renderer, unit, barColor, startTime, expTime, fNum, fLen, sNum, sLen, fFrags, sFrags)
      local embed = self.embed
      -- If aura has slowLen == 0, we normally auto-calculate a value based on the aura's duration.
      -- However, if the aura isn't present, we can't get a duration.  If the embed aura is present
      -- without the parent aura, we look for a saved value of slowLen, else fall back to a default value.
      sLen = (sLen~=0) and sLen or self.slowLenAuto or 5.0
      if embed then
        local r = renderer
        local embedPresent,embedMine,embedDur,embedExpTime,embedCount = r.embedPresent,r.embedMine,r.embedDur,r.embedExpTime,r.embedCount
        if embedPresent then
          local embedColor = embed.color
          -- emit the embedded aura chunk, in its own color
          startTime, fNum, sNum  = self:emit_timer_chunk(renderer, embedColor, startTime, embedExpTime, fNum,fLen,sNum,sLen,fFrags,sFrags)
          -- should we transition to the on or off color?
          local nextColor = embedExpTime<expTime and barColor or bkColor
          -- emit the transition tick
          startTime, fNum, sNum = self:emit_transition_tick(renderer, embedColor, startTime, nextColor, embedExpTime, fNum,fLen,sNum,sLen,fFrags,sFrags)
        end
      end
      -- call original version
      emit_timer__old(self, renderer, unit, barColor, startTime, expTime, fNum, fLen, sNum, sLen, fFrags, sFrags)
    end

    -- post_display() - we need updates if the embed aura is present
    local post_display__old = self.post_display
    self.post_display = function(self, renderer, unit)
      return post_display__old(self, renderer) or renderer.embedPresent
    end
    
  end

  
  -- END OF AURA SUBCLASSES AND HOOKS -----------------------------------------
  
  
  -- BEGIN AURAS OBJECT -------------------------------------------------------
  cache.auras = { }
  local auras = cache.auras
  
  -- constructor
  function auras:new(s)
    s = s or { fmt="", }
    setmetatable(s, self)
    self.__index = self -- s inherits fields from self
    return s
  end

  -- add()
  function auras:add(s)
    if type(s) == 'string' then
      table.insert(self, aura_static:new{text=s})
    else
      local isValid = true
      if s.ifKnown and not GetSpellInfo(s.ifKnown)     then isValid=false end
      if s.ifSpec and GetPrimaryTalentTree()~=s.ifSpec then isValid=false end
      if isValid then
        table.insert(self, s)
      end
--DEBUG
--print(mytime(), "  added aura:", s.name, isValid and "" or "(DISABLED)", "code=", s.code, "fmt=", s.fmt)
    end
  end
  
  -- Convenience functions for adding elements
  local buff, debuff = cache.aura_buff, cache.aura_debuff
  local buff_set, debuff_set = cache.aura_set_buff, cache.aura_set_debuff
  local static = cache.aura_static
  
  function auras:buff(s)       self:add(buff:new(s)) end
  function auras:debuff(s)     self:add(debuff:new(s)) end
  function auras:buff_set(s)   self:add(buff_set:new(s)) end
  function auras:debuff_set(s) self:add(debuff_set:new(s)) end
  function auras:static(s)     self:add(static:new(s)) end

  -- build_format() - assembles the complete format-string for string.format
  function auras:build_format()
    local lastSep, n = "", 0
    for _,v in ipairs(self) do
      self.fmt = self.fmt .. lastSep .. v.fmt
      n = n + v.numStringSlots
      lastSep = v.sep
    end
    self.numStringSlots = n
  end
  
  -- tables to hold aura settings for various frames
  cache.unit_auras = { }
  cache.unit_auras['_friend'] = auras:new()
  cache.unit_auras['_enemy'] =  auras:new()
  cache.unit_auras['_enemy_alt'] = auras:new()
  cache.unit_auras['player'] =  auras:new()
  cache.unit_auras['pet'] =     auras:new()
  cache.unit_auras['target'] =  auras:new()
  cache.unit_auras['focus'] =   auras:new()
  -- END OF AURAS OBJECT ------------------------------------------------------


  -- RENDERER OBJECT ----------------------------------------------------------
  -- The renderer collects the parts used to build the final string.
  cache.renderer = { }
  local renderer = cache.renderer
  
  -- constructor
  function renderer:new(auras, s)
    s = s or { curN=1, } -- how many parts, complete format string
    setmetatable(s, self)
    self.__index = self -- s inherits fields from self
    s.auras = auras
    return s
  end
 
  -- add(), add_if() - append a substring to the accumulated list
  function renderer:add(str)
    self[self.curN] = str
    self.curN = self.curN + 1
  end
  
  function renderer:add_if(test, str)
    if test then self:add(str) end
  end
  
  -- get_count() - how many fragments are currently stored
  function renderer:get_count()
    return self.curN - 1
  end
  
  -- get_format() - the format string for my auras collection
  function renderer:get_format()
    return self.auras.fmt
  end
  
  -- build_display() - scans all auras and collects all the dynamic sub-parts
  function renderer:build_display(unit)
    self.curN = 1 -- restart at first slot
    local needsUpdates = false
    for _,v in ipairs(self.auras) do
      local isPresent, isMine, dur, expTime, count = v:scan(unit)
      local subAuraNeedsUpdates = v:build_aura_display(self, unit, isPresent, isMine, dur, expTime, count)
      needsUpdates = needsUpdates or subAuraNeedsUpdates
    end
    return needsUpdates
  end
  
  -- tables to hold renderers for various frames (indexed by font_string)
  cache.unit_renderers = { }
  cache.unit_renderers['_friend'] = { }
  cache.unit_renderers['_enemy']  = { }
  cache.unit_renderers['_enemy_alt'] = { }
  cache.unit_renderers['player']  = { }
  cache.unit_renderers['pet']     = { }
  cache.unit_renderers['target']  = { }
  cache.unit_renderers['focus']   = { }
  -- END OF RENDERER OBJECT ---------------------------------------------------
  
  
  
  -- Define the auras that we want to track. --------------
  -- Must execute down here, after all the above definitions have been made.
  local playerClass = select(2,UnitClass("player"))
  local playerSpec = GetPrimaryTalentTree()
  cache.setup_tracked_auras(cache, playerClass, playerSpec)
  
  -- for debugging convenience
  _G.tacache = cache
  _G.pbse = PitBull4.LuaTexts.ScriptEnv
  
  -- build_luatext() - renders the full LuaText string
  function cache.build_luatext(cache, unit)
    local auras, renderer
    -- fetch the existing renderer or create one
--DEBUG    
--print(mytime(), "Build: unit=", unit, ", event=", event)    
    local unit_key = unit
    if unit_key=='player' and not font_string.frame.is_singleton then
      -- hack to prevent the party/raid frame for the player from using the player frame's layout
      unit_key='_friend'
    end
    if not cache.unit_auras[unit_key] or #(cache.unit_auras[unit_key]) == 0 then
      -- no aura setup is specifically defined for this unit frame, so use the generic friend/enemy setup
      if UnitIsFriend('player', unit) then
        unit_key = '_friend'
      elseif cache.use_alternate_enemy_layout and cache.use_alternate_enemy_layout() then
        unit_key = '_enemy_alt'
      else
        unit_key = '_enemy'
      end
    end
    auras = cache.unit_auras[unit_key]
    cache.unit_renderers[unit_key][font_string] = cache.unit_renderers[unit_key][font_string] or cache.renderer:new(auras)
    renderer = cache.unit_renderers[unit_key][font_string]

    -- use the renderer to generate all the parts
    local needsUpdates = renderer:build_display(unit)
--DEBUG
--print(mytime(), floor( ((floor( GetTime()*100 )/100)%1000) * 100 )/100, "Render '", unit, "' using", renderer, ", event", event)    
    if needsUpdates then UpdateIn(0.25) end -- periodic updates to animate timer bars
    -- return the list of parts
--DEBUG display the fragments of the output string
--print(mytime(), 'fmt:', table.concat(renderer,'!'))    
    return renderer:get_format() or "FAIL", unpack(renderer)
  end
  
end -- end of cache rebuild clause

