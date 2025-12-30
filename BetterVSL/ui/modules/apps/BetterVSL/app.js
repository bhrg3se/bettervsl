angular.module('beamng.apps')
.directive('bettervsl', [function () {
  return {
    templateUrl: '/ui/modules/apps/BetterVSL/app.html',
    replace: true,
    restrict: 'EA',
    link: function (scope, element, attrs) {
      // Default settings
      scope.updateTime = 0.01
      scope.outputFormat = 'vss-jsonl'
      scope.vssVersion = '4.0'
      
      // VSS Categories
      scope.vss_speed = true
      scope.vss_powertrain = true
      scope.vss_chassis = true
      scope.vss_body = false
      scope.vss_location = true
      scope.vss_obd = false
      
      // Legacy BeamNG modules
      scope.module_general = true
      scope.module_wheels = true
      scope.module_engine = true
      scope.module_inputs = true
      scope.module_powertrain = true
      
      // Advanced options
      scope.showAdvanced = false
      scope.includeTimestamp = true
      scope.includeMetadata = true
      scope.compressOutput = false
      scope.bufferSize = 1024
      
      // Status
      scope.isLogging = false
      scope.loggingTime = 0
      scope.samplesCollected = 0
      scope.currentFile = ''

      // Apply settings to Lua
      scope.applySettings = function() {
        bngApi.activeObjectLua(`extensions.bettervsl.settings.updatePeriod = ${scope.updateTime}`)
        bngApi.activeObjectLua(`extensions.bettervsl.settings.format = "${scope.outputFormat}"`)
        bngApi.activeObjectLua(`extensions.bettervsl.settings.vssVersion = "${scope.vssVersion}"`)
        
        if (scope.outputFormat === 'vss') {
          // VSS categories
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useCategory["Vehicle.Speed"] = ${scope.vss_speed}`)
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useCategory["Vehicle.Powertrain"] = ${scope.vss_powertrain}`)
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useCategory["Vehicle.Chassis"] = ${scope.vss_chassis}`)
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useCategory["Vehicle.Body"] = ${scope.vss_body}`)
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useCategory["Vehicle.CurrentLocation"] = ${scope.vss_location}`)
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useCategory["Vehicle.OBD"] = ${scope.vss_obd}`)
        } else {
          // Legacy modules
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useModule["General"] = ${scope.module_general}`)
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useModule["Wheels"] = ${scope.module_wheels}`)
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useModule["Engine"] = ${scope.module_engine}`)
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useModule["Inputs"] = ${scope.module_inputs}`)
          bngApi.activeObjectLua(`extensions.bettervsl.settings.useModule["Powertrain"] = ${scope.module_powertrain}`)
        }
        
        // Advanced options
        bngApi.activeObjectLua(`extensions.bettervsl.settings.includeTimestamp = ${scope.includeTimestamp}`)
        bngApi.activeObjectLua(`extensions.bettervsl.settings.includeMetadata = ${scope.includeMetadata}`)
        bngApi.activeObjectLua(`extensions.bettervsl.settings.compressOutput = ${scope.compressOutput}`)
        bngApi.activeObjectLua(`extensions.bettervsl.settings.bufferSize = ${scope.bufferSize}`)
      }

      scope.startLogging = function() {
        scope.applySettings()
        scope.isLogging = true
        scope.loggingTime = 0
        scope.samplesCollected = 0
        bngApi.activeObjectLua(`extensions.bettervsl.startLogging()`)
        
        // Start status update timer
        scope.statusTimer = setInterval(function() {
          bngApi.activeObjectLua(`extensions.bettervsl.getStatus()`, function(data) {
            scope.$apply(function() {
              scope.loggingTime = data.time.toFixed(2)
              scope.samplesCollected = data.samples
              scope.currentFile = data.filename
            })
          })
        }, 500)
      }

      scope.stopLogging = function() {
        scope.isLogging = false
        if (scope.statusTimer) {
          clearInterval(scope.statusTimer)
        }
        bngApi.activeObjectLua(`extensions.bettervsl.stopLogging()`)
      }

      scope.exportSettings = function() {
        let timestamp = new Date().toISOString().replace(/:/g, '-').split('.')[0]
        let filename = `vss_config_${timestamp}.json`
        bngApi.activeObjectLua(`extensions.bettervsl.writeSettingsToJSON("${filename}")`)
      }

      scope.importSettings = function() {
        // Trigger file picker or use default
        bngApi.activeObjectLua(`extensions.bettervsl.applySettingsFromJSON("vss_config.json")`)
      }

      scope.openOutputFolder = function() {
        bngApi.activeObjectLua(`extensions.bettervsl.openOutputFolder()`)
      }

      // Cleanup
      scope.$on('$destroy', function() {
        if (scope.statusTimer) {
          clearInterval(scope.statusTimer)
        }
      })
    }
  }
}]);