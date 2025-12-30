-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local vssMapping = require('lua/vehicle/extensions/bettervsl/vssMapping')
local M = {}

local logTag = 'bettervsl'

-- VSS Categories instead of BeamNG modules
local vssCategories = {
  speed = "Vehicle.Speed",
  powertrain = "Vehicle.Powertrain",
  chassis = "Vehicle.Chassis",
  body = "Vehicle.Body",
  currentLocation = "Vehicle.CurrentLocation",
  obd = "Vehicle.OBD"
}

-- Legacy BeamNG modules (for backwards compatibility)
local legacyModules = {
  general = "General",
  wheels = "Wheels",
  inputs = "Inputs",
  engine = "Engine",
  powertrain = "Powertrain"
}

local record = {}
local vssRecord = {}
local legacyRecord = {}
local outputStreams = {}
local settings = {
  outputDir = "VSL",
  format = "vss-jsonl", -- "vss-jsonl", "vss-csv", or "beamng"
  vssVersion = "4.0"
}

local doLogging = false
local timeSinceStartOfLogging = 0
local secUntilNextUpdate = 0
local stepsSinceLastFlush = 0
local totalSamples = 0
local csvSeparator = ","
local currentOutputFile = ""

local devices = nil

local function updateDeviceStates()
  devices = powertrain.getDevices()
end

-- Helper to add stat to record
local function addStatToRecord(category, statID, getValue, vssPath, description, unit)
  if not record[category] then
    record[category] = {}
  end
  
  table.insert(record[category], {
    id = statID,
    get = getValue,
    vssPath = vssPath,
    description = description or vssPath,
    unit = unit or ""
  })
  
  return statID + 1
end

-- VSS Signal Definitions
local function addVehicleSpeedSignals()
  local category = vssCategories.speed
  record[category] = {}
  local statID = 1
  
  statID = addStatToRecord(
    category,
    statID,
    function() return obj:getVelocity():length() * 3.6 end, -- m/s to km/h
    "Vehicle.Speed",
    "Vehicle speed",
    "km/h"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function()
      local vel = obj:getVelocity()
      local prevVel = obj.prevVelocity or vel
      obj.prevVelocity = vel
      return (vel:length() - prevVel:length()) * 3.6 / (settings.updatePeriod or 0.01)
    end,
    "Vehicle.Acceleration.Longitudinal",
    "Longitudinal acceleration",
    "m/s²"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.wheelspeed or 0 end,
    "Vehicle.AverageSpeed",
    "Average wheel speed",
    "km/h"
  )
end

local function addPowertrainSignals()
  local category = vssCategories.powertrain
  record[category] = {}
  local statID = 1
  
  -- Engine signals
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.rpm or 0 end,
    "Vehicle.Powertrain.CombustionEngine.Speed",
    "Engine RPM",
    "rpm"
  )
  
  updateDeviceStates()
  if devices and devices.mainEngine then
    statID = addStatToRecord(
      category,
      statID,
      function()
        return devices.mainEngine.thermals and devices.mainEngine.thermals.coolantTemperature or 0
      end,
      "Vehicle.Powertrain.CombustionEngine.ECT",
      "Engine coolant temperature",
      "celsius"
    )
    
    statID = addStatToRecord(
      category,
      statID,
      function()
        local thermals = devices.mainEngine.thermals
        return thermals and thermals.debugData and thermals.debugData.engineThermalData 
          and thermals.debugData.engineThermalData.oilTemperature or 0
      end,
      "Vehicle.Powertrain.CombustionEngine.EOT",
      "Engine oil temperature",
      "celsius"
    )
    
    statID = addStatToRecord(
      category,
      statID,
      function()
        return devices.mainEngine.engineLoad or 0
      end,
      "Vehicle.Powertrain.CombustionEngine.EngineLoadPercent",
      "Engine load",
      "percent"
    )
    
    statID = addStatToRecord(
      category,
      statID,
      function()
        return devices.mainEngine.lastOutputTorque or 0
      end,
      "Vehicle.Powertrain.CombustionEngine.Torque",
      "Engine torque",
      "Nm"
    )
    
    statID = addStatToRecord(
      category,
      statID,
      function()
        local rpm = electrics.values.rpm or 0
        local torque = devices.mainEngine.lastOutputTorque or 0
        return (rpm * torque * 2 * math.pi) / 60000 -- Convert to kW
      end,
      "Vehicle.Powertrain.CombustionEngine.Power",
      "Engine power",
      "kW"
    )
    
    statID = addStatToRecord(
      category,
      statID,
      function()
        return devices.mainEngine.hasFuel and 1 or 0
      end,
      "Vehicle.Powertrain.CombustionEngine.IsRunning",
      "Engine running status",
      "boolean"
    )
  end
  
  -- Transmission signals
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.gear or 0 end,
    "Vehicle.Powertrain.Transmission.CurrentGear",
    "Current gear",
    "gear"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.clutch or 0 end,
    "Vehicle.Powertrain.Transmission.ClutchEngagement",
    "Clutch engagement",
    "percent"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.gearIndex or 0 end,
    "Vehicle.Powertrain.Transmission.SelectedGear",
    "Selected gear",
    "gear"
  )
  
  -- Fuel system
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.fuel or 0 end,
    "Vehicle.Powertrain.FuelSystem.Level",
    "Fuel level",
    "percent"
  )
end

local function addChassisSignals()
  local category = vssCategories.chassis
  record[category] = {}
  local statID = 1
  
  -- Accelerator
  statID = addStatToRecord(
    category,
    statID,
    function() return (electrics.values.throttle or 0) * 100 end,
    "Vehicle.Chassis.Accelerator.PedalPosition",
    "Accelerator pedal position",
    "percent"
  )
  
  -- Brake
  statID = addStatToRecord(
    category,
    statID,
    function() return (electrics.values.brake or 0) * 100 end,
    "Vehicle.Chassis.Brake.PedalPosition",
    "Brake pedal position",
    "percent"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.parkingbrake or 0 end,
    "Vehicle.Chassis.ParkingBrake.IsEngaged",
    "Parking brake engaged",
    "boolean"
  )
  
  -- Steering
  statID = addStatToRecord(
    category,
    statID,
    function() return (electrics.values.steering or 0) * 450 end, -- normalized to degrees
    "Vehicle.Chassis.SteeringWheel.Angle",
    "Steering wheel angle",
    "degrees"
  )
  
  -- Axles and Wheels
  if wheels and wheels.wheels then
    local wheelNames = {
      [0] = {axle = 1, pos = "Left", name = "Front Left"},
      [1] = {axle = 1, pos = "Right", name = "Front Right"},
      [2] = {axle = 2, pos = "Left", name = "Rear Left"},
      [3] = {axle = 2, pos = "Right", name = "Rear Right"}
    }
    
    for i = 0, 3 do
      if wheels.wheels[i] then
        local wheel = wheelNames[i]
        local basePath = string.format("Vehicle.Chassis.Axle.Row%d.Wheel.%s", wheel.axle, wheel.pos)
        
        -- Wheel speed
        statID = addStatToRecord(
          category,
          statID,
          function() return (wheels.wheels[i].wheelSpeed or 0) * 3.6 end, -- m/s to km/h
          basePath .. ".Speed",
          wheel.name .. " speed",
          "km/h"
        )
        
        -- Tire temperature
        statID = addStatToRecord(
          category,
          statID,
          function() return wheels.wheels[i].tireAirTemperature or 0 end,
          basePath .. ".Tire.Temperature",
          wheel.name .. " tire temperature",
          "celsius"
        )
        
        -- Tire pressure (BeamNG doesn't expose this directly, so estimate from volume)
        statID = addStatToRecord(
          category,
          statID,
          function()
            local volume = wheels.wheels[i].tireVolume or 1
            local temp = wheels.wheels[i].tireAirTemperature or 293
            -- Rough estimation using ideal gas law (for simulation purposes)
            return (temp / 293) * 32 -- Assuming 32 PSI at 20°C
          end,
          basePath .. ".Tire.Pressure",
          wheel.name .. " tire pressure",
          "psi"
        )
        
        -- Tire deflated status
        statID = addStatToRecord(
          category,
          statID,
          function() return wheels.wheels[i].isTireDeflated and 1 or 0 end,
          basePath .. ".Tire.IsDeflated",
          wheel.name .. " tire deflated",
          "boolean"
        )
        
        -- Brake temperature
        statID = addStatToRecord(
          category,
          statID,
          function() return wheels.wheels[i].brakeCoreTemperature or 0 end,
          basePath .. ".Brake.Temperature",
          wheel.name .. " brake temperature",
          "celsius"
        )
        
        -- Brake pad wear (estimated from usage)
        statID = addStatToRecord(
          category,
          statID,
          function()
            local brakeMass = wheels.wheels[i].brakeMass or 1
            return (1 - (brakeMass / 10)) * 100 -- Rough wear percentage
          end,
          basePath .. ".Brake.PadWear",
          wheel.name .. " brake pad wear",
          "percent"
        )
      end
    end
  end
end

local function addBodySignals()
  local category = vssCategories.body
  record[category] = {}
  local statID = 1
  
  -- Lights
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.headlights or 0 end,
    "Vehicle.Body.Lights.IsLowBeamOn",
    "Low beam status",
    "boolean"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.highbeam or 0 end,
    "Vehicle.Body.Lights.IsHighBeamOn",
    "High beam status",
    "boolean"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.signal_L or 0 end,
    "Vehicle.Body.Lights.IsLeftIndicatorOn",
    "Left indicator status",
    "boolean"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.signal_R or 0 end,
    "Vehicle.Body.Lights.IsRightIndicatorOn",
    "Right indicator status",
    "boolean"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.hazard or 0 end,
    "Vehicle.Body.Lights.IsHazardOn",
    "Hazard lights status",
    "boolean"
  )
end

local function addCurrentLocationSignals()
  local category = vssCategories.currentLocation
  record[category] = {}
  local statID = 1
  
  statID = addStatToRecord(
    category,
    statID,
    function() return timeSinceStartOfLogging end,
    "Vehicle.CurrentLocation.Timestamp",
    "Timestamp",
    "seconds"
  )
  
  -- Position (BeamNG coordinates, not lat/lon)
  local pos = obj:getPosition()
  statID = addStatToRecord(
    category,
    statID,
    function() return obj:getPosition().x end,
    "Vehicle.CurrentLocation.Latitude",
    "Position X (latitude analog)",
    "meters"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return obj:getPosition().y end,
    "Vehicle.CurrentLocation.Longitude",
    "Position Y (longitude analog)",
    "meters"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return obj:getPosition().z end,
    "Vehicle.CurrentLocation.Altitude",
    "Position Z (altitude)",
    "meters"
  )
  
  -- Heading (yaw angle)
  statID = addStatToRecord(
    category,
    statID,
    function()
      local _, _, yaw = obj:getRollPitchYaw()
      return math.deg(yaw)
    end,
    "Vehicle.CurrentLocation.Heading",
    "Vehicle heading",
    "degrees"
  )
  
  -- Attitude
  statID = addStatToRecord(
    category,
    statID,
    function()
      local roll, _, _ = obj:getRollPitchYaw()
      return math.deg(roll)
    end,
    "Vehicle.CurrentLocation.Roll",
    "Vehicle roll",
    "degrees"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function()
      local _, pitch, _ = obj:getRollPitchYaw()
      return math.deg(pitch)
    end,
    "Vehicle.CurrentLocation.Pitch",
    "Vehicle pitch",
    "degrees"
  )
end

local function addOBDSignals()
  local category = vssCategories.obd
  record[category] = {}
  local statID = 1
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.check_engine or 0 end,
    "Vehicle.OBD.Status.MIL",
    "Malfunction Indicator Lamp",
    "boolean"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return 0 end, -- Would need to track DTCs
    "Vehicle.OBD.Status.DTCCount",
    "Diagnostic Trouble Code count",
    "count"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.odometer or 0 end,
    "Vehicle.OBD.OdometerReading",
    "Odometer reading",
    "km"
  )
end

-- Legacy BeamNG module definitions (for backwards compatibility)
local function addLegacyGeneralModule()
  local category = legacyModules.general
  legacyRecord[category] = {}
  local statID = 1
  
  statID = addStatToRecord(
    category,
    statID,
    function() return timeSinceStartOfLogging end,
    "time",
    "time",
    "seconds"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return obj:getPosition().x end,
    "posX",
    "vehicle x-position",
    "meters"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return obj:getPosition().y end,
    "posY",
    "vehicle y-position",
    "meters"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return obj:getPosition().z end,
    "posZ",
    "vehicle z-position",
    "meters"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return obj:getVelocity():length() end,
    "velocity",
    "velocity (m/s)",
    "m/s"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() return electrics.values.rpm or 0 end,
    "rpm",
    "revolutions per minute",
    "rpm"
  )
end

-- Initialize VSS record structure
local function initVssRecord()
  addVehicleSpeedSignals()
  addPowertrainSignals()
  addChassisSignals()
  addBodySignals()
  addCurrentLocationSignals()
  addOBDSignals()
end

-- Initialize legacy record structure
local function initLegacyRecord()
  addLegacyGeneralModule()
end

-- Build flat VSS data structure for JSONL/CSV
local function buildVssSnapshot()
  local snapshot = {
    timestamp = timeSinceStartOfLogging
  }
  
  for categoryName, categoryPath in pairs(vssCategories) do
    if settings.useCategory and settings.useCategory[categoryPath] then
      local categoryData = record[categoryPath]
      if categoryData then
        for _, signal in ipairs(categoryData) do
          if settings.useStat and settings.useStat[categoryPath] and 
             settings.useStat[categoryPath][signal.id] ~= false then
            
            local value = signal.get()
            if value ~= nil then
              snapshot[signal.vssPath] = value
            end
          end
        end
      end
    end
  end
  
  return snapshot
end

-- Get all VSS signal paths for CSV header
local function getVssSignalPaths()
  local paths = {"timestamp"} -- Always include timestamp first
  
  for categoryName, categoryPath in pairs(vssCategories) do
    if settings.useCategory and settings.useCategory[categoryPath] then
      local categoryData = record[categoryPath]
      if categoryData then
        for _, signal in ipairs(categoryData) do
          if settings.useStat and settings.useStat[categoryPath] and 
             settings.useStat[categoryPath][signal.id] ~= false then
            table.insert(paths, signal.vssPath)
          end
        end
      end
    end
  end
  
  return paths
end

-- CSV functions for legacy format
local function getStatValues(category)
  local line = "\n"
  local categoryData = legacyRecord[category]
  
  if not categoryData then
    return line
  end
  
  for _, stat in ipairs(categoryData) do
    if settings.useStat[category] and settings.useStat[category][stat.id] ~= false then
      line = line .. tostring(stat.get()) .. csvSeparator
    else
      line = line .. csvSeparator
    end
  end
  
  return line
end

local function getCSVHeader(category)
  local header = ""
  local categoryData = legacyRecord[category]
  
  if not categoryData then
    return header
  end
  
  for _, stat in ipairs(categoryData) do
    header = header .. stat.description .. csvSeparator
  end
  
  return header
end

-- Update functions
local function updateVssJsonlStream()
  local snapshot = buildVssSnapshot()
  local jsonLine = jsonEncode(snapshot)
  outputStreams.vss.txt = outputStreams.vss.txt .. jsonLine .. "\n"
  totalSamples = totalSamples + 1
end

local function updateVssCsvStream()
  local snapshot = buildVssSnapshot()
  local line = ""
  
  for _, path in ipairs(outputStreams.vss.signalPaths) do
    local value = snapshot[path] or ""
    line = line .. tostring(value) .. csvSeparator
  end
  
  outputStreams.vss.txt = outputStreams.vss.txt .. line .. "\n"
  totalSamples = totalSamples + 1
end

local function updateLegacyStreams()
  for _, category in pairs(legacyModules) do
    if settings.useModule and settings.useModule[category] then
      local output = getStatValues(category)
      outputStreams[category].txt = outputStreams[category].txt .. output
    end
  end
  totalSamples = totalSamples + 1
end

local function update()
  updateDeviceStates()
  
  if settings.format == "vss-jsonl" then
    updateVssJsonlStream()
  elseif settings.format == "vss-csv" then
    updateVssCsvStream()
  else
    updateLegacyStreams()
  end
end

-- Output functions
local function writeToFile(fpath, content, mode)
  mode = mode or "a"
  local fhandle = io.open(fpath, mode)
  if not fhandle then
    log("E", logTag, "failed to open file: " .. fpath)
    return false
  end
  fhandle:write(content)
  fhandle:close()
  return true
end

local function initVssJsonlOutput()
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local outputPath = settings.outputDir .. "/" .. timestamp
  local fpath = outputPath .. "/vss_data.jsonl"
  
  currentOutputFile = "vss_data.jsonl"
  
  outputStreams.vss = {
    txt = "",
    fpath = fpath
  }
  
  -- Write metadata as first line (comment-style)
  local metadata = {
    _metadata = true,
    version = settings.vssVersion,
    startTime = os.date("%Y-%m-%dT%H:%M:%S"),
    vehicle = v.data.model or "unknown", -- Fixed: use v.data instead of obj
    updatePeriod = settings.updatePeriod
  }
  writeToFile(fpath, jsonEncode(metadata) .. "\n", "w")
end

local function initVssCsvOutput()
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local outputPath = settings.outputDir .. "/" .. timestamp
  local fpath = outputPath .. "/vss_data.csv"
  
  currentOutputFile = "vss_data.csv"
  
  local signalPaths = getVssSignalPaths()
  outputStreams.vss = {
    txt = "",
    fpath = fpath,
    signalPaths = signalPaths
  }
  
  -- Write CSV header with metadata comment
  local metadataComment = string.format(
    "# VSS v%s | Start: %s | Vehicle: %s | Period: %s\n",
    settings.vssVersion,
    os.date("%Y-%m-%dT%H:%M:%S"),
    v.data.model or "unknown",
    settings.updatePeriod
  )
  writeToFile(fpath, metadataComment, "w")
  
  -- Write CSV header
  local header = table.concat(signalPaths, csvSeparator) .. "\n"
  writeToFile(fpath, header, "a")
end


local function initLegacyOutput()
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local outputPath = settings.outputDir .. "/" .. timestamp
  
  for _, category in pairs(legacyModules) do
    if settings.useModule[category] then
      local fpath = outputPath .. "/" .. category .. ".csv"
      outputStreams[category] = {
        txt = "",
        fpath = fpath
      }
      
      -- Write CSV header
      local header = getCSVHeader(category)
      writeToFile(fpath, header, "w")
    end
  end
  
  currentOutputFile = "multiple CSVs"
end

local function initOutput()
  if settings.format == "vss-jsonl" or settings.format == "vss" then
    initVssJsonlOutput()
  elseif settings.format == "vss-csv" then
    initVssCsvOutput()
  else
    initLegacyOutput()
  end
end

local function flushVssOutput()
  if not outputStreams.vss then return end
  
  local fpath = outputStreams.vss.fpath
  local txt = outputStreams.vss.txt
  
  if txt ~= "" then
    writeToFile(fpath, txt)
    log("D", logTag, "flushed " .. #txt .. " bytes to " .. fpath)
    outputStreams.vss.txt = ""
  end
end

local function flushLegacyOutput()
  for _, category in pairs(legacyModules) do
    if outputStreams[category] then
      local fpath = outputStreams[category].fpath
      local txt = outputStreams[category].txt
      if txt ~= "" then
        writeToFile(fpath, txt)
        outputStreams[category].txt = ""
      end
    end
  end
end

local function flushOutputStream()
  if settings.format == "vss-jsonl" or settings.format == "vss-csv" then
    flushVssOutput()
  else
    flushLegacyOutput()
  end
end

-- Settings functions
local function initSettings()
  settings.outputDir = "VSL"
  settings.updatePeriod = 0.01
  settings.format = "vss-jsonl"
  settings.vssVersion = "4.0"
  settings.includeTimestamp = true
  settings.includeMetadata = true
  settings.bufferSize = 1024
  
  -- VSS categories
  settings.useCategory = {}
  settings.useStat = {}
  
  for _, categoryPath in pairs(vssCategories) do
    settings.useCategory[categoryPath] = true
    settings.useStat[categoryPath] = {}
    
    if record[categoryPath] then
      for _, signal in ipairs(record[categoryPath]) do
        settings.useStat[categoryPath][signal.id] = true
      end
    end
  end
  
  -- Legacy modules
  settings.useModule = {}
  for _, category in pairs(legacyModules) do
    settings.useModule[category] = true
  end
end

-- Public API functions
local function onExtensionLoaded()
  initVssRecord()
  initLegacyRecord()
  initSettings()
  log("I", logTag, "BetterVSL extension loaded")
  guihooks.trigger("LoadedVehicleStatsLogger")
end

local function startLogging()
  log("I", logTag, "starting logging in " .. settings.format .. " format")
  
  if not settings.outputDir then
    log("E", logTag, "settings not initialized")
    initSettings()
  end
  
  doLogging = true
  timeSinceStartOfLogging = 0
  secUntilNextUpdate = 0
  stepsSinceLastFlush = 0
  totalSamples = 0
  
  initOutput()
end

local function stopLogging()
  log("I", logTag, "stopping logging - total samples: " .. totalSamples)
  doLogging = false
  flushOutputStream()
end

local function updateGFX(dt)
  if not doLogging then
    return
  end
  
  timeSinceStartOfLogging = timeSinceStartOfLogging + dt
  
  if secUntilNextUpdate <= 0 then
    secUntilNextUpdate = settings.updatePeriod
    update()
  else
    secUntilNextUpdate = secUntilNextUpdate - dt
  end
  
  -- Flush based on buffer size or sample count
  if stepsSinceLastFlush >= (settings.bufferSize or 1024) then
    flushOutputStream()
    stepsSinceLastFlush = 0
  else
    stepsSinceLastFlush = stepsSinceLastFlush + 1
  end
end

local function getStatus()
  return {
    time = timeSinceStartOfLogging,
    samples = totalSamples,
    filename = currentOutputFile,
    format = settings.format
  }
end

local function applySettingsFromJSON(fpath)
  log("I", logTag, "importing settings from: " .. fpath)
  local json = readFile(fpath)
  if not json then
    log("E", logTag, "failed to read settings file")
    return
  end
  
  local s = jsonDecode(json)
  if not s then
    log("E", logTag, "failed to parse settings JSON")
    return
  end
  
  if s.updatePeriod then settings.updatePeriod = s.updatePeriod end
  if s.outputDir then settings.outputDir = s.outputDir end
  if s.format then settings.format = s.format end
  if s.vssVersion then settings.vssVersion = s.vssVersion end
  if s.includeTimestamp ~= nil then settings.includeTimestamp = s.includeTimestamp end
  if s.includeMetadata ~= nil then settings.includeMetadata = s.includeMetadata end
  if s.bufferSize then settings.bufferSize = s.bufferSize end
  
  if s.useCategory then
    for category, enabled in pairs(s.useCategory) do
      settings.useCategory[category] = enabled
    end
  end
  
  if s.useModule then
    for module, enabled in pairs(s.useModule) do
      settings.useModule[module] = enabled
    end
  end
end

local function writeSettingsToJSON(fpath)
  log("I", logTag, "exporting settings to: " .. fpath)
  
  local s = {
    outputDir = settings.outputDir,
    updatePeriod = settings.updatePeriod,
    format = settings.format,
    vssVersion = settings.vssVersion,
    includeTimestamp = settings.includeTimestamp,
    includeMetadata = settings.includeMetadata,
    bufferSize = settings.bufferSize,
    useCategory = settings.useCategory,
    useModule = settings.useModule
  }
  
  if not jsonWriteFile(fpath, s, true, 0) then
    log("E", logTag, "failed writing settings to file")
  end
end

local function openOutputFolder()
  if FS and FS.openFolder then
    FS.openFolder(settings.outputDir)
  else
    log("W", logTag, "cannot open output folder - FS.openFolder not available")
  end
end

-- Public interface
M.settings = settings
M.record = record

M.onExtensionLoaded = onExtensionLoaded
M.updateGFX = updateGFX
M.startLogging = startLogging
M.stopLogging = stopLogging
M.getStatus = getStatus
M.applySettingsFromJSON = applySettingsFromJSON
M.writeSettingsToJSON = writeSettingsToJSON
M.openOutputFolder = openOutputFolder

return M