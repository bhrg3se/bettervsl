using System;
using System.Collections.Generic;
namespace User.VSSLogger
{
    public static class VSSMappings
    {
        public static readonly Dictionary<string, string> Mapping = new Dictionary<string, string>
        {
            // Vehicle motion
            ["NewData.FilteredSpeedKmh"] = "Vehicle.Speed",
            ["NewData.FeedbackData.LocalVelocity.Forward"] = "Vehicle.Velocity.Longitudinal",
            ["NewData.FeedbackData.LocalVelocity.Lateral"] = "Vehicle.Velocity.Lateral",
            ["NewData.FeedbackData.LocalVelocity.Upward"] = "Vehicle.Velocity.Vertical",
            // Acceleration
            ["NewData.AccelerationSurge"] = "Vehicle.Acceleration.Longitudinal",
            ["NewData.AccelerationSway"] = "Vehicle.Acceleration.Lateral",
            ["NewData.AccelerationHeave"] = "Vehicle.Acceleration.Vertical",
            // Powertrain
            ["NewData.Rpms"] = "Vehicle.Powertrain.CombustionEngine.Speed",
            ["NewData.Gear"] = "Vehicle.Powertrain.Transmission.CurrentGear",
            ["NewData.Throttle"] = "Vehicle.Powertrain.AcceleratorPosition",
            ["NewData.Fuel"] = "Vehicle.Powertrain.FuelSystem.Level",
            ["NewData.WaterTemperature"] = "Vehicle.Powertrain.CombustionEngine.ECT",
            ["NewData.OilTemperature"] = "Vehicle.Powertrain.CombustionEngine.OilTemperature",
            ["NewData.OilPressure"] = "Vehicle.Powertrain.CombustionEngine.OilPressure",
            // Chassis
            ["NewData.Brake"] = "Vehicle.Chassis.Brake.PedalPosition",
            ["NewData.Clutch"] = "Vehicle.Chassis.Clutch.PedalPosition",
            // Orientation
            ["NewData.OrientationPitch"] = "Vehicle.AngularVelocity.Pitch",
            ["NewData.OrientationRoll"] = "Vehicle.AngularVelocity.Roll",
            ["NewData.OrientationYaw"] = "Vehicle.AngularVelocity.Yaw",
            // Wheels - Tire Pressure
            ["NewData.TyrePressureFrontLeft"] = "Vehicle.Chassis.Axle.Row1.Wheel.Left.Tire.Pressure",
            ["NewData.TyrePressureFrontRight"] = "Vehicle.Chassis.Axle.Row1.Wheel.Right.Tire.Pressure",
            ["NewData.TyrePressureRearLeft"] = "Vehicle.Chassis.Axle.Row2.Wheel.Left.Tire.Pressure",
            ["NewData.TyrePressureRearRight"] = "Vehicle.Chassis.Axle.Row2.Wheel.Right.Tire.Pressure",
            // Wheels - Tire Temperature
            ["NewData.TyreTemperatureFrontLeft"] = "Vehicle.Chassis.Axle.Row1.Wheel.Left.Tire.Temperature",
            ["NewData.TyreTemperatureFrontRight"] = "Vehicle.Chassis.Axle.Row1.Wheel.Right.Tire.Temperature",
            ["NewData.TyreTemperatureRearLeft"] = "Vehicle.Chassis.Axle.Row2.Wheel.Left.Tire.Temperature",
            ["NewData.TyreTemperatureRearRight"] = "Vehicle.Chassis.Axle.Row2.Wheel.Right.Tire.Temperature",
            // Brake Temperature
            ["NewData.BrakeTemperatureFrontLeft"] = "Vehicle.Chassis.Axle.Row1.Wheel.Left.Brake.Temperature",
            ["NewData.BrakeTemperatureFrontRight"] = "Vehicle.Chassis.Axle.Row1.Wheel.Right.Brake.Temperature",
            ["NewData.BrakeTemperatureRearLeft"] = "Vehicle.Chassis.Axle.Row2.Wheel.Left.Brake.Temperature",
            ["NewData.BrakeTemperatureRearRight"] = "Vehicle.Chassis.Axle.Row2.Wheel.Right.Brake.Temperature"
        };
    }
}