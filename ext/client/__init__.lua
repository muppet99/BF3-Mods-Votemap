Events:Subscribe('Extension:Loaded', function()
  WebUI:Init()
  WebUI:Show()
end)

Events:Subscribe('MapVote', function(votedMapId)
  NetEvents:Send('MapVote', votedMapId)
end)

Events:Subscribe('Client:UpdateInput', function(data)
  if InputManager:WentKeyDown(InputDeviceKeys.IDK_F1) then
    WebUI:ExecuteJS('f1Pressed();')
  end
end)

NetEvents:Subscribe('VotemapStart', function(maps)
  WebUI:ExecuteJS('VotemapStart(' .. json.encode(maps) .. ');')
end)

NetEvents:Subscribe('VotemapEnd', function(nextMapId)
  WebUI:ExecuteJS('VotemapEnd("' .. nextMapId .. '");')
end)

NetEvents:Subscribe('VotemapStatus', function(maps)
  WebUI:ExecuteJS('VotemapStatus(' .. json.encode(maps) .. ');')
end)
