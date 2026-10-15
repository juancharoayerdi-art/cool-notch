//
//  BoringNotchXPCHelper.swift
//  BoringNotchXPCHelper
//
//  Created by Alexander on 2025-11-16.
//

import Foundation
import AppKit
import ApplicationServices
import IOKit
import CoreGraphics

class BoringNotchXPCHelper: NSObject, BoringNotchXPCHelperProtocol {
    
    @objc func isAccessibilityAuthorized(with reply: @escaping (Bool) -> Void) {
        reply(AXIsProcessTrusted())
    }

    @objc func requestAccessibilityAuthorization() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @objc func ensureAccessibilityAuthorization(_ promptIfNeeded: Bool, with reply: @escaping (Bool) -> Void) {
        if AXIsProcessTrusted() {
            reply(true)
            return
        }

        if promptIfNeeded {
            requestAccessibilityAuthorization()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            reply(AXIsProcessTrusted())
        }
    }
    
    private class KeyboardBrightnessClient {
        private static let keyboardID: UInt64 = 1
        private var clientInstance: NSObject?
        private let getSelector = NSSelectorFromString("brightnessForKeyboard:")
        private let setSelector = NSSelectorFromString("setBrightness:forKeyboard:")

        init() {
            var loaded = false
            let bundlePaths = [
                "/System/Library/PrivateFrameworks/CoreBrightness.framework",
                "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
            ]
            for path in bundlePaths where !loaded {
                if let bundle = Bundle(path: path) {
                    loaded = bundle.load()
                }
            }
            if loaded, let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type {
                clientInstance = cls.init()
            }
        }

        var isAvailable: Bool { clientInstance != nil }

        func currentBrightness() -> Float? {
            guard let clientInstance,
                  let fn: BrightnessGetter = methodIMP(on: clientInstance, selector: getSelector, as: BrightnessGetter.self)
            else { return nil }
            return fn(clientInstance, getSelector, Self.keyboardID)
        }

        func setBrightness(_ value: Float) -> Bool {
            guard let clientInstance,
                  let fn: BrightnessSetter = methodIMP(on: clientInstance, selector: setSelector, as: BrightnessSetter.self)
            else { return false }
            return fn(clientInstance, setSelector, value, Self.keyboardID).boolValue
        }

        private typealias BrightnessGetter = @convention(c) (NSObject, Selector, UInt64) -> Float
        private typealias BrightnessSetter = @convention(c) (NSObject, Selector, Float, UInt64) -> ObjCBool

        private func methodIMP<T>(on object: NSObject, selector: Selector, as type: T.Type) -> T? {
            guard let cls = object_getClass(object),
                  let method = class_getInstanceMethod(cls, selector)
            else { return nil }
            let imp = method_getImplementation(method)
            return unsafeBitCast(imp, to: type)
        }
    }

    private static let keyboardClient = KeyboardBrightnessClient()

    @objc func isKeyboardBrightnessAvailable(with reply: @escaping (Bool) -> Void) {
        reply(Self.keyboardClient.isAvailable)
    }

    @objc func currentKeyboardBrightness(with reply: @escaping (NSNumber?) -> Void) {
        reply(Self.keyboardClient.currentBrightness().map { NSNumber(value: $0) })
    }

    @objc func setKeyboardBrightness(_ value: Float, with reply: @escaping (Bool) -> Void) {
        reply(Self.keyboardClient.setBrightness(value))
    }
    // MARK: - Screen Brightness (moved from client app into helper)

    @objc func isScreenBrightnessAvailable(with reply: @escaping (Bool) -> Void) {
        var b: Float = 0
        reply(displayServicesGetBrightness(displayID: CGMainDisplayID(), out: &b) || ioServiceFor(displayID: CGMainDisplayID()) != nil)
    }

    @objc func currentScreenBrightness(with reply: @escaping (NSNumber?) -> Void) {
        var b: Float = 0
        if displayServicesGetBrightness(displayID: CGMainDisplayID(), out: &b) {
            reply(NSNumber(value: b))
            return
        }
        if let io = ioServiceFor(displayID: CGMainDisplayID()) {
            var level: Float = 0
            if IODisplayGetFloatParameter(io, 0, kIODisplayBrightnessKey as CFString, &level) == kIOReturnSuccess {
                IOObjectRelease(io)
                reply(NSNumber(value: level))
                return
            }
            IOObjectRelease(io)
        }
        reply(nil)
    }

    // MARK: - ChatGPT voice (Cool Notch)

    private static let chatGPTBundleID = "com.openai.codex"

    /// Starts (or ends) ChatGPT's voice chat without leaving the current app by pressing ChatGPT's
    /// own global "Voice chat hotkey" (Control+Option+Command+V, set in ~/.codex/keybindings.json).
    /// One tap = one press, never retried (a second press would toggle voice off again).
    /// If ChatGPT isn't running it's launched hidden first.
    @objc func startChatGPTVoice(with reply: @escaping (Bool) -> Void) {
        guard AXIsProcessTrusted() else {
            reply(false)
            return
        }
        let bundleID = Self.chatGPTBundleID

        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            Self.pressVoiceHotkey()
            reply(true)
            Self.dockVoiceOrbUnderNotch(pid: app.processIdentifier)
            return
        }

        DispatchQueue.main.async {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                reply(false)
                return
            }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            config.hides = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
                guard let app, error == nil else { reply(false); return }
                DispatchQueue.global(qos: .userInitiated).async {
                    // Wait for launch to finish, then a moment for the global hotkey to register.
                    let deadline = Date().addingTimeInterval(15)
                    while !app.isFinishedLaunching && Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    Thread.sleep(forTimeInterval: 2.5)
                    Self.pressVoiceHotkey()
                    reply(true)
                    Self.dockVoiceOrbUnderNotch(pid: app.processIdentifier)
                }
            }
        }
    }

    /// Watches (never presses again) for ChatGPT's small voice-orb window for a few seconds and
    /// moves it so it sits centered right below the notch.
    private static func dockVoiceOrbUnderNotch(pid: pid_t) {
        DispatchQueue.global(qos: .userInitiated).async {
            let deadline = Date().addingTimeInterval(8)
            var placedAt: Date?
            while Date() < deadline {
                if let orb = voiceOrbWindow(pid: pid), let target = orbTargetOrigin(for: orb.size) {
                    if abs(orb.origin.x - target.x) > 1 || abs(orb.origin.y - target.y) > 1 {
                        var point = target
                        if let value = AXValueCreate(.cgPoint, &point) {
                            AXUIElementSetAttributeValue(orb.element, kAXPositionAttribute as CFString, value)
                        }
                    }
                    // Keep correcting briefly in case ChatGPT animates it into place.
                    if placedAt == nil { placedAt = Date() }
                    if let placedAt, Date().timeIntervalSince(placedAt) > 1.2 { return }
                }
                Thread.sleep(forTimeInterval: 0.08)
            }
        }
    }

    private static func voiceOrbWindow(pid: pid_t) -> (element: AXUIElement, origin: CGPoint, size: CGSize)? {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        for window in windows {
            var posRef: CFTypeRef?, sizeRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
                  AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
                  let posRef, let sizeRef else { continue }
            var origin = CGPoint.zero, size = CGSize.zero
            AXValueGetValue(posRef as! AXValue, .cgPoint, &origin)
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
            // The orb is a small, wide pill; regular ChatGPT windows are much bigger.
            if size.width > 80, size.width <= 480, size.height > 20, size.height <= 160, size.width > size.height {
                return (window, origin, size)
            }
        }
        return nil
    }

    /// Top-left (Accessibility coordinates) that centers a window of `size` just below the notch.
    private static func orbTargetOrigin(for size: CGSize) -> CGPoint? {
        let screens = NSScreen.screens
        guard let primary = screens.first,
              let screen = screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return nil }
        let frame = screen.frame
        let notchHeight = max(screen.safeAreaInsets.top, NSStatusBar.system.thickness)
        let x = frame.midX - size.width / 2
        let y = (primary.frame.maxY - frame.maxY) + notchHeight + 4
        return CGPoint(x: x.rounded(), y: y.rounded())
    }

    /// Types Control+Option+Command+V like a person would: modifiers down, V, then release.
    private static func pressVoiceHotkey() {
        let source = CGEventSource(stateID: .hidSystemState)
        let modifiers: [(CGKeyCode, CGEventFlags)] = [
            (59, .maskControl),   // kVK_Control
            (58, .maskAlternate), // kVK_Option
            (55, .maskCommand),   // kVK_Command
        ]
        var flags: CGEventFlags = []
        func post(_ key: CGKeyCode, down: Bool) {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
            usleep(12_000)
        }
        for (key, flag) in modifiers {
            flags.insert(flag)
            post(key, down: true)
        }
        post(9 /* kVK_ANSI_V */, down: true)
        usleep(30_000)
        post(9, down: false)
        for (key, flag) in modifiers.reversed() {
            flags.remove(flag)
            post(key, down: false)
        }
    }

    @objc func setScreenBrightness(_ value: Float, with reply: @escaping (Bool) -> Void) {
        let clamped = max(0, min(1, value))
        if displayServicesSetBrightness(displayID: CGMainDisplayID(), value: clamped) {
            reply(true)
            return
        }
        if let io = ioServiceFor(displayID: CGMainDisplayID()) {
            let ok = IODisplaySetFloatParameter(io, 0, kIODisplayBrightnessKey as CFString, clamped) == kIOReturnSuccess
            IOObjectRelease(io)
            reply(ok)
            return
        }
        reply(false)
    }

    // MARK: - Private helpers for DisplayServices / IOKit access
    private func displayServicesGetBrightness(displayID: CGDirectDisplayID, out: inout Float) -> Bool {
        guard let sym = dlsym(DisplayServicesHandle.handle, "DisplayServicesGetBrightness") else { return false }
        typealias Fn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        var tmp: Float = 0
        let r = fn(displayID, &tmp)
        if r == 0 { out = tmp; return true }
        return false
    }

    private func displayServicesSetBrightness(displayID: CGDirectDisplayID, value: Float) -> Bool {
        guard let sym = dlsym(DisplayServicesHandle.handle, "DisplayServicesSetBrightness") else { return false }
        typealias Fn = @convention(c) (CGDirectDisplayID, Float) -> Int32
        let fn = unsafeBitCast(sym, to: Fn.self)
        return fn(displayID, value) == 0
    }

    private func ioServiceFor(displayID: CGDirectDisplayID) -> io_service_t? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator) == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            let info = IODisplayCreateInfoDictionary(service, 0).takeRetainedValue() as NSDictionary
            if let vendorID = info[kDisplayVendorID] as? UInt32,
               let productID = info[kDisplayProductID] as? UInt32,
               vendorID == CGDisplayVendorNumber(displayID),
               productID == CGDisplayModelNumber(displayID) {
                return service
            }
            IOObjectRelease(service)
        }
        return nil
    }

    // MARK: - Helper handle for private framework
    private enum DisplayServicesHandle {
        static let handle: UnsafeMutableRawPointer? = {
            let paths = [
                "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/Current/DisplayServices"
            ]
            for p in paths {
                if let h = dlopen(p, RTLD_LAZY) { return h }
            }
            return nil
        }()
    }
}
