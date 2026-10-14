import Testing
@testable import TurnkeeperKit

@Suite("Spoken initiative numbers")
struct SpokenNumberParserTests {
    @Test("Words, digits and hyphens", arguments: [
        ("seventeen", 17.0), ("twenty three", 23), ("twenty-three", 23), ("Twenty", 20), ("9", 9),
        ("nine", 9), ("natural twenty", 20), ("minus one", -1), ("negative two", -2), ("thirty", 30)
    ])
    func numbers(transcript: String, expected: Double) {
        #expect(SpokenNumberParser.initiative(from: transcript) == expected)
    }

    @Test("The last number heard wins")
    func corrections() {
        #expect(SpokenNumberParser.initiative(from: "uh, fourteen… no, sixteen") == 16)
        #expect(SpokenNumberParser.initiative(from: "12 sorry 21") == 21)
    }

    @Test("Ties can be broken with halves")
    func halves() {
        #expect(SpokenNumberParser.initiative(from: "17 and a half") == 17.5)
        #expect(SpokenNumberParser.initiative(from: "seventeen point five") == 17.5)
        #expect(SpokenNumberParser.initiative(from: "17.5") == 17.5)
    }

    @Test("Nothing usable gives nil, so the keypad opens")
    func junk() {
        #expect(SpokenNumberParser.initiative(from: "hmm what") == nil)
        #expect(SpokenNumberParser.initiative(from: "") == nil)
    }
}
