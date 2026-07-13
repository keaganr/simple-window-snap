import SwiftUI
import SWSModel

public struct ConfigurationEditorView: View {
    @ObservedObject private var store: ConfigurationStore
    @FocusState private var focusedZoneID: SnapZone.ID?

    public init(store: ConfigurationStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            configurationTabs

            if let configuration = store.activeConfiguration {
                HStack {
                    TextField(
                        "Configuration Name",
                        text: Binding(
                            get: { configuration.name },
                            set: { store.renameConfiguration(configuration.id, to: $0) }
                        )
                    )
                    .font(.headline)
                    .textFieldStyle(.plain)

                    Spacer()

                    Button("Delete", role: .destructive) {
                        store.deleteConfiguration(configuration.id)
                    }
                    .disabled(store.configurations.count <= 1)
                }

                Text("Drag across the grid to add a zone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GridPickerView(existingZones: configuration.zones.map(\.rect)) { newRect in
                    store.addZone(newRect, name: "Zone \(configuration.zones.count + 1)", toConfiguration: configuration.id)
                } onSelectExistingZone: { rect in
                    focusedZoneID = configuration.zones.first { $0.rect == rect }?.id
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

    private var configurationTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(store.configurations) { configuration in
                    tabButton(for: configuration)
                }

                Button {
                    let newConfiguration = store.addConfiguration(name: "New Configuration")
                    store.setActiveConfiguration(newConfiguration.id)
                } label: {
                    Image(systemName: "plus")
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tabButton(for configuration: SnapConfiguration) -> some View {
        let isActive = configuration.id == store.activeConfigurationID
        return Button {
            focusedZoneID = nil
            store.setActiveConfiguration(configuration.id)
        } label: {
            Text(configuration.name)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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
                    .focused($focusedZoneID, equals: zone.id)

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
