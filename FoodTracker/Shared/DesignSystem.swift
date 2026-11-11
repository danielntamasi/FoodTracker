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

    /// Rounder on iOS 26 so cards sit concentric with the glass controls and the
    /// larger sheet and list-section corners.
    enum Radius {
        static var s: CGFloat  { isGlass ? 14 : 10 }
        static var m: CGFloat  { isGlass ? 22 : 16 }
        static var l: CGFloat  { isGlass ? 28 : 24 }
        static var xl: CGFloat { isGlass ? 36 : 32 }

        private static var isGlass: Bool {
            if #available(iOS 26, *) { return true }
            return false
        }
    }

    // MARK: Typography

    enum Typography {
        static let displayL  = Font.system(.largeTitle, design: .default, weight: .bold)
        static let displayM  = Font.system(.title, design: .default, weight: .semibold)
        static let numberL   = Font.system(.title2, design: .rounded, weight: .semibold)
        static let numberM   = Font.system(.body, design: .rounded, weight: .medium)
        static let headline  = Font.system(.headline, design: .default, weight: .semibold)
        static let subhead   = Font.system(.subheadline, design: .default, weight: .regular)
        static let labelL    = Font.system(.subheadline, design: .rounded, weight: .medium)
        static let labelM    = Font.system(.footnote, design: .rounded, weight: .medium)
        static let labelS    = Font.system(.caption2, design: .rounded, weight: .semibold)
        static let caption   = Font.system(.caption, design: .rounded, weight: .regular)
        static let caption2  = Font.system(.caption2, design: .rounded, weight: .regular)
    }

    // MARK: Icons

    /// One symbol per nutrient, shown in its color wherever totals or goals appear
    enum Icon {
        static let calories = "flame.fill"
        static let protein = "dumbbell.fill"   // muscle
        static let carbs = "bolt.fill"         // quick energy
        static let fat = "drop.fill"           // oil
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

struct AppCardSubtleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                    .fill(DS.Color.backgroundSubtle)
            )
    }
}

struct AppCardHighlightModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(color.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                            .strokeBorder(color.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func appCard() -> some View { modifier(AppCardModifier()) }
    func appCardSubtle() -> some View { modifier(AppCardSubtleModifier()) }
    func appCardHighlight(_ color: Color = DS.Color.protein) -> some View { modifier(AppCardHighlightModifier(color: color)) }
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
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        // Never squeezed into two lines in a tight row ("24." over "3"); the name truncates instead
        .fixedSize()
    }
}

/// Icon and title with a small gap (the default label spacing is wide for inline status text)
struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - Goal Tone

/// How a running daily total sits against its goal. Landing within ±10% is a win (green
/// with a check); only clearly overshooting is flagged: orange up to 20% over, red beyond.
/// Below the band the total is just in progress and keeps its normal color.
enum GoalTone: Equatable {
    case inProgress, onTarget, over, wayOver

    init(current: Double, goal: Double) {
        guard goal > 0 else { self = .inProgress; return }
        let ratio = current / goal
        if ratio < PerformanceThresholds.onTargetLow {
            self = .inProgress
        } else if ratio <= PerformanceThresholds.onTargetHigh {
            self = .onTarget
        } else if ratio <= PerformanceThresholds.severeOverThreshold {
            self = .over
        } else {
            self = .wayOver
        }
    }

    /// Rings keep their own color; only way over turns them red. The check/X marks
    /// and status text use `color(normal:)`.
    func ringColor(normal: SwiftUI.Color) -> SwiftUI.Color {
        self == .wayOver ? DS.Color.danger : normal
    }

    func color(normal: SwiftUI.Color) -> SwiftUI.Color {
        switch self {
        case .inProgress: return normal
        case .onTarget: return DS.Color.success
        case .over: return DS.Color.carbs
        case .wayOver: return DS.Color.danger
        }
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

    /// Consumed / goal, up to 3 (the gauge stops opening there)
    private var targetProgress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(consumed) / Double(goal), 3.0)
    }

    private var remaining: Int { goal - consumed }
    private var tone: GoalTone { GoalTone(current: Double(consumed), goal: Double(goal)) }

    /// Blue-to-purple up to the goal; whatever goes past it is drawn red
    private let ringColors: [SwiftUI.Color] = [DS.Color.protein, DS.Color.fat]

    /// "734 left", "✓ On target" or "✗ 350 over" in the tone's color
    @ViewBuilder
    private var statusLabel: some View {
        switch tone {
        case .onTarget:
            Label("On target", systemImage: "checkmark.seal.fill")
                .labelStyle(TightLabelStyle())
                .foregroundStyle(DS.Color.success)
                .symbolEffect(.bounce, value: tone)
        case .over, .wayOver:
            Label("\(abs(remaining)) over", systemImage: "xmark.circle.fill")
                .labelStyle(TightLabelStyle())
                .foregroundStyle(tone.color(normal: DS.Color.protein))
                .contentTransition(.numericText())
        case .inProgress:
            Text("\(remaining) left")
                .foregroundStyle(DS.Color.protein)
                .contentTransition(.numericText())
        }
    }

    private var glowColors: (SwiftUI.Color, SwiftUI.Color) {
        tone == .wayOver ? (DS.Color.danger, DS.Color.danger) : (DS.Color.protein, DS.Color.fat)
    }

    var body: some View {
        ZStack {
            // Gauge with glow via shadow
            CalorieGauge(progress: animatedProgress, colors: ringColors, lineWidth: lineWidth, size: size)
                .shadow(color: glowColors.0.opacity(0.5), radius: 10)
                .shadow(color: glowColors.1.opacity(0.3), radius: 16)
                .animation(.easeInOut(duration: 0.4), value: tone)

            // Center content
            VStack(spacing: 2) {
                Image(systemName: DS.Icon.calories)
                    .font(.title3)
                    .foregroundStyle(LinearGradient(colors: [DS.Color.protein, DS.Color.fat], startPoint: .top, endPoint: .bottom))
                    .accessibilityHidden(true)
                Text("\(consumed)")
                    .font(.system(size: 48, weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(DS.Color.textPrimary)
                    .contentTransition(.numericText())
                if goal > 0 {
                    // Goal and status share one line to keep the ring's center light
                    HStack(spacing: 4) {
                        Text("of \(goal.formatted())")
                            .foregroundStyle(DS.Color.textSecondary)
                        Text("·")
                            .foregroundStyle(DS.Color.textTertiary)
                        statusLabel
                    }
                    .font(DS.Typography.labelM)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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

/// The calorie gauge: an open 270° arc (gap at the bottom) whose length adapts to the day.
/// Below 90% of the goal the whole arc is the goal, so the fill reads as share of the day. From 90% it
/// opens until the arc runs to 110% of the goal at the goal, and past the goal it keeps 10% of the goal
/// ahead of the tip (`scale`). A goal line fades in as it opens. Blue to purple up to the goal, then red
/// with a flat join and one rounded tip. `Animatable`, so it's redrawn every frame and the arc opens with the fill.
private struct CalorieGauge: View, Animatable {
    var progress: Double
    let colors: [SwiftUI.Color]
    let lineWidth: CGFloat
    let size: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Share of the full circle the gauge covers
    private let span = 0.75
    /// Room kept past the goal (and ahead of the tip once over), as a share of the goal
    private static let room = 0.1

    /// What the full arc stands for, in goals: 1 until 90%, then always `room` ahead of the fill
    private var scale: Double { max(1, progress + Self.room) }

    var body: some View {
        let goalAt = span / scale
        let fill = span * progress / scale
        ZStack {
            Group {
                Circle()
                    .trim(from: 0, to: span)
                    .stroke(DS.Color.ringTrack, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                if fill > 0 {
                    Circle()
                        .trim(from: 0, to: min(fill, goalAt))
                        .stroke(
                            AngularGradient(colors: colors, center: .center,
                                            startAngle: .degrees(0), endAngle: .degrees(360 * goalAt)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                }
                if fill > goalAt {
                    Circle()
                        .trim(from: goalAt, to: fill)
                        .stroke(DS.Color.danger, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    // The rounded tip (the join at the goal stays flat)
                    Circle()
                        .trim(from: max(goalAt, fill - 0.001), to: fill)
                        .stroke(DS.Color.danger, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }
            // Trim starts at 3 o'clock; turned so the gauge starts at the bottom left
            .rotationEffect(.degrees(135))

            // Goal line, turned from 12 o'clock to where the goal falls; fades in as the arc opens
            Capsule()
                .fill(DS.Color.textPrimary.opacity(0.55))
                .frame(width: 2.5, height: lineWidth + 8)
                .offset(y: -size / 2)
                .rotationEffect(.degrees(135 + 360 * goalAt - 270))
                .opacity(min(1, (scale - 1) / 0.04))
        }
    }
}

// MARK: - Macro Arc

struct MacroArc: View {
    let label: String
    var icon: String? = nil
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

    private var tone: GoalTone { GoalTone(current: current, goal: goal) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(DS.Color.ringTrack, lineWidth: 5)
                    .frame(width: arcSize, height: arcSize)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        tone.ringColor(normal: color),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: arcSize, height: arcSize)
                    .shadow(color: tone.ringColor(normal: color).opacity(0.4), radius: 4)

                VStack(spacing: 0) {
                    Text("\(Int(current))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tone == .wayOver ? DS.Color.danger : DS.Color.textPrimary)
                    // The unit turns into a mark once the goal is settled: a green check
                    // in the goal band, an X in orange/red when over
                    if tone != .inProgress {
                        Image(systemName: tone == .onTarget ? "checkmark" : "xmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(tone.color(normal: color))
                            .frame(height: 13)
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityLabel(tone == .onTarget ? "On target" : "Over goal")
                    } else {
                        Text("g")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(DS.Color.textSecondary)
                            .frame(height: 13)
                    }
                }
                .animation(.spring(duration: 0.4, bounce: 0.4), value: tone)
            }

            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                }
                Text(label)
                    .foregroundStyle(DS.Color.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .font(DS.Typography.labelS)

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

// MARK: - Liquid Glass

// Liquid Glass (iOS 26) is for the controls layer floating above content: bars,
// floating buttons, camera/photo overlays. Content (cards, rows) stays on solid
// DS colors. Before iOS 26 these fall back to the ultra-thin material look.

extension View {
    /// Glass behind a floating control. `clear` is for controls over photos or the camera.
    /// Also makes the whole shape tappable: glass isn't hit-testable, so a button label
    /// would otherwise only take taps on its text or glyph.
    func glassControl<S: Shape>(in shape: S, tint: SwiftUI.Color? = nil, clear: Bool = false, interactive: Bool = true) -> some View {
        glassBackground(in: shape, tint: tint, clear: clear, interactive: interactive)
            .contentShape(shape)
    }

    @ViewBuilder
    private func glassBackground<S: Shape>(in shape: S, tint: SwiftUI.Color?, clear: Bool, interactive: Bool) -> some View {
        if #available(iOS 26, *) {
            glassEffect((clear ? Glass.clear : .regular).tint(tint).interactive(interactive), in: shape)
        } else if let tint {
            background(tint, in: shape)
        } else {
            background(.ultraThinMaterial.opacity(clear ? 0.6 : 1), in: shape)
        }
    }

    func glassControl(tint: SwiftUI.Color? = nil, clear: Bool = false, interactive: Bool = true) -> some View {
        glassControl(in: Capsule(), tint: tint, clear: clear, interactive: interactive)
    }

    /// Identity for morphing between glass shapes inside a `GlassGroup`.
    @ViewBuilder
    func glassID(_ id: some Hashable & Sendable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26, *) {
            glassEffectID(id, in: namespace)
        } else {
            self
        }
    }

    /// `.glass` / `.glassProminent` button style, `.bordered` / `.borderedProminent` before iOS 26.
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }
}

extension View {
    /// A bar pinned to the bottom edge. On iOS 26 it's a `safeAreaBar`, so content scrolling
    /// under it gets the scroll edge effect; before, a `safeAreaInset` on `fallbackBackground`.
    @ViewBuilder
    func bottomBar<Bar: View>(fallbackBackground: some ShapeStyle = .ultraThinMaterial, @ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .bottom) { bar() }
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) { bar().background(fallbackBackground) }
        }
    }

    /// A hard scroll edge under a `bottomBar` (iOS 26): content scrolling behind several controls is
    /// covered instead of only softly faded, so text doesn't show through the glass buttons.
    @ViewBuilder
    func hardBottomEdge() -> some View {
        if #available(iOS 26, *) {
            scrollEdgeEffectStyle(.hard, for: .bottom)
        } else {
            self
        }
    }
}

/// `GlassEffectContainer` on iOS 26 (shared rendering + morphing), a plain wrapper before.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// Toolbar dismiss button: the system glass xmark on iOS 26, "Cancel" before.
struct CloseButton: View {
    var title: String = "Cancel"
    let action: () -> Void

    var body: some View {
        if #available(iOS 26, *) {
            Button(role: .close, action: action)
                .accessibilityLabel(title)
        } else {
            Button(title, action: action)
        }
    }
}

/// Toolbar confirm button: the system prominent checkmark on iOS 26, the title before.
struct ConfirmButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        if #available(iOS 26, *) {
            Button(role: .confirm, action: action)
                .accessibilityLabel(title)
        } else {
            Button(title, action: action)
        }
    }
}
