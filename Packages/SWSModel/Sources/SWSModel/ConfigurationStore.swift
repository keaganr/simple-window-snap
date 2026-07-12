import Foundation
import os

private let logger = Logger(subsystem: "com.keaganr.SimpleWindowSnap", category: "ConfigurationStore")

/// The on-disk JSON shape. Kept separate from `ConfigurationStore` itself so
/// the persisted format is a plain, directly `Codable` value independent of
/// the store's runtime/ObservableObject concerns.
public struct SWSStore: Codable, Equatable, Sendable {
    public var configurations: [SnapConfiguration]
    public var activeConfigurationID: UUID?

    public init(configurations: [SnapConfiguration], activeConfigurationID: UUID?) {
        self.configurations = configurations
        self.activeConfigurationID = activeConfigurationID
    }
}

/// Loads/persists snap configurations as JSON and exposes CRUD operations
/// for the zones within them. The file URL is injectable so tests can point
/// it at a temp directory instead of the real Application Support folder.
@MainActor
public final class ConfigurationStore: ObservableObject {
    @Published public private(set) var configurations: [SnapConfiguration]
    @Published public private(set) var activeConfigurationID: UUID?

    private let fileURL: URL

    public var activeConfiguration: SnapConfiguration? {
        configurations.first { $0.id == activeConfigurationID }
    }

    public init(fileURL: URL = ConfigurationStore.defaultFileURL) {
        self.fileURL = fileURL
        if let loaded = Self.load(from: fileURL) {
            configurations = loaded.configurations
            activeConfigurationID = loaded.activeConfigurationID
        } else {
            let defaultConfiguration = Self.makeDefaultConfiguration()
            configurations = [defaultConfiguration]
            activeConfigurationID = defaultConfiguration.id
        }
    }

    public static var defaultFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("SimpleWindowSnap", isDirectory: true)
            .appendingPathComponent("configurations.json", isDirectory: false)
    }

    /// Seeded so a fresh install isn't left with zero zones - the same
    /// zones the app used as hardcoded placeholders through Phase 4, now
    /// just the starting point for a fully editable configuration.
    public static func makeDefaultConfiguration() -> SnapConfiguration {
        SnapConfiguration(name: "Default", zones: [
            SnapZone(name: "Left Third", rect: NormalizedRect(x: 0, y: 0, width: 1.0 / 3, height: 1)),
            SnapZone(name: "Right Third", rect: NormalizedRect(x: 2.0 / 3, y: 0, width: 1.0 / 3, height: 1)),
            SnapZone(name: "Top Center", rect: NormalizedRect(x: 1.0 / 3, y: 0, width: 1.0 / 3, height: 0.5)),
        ])
    }

    public func addZone(_ rect: NormalizedRect, name: String, toConfiguration configurationID: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == configurationID }) else { return }
        configurations[index].zones.append(SnapZone(name: name, rect: rect))
        persist()
    }

    public func removeZone(_ zoneID: UUID, fromConfiguration configurationID: UUID) {
        guard let index = configurations.firstIndex(where: { $0.id == configurationID }) else { return }
        configurations[index].zones.removeAll { $0.id == zoneID }
        persist()
    }

    public func renameZone(_ zoneID: UUID, to name: String, inConfiguration configurationID: UUID) {
        guard let configIndex = configurations.firstIndex(where: { $0.id == configurationID }),
              let zoneIndex = configurations[configIndex].zones.firstIndex(where: { $0.id == zoneID }) else { return }
        configurations[configIndex].zones[zoneIndex].name = name
        persist()
    }

    public func setActiveConfiguration(_ id: UUID) {
        guard configurations.contains(where: { $0.id == id }) else { return }
        activeConfigurationID = id
        persist()
    }

    private func persist() {
        let state = SWSStore(configurations: configurations, activeConfigurationID: activeConfigurationID)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to persist configurations: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func load(from url: URL) -> SWSStore? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(SWSStore.self, from: data)
        } catch {
            logger.error("Failed to decode configurations at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
