import Foundation

public struct SnapConfiguration: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var zones: [SnapZone]

    public init(id: UUID = UUID(), name: String, zones: [SnapZone] = []) {
        self.id = id
        self.name = name
        self.zones = zones
    }
}
