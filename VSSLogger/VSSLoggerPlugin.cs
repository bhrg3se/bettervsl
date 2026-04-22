using GameReaderCommon;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using SimHub.Plugins;
using System;
using System.Collections.Generic;
using System.IO;




namespace User.VSSLogger
{
    [PluginDescription("Logs telemetry data in VSS format for research")]
    [PluginAuthor("Bhargab Acharya")]
    [PluginName("VSS Telemetry Logger")]
    public class VSSLoggerPlugin : IPlugin, IDataPlugin
    {
        private StreamWriter _logWriter;
        private bool _isLogging = false;
        private string _outputPath = $@"C:\SimHub\Logs\vss_telemetry_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
        private int _sampleCounter = 0;
        private int _sampleRate = 10; // Log every 10th update (~6Hz if SimHub runs at 60Hz)

        public PluginManager PluginManager { get; set; }

        public void Init(PluginManager pluginManager)
        {
            SimHub.Logging.Current.Info("VSS Logger: Initializing");
            
            // Ensure output directory exists
            Directory.CreateDirectory(Path.GetDirectoryName(_outputPath));
            
            // Start logging automatically
            StartLogging();
        }
        public void DataUpdate(PluginManager pluginManager, ref GameData data)
        {
            if (!_isLogging || !data.GameRunning || data.NewData == null)
                return;

            // Sample rate throttling
            _sampleCounter++;
            if (_sampleCounter < _sampleRate)
                return;

            _sampleCounter = 0;

            try
            {
                long timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

                // Parse data object to JObject for nested property access
                var jObject = JObject.FromObject(data);

                var vssValues = new List<string> { timestamp.ToString() };

                // Extract values using the mapping
                foreach (var mapping in VSSMappings.Mapping)
                {
                    var token = jObject.SelectToken(mapping.Key);
                    vssValues.Add(token?.ToString() ?? "");
                }

                string csvLine = string.Join(",", vssValues);
                _logWriter.WriteLine(csvLine);
            }
            catch (Exception ex)
            {
                SimHub.Logging.Current.Error("VSS Logger error: " + ex.Message);
            }
        }

        public void End(PluginManager pluginManager)
        {
            StopLogging();
            SimHub.Logging.Current.Info("VSS Logger: Stopped");
        }

        private void StartLogging()
        {
            if (_isLogging)
                return;

            try
            {
                _logWriter = new StreamWriter(_outputPath, append: false);

                // CSV Header with VSS signal paths
                var headers = new List<string> { "Timestamp" };
                headers.AddRange(VSSMappings.Mapping.Values);

                _logWriter.WriteLine(string.Join(",", headers));

                _isLogging = true;
                SimHub.Logging.Current.Info("VSS Logger: Started logging to " + _outputPath);
            }
            catch (Exception ex)
            {
                SimHub.Logging.Current.Error("VSS Logger failed to start: " + ex.Message);
            }
        }

        private void StopLogging()
        {
            if (!_isLogging)
                return;

            _isLogging = false;
            _logWriter?.Flush();
            _logWriter?.Close();
            _logWriter = null;
        }
    }
}
