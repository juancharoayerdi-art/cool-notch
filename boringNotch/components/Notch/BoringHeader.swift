//
//  BoringHeader.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

struct BoringHeader: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @StateObject var tvm = ShelfStateViewModel.shared
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                if (!tvm.isEmpty || coordinator.alwaysShowTabs) && Defaults[.boringShelf] {
                    TabSelectionView()
                    // Cool Notch: invisible, wider hit area to the right of the tabs that opens the shelf.
                    if vm.notchState == .open && coordinator.currentView != .shelf {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: 30)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.smooth) { coordinator.currentView = .shelf }
                            }
                    }
                } else if vm.notchState == .open {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)

            if vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            HStack(spacing: 4) {
                if vm.notchState == .open {
                    if isHUDType(coordinator.sneakPeek.type) && coordinator.sneakPeek.show && Defaults[.showOpenNotchHUD] {
                        OpenNotchHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        if Defaults[.showMirror] {
                            Button(action: {
                                vm.toggleCameraPreview()
                            }) {
                                Capsule()
                                    .fill(.black)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Image(systemName: "web.camera")
                                            .foregroundColor(.white)
                                            .padding()
                                            .imageScale(.medium)
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        ChatGPTVoiceButton()
                        if Defaults[.settingsIconInNotch] {
                            Button(action: {
                                DispatchQueue.main.async {
                                    SettingsWindowController.shared.showWindow()
                                }
                                
                            }) {
                                Capsule()
                                    .fill(.black)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        Image(systemName: "gear")
                                            .foregroundColor(.white)
                                            .padding()
                                            .imageScale(.medium)
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        if Defaults[.showBatteryIndicator] {
                            BoringBatteryView(
                                batteryWidth: 30,
                                isCharging: batteryModel.isCharging,
                                isInLowPowerMode: batteryModel.isInLowPowerMode,
                                isPluggedIn: batteryModel.isPluggedIn,
                                levelBattery: batteryModel.levelBattery,
                                maxCapacity: batteryModel.maxCapacity,
                                timeToFullCharge: batteryModel.timeToFullCharge,
                                isForNotification: false
                            )
                        }
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }

    func isHUDType(_ type: SneakContentType) -> Bool {
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return true
        default:
            return false
        }
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}


// MARK: - ChatGPT voice shortcut (Cool Notch)

/// Starts a new ChatGPT voice chat in the background. Shows a spinner while ChatGPT
/// loads so it's clear the tap registered, and a brief warning icon if it failed.
struct ChatGPTVoiceButton: View {
    enum Phase { case idle, loading, failed }
    @State private var phase: Phase = .idle

    var body: some View {
        Button(action: start) {
            Capsule()
                .fill(.black)
                .frame(width: 30, height: 30)
                .overlay {
                    switch phase {
                    case .idle:
                        Image(systemName: "waveform")
                            .foregroundColor(.white)
                            .imageScale(.medium)
                    case .loading:
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    case .failed:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .imageScale(.small)
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(phase == .loading)
        .help("Hablar con ChatGPT")
    }

    private func start() {
        guard phase != .loading else { return }
        withAnimation(.smooth) { phase = .loading }
        Task {
            let authorized = await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
            let ok = authorized ? await XPCHelperClient.shared.startChatGPTVoice() : false
            await MainActor.run {
                withAnimation(.smooth) { phase = ok ? .idle : .failed }
            }
            if !ok {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run { withAnimation(.smooth) { phase = .idle } }
            }
        }
    }
}
