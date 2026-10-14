//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

let tabs = [
    TabModel(label: "Home", icon: "house.fill", view: .home),
    TabModel(label: "Shelf", icon: "tray.fill", view: .shelf)
]

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var shelf = ShelfStateViewModel.shared
    @Namespace var animation
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                    if tab.view == .shelf {
                        // Cool Notch: ChatGPT voice shortcut sits between Home and Shelf.
                        ChatGPTVoiceButton()
                    }
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                        withAnimation(.smooth) {
                            coordinator.currentView = tab.view
                        }
                    }
                    .frame(height: 26)
                    .overlay(alignment: .topTrailing) {
                        if tab.view == .shelf && !shelf.isEmpty && coordinator.currentView != .shelf {
                            Text("\(shelf.items.count)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(minWidth: 12, minHeight: 12)
                                .background(Circle().fill(Color.effectiveAccent))
                                .offset(x: -6, y: 1)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
            }
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
