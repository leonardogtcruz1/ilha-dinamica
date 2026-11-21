import AppKit
import Foundation

@MainActor
final class OverlaySpaceManager {
    static let shared = OverlaySpaceManager()

    private typealias FMainConnectionID = @convention(c) () -> Int32
    private typealias FSpaceCreate = @convention(c) (Int32, Int32, Int32) -> UInt64
    private typealias FSpaceSetAbsoluteLevel = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias FShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias FHideSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias FSpaceDestroy = @convention(c) (Int32, UInt64) -> Int32
    private typealias FAddWindowsToSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32
    private typealias FRemoveWindowsFromSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32
    private typealias FSpaceAddWindowsAndRemoveFromSpaces = @convention(c) (Int32, UInt64, CFArray, Int32) -> Int32
    private typealias FGetActiveSpace = @convention(c) (Int32) -> UInt64
    private typealias FInterruptMenuBarReveal = @convention(c) (Int32, Int32) -> Int32
    private typealias FSpaceResetMenuBar = @convention(c) (Int32, UInt64) -> Int32

    private let handle: UnsafeMutableRawPointer?
    private let slsMainConnectionID: FMainConnectionID?
    private let slsSpaceCreate: FSpaceCreate?
    private let slsSpaceSetAbsoluteLevel: FSpaceSetAbsoluteLevel?
    private let slsShowSpaces: FShowSpaces?
    private let slsHideSpaces: FHideSpaces?
    private let slsSpaceDestroy: FSpaceDestroy?
    private let slsAddWindowsToSpaces: FAddWindowsToSpaces?
    private let slsRemoveWindowsFromSpaces: FRemoveWindowsFromSpaces?
    private let slsSpaceAddWindowsAndRemoveFromSpaces: FSpaceAddWindowsAndRemoveFromSpaces?
    private let slsGetActiveSpace: FGetActiveSpace?
    private let slsInterruptMenuBarReveal: FInterruptMenuBarReveal?
    private let slsSpaceResetMenuBar: FSpaceResetMenuBar?

    private var connection: Int32 = 0
    private var spaceID: UInt64 = 0
    private var attachedWindowNumbers = Set<Int>()

    private init() {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"
        let loaded = dlopen(path, RTLD_NOW)
        self.handle = loaded

        guard let loaded else {
            self.slsMainConnectionID = nil
            self.slsSpaceCreate = nil
            self.slsSpaceSetAbsoluteLevel = nil
            self.slsShowSpaces = nil
            self.slsHideSpaces = nil
            self.slsSpaceDestroy = nil
            self.slsAddWindowsToSpaces = nil
            self.slsRemoveWindowsFromSpaces = nil
            self.slsSpaceAddWindowsAndRemoveFromSpaces = nil
            self.slsGetActiveSpace = nil
            self.slsInterruptMenuBarReveal = nil
            self.slsSpaceResetMenuBar = nil
            return
        }

        func resolve<T>(_ name: String, as type: T.Type) -> T? {
            guard let sym = dlsym(loaded, name) else { return nil }
            return unsafeBitCast(sym, to: type)
        }

        self.slsMainConnectionID = resolve("SLSMainConnectionID", as: FMainConnectionID.self)
        self.slsSpaceCreate = resolve("SLSSpaceCreate", as: FSpaceCreate.self)
        self.slsSpaceSetAbsoluteLevel = resolve("SLSSpaceSetAbsoluteLevel", as: FSpaceSetAbsoluteLevel.self)
        self.slsShowSpaces = resolve("SLSShowSpaces", as: FShowSpaces.self)
        self.slsHideSpaces = resolve("SLSHideSpaces", as: FHideSpaces.self)
        self.slsSpaceDestroy = resolve("SLSSpaceDestroy", as: FSpaceDestroy.self)
        self.slsAddWindowsToSpaces = resolve("SLSAddWindowsToSpaces", as: FAddWindowsToSpaces.self)
        self.slsRemoveWindowsFromSpaces = resolve("SLSRemoveWindowsFromSpaces", as: FRemoveWindowsFromSpaces.self)
        self.slsSpaceAddWindowsAndRemoveFromSpaces = resolve(
            "SLSSpaceAddWindowsAndRemoveFromSpaces",
            as: FSpaceAddWindowsAndRemoveFromSpaces.self
        )
        self.slsGetActiveSpace = resolve("SLSGetActiveSpace", as: FGetActiveSpace.self)
        self.slsInterruptMenuBarReveal = resolve("SLSInterruptMenuBarReveal", as: FInterruptMenuBarReveal.self)
        self.slsSpaceResetMenuBar = resolve("SLSSpaceResetMenuBar", as: FSpaceResetMenuBar.self)

        setupSpaceIfPossible()
    }

    private func setupSpaceIfPossible() {
        guard let slsMainConnectionID,
              let slsSpaceCreate,
              let slsSpaceSetAbsoluteLevel,
              let slsShowSpaces else {
            return
        }

        let conn = slsMainConnectionID()
        guard conn != 0 else { return }

        let sid = slsSpaceCreate(conn, 1, 0)
        guard sid != 0 else { return }

        // kSLSSpaceAbsoluteLevelNotificationCenterAtScreenLock = 400
        _ = slsSpaceSetAbsoluteLevel(conn, sid, 400)
        _ = slsShowSpaces(conn, [NSNumber(value: sid)] as CFArray)

        self.connection = conn
        self.spaceID = sid
    }

    func attach(window: NSWindow) {
        let winNum = window.windowNumber
        guard spaceID != 0,
              connection != 0,
              winNum > 0,
              !attachedWindowNumbers.contains(winNum) else {
            return
        }

        let windows = [NSNumber(value: winNum)] as CFArray
        var attached = false
        if let slsSpaceAddWindowsAndRemoveFromSpaces {
            attached = slsSpaceAddWindowsAndRemoveFromSpaces(connection, spaceID, windows, 7) == 0
        }
        if !attached, let slsAddWindowsToSpaces {
            attached = slsAddWindowsToSpaces(
                connection,
                windows,
                [NSNumber(value: spaceID)] as CFArray
            ) == 0
        }
        if attached {
            attachedWindowNumbers.insert(winNum)
        }
    }

    func detach(window: NSWindow) {
        let winNum = window.windowNumber
        guard spaceID != 0,
              connection != 0,
              winNum > 0,
              attachedWindowNumbers.contains(winNum),
              let slsRemoveWindowsFromSpaces else {
            return
        }

        let windows = [NSNumber(value: winNum)] as CFArray
        if let slsGetActiveSpace,
           let slsAddWindowsToSpaces {
            let activeSpace = slsGetActiveSpace(connection)
            if activeSpace != 0 {
                _ = slsAddWindowsToSpaces(
                    connection,
                    windows,
                    [NSNumber(value: activeSpace)] as CFArray
                )
            }
        }

        _ = slsRemoveWindowsFromSpaces(
            connection,
            windows,
            [NSNumber(value: spaceID)] as CFArray
        )
        attachedWindowNumbers.remove(winNum)
    }

    func interruptMenuBarReveal() {
        guard connection != 0 else { return }
        _ = slsInterruptMenuBarReveal?(connection, 0)
    }

    func resetActiveSpaceMenuBar() {
        guard connection != 0 else { return }
        _ = slsInterruptMenuBarReveal?(connection, 0)
        if let activeSpace = slsGetActiveSpace?(connection), activeSpace != 0 {
            _ = slsSpaceResetMenuBar?(connection, activeSpace)
        }
    }

    func cleanup() {
        guard spaceID != 0, connection != 0 else { return }
        let spaces = [NSNumber(value: spaceID)] as CFArray
        if let slsHideSpaces {
            _ = slsHideSpaces(connection, spaces)
        }
        if let slsSpaceDestroy {
            _ = slsSpaceDestroy(connection, spaceID)
        }
        attachedWindowNumbers.removeAll()
        spaceID = 0
    }
}
