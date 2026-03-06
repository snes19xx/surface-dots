import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib

Lib.Card {
  id: root
  signal closeRequested()
  property bool active: true
  
  // Fetch upcoming events (including currently happening)
  Lib.CommandPoll {
    id: calEvent
    running: root.active
    interval: 60000
    command: ["bash", "-lc", "khal list today 7d --format '{start-date}::{title}::{start-time}-{end-time}::{location}' 2>/dev/null || true"]
    parse: function(out) {
      var lines = String(out).split("\n")
      var events = []
      var now = new Date()
      
      // Change the loop count to the number of events you want
      for (var i = 0; i < lines.length && events.length < 1; i++) {
        var line = lines[i].trim()
        if (line.indexOf("::") !== -1) {
          var parts = line.split("::")
          var dateStr = parts[0] || ""
          var timeStr = parts[2] || ""
          
          // Check if event has ended
          var hasEnded = false
          if (dateStr && timeStr.indexOf("-") !== -1) {
            var endTime = timeStr.split("-")[1].trim()
            
            // Parse date
            var dateParts = dateStr.split("-")
            if (dateParts.length === 3) {
              var year = parseInt(dateParts[0])
              var month = parseInt(dateParts[1]) - 1
              var day = parseInt(dateParts[2])
              var eventDate = new Date(year, month, day)
              
              // Parse end time (format: HH:MM AM/PM)
              var timeParts = endTime.match(/(\d+):(\d+)\s*(AM|PM)/i)
              if (timeParts) {
                var hours = parseInt(timeParts[1])
                var minutes = parseInt(timeParts[2])
                var isPM = timeParts[3].toUpperCase() === "PM"
                
                if (isPM && hours !== 12) hours += 12
                if (!isPM && hours === 12) hours = 0
                
                eventDate.setHours(hours, minutes, 0, 0)
                
                // Skip if event has already ended
                if (eventDate <= now) {
                  hasEnded = true
                }
              }
            }
          }
          
          if (!hasEnded) {
            // Extract day of week from date
            var dayName = ""
            if (dateStr) {
              var dateParts = dateStr.split("-")
              if (dateParts.length === 3) {
                var year = parseInt(dateParts[0])
                var month = parseInt(dateParts[1]) - 1
                var day = parseInt(dateParts[2])
                var d = new Date(year, month, day)
                var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                dayName = days[d.getDay()]
              }
            }
            
            var loc = parts[3] ? parts[3].trim() : ""
            events.push({
              day: dayName,
              title: parts[1] || "Untitled",
              time: parts[2] || "",
              location: loc
            })
          }
        }
      }
      return events
    }
  }
  
  property bool hasEvents: calEvent.value && calEvent.value.length > 0
  
  Layout.preferredHeight: hasEvents ? implicitHeight : 0
  visible: hasEvents
  clip: true
  

  ColumnLayout {
    id: content
    anchors.fill: parent
    spacing: 8
    
    
    // Header: "Upcoming"
    Text {
      text: "Upcoming"
      font.family: theme.textFont
      font.pixelSize: 13
      font.weight: 700
      color: (root.theme ? root.theme.textPrimary : Theme.fgMain)
    }
    
    // Events list
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 8
      
      Repeater {
        model: calEvent.value
        
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 8
          
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            // Day indicator 
            Text {
              text: modelData.day
              font.family: Theme.textFont
              font.pixelSize: 14
              font.weight: 600
              color: (root.theme ? root.theme.accent : theme.accent)
              Layout.alignment: Qt.AlignVCenter
            }
            
            // Event details - single row
            RowLayout {
              Layout.fillWidth: true
              spacing: 8
              
              Text {
                text: modelData.title
                font.family: theme.textFont
                font.pixelSize: 14
                font.weight: 600
                color: (root.theme ? root.theme.textPrimary : theme.fgMain)
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
              
              Text {
                text: {
                  var result = ""
                  var timeStr = modelData.time
                  if (timeStr.indexOf("-") !== -1) {
                    var times = timeStr.split("-")
                    result = times[0].trim() + " - " + times[1].trim()
                  } else {
                    result = timeStr
                  }
                  if (modelData.location && modelData.location !== "") {
                    var loc = modelData.location
                    if (loc.length > 13) {
                      loc = loc.substring(0, 13)
                    }
                    result += " • " + loc
                  }
                  return result
                }
                font.family: theme.textFont
                font.pixelSize: 12
                font.weight: 400
                color: (root.theme ? root.theme.textSecondary : theme.fgMuted)
                opacity: 0.7
                elide: Text.ElideRight
              }
            }
          }
          /*
          // Divider (between events)
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 4
            color: (root.theme ? root.theme.border : Theme.border)
            opacity: 0.3
            visible: index < calEvent.value.length - 1
          }
          */
        }
      }
    }
  }
  
  // Click to open calendar
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      Quickshell.execDetached(["bash", "-lc", "/opt/evercal/ever_cal"])
      root.closeRequested()
    }
  }
}
