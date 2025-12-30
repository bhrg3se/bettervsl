-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = 'bettervsl'

-- VSS Categories
local vssCategories = {
  speed = "Vehicle.Speed",
  powertrain = "Vehicle.Powertrain",
  chassis = "Vehicle.Chassis",
  body = "Vehicle.Body",
  currentLocation = "Vehicle.CurrentLocation",
  obd = "Vehicle.OBD"
}

-- Legacy BeamNG modules
local legacyModules = {
  general = "General",
  wheels = "Wheels",
  inputs = "Inputs",
  engine = "Engine",
  powertrain = "Powertrain"
}

local record = {}
local legacyRecord = {}
local outputStreams = {}
local settings = {}

local doLogging = false
local timeSinceStartOfLogging = 0
local secUntilNextUpdate = 0
local stepsSinceLastFlush = 0
local totalSamples = 0
local csvSeparator = ","
local currentOutputFile = ""

local devices = nil

local function updateDeviceStates()
  devices = powertrain and powertrain.getDevices() or nil
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
    function() 
      return obj and obj:getVelocity():length() * 3.6 or 0
    end,
    "Vehicle.Speed",
    "Vehicle speed",
    "km/h"
  )
end

local function addPowertrainSignals()
  local category = vssCategories.powertrain
  record[category] = {}
  local statID = 1
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return electrics and electrics.values.rpm or 0 
    end,
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
        local eng = devices.mainEngine
        return eng.thermals and eng.thermals.coolantTemperature or 0
      end,
      "Vehicle.Powertrain.CombustionEngine.ECT",
      "Engine coolant temperature",
      "celsius"
    )
    
    statID = addStatToRecord(
      category,
      statID,
      function()
        local eng = devices.mainEngine
        return eng.engineLoad or 0
      end,
      "Vehicle.Powertrain.CombustionEngine.EngineLoadPercent",
      "Engine load",
      "percent"
    )
  end
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return electrics and electrics.values.gear or 0 
    end,
    "Vehicle.Powertrain.Transmission.CurrentGear",
    "Current gear",
    "gear"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return electrics and electrics.values.fuel or 0 
    end,
    "Vehicle.Powertrain.FuelSystem.Level",
    "Fuel level",
    "percent"
  )
end

local function addChassisSignals()
  local category = vssCategories.chassis
  record[category] = {}
  local statID = 1
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return electrics and (electrics.values.throttle or 0) * 100 or 0
    end,
    "Vehicle.Chassis.Accelerator.PedalPosition",
    "Accelerator pedal position",
    "percent"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return electrics and (electrics.values.brake or 0) * 100 or 0
    end,
    "Vehicle.Chassis.Brake.PedalPosition",
    "Brake pedal position",
    "percent"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return electrics and (electrics.values.steering or 0) * 450 or 0
    end,
    "Vehicle.Chassis.SteeringWheel.Angle",
    "Steering wheel angle",
    "degrees"
  )
  
  -- Wheels
  if wheels and wheels.wheels then
    local wheelNames = {
      [0] = {axle = 1, pos = "Left"},
      [1] = {axle = 1, pos = "Right"},
      [2] = {axle = 2, pos = "Left"},
      [3] = {axle = 2, pos = "Right"}
    }
    
    for i = 0, 3 do
      if wheels.wheels[i] then
        local wheel = wheelNames[i]
        local basePath = string.format("Vehicle.Chassis.Axle.Row%d.Wheel.%s", wheel.axle, wheel.pos)
        
        statID = addStatToRecord(
          category,
          statID,
          function() 
            return wheels.wheels[i] and (wheels.wheels[i].wheelSpeed or 0) * 3.6 or 0
          end,
          basePath .. ".Speed",
          "Wheel speed",
          "km/h"
        )
        
        statID = addStatToRecord(
          category,
          statID,
          function() 
            return wheels.wheels[i] and wheels.wheels[i].tireAirTemperature or 0
          end,
          basePath .. ".Tire.Temperature",
          "Tire temperature",
          "celsius"
        )
        
        statID = addStatToRecord(
          category,
          statID,
          function() 
            return wheels.wheels[i] and wheels.wheels[i].brakeCoreTemperature or 0
          end,
          basePath .. ".Brake.Temperature",
          "Brake temperature",
          "celsius"
        )
      end
    end
  end
end

local function addBodySignals()
  local category = vssCategories.body
  record[category] = {}
  local statID = 1
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return electrics and electrics.values.headlights or 0 
    end,
    "Vehicle.Body.Lights.IsLowBeamOn",
    "Low beam status",
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
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return obj and obj:getPosition().x or 0
    end,
    "Vehicle.CurrentLocation.Latitude",
    "Position X",
    "meters"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return obj and obj:getPosition().y or 0
    end,
    "Vehicle.CurrentLocation.Longitude",
    "Position Y",
    "meters"
  )
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return obj and obj:getPosition().z or 0
    end,
    "Vehicle.CurrentLocation.Altitude",
    "Position Z",
    "meters"
  )
end

local function addOBDSignals()
  local category = vssCategories.obd
  record[category] = {}
  local statID = 1
  
  statID = addStatToRecord(
    category,
    statID,
    function() 
      return electrics and electrics.values.odometer or 0 
    end,
    "Vehicle.OBD.OdometerReading",
    "Odometer reading",
    "km"
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

-- Build flat VSS data structure for JSONL/CSV
local function buildVssSnapshot()
  local snapshot = {
    timestamp = timeSinceStartOfLogging
  }
  
  for _, categoryPath in pairs(vssCategories) do
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
  local paths = {"timestamp"}
  
  for _, categoryPath in pairs(vssCategories) do
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

local function update()
  updateDeviceStates()
  
  if settings.format == "vss-jsonl" or settings.format == "vss" then
    updateVssJsonlStream()
  elseif settings.format == "vss-csv" then
    updateVssCsvStream()
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
  
  -- Write metadata as first line
  local metadata = {
    _metadata = true,
    version = settings.vssVersion,
    startTime = os.date("%Y-%m-%dT%H:%M:%S"),
    vehicle = (v and v.data and v.data.model) or "unknown",
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
  
  -- Write metadata comment
  local metadataComment = string.format(
    "# VSS v%s | Start: %s | Vehicle: %s | Period: %s\n",
    settings.vssVersion,
    os.date("%Y-%m-%dT%H:%M:%S"),
    (v and v.data and v.data.model) or "unknown",
    settings.updatePeriod
  )
  writeToFile(fpath, metadataComment, "w")
  
  -- Write CSV header
  local header = table.concat(signalPaths, csvSeparator) .. "\n"
  writeToFile(fpath, header, "a")
end

local function initOutput()
  if settings.format == "vss-jsonl" or settings.format == "vss" then
    initVssJsonlOutput()
  elseif settings.format == "vss-csv" then
    initVssCsvOutput()
  end
end

local function flushVssOutput()
  if not outputStreams.vss then return end
  
  local fpath = outputStreams.vss.fpath
  local txt = outputStreams.vss.txt
  
  if txt ~= "" then
    writeToFile(fpath, txt)
    outputStreams.vss.txt = ""
  end
end

local function flushOutputStream()
  if settings.format == "vss-jsonl" or settings.format == "vss-csv" or settings.format == "vss" then
    flushVssOutput()
  end
end

-- Settings functions
local function initSettings()
  settings.outputDir = "VSL"
  settings.updatePeriod = 0.01
  settings.format = "vss-jsonl"
  settings.vssVersion = "4.0"
  settings.bufferSize = 1024
  
  settings.useCategory = {}
  settings.useStat = {}
  
  for _, categoryPath in pairs(vssCategories) do
    settings.useCategory[categoryPath] = true
    settings.useStat[categoryPath] = {}
  end
end

-- Public API
local function onExtensionLoaded()
  initVssRecord()
  initSettings()
  log("I", logTag, "BetterVSL extension loaded")
  guihooks.trigger("LoadedVehicleStatsLogger")
end

local function startLogging()
  log("I", logTag, "starting logging in " .. settings.format .. " format")
  
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
  if not doLogging then return end
  
  timeSinceStartOfLogging = timeSinceStartOfLogging + dt
  
  if secUntilNextUpdate <= 0 then
    secUntilNextUpdate = settings.updatePeriod
    update()
  else
    secUntilNextUpdate = secUntilNextUpdate - dt
  end
  
  if stepsSinceLastFlush >= settings.bufferSize then
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

-- Public interface
M.settings = settings
M.onExtensionLoaded = onExtensionLoaded
M.updateGFX = updateGFX
M.startLogging = startLogging
M.stopLogging = stopLogging
M.getStatus = getStatus

return M