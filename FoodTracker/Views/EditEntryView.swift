import SwiftUI
import SwiftData
import Charts
import AVFoundation

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var entry: FoodEntry

    @State private var isEditing = false
    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var extractedColor: Color?
    @State private var showingBarcodeScanner = false

    // Snapshot of original values for Cancel support
    @State private var originalName = ""
    @State private var originalCalories = 0
    @State private var originalProtein = 0.0
    @State private var originalCarbs = 0.0
    @State private var originalFat = 0.0
    @State private var originalDate = Date()
    @State private var servings: Double = 1.0

    private let servingPresets: [Double] = stride(from: 0.25, through: 3.0, by: 0.25).map { $0 }

    private var entryImage: UIImage? {
        guard let data = entry.photoData else { return nil }
        return UIImage(data: data)
    }

    /// Background color: extracted from photo bottom edge, or derived from food icon category
    private var bgColor: Color {
        extractedColor ?? iconDerivedBgColor
    }

    private var iconDerivedBgColor: Color {
        let iconName = entry.iconName ?? foodIconName(for: entry.name)
        switch iconName {
        case "bird": return Color(red: 0.15, green: 0.10, blue: 0.05)
        case "flame": return Color(red: 0.21, green: 0.09, blue: 0.05)
        case "fish": return Color(red: 0.05, green: 0.15, blue: 0.15)
        case "egg": return Color(red: 0.22, green: 0.19, blue: 0.08)
        case "cup.and.saucer": return Color(red: 0.14, green: 0.09, blue: 0.05)
        case "cup.and.saucer.fill": return Color(red: 0.10, green: 0.15, blue: 0.20)
        case "waterbottle": return Color(red: 0.05, green: 0.15, blue: 0.18)
        case "wineglass": return Color(red: 0.15, green: 0.05, blue: 0.10)
        case "birthday.cake": return Color(red: 0.18, green: 0.08, blue: 0.12)
        case "takeoutbag.and.cup.and.straw": return Color(red: 0.20, green: 0.12, blue: 0.05)
        case "triangle": return Color(red: 0.22, green: 0.08, blue: 0.05)
        case "leaf": return Color(red: 0.05, green: 0.15, blue: 0.05)
        case "carrot": return Color(red: 0.24, green: 0.14, blue: 0.05)
        case "leaf.circle": return Color(red: 0.12, green: 0.15, blue: 0.08)
        case "chart.bar": return Color(red: 0.10, green: 0.12, blue: 0.18)
        case "snowflake": return Color(red: 0.12, green: 0.19, blue: 0.22)
        case "bowl": return Color(red: 0.20, green: 0.14, blue: 0.06)
        default: return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }

    // MARK: - Macro Calculations

    private var proteinCals: Double { entry.proteinGrams * 4 }
    private var carbsCals: Double { entry.carbsGrams * 4 }
    private var fatCals: Double { entry.fatGrams * 9 }
    private var totalMacroCals: Double { proteinCals + carbsCals + fatCals }

    private var proteinPct: Int {
        guard totalMacroCals > 0 else { return 0 }
        return Int((proteinCals / totalMacroCals * 100).rounded())
    }
    private var carbsPct: Int {
        guard totalMacroCals > 0 else { return 0 }
        return Int((carbsCals / totalMacroCals * 100).rounded())
    }
    private var fatPct: Int {
        guard totalMacroCals > 0 else { return 0 }
        return Int((fatCals / totalMacroCals * 100).rounded())
    }

    private var hasTargets: Bool {
        DailyTarget.calories > 0 || DailyTarget.protein > 0 || DailyTarget.carbs > 0 || DailyTarget.fat > 0
    }

    private var formattedTimestamp: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(entry.date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInYesterday(entry.date) {
            formatter.dateFormat = "'Yesterday at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }
        return formatter.string(from: entry.date)
    }

    private var nameChanged: Bool {
        isEditing && entry.name != originalName && !entry.name.isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mainBody
                floatingButtons
            }
        }
        .onAppear {
            if let uiImage = entryImage {
                extractedColor = dominantColor(from: uiImage)
            }
        }
        .sheet(isPresented: $showingBarcodeScanner) {
            EditBarcodeScannerView { product in
                entry.name = product.name
                entry.calories = product.calories
                entry.proteinGrams = product.proteinGrams
                entry.carbsGrams = product.carbsGrams
                entry.fatGrams = product.fatGrams
                entry.iconName = foodIconName(for: product.name)
            }
        }
    }

    // MARK: - Floating Buttons

    private var floatingButtons: some View {
        HStack {
            if isEditing {
                Button {
                    cancelEditing()
                } label: {
                    floatingButtonLabel("Cancel")
                }
                Spacer()
                Button {
                    finishEditing()
                } label: {
                    floatingButtonLabel("Done")
                }
            } else {
                Button {
                    startEditing()
                } label: {
                    floatingButtonLabel("Edit")
                }
                Spacer()
                Button { dismiss() } label: {
                    floatingButtonLabel("Done")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func startEditing() {
        originalName = entry.name
        originalCalories = entry.calories
        originalProtein = entry.proteinGrams
        originalCarbs = entry.carbsGrams
        originalFat = entry.fatGrams
        originalDate = entry.date
        servings = 1.0
        withAnimation(.easeInOut(duration: 0.25)) { isEditing = true }
    }

    private func cancelEditing() {
        entry.name = originalName
        entry.calories = originalCalories
        entry.proteinGrams = originalProtein
        entry.carbsGrams = originalCarbs
        entry.fatGrams = originalFat
        entry.date = originalDate
        servings = 1.0
        lookupError = nil
        withAnimation(.easeInOut(duration: 0.25)) { isEditing = false }
    }

    private func finishEditing() {
        if servings != 1.0 {
            entry.calories = Int((Double(entry.calories) * servings).rounded())
            entry.proteinGrams = (entry.proteinGrams * servings * 10).rounded() / 10
            entry.carbsGrams = (entry.carbsGrams * servings * 10).rounded() / 10
            entry.fatGrams = (entry.fatGrams * servings * 10).rounded() / 10
        }
        entry.name = entry.name.titleCased()
        entry.iconName = foodIconName(for: entry.name)
        lookupError = nil
        withAnimation(.easeInOut(duration: 0.25)) { isEditing = false }
    }

    private func floatingButtonLabel(_ title: String) -> some View {
        Text(title)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.6))
            .clipShape(Capsule())
    }

    // MARK: - Main Body (Immersive Hero)

    private var mainBody: some View {
        GeometryReader { fullGeo in
            ScrollView {
                VStack(spacing: 0) {
                    if let uiImage = entryImage {
                        ZStack(alignment: .bottom) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: fullGeo.size.width, height: fullGeo.size.height * 0.65)
                                .clipped()

                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: bgColor.opacity(0.3), location: 0.3),
                                    .init(color: bgColor.opacity(0.85), location: 0.7),
                                    .init(color: bgColor, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: fullGeo.size.height * 0.65 * 0.6)

                            VStack(spacing: 12) {
                                Text(entry.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

                                HStack(spacing: 12) {
                                    metricPill(value: "\(entry.calories)", label: "cal", color: .white)
                                    metricPill(value: formatMacro(entry.proteinGrams), label: "P", color: .blue)
                                    metricPill(value: formatMacro(entry.carbsGrams), label: "C", color: .orange)
                                    metricPill(value: formatMacro(entry.fatGrams), label: "F", color: .purple)
                                }

                                if totalMacroCals > 0 {
                                    macroDonut(size: 80)
                                }
                            }
                            .padding(.bottom, 16)
                            .padding(.horizontal, 16)
                        }
                        .frame(height: fullGeo.size.height * 0.65)
                    } else {
                        let iconName = entry.iconName ?? foodIconName(for: entry.name)
                        let iconClr = foodIconColor(for: iconName)

                        ZStack(alignment: .bottom) {
                            LinearGradient(
                                stops: [
                                    .init(color: iconClr.opacity(0.35), location: 0.0),
                                    .init(color: bgColor.opacity(0.6), location: 0.5),
                                    .init(color: bgColor, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: fullGeo.size.height * 0.55)

                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [iconClr.opacity(0.25), .clear],
                                                center: .center,
                                                startRadius: 20,
                                                endRadius: 90
                                            )
                                        )
                                        .frame(width: 180, height: 180)

                                    Image(systemName: iconName)
                                        .font(.system(size: 44, weight: .light))
                                        .foregroundStyle(iconClr)
                                        .frame(width: 88, height: 88)
                                        .background(iconClr.opacity(0.12))
                                        .clipShape(Circle())
                                }

                                Text(entry.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)

                                HStack(spacing: 12) {
                                    metricPill(value: "\(entry.calories)", label: "cal", color: .white)
                                    metricPill(value: formatMacro(entry.proteinGrams), label: "P", color: .blue)
                                    metricPill(value: formatMacro(entry.carbsGrams), label: "C", color: .orange)
                                    metricPill(value: formatMacro(entry.fatGrams), label: "F", color: .purple)
                                }

                                if totalMacroCals > 0 {
                                    macroDonut(size: 80)
                                }
                            }
                            .padding(.bottom, 16)
                            .padding(.horizontal, 16)
                        }
                        .frame(height: fullGeo.size.height * 0.55)
                    }

                    if isEditing {
                        editContent
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        VStack(spacing: 20) {
                            if hasTargets {
                                dailyGoalBars
                            }

                            Text(formattedTimestamp)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 4)
                        }
                        .padding(.top, 12)
                        .transition(.opacity)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(bgColor)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Macro Donut

    private func macroDonut(size: CGFloat) -> some View {
        let segments: [(name: String, cals: Double, color: Color)] = [
            ("Protein", proteinCals, .blue),
            ("Carbs", carbsCals, .orange),
            ("Fat", fatCals, .purple),
        ].filter { $0.cals > 0 }

        return HStack(spacing: 12) {
            Chart(segments, id: \.name) { segment in
                SectorMark(
                    angle: .value(segment.name, segment.cals),
                    innerRadius: .ratio(0.65),
                    angularInset: 2
                )
                .foregroundStyle(segment.color)
            }
            .chartLegend(.hidden)
            .frame(width: size, height: size)

            VStack(alignment: .leading, spacing: 4) {
                macroLabel(pct: proteinPct, name: "P", color: .blue)
                macroLabel(pct: carbsPct, name: "C", color: .orange)
                macroLabel(pct: fatPct, name: "F", color: .purple)
            }
        }
    }

    private func macroLabel(pct: Int, name: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(pct)% \(name)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Shared Components

    private func metricPill(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var dailyGoalBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("% of Daily Goal")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6))

            VStack(spacing: 8) {
                if DailyTarget.calories > 0 {
                    goalBar(
                        label: "Cal",
                        value: Double(entry.calories),
                        target: Double(DailyTarget.calories),
                        color: .gray
                    )
                }
                if DailyTarget.protein > 0 {
                    goalBar(
                        label: "Protein",
                        value: entry.proteinGrams,
                        target: Double(DailyTarget.protein),
                        color: .blue
                    )
                }
                if DailyTarget.carbs > 0 {
                    goalBar(
                        label: "Carbs",
                        value: entry.carbsGrams,
                        target: Double(DailyTarget.carbs),
                        color: .orange
                    )
                }
                if DailyTarget.fat > 0 {
                    goalBar(
                        label: "Fat",
                        value: entry.fatGrams,
                        target: Double(DailyTarget.fat),
                        color: .purple
                    )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func goalBar(label: String, value: Double, target: Double, color: Color) -> some View {
        let pct = target > 0 ? Int((value / target * 100).rounded()) : 0
        return HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 48, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(value / max(target, 1), 1.0), height: 6)
                }
            }
            .frame(height: 6)

            Text("\(pct)%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func formatMacro(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    private func formatServings(_ value: Double) -> String {
        let whole = Int(value)
        let frac = value - Double(whole)
        let fracStr: String?
        if abs(frac - 0.25) < 0.001 { fracStr = "\u{00BC}" }
        else if abs(frac - 0.5) < 0.001 { fracStr = "\u{00BD}" }
        else if abs(frac - 0.75) < 0.001 { fracStr = "\u{00BE}" }
        else if abs(frac) < 0.001 { fracStr = nil }
        else { return String(format: "%.2g", value) }

        if let f = fracStr {
            return whole > 0 ? "\(whole)\(f)" : f
        }
        return "\(whole)"
    }

    // MARK: - Color Extraction

    private func dominantColor(from image: UIImage) -> Color? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height

        let sampleHeight = max(height / 5, 1)
        let yOffset = height - sampleHeight
        guard let cropped = cgImage.cropping(to: CGRect(x: 0, y: yOffset, width: width, height: sampleHeight)) else { return nil }

        let ciImage = CIImage(cgImage: cropped)
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ])
        guard let outputImage = filter?.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)

        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0

        let darkenFactor: Double = colorScheme == .dark ? 0.3 : 0.55
        return Color(
            red: r * darkenFactor,
            green: g * darkenFactor,
            blue: b * darkenFactor
        )
    }

    // MARK: - Edit Content

    private var editContent: some View {
        VStack(spacing: 20) {
            groupedSection(header: "Food") {
                groupedRow {
                    Text("Name")
                    Spacer()
                    TextField("Name", text: $entry.name)
                        .textInputAutocapitalization(.sentences)
                        .multilineTextAlignment(.trailing)
                    if nameChanged {
                        HStack(spacing: 8) {
                            if isLookingUp {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Button { lookupNutrition() } label: {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                            Button { showingBarcodeScanner = true } label: {
                                Image(systemName: "barcode.viewfinder")
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: nameChanged)
                if let error = lookupError {
                    groupedDivider
                    groupedRow {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                groupedDivider
                groupedRow {
                    Text("Calories")
                    Spacer()
                    TextField("Calories", value: $entry.calories, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            groupedSection(header: "Macros (grams)") {
                groupedRow {
                    Text("Protein")
                    Spacer()
                    TextField("Protein", value: $entry.proteinGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                groupedDivider
                groupedRow {
                    Text("Carbs")
                    Spacer()
                    TextField("Carbs", value: $entry.carbsGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                groupedDivider
                groupedRow {
                    Text("Fat")
                    Spacer()
                    TextField("Fat", value: $entry.fatGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            groupedSection(header: "Servings") {
                groupedRow {
                    Text("Servings")
                    Spacer()
                    Text(formatServings(servings))
                        .foregroundStyle(.white.opacity(0.6))
                }
                groupedDivider
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(servingPresets, id: \.self) { preset in
                            Button {
                                servings = preset
                            } label: {
                                Text(formatServings(preset))
                                    .font(.subheadline)
                                    .fontWeight(servings == preset ? .bold : .regular)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        servings == preset
                                            ? Color.accentColor.opacity(0.3)
                                            : .white.opacity(0.1)
                                    )
                                    .foregroundStyle(
                                        servings == preset
                                            ? Color.accentColor
                                            : .white.opacity(0.7)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                groupedDivider
                groupedRow {
                    Text("Custom")
                    Spacer()
                    TextField("Servings", value: $servings, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                }
                if servings != 1.0 && entry.calories > 0 {
                    groupedDivider
                    groupedRow {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Total")
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int((Double(entry.calories) * servings).rounded())) cal")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            HStack {
                                Spacer()
                                coloredMacroText(
                                    protein: entry.proteinGrams * servings,
                                    carbs: entry.carbsGrams * servings,
                                    fat: entry.fatGrams * servings
                                )
                                .font(.caption)
                            }
                        }
                    }
                }
            }

            groupedSection(header: "Date & Time") {
                groupedRow {
                    DatePicker("", selection: $entry.date, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
        }
        .padding(.top, -20)
    }

    // MARK: - Grouped Section Helpers

    @ViewBuilder
    private func groupedSection<Content: View>(
        header: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let header {
                Text(header.uppercased())
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 36)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 36)
            }
        }
    }

    @ViewBuilder
    private func groupedRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var groupedDivider: some View {
        Divider().padding(.leading, 16)
    }

    // MARK: - USDA Lookup

    private func lookupNutrition() {
        isLookingUp = true
        lookupError = nil

        Task {
            do {
                let nutrients = try await USDAService.shared.lookupNutrients(for: entry.name)
                if nutrients.calories > 0 || nutrients.protein > 0 || nutrients.carbs > 0 || nutrients.fat > 0 {
                    entry.calories = Int(nutrients.calories)
                    entry.proteinGrams = (nutrients.protein * 10).rounded() / 10
                    entry.carbsGrams = (nutrients.carbs * 10).rounded() / 10
                    entry.fatGrams = (nutrients.fat * 10).rounded() / 10
                } else {
                    lookupError = "No nutrition data found for \"\(entry.name)\"."
                }
            } catch {
                lookupError = error.localizedDescription
            }
            isLookingUp = false
        }
    }
}

// MARK: - Barcode Scanner for Edit Screen

struct EditBarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onProductScanned: (OpenFoodFactsService.Product) -> Void

    @State private var isLookingUp = false
    @State private var lookupError: String?
    @State private var resetCounter = 0

    var body: some View {
        NavigationStack {
            ZStack {
                BarcodeCameraView(onBarcodeScanned: handleBarcode, resetCounter: resetCounter)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    if isLookingUp {
                        lookupOverlay {
                            ProgressView("Looking up product...")
                                .font(.headline)
                        }
                    } else if let error = lookupError {
                        lookupOverlay {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                Button("Scan Again") {
                                    lookupError = nil
                                    resetCounter += 1
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    } else {
                        lookupOverlay {
                            Label("Point camera at a barcode", systemImage: "barcode.viewfinder")
                                .font(.headline)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.white)
                }
            }
        }
    }

    private func handleBarcode(_ barcode: String) {
        guard !isLookingUp else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        isLookingUp = true
        lookupError = nil

        Task {
            do {
                let product = try await OpenFoodFactsService.shared.lookup(barcode: barcode)
                onProductScanned(product)
                dismiss()
            } catch {
                lookupError = error.localizedDescription
                isLookingUp = false
            }
        }
    }

    @ViewBuilder
    private func lookupOverlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
    }
}
