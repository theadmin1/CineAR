import AVFoundation
import CoreMedia
import Foundation
import ReplayKit

final class ProfessionalRecorder {
    enum RecorderError: LocalizedError {
        case captureUnavailable
        case alreadyRecording
        case notRecording
        case missingVideoFormat
        case invalidVideoDimensions
        case unsupportedVideoSettings
        case writerUnavailable
        case writerStartFailed(String)
        case sampleCaptureFailed(String)
        case sampleDataUnavailable
        case invalidSampleTimestamp
        case sampleAppendFailed(String)
        case noVideoSamples
        case emptyOutput

        var errorDescription: String? {
            switch self {
            case .captureUnavailable:
                "Ekran yakalama şu anda kullanılamıyor"
            case .alreadyRecording:
                "Başka bir kayıt işlemi zaten devam ediyor"
            case .notRecording:
                "Durdurulabilecek etkin bir kayıt yok"
            case .missingVideoFormat:
                "Video biçimi alınamadı"
            case .invalidVideoDimensions:
                "Geçersiz video boyutu alındı"
            case .unsupportedVideoSettings:
                "Bu cihaz seçilen HEVC kayıt ayarlarını desteklemiyor"
            case .writerUnavailable:
                "Video yazıcı hazırlanamadı"
            case .writerStartFailed(let detail):
                "Video yazıcı başlatılamadı: \(detail)"
            case .sampleCaptureFailed(let detail):
                "Görüntü veya ses yakalama hatası: \(detail)"
            case .sampleDataUnavailable:
                "Kayıt verisi kullanıma hazır değildi"
            case .invalidSampleTimestamp:
                "Kayıt verisinin zaman damgası geçersizdi"
            case .sampleAppendFailed(let detail):
                "Kayıt verisi MOV dosyasına yazılamadı: \(detail)"
            case .noVideoSamples:
                "Kayıt için hiç video karesi alınamadı"
            case .emptyOutput:
                "Oluşturulan MOV dosyası boş"
            }
        }
    }

    private enum State {
        case idle
        case starting
        case recording
        case stopping
    }

    private let recorder = RPScreenRecorder.shared()
    private let writingQueue = DispatchQueue(label: "com.cinear.capture.writer")
    private let fileManager = FileManager.default

    // These properties are confined to writingQueue.
    private var state: State = .idle
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var microphoneInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var firstTimestamp: CMTime?
    private var terminalError: Error?
    private var runtimeFailureHandler: ((Error) -> Void)?
    private var runtimeFailureWasReported = false

    func start(
        outputURL: URL,
        runtimeFailure: @escaping (Error) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard recorder.isAvailable else {
            complete(.failure(RecorderError.captureUnavailable), using: completion)
            return
        }

        var validationError: Error?
        writingQueue.sync {
            guard case .idle = state else {
                validationError = RecorderError.alreadyRecording
                return
            }
            self.outputURL = outputURL
            runtimeFailureHandler = runtimeFailure
            terminalError = nil
            runtimeFailureWasReported = false
            firstTimestamp = nil
            state = .starting
        }

        if let validationError {
            complete(.failure(validationError), using: completion)
            return
        }

        recorder.isMicrophoneEnabled = true
        recorder.startCapture(
            handler: { [weak self] sampleBuffer, sampleType, error in
                guard let self else { return }
                self.writingQueue.async {
                    if let error {
                        self.registerFailure(
                            RecorderError.sampleCaptureFailed(error.localizedDescription)
                        )
                        return
                    }
                    self.consume(sampleBuffer, type: sampleType)
                }
            },
            completionHandler: { [weak self] error in
                guard let self else { return }
                self.writingQueue.async {
                    if let error {
                        self.abortSession(removeOutput: true)
                        self.complete(.failure(error), using: completion)
                        return
                    }

                    guard case .starting = self.state else {
                        self.abortSession(removeOutput: true)
                        self.complete(.failure(RecorderError.alreadyRecording), using: completion)
                        return
                    }

                    self.state = .recording
                    self.complete(.success(()), using: completion)
                    self.reportRuntimeFailureIfNeeded()
                }
            }
        )
    }

    func stop(completion: @escaping (Result<URL, Error>) -> Void) {
        var validationError: Error?
        writingQueue.sync {
            guard case .recording = state else {
                validationError = RecorderError.notRecording
                return
            }
            state = .stopping
        }

        if let validationError {
            complete(.failure(validationError), using: completion)
            return
        }

        recorder.stopCapture { [weak self] captureError in
            guard let self else { return }
            self.writingQueue.async {
                self.finishCapture(captureError: captureError, completion: completion)
            }
        }
    }

    private func consume(_ sampleBuffer: CMSampleBuffer, type: RPSampleBufferType) {
        switch state {
        case .starting, .recording:
            break
        case .idle, .stopping:
            return
        }

        guard terminalError == nil else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            registerFailure(RecorderError.sampleDataUnavailable)
            return
        }

        if writer == nil, type == .video {
            do {
                try prepareWriter(using: sampleBuffer)
            } catch {
                registerFailure(error)
                return
            }
        }

        guard let writer else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard timestamp.isValid else {
            registerFailure(RecorderError.invalidSampleTimestamp)
            return
        }
        if firstTimestamp == nil {
            guard type == .video else { return }
            guard writer.startWriting() else {
                registerFailure(
                    RecorderError.writerStartFailed(
                        writer.error?.localizedDescription ?? "bilinmeyen yazıcı hatası"
                    )
                )
                return
            }
            firstTimestamp = timestamp
            writer.startSession(atSourceTime: timestamp)
        } else if let firstTimestamp, CMTimeCompare(timestamp, firstTimestamp) < 0 {
            // ReplayKit can deliver a buffered microphone sample from just before
            // the first video frame. It is outside this writer session.
            return
        }

        guard writer.status == .writing else {
            registerFailure(
                writer.error ?? RecorderError.writerStartFailed("yazıcı writing durumuna geçemedi")
            )
            return
        }

        switch type {
        case .video:
            append(sampleBuffer, to: videoInput, mediaName: "video")
        case .audioMic:
            append(sampleBuffer, to: microphoneInput, mediaName: "mikrofon")
        case .audioApp:
            break
        @unknown default:
            break
        }
    }

    private func append(
        _ sampleBuffer: CMSampleBuffer,
        to input: AVAssetWriterInput?,
        mediaName: String
    ) {
        guard let input, input.isReadyForMoreMediaData else { return }
        guard input.append(sampleBuffer) else {
            registerFailure(
                writer?.error
                    ?? RecorderError.sampleAppendFailed("\(mediaName) verisi reddedildi")
            )
            return
        }
    }

    private func prepareWriter(using sampleBuffer: CMSampleBuffer) throws {
        guard let outputURL else { throw RecorderError.writerUnavailable }
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            throw RecorderError.missingVideoFormat
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        guard dimensions.width > 0, dimensions.height > 0 else {
            throw RecorderError.invalidVideoDimensions
        }

        let compression: [String: Any] = [
            AVVideoAverageBitRateKey: 24_000_000,
            AVVideoExpectedSourceFrameRateKey: 30,
            AVVideoAllowFrameReorderingKey: false
        ]
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(dimensions.width),
            AVVideoHeightKey: Int(dimensions.height),
            AVVideoCompressionPropertiesKey: compression
        ]
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        guard writer.canApply(
            outputSettings: videoSettings,
            forMediaType: .video
        ) else {
            throw RecorderError.unsupportedVideoSettings
        }

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 192_000
        ]
        guard writer.canApply(
            outputSettings: audioSettings,
            forMediaType: .audio
        ) else {
            throw RecorderError.writerUnavailable
        }
        let microphoneInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        microphoneInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(videoInput), writer.canAdd(microphoneInput) else {
            throw RecorderError.writerUnavailable
        }
        writer.add(videoInput)
        writer.add(microphoneInput)

        self.writer = writer
        self.videoInput = videoInput
        self.microphoneInput = microphoneInput
    }

    private func registerFailure(_ error: Error) {
        guard terminalError == nil else { return }
        terminalError = error
        reportRuntimeFailureIfNeeded()
    }

    private func reportRuntimeFailureIfNeeded() {
        guard case .recording = state,
              !runtimeFailureWasReported,
              let terminalError,
              let runtimeFailureHandler else { return }
        runtimeFailureWasReported = true
        DispatchQueue.main.async {
            runtimeFailureHandler(terminalError)
        }
    }

    private func finishCapture(
        captureError: Error?,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if terminalError == nil, let captureError {
            terminalError = captureError
        }

        guard let writer, let outputURL, firstTimestamp != nil else {
            let error = terminalError ?? RecorderError.noVideoSamples
            abortSession(removeOutput: true)
            complete(.failure(error), using: completion)
            return
        }

        guard writer.status == .writing else {
            let error = terminalError ?? writer.error ?? RecorderError.writerUnavailable
            abortSession(removeOutput: true)
            complete(.failure(error), using: completion)
            return
        }

        videoInput?.markAsFinished()
        microphoneInput?.markAsFinished()
        let recordedFailure = terminalError
        writer.finishWriting { [weak self] in
            guard let self else { return }
            self.writingQueue.async {
                let result: Result<URL, Error>
                if let recordedFailure {
                    result = .failure(recordedFailure)
                } else if writer.status != .completed {
                    result = .failure(writer.error ?? RecorderError.writerUnavailable)
                } else if !self.outputHasData(at: outputURL) {
                    result = .failure(RecorderError.emptyOutput)
                } else {
                    result = .success(outputURL)
                }

                let shouldRemoveOutput: Bool
                if case .failure = result {
                    shouldRemoveOutput = true
                } else {
                    shouldRemoveOutput = false
                }
                self.resetSession(removeOutput: shouldRemoveOutput)
                self.complete(result, using: completion)
            }
        }
    }

    private func outputHasData(at url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return false }
        return size.int64Value > 0
    }

    private func abortSession(removeOutput: Bool) {
        if writer?.status == .writing || writer?.status == .unknown {
            writer?.cancelWriting()
        }
        resetSession(removeOutput: removeOutput)
    }

    private func resetSession(removeOutput: Bool) {
        let abandonedURL = outputURL
        state = .idle
        writer = nil
        videoInput = nil
        microphoneInput = nil
        outputURL = nil
        firstTimestamp = nil
        terminalError = nil
        runtimeFailureHandler = nil
        runtimeFailureWasReported = false

        if removeOutput, let abandonedURL,
           fileManager.fileExists(atPath: abandonedURL.path) {
            try? fileManager.removeItem(at: abandonedURL)
        }
    }

    private func complete<Success>(
        _ result: Result<Success, Error>,
        using completion: @escaping (Result<Success, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }
}
