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
        // Adaptive helper: returns a Color that switches between light/dark hex values
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

        static let backgroundPrimary   = adaptive(light: "F2F2F7", dark: "0A0D12")
        static let backgroundSecondary = adaptive(light: "FFFFFF", dark: "12161E")
        static let backgroundElevated  = adaptive(light: "FFFFFF", dark: "1A1F2B")
        static let backgroundSubtle    = adaptive(light: "F0F0F5", dark: "1F2535")

        static let textPrimary   = adaptive(light: "1C1C1E", dark: "F0F3FA")
        static let textSecondary = adaptive(light: "6C6C70", dark: "9BA3B5")
        static let textTertiary  = adaptive(light: "AEAEB2", dark: "4E566A")

        static let protein = adaptive(light: "3478F6", dark: "4D8CF5")
        static let carbs   = adaptive(light: "E09500", dark: "F5A623")
        static let fat     = adaptive(light: "8F5DE0", dark: "A776F5")

        static let success = adaptive(light: "28A060", dark: "34C77B")
        static let danger  = adaptive(light: "D93030", dark: "F05A5A")

        static let border       = adaptiveOpacity(lightBase: .black, lightAlpha: 0.08, darkBase: .white, darkAlpha: 0.07)
        static let borderStrong = adaptiveOpacity(lightBase: .black, lightAlpha: 0.15, darkBase: .white, darkAlpha: 0.12)

        // Semantic tokens
        static let ringTrack       = adaptiveOpacity(lightBase: .black, lightAlpha: 0.06, darkBase: .white, darkAlpha: 0.06)
        static let overlayText     = adaptive(light: "1C1C1E", dark: "FFFFFF")
        static let dimming         = adaptiveOpacity(lightBase: .black, lightAlpha: 0.3, darkBase: .black, darkAlpha: 0.5)
        static let shadowColor     = adaptiveOpacity(lightBase: .black, lightAlpha: 0.1, darkBase: .black, darkAlpha: 0.25)
        static let heroTextShadow  = adaptiveOpacity(lightBase: .white, lightAlpha: 0.5, darkBase: .black, darkAlpha: 0.3)
        static let iconThumbnailBg = adaptiveOpacity(lightBase: .black, lightAlpha: 0.05, darkBase: .white, darkAlpha: 0.05)
    }

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat  = 4
        static let s: CGFloat   = 8
        static let m: CGFloat   = 16
        static let l: CGFloat   = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48
        static let screenEdge: CGFloat = 20
    }

    // MARK: Radius

    enum Radius {
        static let s: CGFloat  = 10
        static let m: CGFloat  = 16
        static let l: CGFloat  = 24
        static let xl: CGFloat = 32
    }

    // MARK: Typography

    enum Typography {
        static let displayL = Font.system(size: 56, weight: .bold, design: .default)
        static let displayM = Font.system(size: 36, weight: .semibold, design: .default)
        static let numberL  = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let numberM  = Font.system(size: 17, weight: .medium, design: .rounded)
        static let labelL   = Font.system(size: 15, weight: .medium, design: .rounded)
        static let labelM   = Font.system(size: 13, weight: .medium, design: .rounded)
        static let labelS   = Font.system(size: 11, weight: .semibold, design: .rounded)
        static let caption   = Font.system(size: 12, weight: .regular, design: .rounded)
    }

    // MARK: Gradient

    enum Gradient {
        static let calorieRing = AngularGradient(
            colors: [DS.Color.protein, DS.Color.fat, DS.Color.protein],
            center: .center
        )

        static let cardShimmer = LinearGradient(
            colors: [DS.Color.backgroundElevated, DS.Color.backgroundSubtle],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let heroGlow = RadialGradient(
            colors: [DS.Color.protein.opacity(0.08), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )

        static let plusButton = LinearGradient(
            colors: [DS.Color.protein, DS.Color.fat],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
                            .strokeBorder(DS.Color.border, lineWidth: 1)
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
    let unit: String   // "P", "C", "F"
    let color: SwiftUI.Color

    var body: some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color.opacity(0.7))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Calorie Ring

struct CalorieRing: View {
    let consumed: Int
    let goal: Int
    var size: CGFloat = 200
    let lineWidth: CGFloat = 18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    private var targetProgress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(consumed) / Double(goal), 1.0)
    }

    private var remaining: Int { goal - consumed }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(DS.Color.ringTrack, lineWidth: lineWidth)

            // Ring with glow via shadow
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [DS.Color.protein, DS.Color.protein, DS.Color.fat, DS.Color.fat],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * animatedProgress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: DS.Color.protein.opacity(0.5), radius: 10)
                .shadow(color: DS.Color.fat.opacity(0.3), radius: 16)

            // Center content
            VStack(spacing: 2) {
                Text("\(consumed)")
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(DS.Color.textPrimary)
                    .contentTransition(.numericText())
                if goal > 0 {
                    Text("/ \(goal) cal")
                        .font(DS.Typography.labelM)
                        .foregroundStyle(DS.Color.textSecondary)
                    Text("\(abs(remaining)) \(remaining >= 0 ? "left" : "over")")
                        .font(DS.Typography.caption)
                        .foregroundStyle(remaining >= 0 ? DS.Color.protein : DS.Color.danger)
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
                    .stroke(DS.Color.ringTrack, lineWidth: 5)
                    .frame(width: arcSize, height: arcSize)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        isOver ? DS.Color.danger : color,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: arcSize, height: arcSize)
                    .shadow(color: color.opacity(0.4), radius: 4)

                VStack(spacing: 0) {
                    Text("\(Int(current))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isOver ? DS.Color.danger : DS.Color.textPrimary)
                    Text("g")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Text(label)
                .font(DS.Typography.labelS)
                .foregroundStyle(DS.Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            if goal > 0 {
                Text("/ \(Int(goal))g")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
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
