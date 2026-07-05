import SwiftUI

struct ProfilesView: View {
    @ObservedObject var appState: AppState
    @State private var selectedProfileID: UUID?

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 210, idealWidth: 240)

            detail
                .frame(minWidth: 420)
        }
        .frame(minWidth: 680, minHeight: 420)
        .onAppear {
            selectedProfileID = selectedProfileID ?? appState.profiles.first?.id
        }
        .padding(16)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profiles")
                .font(.headline)

            List(selection: $selectedProfileID) {
                ForEach(appState.profiles) { profile in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.name)
                            .font(.body)
                        Text(profile.ipAddress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(profile.id as UUID?)
                }
            }

            HStack {
                Button {
                    appState.addProfile()
                    selectedProfileID = appState.profiles.last?.id
                } label: {
                    Label("Add", systemImage: "plus")
                }

                Button {
                    if let id = selectedProfileID {
                        appState.deleteProfile(id: id)
                        selectedProfileID = appState.profiles.first?.id
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedProfileID == nil)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        VStack(alignment: .leading, spacing: 16) {
            CurrentNetworkSummaryView(snapshot: appState.snapshot)

            Divider()

            if let id = selectedProfileID, let profile = binding(for: id) {
                ProfileForm(profile: profile)

                HStack {
                    Button {
                        appState.saveProfiles()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        appState.applyProfile(id: id)
                    } label: {
                        Label("Apply Now", systemImage: "bolt.fill")
                    }
                    .disabled(appState.isApplying)

                    Spacer()

                    Button {
                        appState.applyDHCP()
                    } label: {
                        Label("Use DHCP", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(appState.isApplying)
                }

                if let message = appState.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "No Profile Selected",
                    systemImage: "wifi.router",
                    description: Text("Add a static network profile to begin.")
                )
            }
        }
        .padding(.leading, 12)
    }

    private func binding(for id: UUID) -> Binding<NetworkProfile>? {
        guard let index = appState.profiles.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return $appState.profiles[index]
    }
}

private struct CurrentNetworkSummaryView: View {
    let snapshot: NetworkSnapshot

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("Current Wi-Fi")
                    .font(.headline)
                Text(snapshot.ssid)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Mode")
                Text(snapshot.isDHCP ? "DHCP" : "Manual")
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("IP")
                Text(snapshot.ipAddress)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("Gateway")
                Text(snapshot.router)
                    .foregroundStyle(.secondary)
            }
            GridRow {
                Text("DNS")
                Text(snapshot.dnsServers.isEmpty ? "Automatic" : snapshot.dnsServers.joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
        }
        .textSelection(.enabled)
    }
}

private struct ProfileForm: View {
    @Binding var profile: NetworkProfile

    var body: some View {
        Form {
            TextField("Name", text: $profile.name)
            TextField("IP Address", text: $profile.ipAddress)
            TextField("Subnet Mask", text: $profile.subnetMask)
            TextField("Gateway", text: $profile.router)
            TextField("DNS", text: dnsBinding)
            TextField("Bind SSID", text: $profile.boundSSID)
        }
        .textFieldStyle(.roundedBorder)
    }

    private var dnsBinding: Binding<String> {
        Binding(
            get: {
                profile.dnsServers.joined(separator: ", ")
            },
            set: { newValue in
                profile.dnsServers = newValue
                    .split { character in
                        character == "," || character.isWhitespace
                    }
                    .map(String.init)
            }
        )
    }
}
