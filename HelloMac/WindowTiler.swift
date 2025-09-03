//
//  WindowTiler.swift
//  HelloMac
//
//  Moves the focused window to left/right halves.
//

import Cocoa
import ApplicationServices

enum TilingError: Error { case notTrusted, noFrontApp, noWindow }

enum WindowTiler {
    static func ensureAccessibility(prompt: Bool = true) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    static func tile(_ direction: HotKeyManager.Direction) {
        guard ensureAccessibility(prompt: true) else {
            NSLog("Accessibility not granted. Enable in System Settings > Privacy & Security > Accessibility.")
            return
        }

        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            NSLog("No frontmost application PID.")
            return
        }

        let appRef = AXUIElementCreateApplication(pid)
        var windowRef: AXUIElement?
        if !copyAttribute(element: appRef, attr: kAXFocusedWindowAttribute as CFString, into: &windowRef) || windowRef == nil {
            // Try main window as a fallback
            _ = copyAttribute(element: appRef, attr: kAXMainWindowAttribute as CFString, into: &windowRef)
        }

        guard let window = windowRef else {
            NSLog("No focused or main window accessible.")
            return
        }

        // Determine current screen from window position if possible
        let currentScreen = screenForWindow(window) ?? NSScreen.main
        guard let screen = currentScreen else {
            NSLog("No screen available.")
            return
        }

        let vf = screen.visibleFrame
        let halfWidth = floor(vf.width / 2.0)

        let targetRect: CGRect
        switch direction {
        case .left:
            targetRect = CGRect(x: vf.minX, y: vf.minY, width: halfWidth, height: vf.height)
        case .right:
            let rightWidth = vf.width - halfWidth
            targetRect = CGRect(x: vf.minX + halfWidth, y: vf.minY, width: rightWidth, height: vf.height)
        }

        // Convert Cocoa (bottom-left origin) to AX/CG (top-left origin for y)
        var pt = convertToAXCGPoint(targetRect: targetRect, on: screen)
        var size = targetRect.size
        let axPos = AXValueCreate(.cgPoint, &pt)!
        let axSize = AXValueCreate(.cgSize, &size)!

        setAttribute(element: window, attr: kAXPositionAttribute as CFString, value: axPos)
        setAttribute(element: window, attr: kAXSizeAttribute as CFString, value: axSize)
    }

    // MARK: - Helpers

    private static func copyAttribute<T>(element: AXUIElement, attr: CFString, into out: inout T?) -> Bool {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr, &value)
        if err == .success, let value = value as? T {
            out = value
            return true
        }
        return false
    }

    private static func setAttribute(element: AXUIElement, attr: CFString, value: CFTypeRef) {
        let err = AXUIElementSetAttributeValue(element, attr, value)
        if err != .success {
            NSLog("Failed setting attribute \(attr): \(err.rawValue)")
        }
    }

    private static func screenForWindow(_ window: AXUIElement) -> NSScreen? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        let hasPos = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success
        let hasSize = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success
        guard hasPos, hasSize,
              let cgPoint = posValue as? AXValue,
              let cgSize = sizeValue as? AXValue else { return nil }

        var p = CGPoint.zero
        var s = CGSize.zero
        AXValueGetValue(cgPoint, .cgPoint, &p)
        AXValueGetValue(cgSize, .cgSize, &s)

        // AX coordinates likely use top-left origin; approximate screen detection by center
        let center = CGPoint(x: p.x + s.width/2, y: p.y + s.height/2)
        return NSScreen.screens.first { screen in
            // Convert screen to AX-like top-left coords for y
            let cocoaFrame = screen.frame
            let axRect = convertToAXRect(cocoaRect: cocoaFrame, on: screen)
            return axRect.contains(center)
        }
    }

    private static func convertToAXCGPoint(targetRect: CGRect, on screen: NSScreen) -> CGPoint {
        // Convert Cocoa bottom-left to AX top-left y
        let screenFrame = screen.frame
        let flippedY = (screenFrame.maxY - (targetRect.origin.y + targetRect.size.height))
        return CGPoint(x: targetRect.origin.x, y: flippedY)
    }

    private static func convertToAXRect(cocoaRect: CGRect, on screen: NSScreen) -> CGRect {
        let flippedY = (screen.frame.maxY - (cocoaRect.origin.y + cocoaRect.size.height))
        return CGRect(x: cocoaRect.origin.x, y: flippedY, width: cocoaRect.width, height: cocoaRect.height)
    }
}
