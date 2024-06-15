--print('KRF is loaded!')

FlashlightStatus = {
  SPAWNING = 0,
  SPAWNED = 1,
  DESPAWNING = 2,
  DESPAWNED = 3
}

LightStatus = {
  ON = 0,
  OFF = 1
}

public = {
  isReady = false,
  title = 'KRF',
  version = '2.1'
}

private = {
  drawnWeapon = nil,

  flashlightID = nil,
  flashlight = nil,
  flashlightPath = [[base\gameplay\devices\lighting\industrial\spotlight\spotlight_d_lamp_a.ent]],

  flashlightStatus = FlashlightStatus.DESPAWNED,
  lightStatus = LightStatus.OFF,

  disableFlashlightColl = true,
  disableFlashlightVisib = true,

  radioTurnOnSoundName = nil,
  tvTurnOnSoundName = nil
}

function checkIfSessionStarted()
  return Game.GetPlayer() and Game.GetPlayer():IsAttached() and not Game.GetSystemRequestsHandler():IsPreGame()
end

function checkIfActivelyPlaying()
  local timeSystem = Game.GetTimeSystem()

  return checkIfSessionStarted() and not (Game.GetSystemRequestsHandler():IsGamePaused() or timeSystem:IsPausedState() or (timeSystem:IsTimeDilationActive() and timeSystem:GetActiveTimeDilation() < 0.05))
end

function checkIfInsideVehicle()
  return Game.GetPlayer():GetMountedVehicle() ~= nil
end

function turnOnFlashlight()
  if private.flashlight ~= nil and private.lightStatus == LightStatus.OFF then
    private.lightStatus = LightStatus.ON
    private.flashlight:TurnOnLights()
  end
end

function turnOffFlashlight()
  if private.flashlight ~= nil and private.lightStatus == LightStatus.ON then
    private.lightStatus = LightStatus.OFF
    private.flashlight:TurnOffLights()
  end
end

function playTurnOnSound()
  GameObject.PlaySound(Game.GetPlayer(), private.radioTurnOnSoundName)
end

function playTurnOffSound()
  GameObject.PlaySound(Game.GetPlayer(), private.tvTurnOnSoundName)
end

function getActivePlayerWeapon()
  return Game.GetActiveWeapon(Game.GetPlayer())
end

function getFlashlightSpawnPoint()
  if private.drawnWeapon == nil then
    return nil
  end

  local muzzleTransform = private.drawnWeapon:GetMuzzleSlotWorldTransform()
  local muzzlePos = Transform.GetPosition(muzzleTransform)
  local muzzleAngle = Transform.ToEulerAngles(muzzleTransform)

  local spawnTransform = private.drawnWeapon:GetWorldTransform()
  local spawnPos = Vector4.new(muzzlePos.x, muzzlePos.y, muzzlePos.z - 0.1, muzzlePos.w)
  local spawnAngle = EulerAngles.new(muzzleAngle.pitch, 0, muzzleAngle.yaw - 90)

  WorldTransform.SetPosition(spawnTransform, spawnPos)
  WorldTransform.SetOrientationEuler(spawnTransform, spawnAngle)

  return {
    transform = spawnTransform,
    pos = spawnPos,
    angle = spawnAngle
  }
end

function findFlashlightEntity()
  if private.flashlightStatus == FlashlightStatus.SPAWNING and private.flashlightID ~= nil and private.flashlight == nil then
    private.flashlight = Game.FindEntityByID(private.flashlightID)

    if private.flashlight ~= nil then
      if private.disableFlashlightColl then private.flashlight:ToggleComponentByName(CName.new('Collider'), false) end
      if private.disableFlashlightVisib then private.flashlight:ToggleComponentByName(CName.new('Mesh0371'), false) end

      private.flashlightStatus = FlashlightStatus.SPAWNED
    end
  end
end

function moveFlashlight()
  if private.flashlightStatus == FlashlightStatus.SPAWNED then
    local flashlightSpawnPoint = getFlashlightSpawnPoint()

    Game.GetTeleportationFacility():Teleport(private.flashlight, flashlightSpawnPoint.pos, flashlightSpawnPoint.angle)
  end
end

function spawnFlashlight()
  if private.flashlightStatus == FlashlightStatus.DESPAWNED then
    playTurnOnSound()

    private.flashlightStatus = FlashlightStatus.SPAWNING
    private.lightStatus = LightStatus.ON

    local flashlightSpawnPoint = getFlashlightSpawnPoint()
    private.flashlightID = exEntitySpawner.Spawn(private.flashlightPath, flashlightSpawnPoint.transform)
  end
end

function despawnFlashlight()
  if private.flashlightStatus == FlashlightStatus.SPAWNED then
    playTurnOffSound()

    private.flashlightStatus = FlashlightStatus.DESPAWNING

    exEntitySpawner.Despawn(private.flashlight)

    private.flashlight = nil
    private.flashlightID = nil

    private.lightStatus = LightStatus.OFF
    private.flashlightStatus = FlashlightStatus.DESPAWNED
  end
end

registerForEvent('onInit', function()
  public.isReady = true

  private.radioTurnOnSoundName = CName.new('ui_radio_turn_on')
  private.tvTurnOnSoundName = CName.new('ui_tv_turn_on')
  private.drawnWeapon = getActivePlayerWeapon()

  ObserveAfter('PlayerPuppet', 'OnWeaponEquipEvent', function(self)
    private.drawnWeapon = getActivePlayerWeapon()

    if not private.drawnWeapon:IsMelee() then
      turnOnFlashlight()
    elseif private.drawnWeapon:IsMelee() then
      turnOffFlashlight()
    end
  end)

  Observe('PlayerPuppet', 'OnItemUnequipped', function(self)
    turnOffFlashlight()
  end)

  Observe('UpperBodyTransition', 'SetWeaponHolster', function (self, _scriptInterface, newState)
    local isHolstered = newState

    if isHolstered == true then
      turnOffFlashlight()
    end
  end)

  ObserveBefore('PlayerPuppet', 'OnVehicleStateChange', function(self, newState)
    if newState ~= EnumInt(gamePSMVehicle.Default) and private.flashlightStatus == FlashlightStatus.SPAWNED then
      despawnFlashlight()
    end
  end)

  --print('KRF is initialized!')
end)

registerForEvent('onUpdate', function()
  findFlashlightEntity()
  moveFlashlight()
end)

registerInput('switch_flashlight', 'Switch Flashlight', function(keypress)
  if not keypress then
    local isActivelyPlaying = checkIfActivelyPlaying()
    local isInsideVehicle = checkIfInsideVehicle()

    private.drawnWeapon = getActivePlayerWeapon()

    if not isInsideVehicle and isActivelyPlaying and private.drawnWeapon ~= nil then
      if private.flashlightStatus == FlashlightStatus.DESPAWNED and not private.drawnWeapon:IsMelee() then
        spawnFlashlight()
      elseif private.flashlightStatus == FlashlightStatus.SPAWNED then
        despawnFlashlight()
      end
    end
  end
end)

registerForEvent('onShutdown', function()
  despawnFlashlight()
end)

return public