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

    private let handle: UnsafeMutableRawPointer?
    private let slsMainConnectionID: FMainConnectionID?
    private let slsSpaceCreate: FSpaceCreate?
    private let slsSpaceSetAbsoluteLevel: FSpaceSetAbsoluteLevel?
    private let slsShowSpaces: FShowSpaces?
    private let slsHideSpaces: FHideSpaces?
    private let slsSpaceDestroy: FSpaceDestroy?
    private let slsAddWindowsToSpaces: FAddWindowsToSpaces?
    private let slsRemoveWindowsFromSpaces: FRemoveWindowsFromSpaces?

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
              !attachedWindowNumbers.contains(winNum),
              let slsAddWindowsToSpaces else {
            return
        }

        _ = slsAddWindowsToSpaces(
            connection,
            [NSNumber(value: winNum)] as CFArray,
            [NSNumber(value: spaceID)] as CFArray
        )
        attachedWindowNumbers.insert(winNum)
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

        _ = slsRemoveWindowsFromSpaces(
            connection,
            [NSNumber(value: winNum)] as CFArray,
            [NSNumber(value: spaceID)] as CFArray
        )
        attachedWindowNumbers.remove(winNum)
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
