-- Add items to existing profiles or create your own to sell groups of items using alias commands
local profiles = {}

-- //sellnpc powder
profiles['powder'] = S{
    'prize powder',
    }

-- //sellnpc ore
profiles['ore'] = S{
    'iron ore',
    'copper ore',
    'tin ore',
    }

-- //sellnpc junk
profiles['junk'] = S{
    'chestnut',
    'san d\'Or. carrot',
    }

-- //sellnpc crawlersnest
profiles['crawlersnest'] = S{
    'Silk Thread',
    'Crawler Cocoon',
    'Insect Wing',
    'Beetle Jaw',
    'Beetle Shell',
    'Flame Geode',
    'Snow Geode',
    'Breeze Geode',
    'Fenrite',
    'Ifritite',
    'Ramuite',
    'Titanite',
    'Leviatite',
    'Shivite',
    'Carbite',
    'Crawler Egg'
}

return profiles
