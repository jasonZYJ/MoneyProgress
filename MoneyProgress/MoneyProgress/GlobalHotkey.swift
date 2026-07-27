//
//  GlobalHotkey.swift
//  MoneyProgress
//
//  全局快捷键监听（无需辅助功能权限）
//

import AppKit
import Carbon

final class GlobalHotkey {
    typealias Handler = () -> Void

    private let keyCode: UInt32
    private let modifiers: NSEvent.ModifierFlags
    private let handler: Handler

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var signature: OSType = OSType(0x4D5052)  // 'MPR' (Money PRogress)

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, handler: @escaping Handler) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.handler = handler
    }

    deinit { unregister() }

    func register() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                hotkey.handler()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        var modifiersUInt: UInt32 = 0
        if modifiers.contains(.command) { modifiersUInt |= UInt32(cmdKey) }
        if modifiers.contains(.option) { modifiersUInt |= UInt32(optionKey) }
        if modifiers.contains(.shift) { modifiersUInt |= UInt32(shiftKey) }
        if modifiers.contains(.control) { modifiersUInt |= UInt32(controlKey) }

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            keyCode,
            modifiersUInt,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}
