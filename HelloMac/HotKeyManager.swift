//
//  HotKeyManager.swift
//  HelloMac
//
//  Registers global hotkeys and dispatches actions.
//

import Cocoa
import Carbon.HIToolbox

final class HotKeyManager: NSObject {
    enum Direction {
        case left
        case right
    }

    private var leftHotKeyRef: EventHotKeyRef?
    private var rightHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    override init() {
        super.init()
        installHandler()
        registerHotKeys()
    }

    deinit {
        unregisterHotKeys()
        removeHandler()
    }

    // MARK: - Registration

    private func registerHotKeys() {
        // Command + Shift + Left/Right
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        register(keyCode: UInt32(kVK_LeftArrow), modifiers: modifiers, id: 1, storeIn: &leftHotKeyRef)
        register(keyCode: UInt32(kVK_RightArrow), modifiers: modifiers, id: 2, storeIn: &rightHotKeyRef)
    }

    private func register(keyCode: UInt32, modifiers: UInt32, id: UInt32, storeIn ref: inout EventHotKeyRef?) {
        var hotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: 0x484B4D47)), // 'HKMG'
                                     id: id)
        let status = RegisterEventHotKey(keyCode,
                                         modifiers,
                                         hotKeyID,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &ref)
        if status != noErr {
            NSLog("RegisterEventHotKey failed with status: \(status)")
        }
    }

    private func unregisterHotKeys() {
        if let leftHotKeyRef { UnregisterEventHotKey(leftHotKeyRef) }
        if let rightHotKeyRef { UnregisterEventHotKey(rightHotKeyRef) }
        leftHotKeyRef = nil
        rightHotKeyRef = nil
    }

    // MARK: - Handler

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handleHotKey(theEvent: theEvent)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventType, selfPtr, &eventHandler)
        if status != noErr {
            NSLog("InstallEventHandler failed with status: \(status)")
        }
    }

    private func removeHandler() {
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
    }

    private func handleHotKey(theEvent: EventRef?) -> OSStatus {
        guard let theEvent else { return noErr }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(theEvent,
                                       EventParamName(kEventParamDirectObject),
                                       EventParamType(typeEventHotKeyID),
                                       nil,
                                       MemoryLayout<EventHotKeyID>.size,
                                       nil,
                                       &hotKeyID)
        if status != noErr { return status }

        switch hotKeyID.id {
        case 1:
            WindowTiler.tile(.left)
        case 2:
            WindowTiler.tile(.right)
        default:
            break
        }
        return noErr
    }
}

