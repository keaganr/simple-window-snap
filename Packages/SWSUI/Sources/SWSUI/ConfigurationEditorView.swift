import SwiftUI
import SWSModel

public struct ConfigurationEditorView: View {
    @ObservedObject private var store: ConfigurationStore

    public init(store: ConfigurationStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let configuration = store.activeConfiguration {
                Text(configuration.name)
                    .font(.headline)

                Text("Drag across the grid to add a zone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GridPickerView(existingZones: configuration.zones.map(\.rect)) { newRect in
                    store.addZone(newRect, name: "Zone \(configuration.zones.count + 1)", toConfiguration: configuration.id)
                }
                .frame(height: 220)

                zoneList(for: configuration)
            } else {
                Text("No configuration selected")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 420, idealWidth: 480, minHeight: 480, idealHeight: 560)
    }

    private func zoneList(for configuration: SnapConfiguration) -> some View {
        List {
            ForEach(configuration.zones) { zone in
                HStack {
                    TextField(
                        "Name",
                        text: Binding(
                            get: { zone.name },
                            set: { store.renameZone(zone.id, to: $0, inConfiguration: configuration.id) }
                        )
                    )
                    .textFieldStyle(.plain)

                    Spacer()

                    Button {
                        store.removeZone(zone.id, fromConfiguration: configuration.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
