import SwiftUI

/// All brain character sprites, loaded from individual image assets
enum BrainCharacter: String, CaseIterable {
    // Pray sprites — home hero section
    case pray1 = "SpritePray1"
    case pray2 = "SpritePray2"
    case pray3 = "SpritePray3"
    case pray4 = "SpritePray4"

    // Work sprites — results page (accuracy >= 70%)
    case work1 = "SpriteWork1"
    case work2 = "SpriteWork2"
    case work3 = "SpriteWork3"
    case work4 = "SpriteWork4"

    // Mistake sprites — results page (accuracy < 70%) and mistake popups
    case mistake1 = "SpriteMistake1"
    case mistake2 = "SpriteMistake2"
    case mistake3 = "SpriteMistake3"
    case mistake4 = "SpriteMistake4"

    // Speech sprite — recitation tutorial
    case speech = "SpriteSpeech"

    /// The asset catalog image name
    var assetName: String { rawValue }

    // MARK: - Character Groups

    /// Pray characters for home page hero section
    static let hero: [BrainCharacter] = [.pray1, .pray2, .pray3, .pray4]

    /// Work characters for results page (good score)
    static let success: [BrainCharacter] = [.work1, .work2, .work3, .work4]

    /// Mistake characters for mistake popups and bad results
    static let mistakes: [BrainCharacter] = [.mistake1, .mistake2, .mistake3, .mistake4]

    /// Pick a random character from a group
    static func random(from group: [BrainCharacter]) -> BrainCharacter {
        group.randomElement() ?? .pray1
    }
}

// MARK: - SwiftUI View

/// Displays a brain character sprite from an individual image asset
struct BrainCharacterView: View {
    let character: BrainCharacter
    var size: CGFloat = 120

    var body: some View {
        Image(character.assetName)
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
