# Description:
#   Tools for interacting with the arkhahorrordb API
#   Author whassa
# Commands:
# 
#   {{arkh|card name}} or {{card name|arkh}} - fetch the card image for a arkham cards


Fuse = require 'fuse.js'

preloadData = (robot) ->
    locales = ["en"]
    for locale in locales
        do (locale) ->
            robot.http("https://arkhamdb.com/api/public/cards/")
                .get() (err, res, body) ->
                    cardData = JSON.parse body
                    robot.logger.info "Loaded " + cardData.length + " ArkhamDB cards"
                    robot.brain.set 'ARKHAMDBcards-'+locale, cardData

            robot.http("https://arkhamdb.com/api/public/packs/")
                .get() (err, res, body) ->
                    packData = JSON.parse body
                    robot.logger.info "Loaded " + packData.length + " ArkhamDB packs"
                    robot.brain.set 'ARKHAMDBpacks-' + locale, packData

      
lookupCard = (query, cards, locale) ->
    query = query.toLowerCase()

    if locale in ["kr"]
        # fuzzy search won't work, do naive string-matching
        results_exact = cards.filter((card) -> card._locale && card._locale[locale].title == query)
        results_includes = cards.filter((card) -> card._locale && card._locale[locale].title.includes(query))

        if results_exact.length > 0
            return results_exact[0]

        if results_includes.length > 0
            sortedResults = results_includes.sort((c1, c2) -> c1._locale[locale].title.length - c2._locale[locale].title.length)
            return sortedResults[0]
        return false
    else
        
        keys = ['name']

        fuseOptions =
            caseSensitive: false
            include: ['score']
            shouldSort: true
            threshold: 0.6
            location: 0
            distance: 100
            maxPatternLength: 32
            keys: keys

        fuse = new Fuse cards, fuseOptions
        results = fuse.search(query)

        if results? and results.length > 0
            filteredResults = results.filter((c) -> c.score == results[0].score)
            sortedResults = []
            if locale is "en"
                sortedResults = filteredResults.sort((c1, c2) -> c1.item.name.length - c2.item.name.length)
            else
                # favor localized results over non-localized results when showing matches
                sortedResults = filteredResults.sort((c1, c2) ->
                    if c1.item._locale and c2.item._locale
                        return c1.item._locale[locale].name.length - c2.item._locale[locale].name.length
                    if c1.item._locale and not c2.item._locale
                        return -1
                    if c2.item._locale and not c1.item._locale
                        return 1
                    return c1.item.name.length - c2.item.name.length
                )
            return sortedResults[0].item
        else
            return false



module.exports = (robot) ->
    # delay preload to give the app time to connect to redis
    setTimeout ( ->
        preloadData(robot)
    ), 1000
    
    # Give the doomtown image to stuff
    robot.hear /{{arkh\|([^}]+)}}|{{([^}]+\|arkh)}}/, (res) ->
        # get the query
        match = ''
        ## check the match to take of the result
        if res.match[1]
            match = res.match[1]
        else if res.match[2]
            match = res.match[2]
        # remove unnecessary space
        query = match.replace /^\s+|\s+$/g, ""
    
        # Regex 
        locale = "en"
        hangul = new RegExp("[\u1100-\u11FF|\u3130-\u318F|\uA960-\uA97F|\uAC00-\uD7AF|\uD7B0-\uD7FF]");
       
        # Get the dtdb card
        card = lookupCard(query, robot.brain.get('ARKHAMDBcards-'+locale), locale)
        robot.logger.info "Searching ARKHAMDB for card image #{query} (from #{res.message.user.name} in #{res.message.room})"
        robot.logger.info "Locale: " + locale

        if card
            res.send "https://arkhamdb.com"+card.imagesrc
        else
            res.send "No ArkhamHorrorDB card result found for \"" + match + "\"."

