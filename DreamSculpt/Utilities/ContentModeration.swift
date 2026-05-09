//
//  ContentModeration.swift
//  DreamSculpt
//

import Foundation

/// Lightweight client-side prompt filter. Apple's review guideline 1.2
/// requires apps with user-generated AI content to make a "reasonable
/// effort" to block objectionable input — even when the backend also
/// filters. This catches the obvious cases before the request leaves the
/// device, which both speeds up rejection (no round-trip) and gives the
/// reviewer something to point at.
///
/// The list is intentionally narrow — false positives on benign words
/// (e.g. "kill the fire") would be more annoying than the harm avoided.
/// Keep server-side moderation as the real defense.
enum ContentModeration {
    /// Returns true if `prompt` contains a term that should be blocked
    /// outright. Match is case-insensitive and word-boundary-aware so
    /// "scrape" doesn't trigger a block on "rape".
    static func shouldBlock(prompt: String) -> Bool {
        let lowered = prompt.lowercased()
        let tokens = lowered
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let tokenSet = Set(tokens)
        return !blockedTerms.isDisjoint(with: tokenSet)
    }

    /// Single-word terms covering the categories Apple explicitly calls
    /// out: child sexual abuse material, sexual violence, terrorism /
    /// weapons of mass harm, and graphic gore. Multi-word phrases would
    /// need a substring match, but these are the clearest line.
    private static let blockedTerms: Set<String> = [
        // CSAM-adjacent
        "child", "children", "kid", "kids", "minor", "minors",
        "underage", "preteen", "toddler", "infant", "loli", "shota",
        // Sexual violence
        "rape", "raping", "molest", "molestation",
        // Weapons of mass harm
        "bomb", "bombs", "explosive", "explosives", "ied", "anthrax",
        "nerve", "sarin",
        // Graphic violence
        "behead", "beheading", "decapitate", "decapitation",
        "lynch", "lynching",
    ]
}
