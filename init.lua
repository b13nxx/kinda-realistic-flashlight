require 'src/core/utils'
require 'src/core/debug'
require 'src/core/enums'
require 'src/core/operator'
require 'src/core/player'

require 'src/core/generalOptions'
require 'src/core/color'
require 'src/core/lightBeam'
require 'src/core/sound'

require 'src/flashlight'
require 'src/settingsScreen'

public = {
  isReady = false,
  title = 'KRF',
  version = '3.0'
}

private = {
  passedTime = 0,
  tickTime = 0.5
}

registerForEvent('onInit', function()
  settingsScreen:init(public.title, public.version)
  settingsScreen:load()
  settingsScreen:draw()

  flashlight:init()

  ObserveAfter('UpperBodyEventsTransition', 'UpdateSwitchItem', function(self, timeDelta, stateContext)
    if flashlight.stateContext ~= nil then return end
    flashlight:setStateContext(stateContext)
  end)

  ObserveAfter('SwimmingSurfaceDecisions', 'EnterCondition', function(self, stateContext)
    if flashlight.stateContext ~= nil then return end
    flashlight:setStateContext(stateContext)
  end)

  ObserveAfter('SwimmingTransitionDecisions', 'EnterCondition', function(self, stateContext)
    if flashlight.stateContext ~= nil then return end
    flashlight:setStateContext(stateContext)
  end)

  -- ObserveBefore('PublicSafeDecisions', 'EnterCondition', function(self, stateContext)
  --   print('PublicSafeDecisions EnterCondition', stateContext:GetBoolParameter(CName.new('ForceReadyState'), true))
  -- end)

  Observe('PlayerPuppet', 'OnDetach', function(self)
    if not self:IsReplacer() then
      flashlight:despawn()
    end
  end)

  ObserveAfter('PlayerPuppet', 'OnWeaponEquipEvent', function(self)
    local playerWeapon = player:getActiveWeapon()

    flashlight:bindToPlayerWeapon()

    if not playerWeapon:IsMelee() then
      flashlight:turnOn()
    elseif playerWeapon:IsMelee() then
      flashlight:turnOff()
    end
  end)

  Observe('PlayerPuppet', 'OnItemUnequipped', function(self)
    flashlight:turnOff()
  end)

  Observe('UpperBodyTransition', 'SetWeaponHolster', function (self, _scriptInterface, isHolstered)
    if isHolstered then
      flashlight:turnOff()
    end
  end)

  ObserveBefore('PlayerPuppet', 'OnVehicleStateChange', function(self, newState)
    if newState ~= EnumInt(gamePSMVehicle.Default) and flashlight.entityStatus == FlashlightStatus.SPAWNED then
      flashlight:despawn()
    end
  end)

  print('KRF is initialized!')

  public.isReady = true
end)

registerForEvent('onUpdate', function(delta)
  private.passedTime = private.passedTime + delta

  if private.passedTime > private.tickTime then
    private.passedTime = 0

    if flashlight.entityStatus ~= FlashlightStatus.SPAWNED then
      flashlight:findEntity()
    end

    if sound.requestPlayTurnOn > 0 or sound.requestPlayTurnOff > 0 then
      sound:checkPlayRequests(private.tickTime)
    end

    flashlight:calibrate()
  end
end)

registerInput('switch_flashlight', 'Switch Flashlight', function(keypress)
  if not keypress then
    flashlight:switch()
  end
end)

registerForEvent('onShutdown', function()
  flashlight:despawn()
  flashlight:destroy()
  settingsScreen:destroy()
end)

return public
