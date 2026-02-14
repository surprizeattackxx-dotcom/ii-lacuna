pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell

Item {
    id: root

    property list<var> sections: []

    property string currentSearch: ""
    onCurrentSearchChanged: {
        console.log("CURRENT SERACH:", currentSearch)
    }

    // used by config components like ConfigSwitch, ConfigSpinBox
    function findSection(item) {
        while (item) {
            if (item.addKeyword) return item
            item = item.parent
        }
    }

    function tokenize(text) {
        if (!text || typeof text !== "string")
            return []

        return text
            .toLowerCase()
            .replace(/[^a-z0-9\sğüşöçıİ_\-\.]/g, " ")
            .split(/[\s_\-\.]+/)
            .filter(function(t) { return t.length > 1 })
    }

    function fuzzyMatch(word, query) {
        let wi = 0
        let qi = 0
        let score = 0

        word = word.toLowerCase()
        query = query.toLowerCase()

        while (wi < word.length && qi < query.length) {
            if (word[wi] === query[qi]) {
                score += 10
                qi++
            }
            wi++
        }

        if (qi === query.length)
            return score

        return 0
    }

    function registerSection(data) {
        let combined = (data.title + " " + data.searchStrings.join(" ")).toLowerCase()
        
        data._tokens = tokenize(combined)
        data._searchText = combined
        
        sections.push(data)
        
        // console.log("[SearchRegistry] Registered section:", data.title, "with strings:", data.searchStrings)
    }

    function getBestResult(text) {
        let results = getSearchResult(text)
        if (results.length === 0)
            return null

        results.sort((a, b) => b.score - a.score)
        return results[0]
    }

    function getResultsRanked(text) {
        let results = getSearchResult(text)
        results.sort((a, b) => b.score - a.score)
        return results
    }

    function getSearchResult(query) {
        if (!query || query.trim() === "") return []

        query = query.toLowerCase().trim()
        let queryTokens = tokenize(query)
        let results = []

        for (let section of sections) {
            let totalScore = 0
            let bestMatch = "" 
            let bestMatchScore = 0
            let bestMatchSource = "" 
            
            // direct match in title
            if (section.title.toLowerCase().includes(query)) {
                totalScore += 1000
                if (bestMatchScore < 1000) {
                    bestMatch = section.title
                    bestMatchSource = section.title
                    bestMatchScore = 1000
                }
            }
            
            // direct match in searchStrings
            for (let searchStr of section.searchStrings) {
                let lowerStr = searchStr.toLowerCase()
                if (lowerStr.includes(query)) {
                    let score = lowerStr === query ? 800 : 500
                    totalScore += score
                    if (score > bestMatchScore) {
                        bestMatch = searchStr
                        bestMatchSource = searchStr
                        bestMatchScore = score
                    }
                }
            }
            
            for (let searchStr of section.searchStrings) {
                let searchStrLower = searchStr.toLowerCase()
                let searchTokens = tokenize(searchStrLower)
                let matchedTokenCount = 0
                let tokenScore = 0
                
                for (let qToken of queryTokens) {
                    for (let sToken of searchTokens) {
                        let score = 0
                        if (sToken.startsWith(qToken)) {
                            score = 200
                            matchedTokenCount++
                        } else if (sToken.includes(qToken)) {
                            score = 100
                            matchedTokenCount++
                        } else {
                            let fuzzyScore = fuzzyMatch(sToken, qToken)
                            if (fuzzyScore > 0) {
                                score = fuzzyScore
                                matchedTokenCount++
                            }
                        }
                        
                        if (score > 0) {
                            tokenScore += score
                        }
                    }
                }
                
                if (tokenScore > 0) {
                    totalScore += tokenScore
                    if (tokenScore > bestMatchScore && matchedTokenCount > 0) {
                        bestMatch = searchStr
                        bestMatchSource = searchStr
                        bestMatchScore = tokenScore
                    }
                }
            }
            
            if (totalScore > 0) {
                results.push({
                    pageIndex: section.pageIndex,
                    title: section.title,
                    keyword: section._searchText,
                    matchedString: bestMatch || section.title,
                    yPos: section.yPos,
                    score: totalScore
                })
            }
        }
        
        return results
    }

    function scoreResult(result, text) {
        return result.score
    }

    // Debug
    function listAllSections() {
        console.log("=== Registered Sections ===")
        for (let i = 0; i < sections.length; i++) {
            console.log(i + ":", sections[i].title, "tokens:", sections[i]._tokens)
        }
    }
}