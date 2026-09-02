import SwiftUI
import UIKit

// The palette, carried over from the web app's CSS custom properties.
//
// Each token is one dynamic colour holding both themes, so a view names `Color.fsSurface` and
// never asks which theme is on. That matters more than it sounds: the two palettes are not
// inversions of each other — the light theme is a warm bone canvas with hairline borders, the
// dark one is near-black with raised surfaces — and any view that tried to derive one from the
// other would get grey-on-grey.

extension UIColor {
    /// #RGB, #RRGGBB or #RRGGBBAA. An unparseable string is magenta, which is easier to spot in a
    /// screenshot than a silent black.
    convenience init(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else {
            self.init(red: 1, green: 0, blue: 1, alpha: 1)
            return
        }
        let hasAlpha = s.count == 8
        let r = Double((v >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = Double((v >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = Double((v >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? Double(v & 0xFF) / 255 : 1
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension Color {
    /// One token, both themes.
    static func fsToken(dark: String, light: String) -> Color {
        Color(UIColor { traits in
            UIColor(hexString: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// A flat colour that is the same in both themes — the category marks, which are their own
    /// identity rather than chrome.
    static func fsFixed(_ hex: String) -> Color { Color(UIColor(hexString: hex)) }

    // Canvas and surfaces
    static let fsBg        = fsToken(dark: "#08090B", light: "#F7F6F3")
    static let fsSurface   = fsToken(dark: "#131419", light: "#FFFFFF")
    static let fsSurface2  = fsToken(dark: "#1A1B20", light: "#FBFBFA")
    static let fsSurface3  = fsToken(dark: "#22242A", light: "#F2F1ED")

    // Lines
    static let fsBorder    = fsToken(dark: "#202126", light: "#E7E5E0")
    static let fsBorder2   = fsToken(dark: "#2E3036", light: "#DAD8D2")

    // Type
    static let fsText      = fsToken(dark: "#F2F3F5", light: "#16171A")
    static let fsMuted     = fsToken(dark: "#A2A4AC", light: "#6B6C72")
    static let fsDim       = fsToken(dark: "#6E7079", light: "#95969C")

    // Signals. The light values are darkened rather than reused: the dark theme's accents are
    // tuned against black and go pastel the moment the page turns white.
    static let fsAccent    = fsToken(dark: "#3ECFAA", light: "#12876B")
    static let fsGreen     = fsToken(dark: "#2D6B5E", light: "#1F6E4E")
    static let fsRed       = fsToken(dark: "#D9526B", light: "#B23A54")
    static let fsAmber     = fsToken(dark: "#E0A63E", light: "#9A6B12")
    static let fsPurple    = fsToken(dark: "#7C7FD9", light: "#5A5DBF")

    // The inverted island: a pale block on black, an ink block on bone.
    static let fsPanel     = fsToken(dark: "#D6F0EE", light: "#1C4A3E")
    static let fsOnPanel   = fsToken(dark: "#1C4A3E", light: "#F0FBFA")
}

enum Radius {
    // The web app tightens every radius in its light theme, on the grounds that big soft corners
    // read as toy-like against hairline borders. On iPhone the tighter set is right for both: a
    // 28pt corner on a 390pt-wide card is most of the card.
    static let card: CGFloat = 20
    static let inner: CGFloat = 14
    static let chip: CGFloat = 10
}

enum FSFont {
    /// Headings. The web app sets these in Archivo; until that face is in the bundle, SF with the
    /// tracking pulled in is the closer match of what is available.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    /// Figures, always tabular — a column of money that shifts as digits change is unreadable.
    static func number(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
