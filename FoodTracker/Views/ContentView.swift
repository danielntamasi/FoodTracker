import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DailySummaryView()
                .tabItem {
                    Label("Today", systemImage: "fork.knife")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
