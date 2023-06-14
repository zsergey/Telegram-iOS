import Foundation
import AVFoundation
import UIKit
import SwiftSignalKit
import CoreImage
import Vision
import VideoToolbox

public struct CameraCode: Equatable {
    public enum CodeType {
        case qr
    }
    
    public let type: CodeType
    public let message: String
    public let corners: [CGPoint]
    
    public init(type: CameraCode.CodeType, message: String, corners: [CGPoint]) {
        self.type = type
        self.message = message
        self.corners = corners
    }
    
    public var boundingBox: CGRect {
        let x = self.corners.map { $0.x }
        let y = self.corners.map { $0.y }
        if let minX = x.min(), let minY = y.min(), let maxX = x.max(), let maxY = y.max() {
            return CGRect(x: minX, y: minY, width: abs(maxX - minX), height: abs(maxY - minY))
        }
        return CGRect.null
    }
    
    public static func == (lhs: CameraCode, rhs: CameraCode) -> Bool {
        if lhs.type != rhs.type {
            return false
        }
        if lhs.message != rhs.message {
            return false
        }
        if lhs.corners != rhs.corners {
            return false
        }
        return true
    }
}

final class CameraOutput: NSObject {
    let photoOutput = AVCapturePhotoOutput()
    let videoOutput = AVCaptureVideoDataOutput()
    let audioOutput = AVCaptureAudioDataOutput()
    let metadataOutput = AVCaptureMetadataOutput()
    private let faceLandmarksOutput = FaceLandmarksDataOutput()
    
    private var photoConnection: AVCaptureConnection?
    private var videoConnection: AVCaptureConnection?
    private var previewConnection: AVCaptureConnection?
    
    private let queue = DispatchQueue(label: "")
    private let metadataQueue = DispatchQueue(label: "")
    private let faceLandmarksQueue = DispatchQueue(label: "")
    
    private var photoCaptureRequests: [Int64: PhotoCaptureContext] = [:]
    private var videoRecorder: VideoRecorder?
    
    var activeFilter: CameraFilter?
    var faceLandmarks: Bool = false
    
    var processSampleBuffer: ((CMSampleBuffer, CVImageBuffer, AVCaptureConnection) -> Void)?
    var processCodes: (([CameraCode]) -> Void)?
    var processFaceLandmarks: (([VNFaceObservation]) -> Void)?
    
    override init() {
        super.init()

        self.videoOutput.alwaysDiscardsLateVideoFrames = false
        self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] as [String : Any]
        
        self.faceLandmarksOutput.outputFaceObservations = { [weak self] observations in
            if let self {
                self.processFaceLandmarks?(observations)
            }
        }
    }
    
    deinit {
        self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
        self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
    }
    
    func configure(for session: CameraSession, device: CameraDevice, input: CameraInput, previewView: CameraSimplePreviewView?, audio: Bool, photo: Bool, metadata: Bool) {
        if session.session.canAddOutput(self.videoOutput) {
            session.session.addOutputWithNoConnections(self.videoOutput)
            self.videoOutput.setSampleBufferDelegate(self, queue: self.queue)
        }
        if audio, session.session.canAddOutput(self.audioOutput) {
            session.session.addOutput(self.audioOutput)
            self.audioOutput.setSampleBufferDelegate(self, queue: self.queue)
        }
        if photo, session.session.canAddOutput(self.photoOutput) {
            session.session.addOutputWithNoConnections(self.photoOutput)
        }
        if metadata, session.session.canAddOutput(self.metadataOutput) {
            session.session.addOutput(self.metadataOutput)
            
            self.metadataOutput.setMetadataObjectsDelegate(self, queue: self.metadataQueue)
            if self.metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                self.metadataOutput.metadataObjectTypes = [.qr]
            }
        }
        
        if #available(iOS 13.0, *) {
            if let device = device.videoDevice, let ports = input.videoInput?.ports(for: AVMediaType.video, sourceDeviceType: device.deviceType, sourceDevicePosition: device.position) {
                if let previewView {
                    let previewConnection = AVCaptureConnection(inputPort: ports.first!, videoPreviewLayer: previewView.videoPreviewLayer)
                    if session.session.canAddConnection(previewConnection) {
                        session.session.addConnection(previewConnection)
                        self.previewConnection = previewConnection
                    }
                }
                
                let videoConnection = AVCaptureConnection(inputPorts: ports, output: self.videoOutput)
                if session.session.canAddConnection(videoConnection) {
                    session.session.addConnection(videoConnection)
                    self.videoConnection = videoConnection
                }
                
                if photo {
                    let photoConnection = AVCaptureConnection(inputPorts: ports, output: self.photoOutput)
                    if session.session.canAddConnection(photoConnection) {
                        session.session.addConnection(photoConnection)
                        self.photoConnection = photoConnection
                    }
                }
            }
        }
    }
    
    func reconfigure(for session: CameraSession, device: CameraDevice, input: CameraInput, otherPreviewView: CameraSimplePreviewView?, otherOutput: CameraOutput) {
        if #available(iOS 13.0, *) {
            if let previewConnection = self.previewConnection {
                if session.session.connections.contains(where: { $0 === previewConnection }) {
                    session.session.removeConnection(previewConnection)
                }
                self.previewConnection = nil
            }
            if let videoConnection = self.videoConnection {
                if session.session.connections.contains(where: { $0 === videoConnection }) {
                    session.session.removeConnection(videoConnection)
                }
                self.videoConnection = nil
            }
            if let photoConnection = self.photoConnection {
                if session.session.connections.contains(where: { $0 === photoConnection }) {
                    session.session.removeConnection(photoConnection)
                }
                self.photoConnection = nil
            }
            
            if let device = device.videoDevice, let ports = input.videoInput?.ports(for: AVMediaType.video, sourceDeviceType: device.deviceType, sourceDevicePosition: device.position) {
                if let otherPreviewView {
                    let previewConnection = AVCaptureConnection(inputPort: ports.first!, videoPreviewLayer: otherPreviewView.videoPreviewLayer)
                    if session.session.canAddConnection(previewConnection) {
                        session.session.addConnection(previewConnection)
                        self.previewConnection = previewConnection
                    }
                }
                
                let videoConnection = AVCaptureConnection(inputPorts: ports, output: otherOutput.videoOutput)
                if session.session.canAddConnection(videoConnection) {
                    session.session.addConnection(videoConnection)
                    self.videoConnection = videoConnection
                }
                
                
                let photoConnection = AVCaptureConnection(inputPorts: ports, output: otherOutput.photoOutput)
                if session.session.canAddConnection(photoConnection) {
                    session.session.addConnection(photoConnection)
                    self.photoConnection = photoConnection
                }
            }
        }
    }
    
    func toggleConnection() {
        
    }
    
    func invalidate(for session: CameraSession) {
        if #available(iOS 13.0, *) {
            if let previewConnection = self.previewConnection {
                if session.session.connections.contains(where: { $0 === previewConnection }) {
                    session.session.removeConnection(previewConnection)
                }
                self.previewConnection = nil
            }
            if let videoConnection = self.videoConnection {
                if session.session.connections.contains(where: { $0 === videoConnection }) {
                    session.session.removeConnection(videoConnection)
                }
                self.videoConnection = nil
            }
            if let photoConnection = self.photoConnection {
                if session.session.connections.contains(where: { $0 === photoConnection }) {
                    session.session.removeConnection(photoConnection)
                }
                self.photoConnection = nil
            }
        }
        if session.session.outputs.contains(where: { $0 === self.videoOutput }) {
            session.session.removeOutput(self.videoOutput)
        }
        if session.session.outputs.contains(where: { $0 === self.audioOutput }) {
            session.session.removeOutput(self.audioOutput)
        }
        if session.session.outputs.contains(where: { $0 === self.photoOutput }) {
            session.session.removeOutput(self.photoOutput)
        }
        if session.session.outputs.contains(where: { $0 === self.metadataOutput }) {
            session.session.removeOutput(self.metadataOutput)
        }
    }
    
    func configureVideoStabilization() {
        if let videoDataOutputConnection = self.videoOutput.connection(with: .video), videoDataOutputConnection.isVideoStabilizationSupported {
            videoDataOutputConnection.preferredVideoStabilizationMode = .standard
//            if #available(iOS 13.0, *) {
//                videoDataOutputConnection.preferredVideoStabilizationMode = .cinematicExtended
//            } else {
//                videoDataOutputConnection.preferredVideoStabilizationMode = .cinematic
//            }
        }
    }
    
    var isFlashActive: Signal<Bool, NoError> {
        return Signal { [weak self] subscriber in
            guard let self else {
                return EmptyDisposable
            }
            subscriber.putNext(self.photoOutput.isFlashScene)
            let observer = self.photoOutput.observe(\.isFlashScene, options: [.new], changeHandler: { device, _ in
                subscriber.putNext(self.photoOutput.isFlashScene)
            })
            return ActionDisposable {
                observer.invalidate()
            }
        }
        |> distinctUntilChanged
    }
    
    func takePhoto(orientation: AVCaptureVideoOrientation, flashMode: AVCaptureDevice.FlashMode) -> Signal<PhotoCaptureResult, NoError> {
        if let connection = self.photoOutput.connection(with: .video) {
            connection.videoOrientation = orientation
        }
        
        let settings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
        settings.flashMode = flashMode
        if let previewPhotoPixelFormatType = settings.availablePreviewPhotoPixelFormatTypes.first {
            settings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }
        if #available(iOS 13.0, *) {
            settings.photoQualityPrioritization = .speed
        }
        
        let uniqueId = settings.uniqueID
        let photoCapture = PhotoCaptureContext(settings: settings, filter: self.activeFilter)
        self.photoCaptureRequests[uniqueId] = photoCapture
        self.photoOutput.capturePhoto(with: settings, delegate: photoCapture)
        
        return photoCapture.signal
        |> afterDisposed { [weak self] in
            self?.photoCaptureRequests.removeValue(forKey: uniqueId)
        }
    }
    
    private var recordingCompletionPipe = ValuePipe<(String, UIImage?)?>()
    func startRecording() -> Signal<Double, NoError> {
        guard self.videoRecorder == nil else {
            return .complete()
        }
        
        let codecType: AVVideoCodecType
        if hasHEVCHardwareEncoder {
            codecType = .hevc
        } else {
            codecType = .h264
        }
        
        guard let videoSettings = self.videoOutput.recommendedVideoSettings(forVideoCodecType: codecType, assetWriterOutputFileType: .mp4) else {
            return .complete()
        }
        guard let audioSettings = self.audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4) else {
            return .complete()
        }
        
        let outputFileName = NSUUID().uuidString
        let outputFilePath = NSTemporaryDirectory() + outputFileName + ".mp4"
        let outputFileURL = URL(fileURLWithPath: outputFilePath)
        let videoRecorder = VideoRecorder(configuration: VideoRecorder.Configuration(videoSettings: videoSettings, audioSettings: audioSettings), videoTransform: CGAffineTransform(rotationAngle: .pi / 2.0), fileUrl: outputFileURL, completion: { [weak self] result in
            if case let .success(transitionImage) = result {
                self?.recordingCompletionPipe.putNext((outputFilePath, transitionImage))
            } else {
                self?.recordingCompletionPipe.putNext(nil)
            }
        })
        
        videoRecorder?.start()
        self.videoRecorder = videoRecorder
        
        return Signal { subscriber in
            let timer = SwiftSignalKit.Timer(timeout: 0.1, repeat: true, completion: { [weak videoRecorder] in
                subscriber.putNext(videoRecorder?.duration ?? 0.0)
            }, queue: Queue.mainQueue())
            timer.start()
            
            return ActionDisposable {
                timer.invalidate()
            }
        }
    }
    
    func stopRecording() -> Signal<(String, UIImage?)?, NoError> {
        self.videoRecorder?.stop()
        
        return self.recordingCompletionPipe.signal()
        |> take(1)
        |> afterDisposed {
            self.videoRecorder = nil
        }
    }
}

extension CameraOutput: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }
        
        if self.faceLandmarks {
            self.faceLandmarksQueue.async {
                self.faceLandmarksOutput.process(sampleBuffer: sampleBuffer)
            }
        }
        
        if let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            self.processSampleBuffer?(sampleBuffer, videoPixelBuffer, connection)
        }
        
//        let finalSampleBuffer: CMSampleBuffer = sampleBuffer
//        if let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
//            var finalVideoPixelBuffer = videoPixelBuffer
//            if let filter = self.activeFilter {
//                if !filter.isPrepared {
//                    filter.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
//                }
//
//                guard let filteredBuffer = filter.render(pixelBuffer: finalVideoPixelBuffer) else {
//                    return
//                }
//                finalVideoPixelBuffer = filteredBuffer
//            }
//            self.processSampleBuffer?(finalVideoPixelBuffer, connection)
//        }
        
        if let videoRecorder = self.videoRecorder, videoRecorder.isRecording {
            videoRecorder.appendSampleBuffer(sampleBuffer)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
    }
}

extension CameraOutput: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let codes: [CameraCode] = metadataObjects.filter { $0.type == .qr }.compactMap { object in
            if let object = object as? AVMetadataMachineReadableCodeObject, let stringValue = object.stringValue, !stringValue.isEmpty {
                #if targetEnvironment(simulator)
                return CameraCode(type: .qr, message: stringValue, corners: [CGPoint(), CGPoint(), CGPoint(), CGPoint()])
                #else
                return CameraCode(type: .qr, message: stringValue, corners: object.corners)
                #endif
            } else {
                return nil
            }
        }
        self.processCodes?(codes)
    }
}

private let hasHEVCHardwareEncoder: Bool = {
    let spec: [CFString: Any] = [:]
    var outID: CFString?
    var properties: CFDictionary?
    let result = VTCopySupportedPropertyDictionaryForEncoder(width: 1920, height: 1080, codecType: kCMVideoCodecType_HEVC, encoderSpecification: spec as CFDictionary, encoderIDOut: &outID, supportedPropertiesOut: &properties)
    if result == kVTCouldNotFindVideoEncoderErr {
        return false
    }
    return result == noErr
}()
