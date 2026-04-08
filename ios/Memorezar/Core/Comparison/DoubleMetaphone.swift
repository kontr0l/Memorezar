import Foundation

/// Double Metaphone phonetic encoding algorithm.
///
/// Produces two 4-character codes (primary and alternate) per word.
/// Two words are phonetically similar if any of their 4 code combinations match.
///
/// Based on Lawrence Philips' Double Metaphone algorithm.
/// Optimized for hot-path usage: single-word encoding takes ~0.01ms.
final class DoubleMetaphone {

    struct PhoneticCode: Equatable {
        let primary: String
        let alternate: String

        /// Check if this code matches another (any combination of primary/alternate)
        func matches(_ other: PhoneticCode) -> Bool {
            if primary == other.primary { return true }
            if primary == other.alternate { return true }
            if alternate == other.primary { return true }
            if alternate == other.alternate { return true }
            return false
        }
    }

    /// Encode a word into Double Metaphone codes.
    /// Returns nil for empty/very short words.
    static func encode(_ word: String) -> PhoneticCode? {
        let input = word.uppercased()
        guard input.count >= 1 else { return nil }

        let chars = Array(input)
        let length = chars.count
        let last = length - 1

        var primary = ""
        var alternate = ""
        let maxCodeLen = 4
        var current = 0

        // Helper functions
        func isVowel(_ ch: Character) -> Bool {
            "AEIOUY".contains(ch)
        }

        func charAt(_ index: Int) -> Character {
            guard index >= 0 && index < length else { return "\0" }
            return chars[index]
        }

        func stringAt(_ start: Int, _ len: Int, _ strings: [String]) -> Bool {
            guard start >= 0 && start + len <= length else { return false }
            let sub = String(chars[start..<(start + len)])
            return strings.contains(sub)
        }

        func isSlavoGermanic() -> Bool {
            input.contains("W") || input.contains("K") || input.contains("CZ") || input.contains("WITZ")
        }

        func addCode(_ p: String, _ a: String? = nil) {
            if primary.count < maxCodeLen { primary += p }
            if alternate.count < maxCodeLen { alternate += a ?? p }
        }

        let slavoGermanic = isSlavoGermanic()

        // Skip initial silent letters
        if stringAt(0, 2, ["GN", "KN", "PN", "AE", "WR"]) {
            current += 1
        }

        // Initial 'X' is pronounced 'S'
        if charAt(0) == "X" {
            addCode("S")
            current += 1
        }

        while current < length && (primary.count < maxCodeLen || alternate.count < maxCodeLen) {
            let ch = chars[current]

            switch ch {
            case "A", "E", "I", "O", "U", "Y":
                if current == 0 {
                    addCode("A")
                }
                current += 1

            case "B":
                addCode("P")
                current += (charAt(current + 1) == "B") ? 2 : 1

            case "Ç":
                addCode("S")
                current += 1

            case "C":
                // Various Germanic
                if current > 1 && !isVowel(charAt(current - 2))
                    && stringAt(current - 1, 3, ["ACH"])
                    && charAt(current + 2) != "I"
                    && (charAt(current + 2) != "E" || stringAt(current - 2, 6, ["BACHER", "MACHER"])) {
                    addCode("K")
                    current += 2
                } else if current == 0 && stringAt(current, 6, ["CAESAR"]) {
                    addCode("S")
                    current += 2
                } else if stringAt(current, 4, ["CHIA"]) {
                    addCode("K")
                    current += 2
                } else if stringAt(current, 2, ["CH"]) {
                    // Find 'Michael'
                    if current > 0 && stringAt(current, 4, ["CHAE"]) {
                        addCode("K", "X")
                        current += 2
                    } else if current == 0 && (stringAt(current + 1, 5, ["HARAC", "HARIS"]) || stringAt(current + 1, 3, ["HOR", "HYM", "HIA", "HEM"])) && !stringAt(0, 5, ["CHORE"]) {
                        addCode("K")
                        current += 2
                    } else if stringAt(0, 4, ["VAN ", "VON "]) || stringAt(0, 3, ["SCH"])
                                || stringAt(current - 2, 6, ["ORCHES", "ARCHIT", "ORCHID"])
                                || stringAt(current + 2, 1, ["T", "S"])
                                || ((current == 0 || stringAt(current - 1, 1, ["A", "O", "U", "E"])) && stringAt(current + 2, 1, ["L", "R", "N", "M", "B", "H", "F", "V", "W", " "])) {
                        addCode("K")
                        current += 2
                    } else if current > 0 {
                        if stringAt(0, 2, ["MC"]) {
                            addCode("K")
                        } else {
                            addCode("X", "K")
                        }
                        current += 2
                    } else {
                        addCode("X")
                        current += 2
                    }
                } else if stringAt(current, 2, ["CZ"]) && !stringAt(current - 2, 4, ["WICZ"]) {
                    addCode("S", "X")
                    current += 2
                } else if stringAt(current + 1, 3, ["CIA"]) {
                    addCode("X")
                    current += 3
                } else if stringAt(current, 2, ["CC"]) && !(current == 1 && charAt(0) == "M") {
                    if stringAt(current + 2, 1, ["I", "E", "H"]) && !stringAt(current + 2, 2, ["HU"]) {
                        if (current == 1 && charAt(current - 1) == "A") || stringAt(current - 1, 5, ["UCCEE", "UCCES"]) {
                            addCode("KS")
                        } else {
                            addCode("X")
                        }
                        current += 3
                    } else {
                        addCode("K")
                        current += 2
                    }
                } else if stringAt(current, 2, ["CK", "CG", "CQ"]) {
                    addCode("K")
                    current += 2
                } else if stringAt(current, 2, ["CI", "CE", "CY"]) {
                    if stringAt(current, 3, ["CIO", "CIE", "CIA"]) {
                        addCode("S", "X")
                    } else {
                        addCode("S")
                    }
                    current += 2
                } else {
                    addCode("K")
                    if stringAt(current + 1, 2, [" C", " Q", " G"]) {
                        current += 3
                    } else if stringAt(current + 1, 1, ["C", "K", "Q"]) && !stringAt(current + 1, 2, ["CE", "CI"]) {
                        current += 2
                    } else {
                        current += 1
                    }
                }

            case "D":
                if stringAt(current, 2, ["DG"]) {
                    if stringAt(current + 2, 1, ["I", "E", "Y"]) {
                        addCode("J")
                        current += 3
                    } else {
                        addCode("TK")
                        current += 2
                    }
                } else if stringAt(current, 2, ["DT", "DD"]) {
                    addCode("T")
                    current += 2
                } else {
                    addCode("T")
                    current += 1
                }

            case "F":
                addCode("F")
                current += (charAt(current + 1) == "F") ? 2 : 1

            case "G":
                if charAt(current + 1) == "H" {
                    if current > 0 && !isVowel(charAt(current - 1)) {
                        addCode("K")
                        current += 2
                    } else if current == 0 {
                        if charAt(current + 2) == "I" {
                            addCode("J")
                        } else {
                            addCode("K")
                        }
                        current += 2
                    } else if (current > 1 && stringAt(current - 2, 1, ["B", "H", "D"]))
                                || (current > 2 && stringAt(current - 3, 1, ["B", "H", "D"]))
                                || (current > 3 && stringAt(current - 4, 1, ["B", "H"])) {
                        current += 2
                    } else {
                        if current > 2 && charAt(current - 1) == "U"
                            && stringAt(current - 3, 1, ["C", "G", "L", "R", "T"]) {
                            addCode("F")
                        } else if current > 0 && charAt(current - 1) != "I" {
                            addCode("K")
                        }
                        current += 2
                    }
                } else if charAt(current + 1) == "N" {
                    if current == 1 && isVowel(charAt(0)) && !slavoGermanic {
                        addCode("KN", "N")
                    } else {
                        if !stringAt(current + 2, 2, ["EY"]) && charAt(current + 1) != "Y" && !slavoGermanic {
                            addCode("N", "KN")
                        } else {
                            addCode("KN")
                        }
                    }
                    current += 2
                } else if stringAt(current + 1, 2, ["LI"]) && !slavoGermanic {
                    addCode("KL", "L")
                    current += 2
                } else if current == 0 && (charAt(current + 1) == "Y"
                    || stringAt(current + 1, 2, ["ES", "EP", "EB", "EL", "EY", "IB", "IL", "IN", "IE", "EI", "ER"])) {
                    addCode("K", "J")
                    current += 2
                } else if (stringAt(current + 1, 2, ["ER"]) || charAt(current + 1) == "Y")
                    && !stringAt(0, 6, ["DANGER", "RANGER", "MANGER"])
                    && !stringAt(current - 1, 1, ["E", "I"])
                    && !stringAt(current - 1, 3, ["RGY", "OGY"]) {
                    addCode("K", "J")
                    current += 2
                } else if stringAt(current + 1, 1, ["E", "I", "Y"]) || stringAt(current - 1, 4, ["AGGI", "OGGI"]) {
                    if stringAt(0, 4, ["VAN ", "VON "]) || stringAt(0, 3, ["SCH"]) || stringAt(current + 1, 2, ["ET"]) {
                        addCode("K")
                    } else {
                        if stringAt(current + 1, 4, ["IER "]) {
                            addCode("J")
                        } else {
                            addCode("J", "K")
                        }
                    }
                    current += 2
                } else {
                    if charAt(current + 1) == "G" {
                        current += 2
                    } else {
                        current += 1
                    }
                    addCode("K")
                }

            case "H":
                if (current == 0 || isVowel(charAt(current - 1))) && isVowel(charAt(current + 1)) {
                    addCode("H")
                    current += 2
                } else {
                    current += 1
                }

            case "J":
                if stringAt(current, 4, ["JOSE"]) || stringAt(0, 4, ["SAN "]) {
                    if (current == 0 && charAt(current + 4) == " ") || stringAt(0, 4, ["SAN "]) {
                        addCode("H")
                    } else {
                        addCode("J", "H")
                    }
                    current += 1
                } else if current == 0 && !stringAt(current, 4, ["JOSE"]) {
                    addCode("J", "A")
                    current += (charAt(current + 1) == "J") ? 2 : 1
                } else {
                    if isVowel(charAt(current - 1)) && !slavoGermanic && (charAt(current + 1) == "A" || charAt(current + 1) == "O") {
                        addCode("J", "H")
                    } else if current == last {
                        addCode("J", " ")
                    } else if !stringAt(current + 1, 1, ["L", "T", "K", "S", "N", "M", "B", "H", "F", "Z"])
                                && !stringAt(current - 1, 1, ["S", "K", "L"]) {
                        addCode("J")
                    }
                    current += (charAt(current + 1) == "J") ? 2 : 1
                }

            case "K":
                addCode("K")
                current += (charAt(current + 1) == "K") ? 2 : 1

            case "L":
                if charAt(current + 1) == "L" {
                    if (current == length - 3 && stringAt(current - 1, 4, ["ILLO", "ILLA", "ALLE"]))
                        || ((stringAt(last - 1, 2, ["AS", "OS"]) || stringAt(last, 1, ["A", "O"]))
                            && stringAt(current - 1, 4, ["ALLE"])) {
                        addCode("L", " ")
                        current += 2
                    } else {
                        addCode("L")
                        current += 2
                    }
                } else {
                    addCode("L")
                    current += 1
                }

            case "M":
                addCode("M")
                if stringAt(current - 1, 3, ["UMB"]) && (current + 1 == last || stringAt(current + 2, 2, ["ER"])) {
                    current += 2
                } else {
                    current += (charAt(current + 1) == "M") ? 2 : 1
                }

            case "N":
                addCode("N")
                current += (charAt(current + 1) == "N") ? 2 : 1

            case "Ñ":
                addCode("N")
                current += 1

            case "P":
                if charAt(current + 1) == "H" {
                    addCode("F")
                    current += 2
                } else {
                    addCode("P")
                    current += stringAt(current + 1, 1, ["P", "B"]) ? 2 : 1
                }

            case "Q":
                addCode("K")
                current += (charAt(current + 1) == "Q") ? 2 : 1

            case "R":
                // French final 'R' not pronounced
                if current == last && !slavoGermanic
                    && stringAt(current - 2, 2, ["IE"])
                    && !stringAt(current - 4, 2, ["ME", "MA"]) {
                    addCode("", "R")
                } else {
                    addCode("R")
                }
                current += (charAt(current + 1) == "R") ? 2 : 1

            case "S":
                if stringAt(current - 1, 3, ["ISL", "YSL"]) {
                    current += 1
                } else if current == 0 && stringAt(current, 5, ["SUGAR"]) {
                    addCode("X", "S")
                    current += 1
                } else if stringAt(current, 2, ["SH"]) {
                    if stringAt(current + 1, 4, ["HEIM", "HOEK", "HOLM", "HOLZ"]) {
                        addCode("S")
                    } else {
                        addCode("X")
                    }
                    current += 2
                } else if stringAt(current, 3, ["SIO", "SIA"]) || stringAt(current, 4, ["SIAN"]) {
                    if !slavoGermanic {
                        addCode("S", "X")
                    } else {
                        addCode("S")
                    }
                    current += 3
                } else if (current == 0 && stringAt(current + 1, 1, ["M", "N", "L", "W"])) || stringAt(current + 1, 1, ["Z"]) {
                    addCode("S", "X")
                    current += stringAt(current + 1, 1, ["Z"]) ? 2 : 1
                } else if stringAt(current, 2, ["SC"]) {
                    if charAt(current + 2) == "H" {
                        if stringAt(current + 3, 2, ["OO", "ER", "EN", "UY", "ED", "EM"]) {
                            if stringAt(current + 3, 2, ["ER", "EN"]) {
                                addCode("X", "SK")
                            } else {
                                addCode("SK")
                            }
                        } else {
                            if current == 0 && !isVowel(charAt(3)) && charAt(3) != "W" {
                                addCode("X", "S")
                            } else {
                                addCode("X")
                            }
                        }
                        current += 3
                    } else if stringAt(current + 2, 1, ["I", "E", "Y"]) {
                        addCode("S")
                        current += 3
                    } else {
                        addCode("SK")
                        current += 3
                    }
                } else {
                    if current == last && stringAt(current - 2, 2, ["AI", "OI"]) {
                        addCode("", "S")
                    } else {
                        addCode("S")
                    }
                    current += stringAt(current + 1, 1, ["S", "Z"]) ? 2 : 1
                }

            case "T":
                if stringAt(current, 4, ["TION"]) {
                    addCode("X")
                    current += 3
                } else if stringAt(current, 3, ["TIA", "TCH"]) {
                    addCode("X")
                    current += 3
                } else if stringAt(current, 2, ["TH"]) || stringAt(current, 3, ["TTH"]) {
                    if stringAt(current + 2, 2, ["OM", "AM"]) || stringAt(0, 4, ["VAN ", "VON "]) || stringAt(0, 3, ["SCH"]) {
                        addCode("T")
                    } else {
                        addCode("0", "T")
                    }
                    current += 2
                } else {
                    addCode("T")
                    current += stringAt(current + 1, 1, ["T", "D"]) ? 2 : 1
                }

            case "V":
                addCode("F")
                current += (charAt(current + 1) == "V") ? 2 : 1

            case "W":
                if stringAt(current, 2, ["WR"]) {
                    addCode("R")
                    current += 2
                } else if current == 0 && (isVowel(charAt(current + 1)) || stringAt(current, 2, ["WH"])) {
                    if isVowel(charAt(current + 1)) {
                        addCode("A", "F")
                    } else {
                        addCode("A")
                    }
                    current += 1
                } else if (current == last && isVowel(charAt(current - 1)))
                    || stringAt(current - 1, 5, ["EWSKI", "EWSKY", "OWSKI", "OWSKY"])
                    || stringAt(0, 3, ["SCH"]) {
                    addCode("", "F")
                    current += 1
                } else if stringAt(current, 4, ["WICZ", "WITZ"]) {
                    addCode("TS", "FX")
                    current += 4
                } else {
                    current += 1
                }

            case "X":
                if !(current == last && (stringAt(current - 3, 3, ["IAU", "EAU"]) || stringAt(current - 2, 2, ["AU", "OU"]))) {
                    addCode("KS")
                }
                current += stringAt(current + 1, 1, ["C", "X"]) ? 2 : 1

            case "Z":
                if charAt(current + 1) == "H" {
                    addCode("J")
                    current += 2
                } else if stringAt(current + 1, 2, ["ZO", "ZI", "ZA"]) || (slavoGermanic && current > 0 && charAt(current - 1) != "T") {
                    addCode("S", "TS")
                    current += (charAt(current + 1) == "Z") ? 2 : 1
                } else {
                    addCode("S")
                    current += (charAt(current + 1) == "Z") ? 2 : 1
                }

            default:
                current += 1
            }
        }

        // Pad to maxCodeLen
        while primary.count < maxCodeLen { primary += " " }
        while alternate.count < maxCodeLen { alternate += " " }

        primary = String(primary.prefix(maxCodeLen))
        alternate = String(alternate.prefix(maxCodeLen))

        return PhoneticCode(primary: primary, alternate: alternate)
    }

    /// Check if two words are phonetically similar via Double Metaphone.
    /// Both words must be >= 3 characters and within 60% length ratio.
    static func arePhoneticallySimilar(_ word1: String, _ word2: String) -> Bool {
        guard word1.count >= 3, word2.count >= 3 else { return false }

        // Length ratio guard: shorter/longer >= 0.6
        let shorter = min(word1.count, word2.count)
        let longer = max(word1.count, word2.count)
        guard Double(shorter) / Double(longer) >= 0.6 else { return false }

        guard let code1 = encode(word1), let code2 = encode(word2) else { return false }
        return code1.matches(code2)
    }
}
