import SwiftUI

enum AppTab {
    case today, history, settings
}

enum QuickAddAction {
    case chat, barcode, search, browse, buildMeal
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var activeTab: AppTab = .today
    @State private var todayViewID = Calendar.current.startOfDay(for: Date())
    @State private var showingRadialMenu = false
    @State private var showingAddEntry = false
    @State private var showingChat = false
    @State private var showingBarcodeScanner = false
    @State private var showingBrowse = false
    @State private var showingSearch = false
    @State private var showingBuildMeal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var layoutHeight: CGFloat = 700
    @State private var layoutWidth: CGFloat = 393

    private let radialItems: [(icon: String, label: String, action: QuickAddAction)] = [
        ("clock.arrow.circlepath", "Recent", .browse),
        ("magnifyingglass", "Search", .search),
        ("sparkles", "AI Chat", .chat),
        ("square.stack.3d.up", "Build", .buildMeal),
        ("barcode.viewfinder", "Barcode", .barcode),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch activeTab {
                case .today:
                    DailySummaryView()
                        .id(todayViewID)
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    let newStart = Calendar.current.startOfDay(for: Date())
                    if newStart != todayViewID { todayViewID = newStart }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 110)
            }

            // Dimming backdrop
            if showingRadialMenu {
                DS.Color.dimming
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            showingRadialMenu = false
                        }
                    }
            }

            floatingTabBar
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        layoutHeight = geo.size.height
                        layoutWidth = geo.size.width
                    }
                    .onChange(of: geo.size) { _, s in
                        layoutHeight = s.height
                        layoutWidth = s.width
                    }
            }
        )
        .sheet(isPresented: $showingAddEntry) {
            AddEntryView()
        }
        .sheet(isPresented: $showingChat) {
            FoodChatView()
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            BarcodeScannerView()
        }
        .sheet(isPresented: $showingBrowse) {
            BrowseFoodsView()
        }
        .sheet(isPresented: $showingSearch) {
            SearchFoodView()
        }
        .sheet(isPresented: $showingBuildMeal) {
            BuildMealView()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            // Capture the screen before the feedback sheet covers it
            let screenshot = FeedbackPresenter.screenshot()
            FeedbackPresenter.present(context: FeedbackService.makeContext(screenshot: screenshot, modelContext: modelContext))
        }
    }

    // MARK: - Deep Link

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "foodtracker", url.host == "add" else { return }
        activeTab = .today
        showingAddEntry = false
        showingChat = false
        showingBarcodeScanner = false
        showingBrowse = false
        showingSearch = false
        showingBuildMeal = false
        showingRadialMenu = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                showingRadialMenu = true
            }
        }
    }

    // MARK: - Radial Menu

    /// Offset from the + button center for each radial item.
    /// Fixed values — no screen geometry needed. Negative Y = upward.
    private func radialOffset(for index: Int) -> CGSize {
        let spacing: CGFloat = 56
        let archCurve: CGFloat = 20
        let riseAboveButton: CGFloat = 100
        // The + button is the 3rd of 4 items: [Today][History][+][Settings]
        // With 3 flex tabs + 1 fixed 52pt button + 56pt total padding,
        // the button sits (layoutWidth - 108) / 6 to the right of screen center.
        // Shift items left by that amount so they land at screen center.
        let buttonOffsetFromCenter = (layoutWidth - 108) / 6
        let midIndex = Double(radialItems.count - 1) / 2.0
        let dx = CGFloat(Double(index) - midIndex) * spacing - buttonOffsetFromCenter
        let normalizedX = CGFloat(Double(index) - midIndex) / midIndex
        let archDy = archCurve * normalizedX * normalizedX
        return CGSize(width: dx, height: -riseAboveButton + archDy)
    }

    private func radialMenuItem(index: Int, item: (icon: String, label: String, action: QuickAddAction)) -> some View {
        let offset = radialOffset(for: index)

        return Button {
            let action = item.action
            withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                showingRadialMenu = false
            } completion: {
                triggerAction(action)
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Color.overlayText)
                    .frame(width: 52, height: 52)
                    .background(DS.Color.backgroundElevated)
                    .clipShape(Circle())
                    .shadow(color: DS.Color.protein.opacity(0.2), radius: 6, y: 2)
                Text(item.label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Color.textPrimary)
            }
        }
        .accessibilityLabel(item.label)
        .buttonStyle(.plain)
        .offset(x: showingRadialMenu ? offset.width : 0,
                y: showingRadialMenu ? offset.height : 0)
        .scaleEffect(showingRadialMenu ? 1 : 0.01)
        .opacity(showingRadialMenu ? 1 : 0)
        .animation(
            reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.45, bounce: 0.35).delay(Double(index) * 0.03),
            value: showingRadialMenu
        )
    }

    private func triggerAction(_ action: QuickAddAction) {
        switch action {
        case .chat: showingChat = true
        case .barcode: showingBarcodeScanner = true
        case .search: showingSearch = true
        case .browse: showingBrowse = true
        case .buildMeal: showingBuildMeal = true
        }
    }

    // MARK: - Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "fork.knife", filledIcon: "fork.knife", label: "Today", tab: .today)
            tabItem(icon: "calendar", filledIcon: "calendar", label: "History", tab: .history)

            Button {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                    showingRadialMenu.toggle()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(DS.Gradient.plusButton)
                    .clipShape(Circle())
                    .shadow(color: DS.Color.protein.opacity(0.4), radius: 12, y: 4)
                    .rotationEffect(.degrees(showingRadialMenu ? 45 : 0))
            }
            .accessibilityLabel(showingRadialMenu ? "Close menu" : "Add food")
            .buttonStyle(ScaleButtonStyle())
            .overlay {
                ForEach(Array(radialItems.enumerated()), id: \.offset) { index, item in
                    radialMenuItem(index: index, item: item)
                }
            }

            tabItem(icon: "gearshape", filledIcon: "gearshape.fill", label: "Settings", tab: .settings)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.l)
                .fill(DS.Color.backgroundPrimary.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.l)
                        .fill(.ultraThinMaterial)
                )
                .shadow(color: DS.Color.shadowColor, radius: 12, y: 4)
        )
        .padding(.horizontal, DS.Spacing.screenEdge)
        .padding(.bottom, 8)
    }

    private func tabItem(icon: String, filledIcon: String, label: String, tab: AppTab) -> some View {
        let isActive = activeTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isActive ? filledIcon : icon)
                    .font(.body)
                    .symbolEffect(.bounce, value: activeTab)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(isActive ? DS.Color.protein : DS.Color.textTertiary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .buttonStyle(.plain)
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

