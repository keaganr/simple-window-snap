import Foundation

public struct SnapZone: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var rect: NormalizedRect

    public init(id: UUID = UUID(), name: String, rect: NormalizedRect) {
        self.id = id
        self.name = name
        self.rect = rect
    }
}
