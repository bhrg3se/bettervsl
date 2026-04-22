# VSS Telemetry Logger for SimHub

Simple plugin that logs telemetry data in CSV format for research purposes.

## Setup

1. Set `SIMHUB_INSTALL_PATH` environment variable to your SimHub installation (e.g., `C:\Program Files (x86)\SimHub\`)

2. Open `User.VSSLogger.csproj` in Visual Studio

3. Build the project (it will auto-copy to SimHub directory)

4. Restart SimHub

## Configuration (hardcoded defaults)

- **Output**: `C:\SimHub\Logs\vss_telemetry.csv`
- **Sample rate**: Every 10th frame (~6Hz)
- **Auto-starts**: Begins logging when game is running

## CSV Columns (placeholder VSS mapping)

```
Timestamp,Speed,RPM,Throttle,Brake,Clutch,Gear,SteeringAngle
```

## Next Steps

Replace the placeholder mapping in `DataUpdate()` with actual VSS signal paths from your schema.
