import AppKit
import SwiftUI

@main
struct MoonlightMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var library = MacLibraryModel()

    var body: some Scene {
        WindowGroup("Moonlight") {
            MacRootView(library: library)
                .frame(minWidth: 860, minHeight: 520)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct MacRootView: View {
    @ObservedObject var library: MacLibraryModel
    @State private var address = ""

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hosts").font(.headline)
                List(selection: $library.selectedHostID) {
                    ForEach(library.hosts, id: \.uuid) { host in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.name.isEmpty ? "Host" : host.name)
                            Text(host.activeAddress ?? host.address ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(host.uuid)
                    }
                }
                HStack {
                    TextField("Address", text: $address)
                    Button("Add") {
                        library.addHost(address: address)
                        address = ""
                    }
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                HStack {
                    Button("Pair") { library.pairSelectedHost() }
                        .disabled(library.selectedHost == nil)
                    Button("Refresh") { library.refresh() }
                }
            }
            .padding(8)
            .frame(minWidth: 240)

            VStack(alignment: .leading, spacing: 8) {
                if library.streaming, let video = library.videoView {
                    ZStack(alignment: .topTrailing) {
                        MacVideoRepresentable(view: video)
                        VStack(alignment: .trailing, spacing: 6) {
                            Toggle("Relative mouse", isOn: Binding(
                                get: { video.relativeMouse },
                                set: { video.relativeMouse = $0 }
                            ))
                            Button("Stop") { library.stopStream() }
                        }
                        .padding(8)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                        .padding(8)
                    }
                } else {
                    Text("Apps").font(.headline)
                    if library.apps.isEmpty {
                        ContentUnavailableView("No apps", systemImage: "gamecontroller") {
                            Text(library.status)
                        }
                    } else {
                        List(library.apps, id: \.id) { app in
                            Button(app.name) {
                                library.stream(app)
                            }
                        }
                    }
                    Text(library.status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(8)
        }
        .onAppear { library.start() }
        .onChange(of: library.selectedHostID) { _, _ in
            library.loadApps()
        }
        .alert("Pairing", isPresented: $library.showPin) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enter PIN \(library.pin) on the host.")
        }
    }
}

struct MacVideoRepresentable: NSViewRepresentable {
    let view: MacVideoView

    func makeNSView(context: Context) -> MacVideoView {
        view
    }

    func updateNSView(_ nsView: MacVideoView, context: Context) {
        nsView.window?.makeFirstResponder(nsView)
    }
}

final class MacStreamSink: NSObject, ConnectionCallbacks {
    weak var library: MacLibraryModel?
    let token: UUID

    init(library: MacLibraryModel, token: UUID) {
        self.library = library
        self.token = token
    }

    func connectionStarted() {
        library?.connectionStarted(token: token)
    }

    func connectionTerminated(_ errorCode: Int32) {
        library?.connectionTerminated(errorCode, token: token)
    }

    func stageStarting(_ stageName: UnsafePointer<CChar>!) {
        library?.stageStarting(stageName, token: token)
    }

    func stageComplete(_ stageName: UnsafePointer<CChar>!) {
        library?.stageComplete(stageName, token: token)
    }

    func stageFailed(_ stageName: UnsafePointer<CChar>!, withError errorCode: Int32, portTestFlags: Int32) {
        library?.stageFailed(stageName, withError: errorCode, portTestFlags: portTestFlags, token: token)
    }

    func launchFailed(_ message: String!) {
        library?.launchFailed(message, token: token)
    }

    func rumble(_ controllerNumber: UInt16, lowFreqMotor: UInt16, highFreqMotor: UInt16) {}

    func connectionStatusUpdate(_ status: Int32) {
        library?.connectionStatusUpdate(status, token: token)
    }

    func setHdrMode(_ enabled: Bool) {
        library?.setHdrMode(enabled, token: token)
    }

    func rumbleTriggers(_ controllerNumber: UInt16, leftTrigger: UInt16, rightTrigger: UInt16) {}

    func setMotionEventState(_ controllerNumber: UInt16, motionType: UInt8, reportRateHz: UInt16) {}

    func setControllerLed(_ controllerNumber: UInt16, r: UInt8, g: UInt8, b: UInt8) {}

    func videoContentShown() {
        library?.videoContentShown(token: token)
    }
}

final class MacLibraryModel: NSObject, ObservableObject, DiscoveryCallback, PairCallback {
    @Published var hosts: [TemporaryHost] = []
    @Published var apps: [TemporaryApp] = []
    @Published var selectedHostID: String?
    @Published var status = "Searching the local network."
    @Published var streaming = false
    @Published var showPin = false
    @Published var pin = ""

    private let database = DataManager()
    private var discovery: DiscoveryManager?
    private let workQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private(set) var videoView: MacVideoView?
    private var streamManager: StreamManager?
    private var streamSink: MacStreamSink?
    private var activeToken: UUID?
    private var pairingHost: TemporaryHost?

    var selectedHost: TemporaryHost? {
        hosts.first { $0.uuid == selectedHostID }
    }

    func start() {
        let saved = (database.getHosts() as? [TemporaryHost]) ?? []
        hosts = saved
        discovery = DiscoveryManager(hosts: saved, andCallback: self)
        discovery?.startDiscovery()
        status = saved.isEmpty ? "No saved hosts yet. Add an address or wait for discovery." : "Looking for hosts."
    }

    func refresh() {
        discovery?.resetDiscoveryState()
        discovery?.startDiscovery()
    }

    func addHost(address: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        status = "Contacting \(trimmed)…"
        let manager = discovery
        DispatchQueue.global(qos: .userInitiated).async {
            manager?.discoverHost(trimmed, withCallback: { host, message in
                DispatchQueue.main.async {
                    if let host {
                        self.database.updateHost(host)
                        self.selectedHostID = host.uuid
                        self.status = "Added \(host.name)."
                    } else {
                        self.status = message ?? "Could not add that host."
                    }
                }
            })
        }
    }

    func updateAllHosts(_ hosts: [Any]!) {
        let found = (hosts as? [TemporaryHost]) ?? []
        DispatchQueue.main.async {
            self.hosts = found
            if self.selectedHostID == nil {
                self.selectedHostID = found.first?.uuid
            }
        }
    }

    func loadApps() {
        guard let host = selectedHost else {
            apps = []
            return
        }
        if host.pairState != .paired {
            apps = []
            status = "\(host.name) is not paired."
            return
        }
        status = "Loading apps on \(host.name)…"
        DispatchQueue.global(qos: .userInitiated).async {
            let response = ConnectionHelper.getAppListForHost(host)
            let raw = response?.getAppList() as NSSet?
            let loaded = raw?.compactMap { $0 as? TemporaryApp } ?? []
            for app in loaded {
                app.setHost(host)
            }
            DispatchQueue.main.async {
                self.apps = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.status = loaded.isEmpty ? "No apps returned." : "\(loaded.count) apps."
            }
        }
    }

    func pairSelectedHost() {
        guard let host = selectedHost else { return }
        let address = host.activeAddress ?? host.address ?? ""
        guard !address.isEmpty else {
            status = "That host has no address."
            return
        }
        CryptoManager.generateKeyPairUsingSSL()
        let http = HttpManager(host: host)
        pairingHost = host
        let operation = PairManager(manager: http, clientCert: CryptoManager.readCertFromFile(), callback: self)
        workQueue.addOperation(operation)
        status = "Pairing with \(host.name)…"
    }

    func startPairing(_ PIN: String!) {
        DispatchQueue.main.async {
            self.pin = PIN ?? ""
            self.showPin = true
            self.status = "Enter PIN \(self.pin) on the host."
        }
    }

    func pairSuccessful(_ serverCert: Data!) {
        DispatchQueue.main.async {
            if let host = self.pairingHost {
                host.serverCert = serverCert
                host.pairState = .paired
                self.database.updateHost(host)
            }
            self.showPin = false
            self.status = "Paired."
            self.loadApps()
        }
    }

    func pairFailed(_ message: String!) {
        DispatchQueue.main.async {
            self.showPin = false
            self.status = message ?? "Pairing failed."
        }
    }

    func alreadyPaired() {
        DispatchQueue.main.async {
            self.status = "Already paired."
            self.loadApps()
        }
    }

    func stream(_ app: TemporaryApp) {
        guard let config = MacStreamConfig.configurationForApp(app) else {
            status = "Could not build a stream configuration."
            return
        }
        tearDownStream()
        let token = UUID()
        let sink = MacStreamSink(library: self, token: token)
        let video = MacVideoView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        video.callbacks = sink
        let manager = StreamManager(config: config, rendererProvider: { video }, connectionCallbacks: sink)
        activeToken = token
        streamSink = sink
        videoView = video
        streamManager = manager
        streaming = true
        status = "Starting \(app.name)…"
        workQueue.addOperation(manager)
    }

    func stopStream() {
        tearDownStream()
        status = "Stopped."
    }

    private func tearDownStream() {
        activeToken = nil
        streamManager?.stopStream()
        videoView?.stop()
        streamManager = nil
        streamSink = nil
        videoView = nil
        streaming = false
    }

    private func onSession(_ token: UUID, _ body: @escaping () -> Void) {
        DispatchQueue.main.async {
            guard token == self.activeToken else { return }
            body()
        }
    }

    func connectionStarted(token: UUID) {
        onSession(token) { self.status = "Connected." }
    }

    func connectionTerminated(_ errorCode: Int32, token: UUID) {
        onSession(token) {
            self.tearDownStream()
            self.status = "Connection ended (\(errorCode))."
        }
    }

    func stageStarting(_ stageName: UnsafePointer<CChar>!, token: UUID) {
        let stage = stageName.map { String(cString: $0) } ?? ""
        onSession(token) { self.status = "Starting \(stage)…" }
    }

    func stageComplete(_ stageName: UnsafePointer<CChar>!, token: UUID) {
        let stage = stageName.map { String(cString: $0) } ?? ""
        onSession(token) { self.status = "\(stage) complete." }
    }

    func stageFailed(_ stageName: UnsafePointer<CChar>!, withError errorCode: Int32, portTestFlags: Int32, token: UUID) {
        let stage = stageName.map { String(cString: $0) } ?? "stage"
        onSession(token) {
            self.tearDownStream()
            self.status = "\(stage) failed (\(errorCode), flags \(portTestFlags))."
        }
    }

    func launchFailed(_ message: String!, token: UUID) {
        onSession(token) {
            self.tearDownStream()
            self.status = message ?? "Launch failed."
        }
    }

    func connectionStatusUpdate(_ status: Int32, token: UUID) {
        onSession(token) { self.status = "Status \(status)." }
    }

    func setHdrMode(_ enabled: Bool, token: UUID) {
        onSession(token) { self.videoView?.setHdrMode(enabled) }
    }

    func videoContentShown(token: UUID) {
        onSession(token) { self.status = "Streaming." }
    }
}
