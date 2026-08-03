import SwiftUI

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Design System

enum DS {

    // MARK: Color

    enum Color {
        private static func adaptive(light: String, dark: String) -> SwiftUI.Color {
            SwiftUI.Color(uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                var int: UInt64 = 0
                Scanner(string: trimmed).scanHexInt64(&int)
                let r = CGFloat((int >> 16) & 0xFF) / 255
                let g = CGFloat((int >> 8) & 0xFF) / 255
                let b = CGFloat(int & 0xFF) / 255
                return UIColor(red: r, green: g, blue: b, alpha: 1)
            })
        }

        private static func adaptiveOpacity(lightBase: UIColor, lightAlpha: CGFloat, darkBase: UIColor, darkAlpha: CGFloat) -> SwiftUI.Color {
            SwiftUI.Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? darkBase.withAlphaComponent(darkAlpha)
                    : lightBase.withAlphaComponent(lightAlpha)
            })
        }

        // Surfaces — off-white page + white cards (Airbnb layering)
        static let backgroundPrimary   = adaptive(light: "F7F7F7", dark: "000000")
        static let backgroundSecondary = adaptive(light: "FFFFFF", dark: "1A1A1A")
        static let backgroundElevated  = adaptive(light: "FFFFFF", dark: "222222")
        static let backgroundSubtle    = adaptive(light: "F0F0F0", dark: "2A2A2A")

        // Text — 4-tier Airbnb hierarchy
        static let textPrimary   = adaptive(light: "222222", dark: "F5F5F5")
        static let textSecondary = adaptive(light: "717171", dark: "A0A0A0")
        static let textTertiary  = adaptive(light: "B0B0B0", dark: "6B6B6B")

        // Brand
        static let brandPink = SwiftUI.Color(hex: "FF385C")

        // Macros
        static let protein = adaptive(light: "3B82F6", dark: "60A5FA")
        static let carbs   = adaptive(light: "D97706", dark: "F59E0B")
        static let fat     = adaptive(light: "9333EA", dark: "A855F7")

        // Status
        static let success = adaptive(light: "008A05", dark: "34C759")
        static let danger  = adaptive(light: "D93030", dark: "FF453A")

        // Borders — hairline Airbnb style
        static let border       = adaptive(light: "EBEBEB", dark: "2A2A2A")
        static let borderStrong = adaptive(light: "DDDDDD", dark: "3A3A3A")

        // Semantic
        static let ringTrack       = adaptiveOpacity(lightBase: .black, lightAlpha: 0.04, darkBase: .white, darkAlpha: 0.06)
        static let overlayText     = adaptive(light: "222222", dark: "FFFFFF")
        static let dimming         = adaptiveOpacity(lightBase: .black, lightAlpha: 0.3, darkBase: .black, darkAlpha: 0.5)
        static let shadowColor     = adaptiveOpacity(lightBase: .black, lightAlpha: 0.04, darkBase: .black, darkAlpha: 0.15)
        static let heroTextShadow  = adaptiveOpacity(lightBase: .white, lightAlpha: 0.5, darkBase: .black, darkAlpha: 0.3)
        static let iconThumbnailBg = adaptiveOpacity(lightBase: .black, lightAlpha: 0.04, darkBase: .white, darkAlpha: 0.06)
    }

    // MARK: Spacing (8px grid)

    enum Spacing {
        static let xs: CGFloat  = 4
        static let s: CGFloat   = 8
        static let m: CGFloat   = 16
        static let l: CGFloat   = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48
        static let screenEdge: CGFloat = 24
    }

    // MARK: Radius

    enum Radius {
        static let s: CGFloat  = 8
        static let m: CGFloat  = 12
        static let l: CGFloat  = 16
        static let xl: CGFloat = 24
    }

    // MARK: Border

    enum Border {
        static let hairline: CGFloat = 0.5
        static let regular: CGFloat = 1.0
    }

    // MARK: Typography

    enum Typography {
        static let displayL = Font.system(size: 32, weight: .bold)
        static let displayM = Font.system(size: 22, weight: .semibold)
        static let numberL  = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let numberM  = Font.system(size: 17, weight: .medium, design: .rounded)
        static let labelL   = Font.system(size: 16, weight: .semibold)
        static let labelM   = Font.system(size: 14, weight: .medium)
        static let labelS   = Font.system(size: 12, weight: .semibold)
        static let caption   = Font.system(size: 12, weight: .regular)
        static let sectionLabel = Font.system(size: 11, weight: .bold)
    }

    // MARK: Gradient

    enum Gradient {
        static let calorieRing = AngularGradient(
            colors: [SwiftUI.Color(hex: "FF385C"), SwiftUI.Color(hex: "FF6B81"), SwiftUI.Color(hex: "FF385C")],
            center: .center
        )

        static let cardShimmer = LinearGradient(
            colors: [DS.Color.backgroundSecondary, DS.Color.backgroundSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let heroGlow = RadialGradient(
            colors: [SwiftUI.Color(hex: "FF385C").opacity(0.06), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )

        static let plusButton = LinearGradient(
            colors: [SwiftUI.Color(hex: "E31C5F"), SwiftUI.Color(hex: "FF385C")],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let ctaButton = LinearGradient(
            colors: [SwiftUI.Color(hex: "D03660"), SwiftUI.Color(hex: "D73B53")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - App Card Modifier

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(DS.Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                            .strokeBorder(DS.Color.border, lineWidth: DS.Border.hairline)
                    )
            )
    }
}

extension View {
    func appCard() -> some View { modifier(AppCardModifier()) }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Macro Pill

struct MacroPill: View {
    let value: String
    let unit: String
    let color: SwiftUI.Color

    var body: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - Calorie Ring

struct CalorieRing: View {
    let consumed: Int
    let goal: Int
    var size: CGFloat = 200
    let lineWidth: CGFloat = 16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    private var targetProgress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(consumed) / Double(goal), 1.0)
    }

    private var remaining: Int { goal - consumed }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.Color.ringTrack, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            SwiftUI.Color(hex: "FF385C"),
                            SwiftUI.Color(hex: "FF6B81"),
                            SwiftUI.Color(hex: "FF385C"),
                            SwiftUI.Color(hex: "FF385C"),
                        ],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * animatedProgress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: SwiftUI.Color(hex: "FF385C").opacity(0.25), radius: 8)

            VStack(spacing: 2) {
                Text("\(consumed)")
                    .font(.system(size: 44, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(DS.Color.textPrimary)
                    .contentTransition(.numericText())
                if goal > 0 {
                    Text("/ \(goal) cal")
                        .font(DS.Typography.labelM)
                        .foregroundStyle(DS.Color.textSecondary)
                    Text("\(abs(remaining)) \(remaining >= 0 ? "left" : "over")")
                        .font(DS.Typography.caption)
                        .foregroundStyle(remaining >= 0 ? DS.Color.brandPink : DS.Color.danger)
                        .contentTransition(.numericText())
                } else {
                    Text("calories")
                        .font(DS.Typography.labelM)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion {
                animatedProgress = targetProgress
            } else {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                    animatedProgress = targetProgress
                }
            }
        }
        .onChange(of: targetProgress) { _, newValue in
            if reduceMotion {
                animatedProgress = newValue
            } else {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                    animatedProgress = newValue
                }
            }
        }
    }
}

// MARK: - Macro Arc

struct MacroArc: View {
    let label: String
    let current: Double
    let goal: Double
    let color: SwiftUI.Color
    var arcSize: CGFloat = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    private var targetProgress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    private var isOver: Bool { goal > 0 && current > goal }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(DS.Color.ringTrack, lineWidth: 4)
                    .frame(width: arcSize, height: arcSize)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        isOver ? DS.Color.danger : color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: arcSize, height: arcSize)

                VStack(spacing: 0) {
                    Text("\(Int(current))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isOver ? DS.Color.danger : DS.Color.textPrimary)
                    Text("g")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Text(label.uppercased())
                .font(DS.Typography.sectionLabel)
                .foregroundStyle(DS.Color.textSecondary)
                .tracking(1.0)

            if goal > 0 {
                Text("/ \(Int(goal))g")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(DS.Color.textTertiary)
            }
        }
        .onAppear {
            if reduceMotion {
                animatedProgress = targetProgress
            } else {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                    animatedProgress = targetProgress
                }
            }
        }
        .onChange(of: targetProgress) { _, newValue in
            if reduceMotion {
                animatedProgress = newValue
            } else {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                    animatedProgress = newValue
                }
            }
        }
    }
}
