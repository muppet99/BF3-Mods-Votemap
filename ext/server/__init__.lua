require('__shared/version')

votingActive = false
playerVotes = {}
votingMaps = {}
orderedMaps = {}

config = {
    ['randomize'] = true,
    ['excludeCurrentMap'] = true,
    ['limit'] = 15
}

-- ── Map helpers ────────────────────────────────────────────────────────────

function getMapAmount(res, currentMapId)
    local mapAmount = 0
    local currentId = 1
    for index, name in pairs(res) do
        if index > 3 and index % 3 == 1 then
            if currentId ~= currentMapId or config.excludeCurrentMap == false then
                mapAmount = mapAmount + 1
            end
            currentId = currentId + 1
        end
    end
    return mapAmount
end

function getRandomMapIds(limitMapsEnabled, mapAmount, currentMapId)
    local randomMapIds = {}
    if limitMapsEnabled then
        print('Picking ' .. config.limit .. ' random maps out of ' .. mapAmount .. ', mapvote.excludeCurrentMap: ' .. tostring(config.excludeCurrentMap))
        local generatedMapCount = 0
        while generatedMapCount < config.limit do
            local notUnique = true
            while notUnique do
                notUnique = false
                randomMapId = (math.floor(math.random() * mapAmount)) + 1
                if randomMapIds[randomMapId] == true then
                    notUnique = true
                end
                if randomMapId == currentMapId and config.excludeCurrentMap == true then
                    notUnique = true
                end
            end
            randomMapIds[randomMapId] = true
            generatedMapCount = generatedMapCount + 1
        end
    elseif config.limit > 0 then
        print('Skip picking random maps: maplist too short (' .. mapAmount .. ') vs mapvote.limit (' .. config.limit .. ')')
    end
    return randomMapIds
end

-- Shuffle (thanks XeduR: https://gist.github.com/Uradamus/10323382#gistcomment-3149506)
function shuffle(t)
    local tbl = {}
    for i = 1, #t do tbl[i] = t[i] end
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

function getMaps()
    local mapIndices = RCON:SendCommand('mapList.getMapIndices')
    local currentMapId = tonumber(mapIndices[2]) + 1
    local res = RCON:SendCommand('mapList.List')

    local mapAmount = getMapAmount(res, currentMapId)
    local limitMapsEnabled = config.limit > 0 and mapAmount > config.limit
    local randomMapIds = getRandomMapIds(limitMapsEnabled, mapAmount, currentMapId)

    local mapList = {}
    local id = 1

    for index, name in pairs(res) do
        if index > 3 and index % 3 == 1 then
            local map = {
                id = id,
                name = name,
                gameMode = res[index + 1],
                rounds = res[index + 2],
                votes = 0,
                enabled = (id ~= currentMapId or config.excludeCurrentMap == false)
                          and (limitMapsEnabled == false or randomMapIds[id] == true)
            }
            orderedMaps[id] = map
            mapList[id] = map
            id = id + 1
        end
    end

    if config.randomize then
        print('mapvote.randomize true, shuffling maps')
        mapList = shuffle(mapList)
    end

    return mapList, orderedMaps
end

-- ── Vote logic ─────────────────────────────────────────────────────────────

function startVote()
    playerVotes = {}
    votingMaps, orderedMaps = getMaps()
    print('Starting mapvote')
    votingActive = true
    NetEvents:Broadcast('VotemapStart', votingMaps)
end

function endVote()
    if votingActive == false then return end

    votingActive = false

    local mostVotes = 0
    local nextMapId = nil
    for _, map in pairs(votingMaps) do
        if map.enabled and map.votes >= mostVotes then
            mostVotes = map.votes
            nextMapId = map.id
        end
    end

    local nextMap = orderedMaps[nextMapId]
    print('Voting result: ' .. nextMap.name .. ' ' .. nextMap.gameMode)

    setNextMap(nextMapId)
    NetEvents:Broadcast('VotemapEnd', nextMapId)
end

function setNextMap(mapId)
    RCON:SendCommand('mapList.setNextMapIndex', { ['index'] = tostring(mapId - 1) })
end

-- ── Player joins during active vote ───────────────────────────────────────

Events:Subscribe('Player:Authenticated', function(player)
    if votingActive then
        NetEvents:SendTo('VotemapStart', player, votingMaps)
    end
end)

-- ── Receive player vote ────────────────────────────────────────────────────

NetEvents:Subscribe('MapVote', function(player, mapId)
    mapId = tonumber(mapId)

    if playerVotes[player.name] ~= nil then
        local previousMapId = playerVotes[player.name]
        orderedMaps[previousMapId].votes = orderedMaps[previousMapId].votes - 1
    end

    playerVotes[player.name] = mapId
    orderedMaps[mapId].votes = orderedMaps[mapId].votes + 1
    print(player.name .. ' voted for ' .. orderedMaps[mapId].name)
    NetEvents:Broadcast('VotemapStatus', votingMaps)
end)

-- ── Vote countdown ─────────────────────────────────────────────────────────

currentVoteTime = 0
voteTime = 52

Events:Subscribe('Engine:Update', function(delta, simulationDelta)
    if votingActive == false then return end
    if currentVoteTime >= voteTime then
        endVote()
        currentVoteTime = 0
        return
    end
    currentVoteTime = currentVoteTime + delta
end)

-- ── Round end trigger ──────────────────────────────────────────────────────

function getRoundInfo()
    local getRounds = RCON:SendCommand('mapList.getRounds')
    local currentRound = tonumber(getRounds[2]) + 1
    local roundCount = tonumber(getRounds[3])
    return currentRound, roundCount
end

Events:Subscribe('Server:RoundOver', function(roundTime, winningTeam)
    local currentRound, roundCount = getRoundInfo()
    print('RoundOver: currentRound=' .. tostring(currentRound) .. ' roundCount=' .. tostring(roundCount))
    if currentRound == roundCount then
        startVote()
    end
end)

-- ── RCON commands ──────────────────────────────────────────────────────────

RCON:RegisterCommand('mapvote.start', RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
    startVote()
    return { 'OK' }
end)

RCON:RegisterCommand('mapvote.end', RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
    endVote()
    return { 'OK' }
end)

RCON:RegisterCommand('mapvote.limit', RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
    if args[1] ~= nil then
        config.limit = tonumber(args[1])
    end
    print(config.limit)
    return { 'OK' }
end)

RCON:RegisterCommand('mapvote.excludecurrentmap', RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
    if args[1] ~= nil then
        config.excludeCurrentMap = args[1] == 'true'
    end
    print(config.excludeCurrentMap)
    return { 'OK' }
end)

RCON:RegisterCommand('mapvote.randomize', RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
    if args[1] ~= nil then
        config.randomize = args[1] == 'true'
    end
    print(config.randomize)
    return { 'OK' }
end)

print('MapVote server loaded')
