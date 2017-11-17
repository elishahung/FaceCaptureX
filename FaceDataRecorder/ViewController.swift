//
//  ViewController.swift
//  FaceDataRecorder
//
//  Created by 洪健淇 on 2017/11/12.
//  Copyright © 2017年 洪健淇. All rights reserved.
//

import UIKit
import ARKit
import SceneKit
import Foundation

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var switchButton: UISwitch!
    @IBOutlet weak var settingButton: UIButton!
    @IBOutlet weak var infoText: UILabel!    
    
    private let ini = UserDefaults.standard
    
    var session: ARSession {
        return sceneView.session
    }
    
    var isCapturing = false {
        didSet {
            switchButton.isEnabled = !isCapturing
            settingButton.isEnabled = !isCapturing
        }
    }
    
    var captureMode = CaptureMode.stream {
        didSet {
            if captureMode == .record {
                 if switchButton.isOn { switchButton.isOn = false }
            }
            refreshInfo()
            ini.set(captureMode == .record, forKey: "mode")
        }
    }
    
    // stream's attr
    var host = "192.168.1.101" {
        didSet {
            ini.set(host, forKey: "host")
        }
    }
    var port = 19977 {
        didSet {
            ini.set(port, forKey: "port")
        }
    }
    var outputStream: OutputStream!
    
    // record's attr
    var fps = 30.0 {
        didSet {
            fps = min(max(fps, 1.0), 60.0)
            ini.set(fps, forKey: "fps")
        }
    }
    var fpsTimer: Timer!
    var captureData: [CaptureData]!
    var currentCaptureFrame = 0
    var folderPath : URL!
    private let saveQueue = DispatchQueue.init(label: "com.eliWorks.faceCaptureX")
    
    // init
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let lastHost = ini.string(forKey: "host") {
            host = lastHost
        }
        let lastPort = ini.integer(forKey: "port")
        if lastPort != 0 {
            port = lastPort
        }
        let lastFps = ini.double(forKey: "fps")
        if lastFps != 0 {
            fps = lastFps
        }
        let lastMode = ini.bool(forKey: "mode")
        if lastMode {
            captureMode = .record
        }else{
            captureMode = .stream
        }
       
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = false
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // view
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        initTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCapture()
        session.pause()
    }
    
    // delegate
    func session(_ session: ARSession, didFailWithError error: Error) {
        return
    }
    func sessionWasInterrupted(_ session: ARSession) {
        return
    }
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.initTracking()
        }
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if captureMode == .stream && isCapturing {
            streamData()
        }
    }
    
    // UI Actions
    @IBAction func pressCaptureButton(_ sender: Any) {
        // STOP
        if isCapturing {
            stopCapture()
        }else{
        // CAPTURE
            var text: String!
            switch captureMode {
            case .record:
                text = "Recording"
            case .stream:
                text = "Streaming"
            }
            captureButton.setTitle(text, for: .normal)
            
            startCapture()
        }
    }
    
    @IBAction func switchCaptureMode(_ sender: Any) {
        captureMode = switchButton.isOn ? .stream : .record
    }
    
    @IBAction func settingPressed(_ sender: Any) {
        switch captureMode {
        case .record:
            popRecordSetting()
        case .stream:
            popStreamSetting()
        }
    }
    
    func refreshInfo() {
        switch captureMode{
        case .record:
            infoText.text = "Record > \(fps) FPS"
        case .stream:
            infoText.text = "Stream > \(host):\(port)"
        }
    }
    
    // standard
    func initTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func startCapture() {
        isCapturing = true
        refreshInfo()
        
        switch captureMode {
            
        case .stream:
            if outputStream != nil {
                outputStream.close()
            }
            var out: OutputStream?
            Stream.getStreamsToHost(withName: host, port: port, inputStream: nil, outputStream: &out)
            outputStream = out!
            outputStream.open()
            streamData()
            
        case .record:
            captureData = []
            currentCaptureFrame = 0
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            folderPath = documentPath.appendingPathComponent(folderName())
            try? FileManager.default.createDirectory(atPath: folderPath.path, withIntermediateDirectories: true, attributes: nil)
            
            fpsTimer = Timer.scheduledTimer(withTimeInterval: 1/fps, repeats: true, block: {(timer) -> Void in
                self.recordData()
            })
            
        }
    }
    
    func stopCapture() {
        isCapturing = false
        switch captureMode {
        case .stream:
            let dataStr = "e"
            let dataBuffer = dataStr.data(using: .utf8)!
            _ = dataBuffer.withUnsafeBytes { self.outputStream.write($0, maxLength: dataBuffer.count) }
            outputStream.close()
        case .record:
            fpsTimer.invalidate()
            let fileName = folderPath.appendingPathComponent("faceData.txt")
            let data = captureData.map{ $0.str }.joined(separator: "\n")
            try? data.write(to: fileName, atomically: false, encoding: String.Encoding.utf8)
        }
        
        captureButton.setTitle("Capture", for: .normal)
    }
    
    func streamData() {
        if outputStream.streamStatus == .error {
            infoText.text = "Connection Error!"
            stopCapture()
            return
        }
        let arFrame = session.currentFrame!
        guard let anchor = arFrame.anchors[0] as? ARFaceAnchor else {return}
        let vertices = anchor.geometry.vertices
        let data = CaptureData(vertices: vertices, camTransform: arFrame.camera.transform, faceTransform: anchor.transform)
        
        saveQueue.async{
            autoreleasepool {
                let dataStr = data.str + "a"
                let dataBuffer = dataStr.data(using: .utf8)!
                _ = dataBuffer.withUnsafeBytes { self.outputStream.write($0, maxLength: dataBuffer.count) }
            }
        }
    }
    
    func recordData() {
        let arFrame = session.currentFrame!
        guard let anchor = arFrame.anchors[0] as? ARFaceAnchor else {return}
        let vertices = anchor.geometry.vertices
        let data = CaptureData(vertices: vertices, camTransform: arFrame.camera.transform, faceTransform: anchor.transform)
        captureData.append(data)
        
        let snap = arFrame.capturedImage
        let num = currentCaptureFrame
        saveQueue.async{
            autoreleasepool {
                let writePath = self.folderPath.appendingPathComponent( String(format: "%04d", num)+".jpg" )
                try? UIImageJPEGRepresentation(UIImage(pixelBuffer: snap), 0.85)?.write(to: writePath)
            }
        }

        currentCaptureFrame += 1
    }
    
    // utility
    func folderName() -> String {
        let dateFormatter : DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMdd_HHmmss"
        let date = Date()
        let folderStr = dateFormatter.string(from: date)
        return folderStr
    }
    
    func popRecordSetting() {
        let alert = UIAlertController(title: "Record Setting", message: "Set frames per second.", preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "\(self.fps)"
            textField.keyboardType = .decimalPad
        })
        
        let okAction = UIAlertAction(title: "Accept", style: .default, handler: { (action) -> Void in
            self.fps = Double(alert.textFields![0].text!)!
            self.refreshInfo()
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: {(action) -> Void in})
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func popStreamSetting() {
        let alert = UIAlertController(title: "Stream Setting", message: "Set stream server IP address.", preferredStyle: .alert)
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = self.host
            textField.keyboardType = .decimalPad
        })
        
        alert.addTextField(configurationHandler: { textField in
            textField.placeholder = "\(self.port)"
            textField.keyboardType = .decimalPad
        })
        
        let okAction = UIAlertAction(title: "Accept", style: .default, handler: { (action) -> Void in
            if alert.textFields![0].text != "" {
                self.host = alert.textFields![0].text!
            }
            if alert.textFields![1].text != "" {
                self.port = Int(alert.textFields![1].text!)!
            }
            self.refreshInfo()
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: {(action) -> Void in})
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
}
    


