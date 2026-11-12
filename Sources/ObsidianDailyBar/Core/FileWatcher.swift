import Foundation

public final class FileWatcher: @unchecked Sendable {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private let queue = DispatchQueue(label: "com.obsidian.dailybar.filewatcher", qos: .utility)
    private var debounceTimer: DispatchSourceTimer?
    private var pollTimer: DispatchSourceTimer?
    private var lastMTime: Date?
    private var currentFileURL: URL?

    public var onChange: (@Sendable () -> Void)?

    public init() {}

    deinit {
        stop()
    }

    public func watch(file: URL?, folder: URL?) {
        stop()

        self.currentFileURL = file
        if let file = file {
            self.lastMTime = getModificationDate(for: file)
            addWatchSource(for: file)
        }

        if let folder = folder {
            addWatchSource(for: folder)
        }

        // 启动后台轻量 mtime 定时检测兜底 (每 2 秒一次，极其省电)
        startPollTimer()
    }

    private func addWatchSource(for url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptors.append(fd)

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            self?.notifyWithDebounce()
        }

        src.setCancelHandler { [fd] in
            close(fd)
        }

        sources.append(src)
        src.resume()
    }

    private func startPollTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(2), repeating: .seconds(2))
        timer.setEventHandler { [weak self] in
            guard let self = self, let file = self.currentFileURL else { return }
            let currentMTime = self.getModificationDate(for: file)
            if currentMTime != self.lastMTime {
                self.lastMTime = currentMTime
                self.notifyWithDebounce()
            }
        }
        self.pollTimer = timer
        timer.resume()
    }

    private func getModificationDate(for url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    public func stop() {
        if let timer = debounceTimer {
            timer.cancel()
            debounceTimer = nil
        }
        if let timer = pollTimer {
            timer.cancel()
            pollTimer = nil
        }
        for src in sources {
            src.cancel()
        }
        sources.removeAll()
        fileDescriptors.removeAll()
        currentFileURL = nil
        lastMTime = nil
    }

    private func notifyWithDebounce() {
        debounceTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(150))
        timer.setEventHandler { [weak self] in
            self?.onChange?()
        }
        debounceTimer = timer
        timer.resume()
    }
}
