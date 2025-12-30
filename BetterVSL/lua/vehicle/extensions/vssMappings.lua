-- vssMapping.lua
-- Maps BeamNG internal signal names to VSS (Vehicle Signal Specification) paths
-- VSS spec: https://covesa.github.io/vehicle_signal_specification/

local M = {}

-- General module mappings
M.general = {
  time = "Vehicle.CurrentLocation.Timestamp",
  ["vehicle x-position"] = "Vehicle.CurrentLocation.Longitude",
  ["vehicle y-position"] = "Vehicle.CurrentLocation.Latitude", 
  ["vehicle z-position"] = "Vehicle.CurrentLocation.Altitude",
  velocity = "Vehicle.Speed",
  rpm = "Vehicle.Powertrain.CombustionEngine.Speed",
  roll = "Vehicle.AngularVelocity.Roll",
  pitch = "Vehicle.AngularVelocity.Pitch",
  yaw = "Vehicle.AngularVelocity.Yaw",
  waterTemperature = "Vehicle.Powertrain.CombustionEngine.ECT",
  steeringWheelPosition = "Vehicle.Chassis.SteeringWheel.Angle",
  throttle = "Vehicle.Chassis.Accelerator.PedalPosition",
  brake = "Vehicle.Chassis.Brake.PedalPosition",
  clutch = "Vehicle.Powertrain.Transmission.ClutchEngagement",
  airspeed = "Vehicle.Speed",
  airflowSpeed = "Vehicle.Exterior.AirTemperature",
  altitude = "Vehicle.CurrentLocation.Altitude",
  reverse = "Vehicle.Powertrain.Transmission.CurrentGear"
}

-- Wheels module mappings
M.wheels = {
  time = "Vehicle.CurrentLocation.Timestamp",
  avgWheelAV = "Vehicle.Chassis.Axle.Row1.Wheel.Left.AngularSpeed",
  
  -- Wheel-specific mappings (format strings for indexed wheels)
  -- Row1 = front axle, Row2 = rear axle
  -- Left/Right based on driver perspective
  wheelSpeed = {
    [0] = "Vehicle.Chassis.Axle.Row1.Wheel.Left.Speed",
    [1] = "Vehicle.Chassis.Axle.Row1.Wheel.Right.Speed",
    [2] = "Vehicle.Chassis.Axle.Row2.Wheel.Left.Speed",
    [3] = "Vehicle.Chassis.Axle.Row2.Wheel.Right.Speed"
  },
  angularVelocity = {
    [0] = "Vehicle.Chassis.Axle.Row1.Wheel.Left.AngularSpeed",
    [1] = "Vehicle.Chassis.Axle.Row1.Wheel.Right.AngularSpeed",
    [2] = "Vehicle.Chassis.Axle.Row2.Wheel.Left.AngularSpeed",
    [3] = "Vehicle.Chassis.Axle.Row2.Wheel.Right.AngularSpeed"
  },
  isBroken = {
    [0] = "Vehicle.Chassis.Axle.Row1.Wheel.Left.Brake.IsBrakesWorn",
    [1] = "Vehicle.Chassis.Axle.Row1.Wheel.Right.Brake.IsBrakesWorn",
    [2] = "Vehicle.Chassis.Axle.Row2.Wheel.Left.Brake.IsBrakesWorn",
    [3] = "Vehicle.Chassis.Axle.Row2.Wheel.Right.Brake.IsBrakesWorn"
  },
  brakeCoreTemperature = {
    [0] = "Vehicle.Chassis.Axle.Row1.Wheel.Left.Brake.Temperature",
    [1] = "Vehicle.Chassis.Axle.Row1.Wheel.Right.Brake.Temperature",
    [2] = "Vehicle.Chassis.Axle.Row2.Wheel.Left.Brake.Temperature",
    [3] = "Vehicle.Chassis.Axle.Row2.Wheel.Right.Brake.Temperature"
  },
  tirePressure = {
    [0] = "Vehicle.Chassis.Axle.Row1.Wheel.Left.Tire.Pressure",
    [1] = "Vehicle.Chassis.Axle.Row1.Wheel.Right.Tire.Pressure",
    [2] = "Vehicle.Chassis.Axle.Row2.Wheel.Left.Tire.Pressure",
    [3] = "Vehicle.Chassis.Axle.Row2.Wheel.Right.Tire.Pressure"
  },
  tireTemperature = {
    [0] = "Vehicle.Chassis.Axle.Row1.Wheel.Left.Tire.Temperature",
    [1] = "Vehicle.Chassis.Axle.Row1.Wheel.Right.Tire.Temperature",
    [2] = "Vehicle.Chassis.Axle.Row2.Wheel.Left.Tire.Temperature",
    [3] = "Vehicle.Chassis.Axle.Row2.Wheel.Right.Tire.Temperature"
  }
}

-- Engine module mappings
M.engine = {
  time = "Vehicle.CurrentLocation.Timestamp",
  engineLoad = "Vehicle.Powertrain.CombustionEngine.Power",
  outputTorque = "Vehicle.Powertrain.CombustionEngine.Torque",
  rpm = "Vehicle.Powertrain.CombustionEngine.Speed",
  isRunning = "Vehicle.Powertrain.CombustionEngine.IsRunning",
  
  -- Thermals
  coolantTemperature = "Vehicle.Powertrain.CombustionEngine.ECT",
  oilTemperature = "Vehicle.Powertrain.CombustionEngine.EOT",
  oilPressure = "Vehicle.Powertrain.CombustionEngine.EOP",
  
  -- Engine state
  hasFuel = "Vehicle.Powertrain.FuelSystem.RelativeLevel"
}

-- Inputs module mappings
M.inputs = {
  time = "Vehicle.CurrentLocation.Timestamp",
  throttle = "Vehicle.Chassis.Accelerator.PedalPosition",
  steering = "Vehicle.Chassis.SteeringWheel.Angle",
  clutch = "Vehicle.Powertrain.Transmission.ClutchEngagement",
  parkingbrake = "Vehicle.Chassis.ParkingBrake.IsEngaged",
  brake = "Vehicle.Chassis.Brake.PedalPosition"
}

-- Powertrain module mappings
M.powertrain = {
  time = "Vehicle.CurrentLocation.Timestamp",
  currentGear = "Vehicle.Powertrain.Transmission.CurrentGear",
  selectedGear = "Vehicle.Powertrain.Transmission.SelectedGear",
  transmissionTemperature = "Vehicle.Powertrain.Transmission.Temperature",
  clutchWear = "Vehicle.Powertrain.Transmission.ClutchWear",
  
  -- Drive type and mode
  driveType = "Vehicle.Powertrain.Transmission.DriveType",
  performanceMode = "Vehicle.Powertrain.Transmission.PerformanceMode"
}

-- Helper function to get VSS path for a BeamNG signal
-- @param module: module name (e.g., "general", "wheels")
-- @param signal: signal name from BeamNG
-- @param wheelIndex: optional wheel index for wheel-specific signals (0-3)
-- @return VSS path string or nil if not found
function M.getVssPath(module, signal, wheelIndex)
  local moduleMap = M[module]
  if not moduleMap then
    return nil
  end
  
  local mapping = moduleMap[signal]
  if not mapping then
    return nil
  end
  
  -- Handle indexed wheel signals
  if type(mapping) == "table" and wheelIndex ~= nil then
    return mapping[wheelIndex]
  end
  
  return mapping
end

-- Helper function to check if a module has VSS mappings
-- @param module: module name to check
-- @return boolean
function M.hasModule(module)
  return M[module] ~= nil
end

return M