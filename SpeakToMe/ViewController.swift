/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The primary view controller. The speach-to-text engine is managed an configured here.
*/

import UIKit
import Speech

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    // MARK: Properties
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))! // 認識インスタンス
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?   // 認識リクエスト
    private var recognitionTask: SFSpeechRecognitionTask?   //認識したいタスク
    
    private let audioEngine = AVAudioEngine()
    
    @IBOutlet var textView : UITextView!    // 認識したテキスト
    @IBOutlet var recordButton : UIButton!  // 録音開始のボタン
    
    // MARK: UIViewController
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        speechRecognizer.delegate = self    // デリゲートを設定
        
        /* ユーザから承認を得る（録音ボタンを可否を更新） */
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
                The callback may not be called on the main thread. Add an
                operation to the main queue to update the record button's state.
            */
            OperationQueue.main.addOperation {
                switch authStatus {
                    case .authorized:   // 承認なら録音ボタンを有効
                        self.recordButton.isEnabled = true

                    case .denied:   // 拒否なら録音ボタンを無効
                        self.recordButton.isEnabled = false
                        self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)

                    case .restricted:   // 限定なら録音ボタンを無効にしてメッセージ
                        self.recordButton.isEnabled = false
                        self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)

                    case .notDetermined:    // 不明なら録音ボタンを無効にしてメッセージ
                        self.recordButton.isEnabled = false
                        self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
    }
    
    // 録音する
    private func startRecording() throws {

        // Cancel the previous task if it's running.実行中なら以前のタスクをキャンセル
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // 録音オーディオセッション
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        // バッファを認識するリクエスト
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // 音声エンジンの入力ノード
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        // 認識リクエスト
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.（認識タスクは、音声認識セッションを代理する）
        // We keep a reference to the task so that it can be cancelled.（タスクへの参照をキープするので、キャンセルできる）
        // resultには認識した音声のテキストが入っている
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false // 認識完了フラグ
            
            if let result = result {
            // 認識結果がnilでなければ、画面に表示して
                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal // 完了フラグを立てる
            }
            
            if error != nil || isFinal {
            // 完了した結果にエラーがあるならば、再録音できる状態にする
                self.audioEngine.stop()         // オーディオエンジン停止
                inputNode.removeTap(onBus: 0)   // 入力ノード削除
                
                self.recognitionRequest = nil   // 認識リクエストをカラに
                self.recognitionTask = nil      // 認識タスクをカラに
                
                self.recordButton.isEnabled = true  // 録音ボタンを有効
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }
        
        /* 認識リクエストにバッファを追加 */
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()   // オーディオエンジン準備
        try audioEngine.start() // オーディオエンジン開始
        
        textView.text = "(Go ahead, I'm listening)"
    }

    // MARK: SFSpeechRecognizerDelegate
    // 音声認識機能の状態が変化したら呼ばれる
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
        // 利用可能になったら、録音ボタンを有効にする
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
        // 利用できないなら、録音ボタンは無効にする
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition not available", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    // 録音開始ボタン
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
        // 音声エンジン動作中なら停止
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
            return
        }
        // 録音を開始する
        try! startRecording()
        recordButton.setTitle("Stop recording", for: [])

    }
}

