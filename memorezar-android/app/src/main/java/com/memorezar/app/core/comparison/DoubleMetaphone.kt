package com.memorezar.app.core.comparison

object DoubleMetaphone {

    data class PhoneticCode(val primary: String, val alternate: String) {
        fun matches(other: PhoneticCode): Boolean {
            if (primary == other.primary) return true
            if (primary == other.alternate) return true
            if (alternate == other.primary) return true
            if (alternate == other.alternate) return true
            return false
        }
    }

    fun encode(word: String): PhoneticCode? {
        val input = word.uppercase()
        if (input.isEmpty()) return null

        val chars = input.toCharArray()
        val length = chars.size
        val last = length - 1

        val primaryBuf = StringBuilder()
        val alternateBuf = StringBuilder()
        val maxCodeLen = 4
        var current = 0

        fun isVowel(ch: Char): Boolean = ch in "AEIOUY"

        fun charAt(index: Int): Char {
            return if (index in 0 until length) chars[index] else '\u0000'
        }

        fun stringAt(start: Int, len: Int, strings: List<String>): Boolean {
            if (start < 0 || start + len > length) return false
            val sub = String(chars, start, len)
            return sub in strings
        }

        fun isSlavoGermanic(): Boolean {
            return "W" in input || "K" in input || "CZ" in input || "WITZ" in input
        }

        fun addCode(p: String, a: String? = null) {
            if (primaryBuf.length < maxCodeLen) primaryBuf.append(p)
            if (alternateBuf.length < maxCodeLen) alternateBuf.append(a ?: p)
        }

        val slavoGermanic = isSlavoGermanic()

        if (stringAt(0, 2, listOf("GN", "KN", "PN", "AE", "WR"))) {
            current += 1
        }

        if (charAt(0) == 'X') {
            addCode("S")
            current += 1
        }

        while (current < length && (primaryBuf.length < maxCodeLen || alternateBuf.length < maxCodeLen)) {
            val ch = chars[current]

            when (ch) {
                'A', 'E', 'I', 'O', 'U', 'Y' -> {
                    if (current == 0) addCode("A")
                    current += 1
                }

                'B' -> {
                    addCode("P")
                    current += if (charAt(current + 1) == 'B') 2 else 1
                }

                '\u00C7' -> { // Ç
                    addCode("S")
                    current += 1
                }

                'C' -> {
                    if (current > 1 && !isVowel(charAt(current - 2))
                        && stringAt(current - 1, 3, listOf("ACH"))
                        && charAt(current + 2) != 'I'
                        && (charAt(current + 2) != 'E' || stringAt(current - 2, 6, listOf("BACHER", "MACHER")))
                    ) {
                        addCode("K"); current += 2
                    } else if (current == 0 && stringAt(current, 6, listOf("CAESAR"))) {
                        addCode("S"); current += 2
                    } else if (stringAt(current, 4, listOf("CHIA"))) {
                        addCode("K"); current += 2
                    } else if (stringAt(current, 2, listOf("CH"))) {
                        if (current > 0 && stringAt(current, 4, listOf("CHAE"))) {
                            addCode("K", "X"); current += 2
                        } else if (current == 0 && (stringAt(current + 1, 5, listOf("HARAC", "HARIS")) || stringAt(current + 1, 3, listOf("HOR", "HYM", "HIA", "HEM"))) && !stringAt(0, 5, listOf("CHORE"))) {
                            addCode("K"); current += 2
                        } else if (stringAt(0, 4, listOf("VAN ", "VON ")) || stringAt(0, 3, listOf("SCH"))
                            || stringAt(current - 2, 6, listOf("ORCHES", "ARCHIT", "ORCHID"))
                            || stringAt(current + 2, 1, listOf("T", "S"))
                            || ((current == 0 || stringAt(current - 1, 1, listOf("A", "O", "U", "E"))) && stringAt(current + 2, 1, listOf("L", "R", "N", "M", "B", "H", "F", "V", "W", " ")))
                        ) {
                            addCode("K"); current += 2
                        } else if (current > 0) {
                            if (stringAt(0, 2, listOf("MC"))) {
                                addCode("K")
                            } else {
                                addCode("X", "K")
                            }
                            current += 2
                        } else {
                            addCode("X"); current += 2
                        }
                    } else if (stringAt(current, 2, listOf("CZ")) && !stringAt(current - 2, 4, listOf("WICZ"))) {
                        addCode("S", "X"); current += 2
                    } else if (stringAt(current + 1, 3, listOf("CIA"))) {
                        addCode("X"); current += 3
                    } else if (stringAt(current, 2, listOf("CC")) && !(current == 1 && charAt(0) == 'M')) {
                        if (stringAt(current + 2, 1, listOf("I", "E", "H")) && !stringAt(current + 2, 2, listOf("HU"))) {
                            if ((current == 1 && charAt(current - 1) == 'A') || stringAt(current - 1, 5, listOf("UCCEE", "UCCES"))) {
                                addCode("KS")
                            } else {
                                addCode("X")
                            }
                            current += 3
                        } else {
                            addCode("K"); current += 2
                        }
                    } else if (stringAt(current, 2, listOf("CK", "CG", "CQ"))) {
                        addCode("K"); current += 2
                    } else if (stringAt(current, 2, listOf("CI", "CE", "CY"))) {
                        if (stringAt(current, 3, listOf("CIO", "CIE", "CIA"))) {
                            addCode("S", "X")
                        } else {
                            addCode("S")
                        }
                        current += 2
                    } else {
                        addCode("K")
                        if (stringAt(current + 1, 2, listOf(" C", " Q", " G"))) {
                            current += 3
                        } else if (stringAt(current + 1, 1, listOf("C", "K", "Q")) && !stringAt(current + 1, 2, listOf("CE", "CI"))) {
                            current += 2
                        } else {
                            current += 1
                        }
                    }
                }

                'D' -> {
                    if (stringAt(current, 2, listOf("DG"))) {
                        if (stringAt(current + 2, 1, listOf("I", "E", "Y"))) {
                            addCode("J"); current += 3
                        } else {
                            addCode("TK"); current += 2
                        }
                    } else if (stringAt(current, 2, listOf("DT", "DD"))) {
                        addCode("T"); current += 2
                    } else {
                        addCode("T"); current += 1
                    }
                }

                'F' -> {
                    addCode("F")
                    current += if (charAt(current + 1) == 'F') 2 else 1
                }

                'G' -> {
                    if (charAt(current + 1) == 'H') {
                        if (current > 0 && !isVowel(charAt(current - 1))) {
                            addCode("K"); current += 2
                        } else if (current == 0) {
                            if (charAt(current + 2) == 'I') {
                                addCode("J")
                            } else {
                                addCode("K")
                            }
                            current += 2
                        } else if ((current > 1 && stringAt(current - 2, 1, listOf("B", "H", "D")))
                            || (current > 2 && stringAt(current - 3, 1, listOf("B", "H", "D")))
                            || (current > 3 && stringAt(current - 4, 1, listOf("B", "H")))
                        ) {
                            current += 2
                        } else {
                            if (current > 2 && charAt(current - 1) == 'U' && stringAt(current - 3, 1, listOf("C", "G", "L", "R", "T"))) {
                                addCode("F")
                            } else if (current > 0 && charAt(current - 1) != 'I') {
                                addCode("K")
                            }
                            current += 2
                        }
                    } else if (charAt(current + 1) == 'N') {
                        if (current == 1 && isVowel(charAt(0)) && !slavoGermanic) {
                            addCode("KN", "N")
                        } else {
                            if (!stringAt(current + 2, 2, listOf("EY")) && charAt(current + 1) != 'Y' && !slavoGermanic) {
                                addCode("N", "KN")
                            } else {
                                addCode("KN")
                            }
                        }
                        current += 2
                    } else if (stringAt(current + 1, 2, listOf("LI")) && !slavoGermanic) {
                        addCode("KL", "L"); current += 2
                    } else if (current == 0 && (charAt(current + 1) == 'Y' || stringAt(current + 1, 2, listOf("ES", "EP", "EB", "EL", "EY", "IB", "IL", "IN", "IE", "EI", "ER")))) {
                        addCode("K", "J"); current += 2
                    } else if ((stringAt(current + 1, 2, listOf("ER")) || charAt(current + 1) == 'Y')
                        && !stringAt(0, 6, listOf("DANGER", "RANGER", "MANGER"))
                        && !stringAt(current - 1, 1, listOf("E", "I"))
                        && !stringAt(current - 1, 3, listOf("RGY", "OGY"))
                    ) {
                        addCode("K", "J"); current += 2
                    } else if (stringAt(current + 1, 1, listOf("E", "I", "Y")) || stringAt(current - 1, 4, listOf("AGGI", "OGGI"))) {
                        if (stringAt(0, 4, listOf("VAN ", "VON ")) || stringAt(0, 3, listOf("SCH")) || stringAt(current + 1, 2, listOf("ET"))) {
                            addCode("K")
                        } else {
                            if (stringAt(current + 1, 4, listOf("IER "))) {
                                addCode("J")
                            } else {
                                addCode("J", "K")
                            }
                        }
                        current += 2
                    } else {
                        if (charAt(current + 1) == 'G') {
                            current += 2
                        } else {
                            current += 1
                        }
                        addCode("K")
                    }
                }

                'H' -> {
                    if ((current == 0 || isVowel(charAt(current - 1))) && isVowel(charAt(current + 1))) {
                        addCode("H"); current += 2
                    } else {
                        current += 1
                    }
                }

                'J' -> {
                    if (stringAt(current, 4, listOf("JOSE")) || stringAt(0, 4, listOf("SAN "))) {
                        if ((current == 0 && charAt(current + 4) == ' ') || stringAt(0, 4, listOf("SAN "))) {
                            addCode("H")
                        } else {
                            addCode("J", "H")
                        }
                        current += 1
                    } else if (current == 0 && !stringAt(current, 4, listOf("JOSE"))) {
                        addCode("J", "A")
                        current += if (charAt(current + 1) == 'J') 2 else 1
                    } else {
                        if (isVowel(charAt(current - 1)) && !slavoGermanic && (charAt(current + 1) == 'A' || charAt(current + 1) == 'O')) {
                            addCode("J", "H")
                        } else if (current == last) {
                            addCode("J", " ")
                        } else if (!stringAt(current + 1, 1, listOf("L", "T", "K", "S", "N", "M", "B", "H", "F", "Z"))
                            && !stringAt(current - 1, 1, listOf("S", "K", "L"))
                        ) {
                            addCode("J")
                        }
                        current += if (charAt(current + 1) == 'J') 2 else 1
                    }
                }

                'K' -> {
                    addCode("K")
                    current += if (charAt(current + 1) == 'K') 2 else 1
                }

                'L' -> {
                    if (charAt(current + 1) == 'L') {
                        if ((current == length - 3 && stringAt(current - 1, 4, listOf("ILLO", "ILLA", "ALLE")))
                            || ((stringAt(last - 1, 2, listOf("AS", "OS")) || stringAt(last, 1, listOf("A", "O")))
                                && stringAt(current - 1, 4, listOf("ALLE")))
                        ) {
                            addCode("L", " "); current += 2
                        } else {
                            addCode("L"); current += 2
                        }
                    } else {
                        addCode("L"); current += 1
                    }
                }

                'M' -> {
                    addCode("M")
                    if (stringAt(current - 1, 3, listOf("UMB")) && (current + 1 == last || stringAt(current + 2, 2, listOf("ER")))) {
                        current += 2
                    } else {
                        current += if (charAt(current + 1) == 'M') 2 else 1
                    }
                }

                'N' -> {
                    addCode("N")
                    current += if (charAt(current + 1) == 'N') 2 else 1
                }

                '\u00D1' -> { // Ñ
                    addCode("N"); current += 1
                }

                'P' -> {
                    if (charAt(current + 1) == 'H') {
                        addCode("F"); current += 2
                    } else {
                        addCode("P"); current += if (stringAt(current + 1, 1, listOf("P", "B"))) 2 else 1
                    }
                }

                'Q' -> {
                    addCode("K")
                    current += if (charAt(current + 1) == 'Q') 2 else 1
                }

                'R' -> {
                    if (current == last && !slavoGermanic
                        && stringAt(current - 2, 2, listOf("IE"))
                        && !stringAt(current - 4, 2, listOf("ME", "MA"))
                    ) {
                        addCode("", "R")
                    } else {
                        addCode("R")
                    }
                    current += if (charAt(current + 1) == 'R') 2 else 1
                }

                'S' -> {
                    if (stringAt(current - 1, 3, listOf("ISL", "YSL"))) {
                        current += 1
                    } else if (current == 0 && stringAt(current, 5, listOf("SUGAR"))) {
                        addCode("X", "S"); current += 1
                    } else if (stringAt(current, 2, listOf("SH"))) {
                        if (stringAt(current + 1, 4, listOf("HEIM", "HOEK", "HOLM", "HOLZ"))) {
                            addCode("S")
                        } else {
                            addCode("X")
                        }
                        current += 2
                    } else if (stringAt(current, 3, listOf("SIO", "SIA")) || stringAt(current, 4, listOf("SIAN"))) {
                        if (!slavoGermanic) {
                            addCode("S", "X")
                        } else {
                            addCode("S")
                        }
                        current += 3
                    } else if ((current == 0 && stringAt(current + 1, 1, listOf("M", "N", "L", "W"))) || stringAt(current + 1, 1, listOf("Z"))) {
                        addCode("S", "X")
                        current += if (stringAt(current + 1, 1, listOf("Z"))) 2 else 1
                    } else if (stringAt(current, 2, listOf("SC"))) {
                        if (charAt(current + 2) == 'H') {
                            if (stringAt(current + 3, 2, listOf("OO", "ER", "EN", "UY", "ED", "EM"))) {
                                if (stringAt(current + 3, 2, listOf("ER", "EN"))) {
                                    addCode("X", "SK")
                                } else {
                                    addCode("SK")
                                }
                            } else {
                                if (current == 0 && !isVowel(charAt(3)) && charAt(3) != 'W') {
                                    addCode("X", "S")
                                } else {
                                    addCode("X")
                                }
                            }
                            current += 3
                        } else if (stringAt(current + 2, 1, listOf("I", "E", "Y"))) {
                            addCode("S"); current += 3
                        } else {
                            addCode("SK"); current += 3
                        }
                    } else {
                        if (current == last && stringAt(current - 2, 2, listOf("AI", "OI"))) {
                            addCode("", "S")
                        } else {
                            addCode("S")
                        }
                        current += if (stringAt(current + 1, 1, listOf("S", "Z"))) 2 else 1
                    }
                }

                'T' -> {
                    if (stringAt(current, 4, listOf("TION"))) {
                        addCode("X"); current += 3
                    } else if (stringAt(current, 3, listOf("TIA", "TCH"))) {
                        addCode("X"); current += 3
                    } else if (stringAt(current, 2, listOf("TH")) || stringAt(current, 3, listOf("TTH"))) {
                        if (stringAt(current + 2, 2, listOf("OM", "AM")) || stringAt(0, 4, listOf("VAN ", "VON ")) || stringAt(0, 3, listOf("SCH"))) {
                            addCode("T")
                        } else {
                            addCode("0", "T")
                        }
                        current += 2
                    } else {
                        addCode("T"); current += if (stringAt(current + 1, 1, listOf("T", "D"))) 2 else 1
                    }
                }

                'V' -> {
                    addCode("F")
                    current += if (charAt(current + 1) == 'V') 2 else 1
                }

                'W' -> {
                    if (stringAt(current, 2, listOf("WR"))) {
                        addCode("R"); current += 2
                    } else if (current == 0 && (isVowel(charAt(current + 1)) || stringAt(current, 2, listOf("WH")))) {
                        if (isVowel(charAt(current + 1))) {
                            addCode("A", "F")
                        } else {
                            addCode("A")
                        }
                        current += 1
                    } else if ((current == last && isVowel(charAt(current - 1)))
                        || stringAt(current - 1, 5, listOf("EWSKI", "EWSKY", "OWSKI", "OWSKY"))
                        || stringAt(0, 3, listOf("SCH"))
                    ) {
                        addCode("", "F"); current += 1
                    } else if (stringAt(current, 4, listOf("WICZ", "WITZ"))) {
                        addCode("TS", "FX"); current += 4
                    } else {
                        current += 1
                    }
                }

                'X' -> {
                    if (!(current == last && (stringAt(current - 3, 3, listOf("IAU", "EAU")) || stringAt(current - 2, 2, listOf("AU", "OU"))))) {
                        addCode("KS")
                    }
                    current += if (stringAt(current + 1, 1, listOf("C", "X"))) 2 else 1
                }

                'Z' -> {
                    if (charAt(current + 1) == 'H') {
                        addCode("J"); current += 2
                    } else if (stringAt(current + 1, 2, listOf("ZO", "ZI", "ZA")) || (slavoGermanic && current > 0 && charAt(current - 1) != 'T')) {
                        addCode("S", "TS")
                        current += if (charAt(current + 1) == 'Z') 2 else 1
                    } else {
                        addCode("S")
                        current += if (charAt(current + 1) == 'Z') 2 else 1
                    }
                }

                else -> {
                    current += 1
                }
            }
        }

        var primary = primaryBuf.toString()
        var alternate = alternateBuf.toString()

        while (primary.length < maxCodeLen) primary += " "
        while (alternate.length < maxCodeLen) alternate += " "
        primary = primary.substring(0, maxCodeLen)
        alternate = alternate.substring(0, maxCodeLen)

        return PhoneticCode(primary = primary, alternate = alternate)
    }

    fun arePhoneticallySimilar(word1: String, word2: String): Boolean {
        if (word1.length < 3 || word2.length < 3) return false
        val shorter = minOf(word1.length, word2.length)
        val longer = maxOf(word1.length, word2.length)
        if (shorter.toDouble() / longer.toDouble() < 0.6) return false
        val code1 = encode(word1) ?: return false
        val code2 = encode(word2) ?: return false
        return code1.matches(code2)
    }
}
