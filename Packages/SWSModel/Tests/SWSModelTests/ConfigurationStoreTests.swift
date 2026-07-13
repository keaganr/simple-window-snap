import Testing
@testable import SWSModel
import Foundation

@MainActor
private func makeTempStoreURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("SWSModelTests-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("configurations.json", isDirectory: false)
}

@Test @MainActor func freshStoreSeedsADefaultConfigurationWithZones() {
    let store = ConfigurationStore(fileURL: makeTempStoreURL())
    #expect(store.configurations.count == 1)
    #expect(store.activeConfiguration?.name == "Default")
    #expect(store.activeConfiguration?.zones.isEmpty == false)
    #expect(store.activeConfigurationID == store.configurations.first?.id)
}

@Test @MainActor func addZoneAppendsToTheTargetConfigurationAndPersists() throws {
    let url = makeTempStoreURL()
    let store = ConfigurationStore(fileURL: url)
    let configID = try #require(store.activeConfigurationID)
    let countBefore = store.activeConfiguration?.zones.count ?? 0

    store.addZone(NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5), name: "New Zone", toConfiguration: configID)

    #expect(store.activeConfiguration?.zones.count == countBefore + 1)
    #expect(store.activeConfiguration?.zones.last?.name == "New Zone")
    #expect(FileManager.default.fileExists(atPath: url.path))
}

@Test @MainActor func removeZoneDeletesOnlyTheMatchingZone() throws {
    let store = ConfigurationStore(fileURL: makeTempStoreURL())
    let configID = try #require(store.activeConfigurationID)
    let zoneToRemove = try #require(store.activeConfiguration?.zones.first)
    let countBefore = store.activeConfiguration?.zones.count ?? 0

    store.removeZone(zoneToRemove.id, fromConfiguration: configID)

    #expect(store.activeConfiguration?.zones.count == countBefore - 1)
    #expect(store.activeConfiguration?.zones.contains(where: { $0.id == zoneToRemove.id }) == false)
}

@Test @MainActor func renameZoneUpdatesTheNameInPlace() throws {
    let store = ConfigurationStore(fileURL: makeTempStoreURL())
    let configID = try #require(store.activeConfigurationID)
    let zone = try #require(store.activeConfiguration?.zones.first)

    store.renameZone(zone.id, to: "Renamed", inConfiguration: configID)

    #expect(store.activeConfiguration?.zones.first(where: { $0.id == zone.id })?.name == "Renamed")
}

@Test @MainActor func persistedStateSurvivesAFreshStoreInstance() throws {
    let url = makeTempStoreURL()
    let firstStore = ConfigurationStore(fileURL: url)
    let configID = try #require(firstStore.activeConfigurationID)
    firstStore.addZone(NormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5), name: "Persisted Zone", toConfiguration: configID)

    let secondStore = ConfigurationStore(fileURL: url)

    #expect(secondStore.activeConfigurationID == configID)
    #expect(secondStore.activeConfiguration?.zones.contains(where: { $0.name == "Persisted Zone" }) == true)
}

@Test @MainActor func setActiveConfigurationIgnoresUnknownIDs() {
    let store = ConfigurationStore(fileURL: makeTempStoreURL())
    let originalActiveID = store.activeConfigurationID

    store.setActiveConfiguration(UUID())

    #expect(store.activeConfigurationID == originalActiveID)
}

@Test @MainActor func addConfigurationAppendsWithoutActivatingIt() {
    let store = ConfigurationStore(fileURL: makeTempStoreURL())
    let originalActiveID = store.activeConfigurationID

    let newConfiguration = store.addConfiguration(name: "Second")

    #expect(store.configurations.count == 2)
    #expect(store.configurations.contains(where: { $0.id == newConfiguration.id && $0.name == "Second" }))
    #expect(store.activeConfigurationID == originalActiveID)
}

@Test @MainActor func deleteConfigurationFallsBackWhenActiveOneIsDeleted() throws {
    let store = ConfigurationStore(fileURL: makeTempStoreURL())
    let firstID = try #require(store.activeConfigurationID)
    let second = store.addConfiguration(name: "Second")
    store.setActiveConfiguration(second.id)

    store.deleteConfiguration(second.id)

    #expect(store.configurations.count == 1)
    #expect(store.activeConfigurationID == firstID)
}

@Test @MainActor func deleteConfigurationRefusesToRemoveTheLastOne() throws {
    let store = ConfigurationStore(fileURL: makeTempStoreURL())
    let onlyID = try #require(store.activeConfigurationID)

    store.deleteConfiguration(onlyID)

    #expect(store.configurations.count == 1)
    #expect(store.activeConfigurationID == onlyID)
}

@Test @MainActor func renameConfigurationUpdatesTheName() throws {
    let store = ConfigurationStore(fileURL: makeTempStoreURL())
    let id = try #require(store.activeConfigurationID)

    store.renameConfiguration(id, to: "Renamed Config")

    #expect(store.activeConfiguration?.name == "Renamed Config")
}

@Test func swsStoreRoundTripsThroughJSON() throws {
    let configuration = SnapConfiguration(name: "Test", zones: [
        SnapZone(name: "Zone A", rect: NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5)),
    ])
    let original = SWSStore(configurations: [configuration], activeConfigurationID: configuration.id)

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(SWSStore.self, from: data)

    #expect(decoded == original)
}
