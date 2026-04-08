import SwiftUI

struct TipDefinition {
    let id: String
    let content: LocalizedStringKey
    /// Tip ID that must be completed before this tip shows
    var requiredTipId: String? = nil
}

extension TipDefinition {
    static let addOwnQuote = TipDefinition(
        id: "tip.addOwnQuote",
        content: "Add your\nown quote"
    )

    static let addCategory = TipDefinition(
        id: "tip.addCategory",
        content: "Add your own\ncategory"
    )

    static let browsePacks = TipDefinition(
        id: "tip.browsePacks",
        content: "Explore curated packs\nof quotes to add\nto your library",
        requiredTipId: "tip.addOwnQuote"
    )

    static let splitLongQuote = TipDefinition(
        id: "tip.splitLongQuote",
        content: "Try splitting into smaller chunks"
    )

    static let recitationIntro = TipDefinition(
        id: "tip.recitationIntro",
        content: ""
    )
}
