import Foundation
import AVFoundation

class Recorder: NSObject, ObservableObject {
    // 録音クラス

    // オプショナル型としてAVAudioRecoderを定義
    var audioRecorder: AVAudioRecorder?

    // 録音の状態を管理するプロパティ
    @Published var isRecording = false

    // 録音データの変数を宣言
    @Published var waveformData: [Float] = []

    // サンプリングレート
    var sampleRate: Float = 12800

    // 再生用のAVAudioPlayerを宣言
    private var player: AVAudioPlayer?

    // audioFileURL をプロパティとして宣言（クラス全体でアクセスするため:再生用）
    private var audioFileURL: URL?

    // カスタムクラスのコンストラクタを定義
    override init() {
        super.init()
        setUpAudioRecorder()
    }

    private func setUpAudioRecorder() {
        // 録音の設定

        let recordingSession = AVAudioSession.sharedInstance()

        // エラーを確認
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)

            // 辞書型で設定値を変更
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            // wavファイルのパスを設定する（.wavはリアルタイムに書き込まれる）
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            audioFileURL = documentsPath.appendingPathComponent("recording.wav")

            // audioFileURLのnilチェック
            guard let url = audioFileURL else {
                print("Error: audioFileURL is nil")
                return
            }

            do {
                audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                // audioRecorderがnilでない場合のみバッファ割当てや初期化、設定をする
                audioRecorder?.prepareToRecord()
            } catch {
                print("Error setting up audio recorder: \(error)")
            }

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)

            // audioRecorderがnilでない場合のみバッファ割当てや初期化、設定をする
            audioRecorder?.prepareToRecord()
        }

        // エラーの場合
        catch {
            print("Error setting up audio recorder: \(error)")
        }
    }

    func startRecording() {
        // 録音するメソッド

        audioRecorder?.record()
        isRecording = true
    }

    func stopRecording() {
        // 録音停止するメソッド

        audioRecorder?.stop()
        isRecording = false

        // 録音停止時にwavファイルのパスをコンソールに表示する
        if let audioFileURL = audioRecorder?.url {
            print(audioFileURL)}

        // 配列データとして取得する
        getWaveformData { waveformData in
            print("wave length=", waveformData.count)
            self.waveformData = waveformData
        }
    }

    func getWaveformData(completion: @escaping ([Float]) -> Void) {
        // 録音結果の配列データを取得するメソッド

        guard let audioFileURL = audioRecorder?.url else { return }

        do {
            let audioFile = try AVAudioFile(forReading: audioFileURL)
            let audioFormat = AVAudioFormat(standardFormatWithSampleRate: audioFile.processingFormat.sampleRate, channels: audioFile.processingFormat.channelCount)

            let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: UInt32(audioFile.length))
            try audioFile.read(into: audioBuffer!)

            let floatArray = Array(UnsafeBufferPointer(start: audioBuffer!.floatChannelData![0], count: Int(audioBuffer!.frameLength)))

            completion(floatArray)
        } catch {
            print("Error getting waveform data: \(error)")
        }
    }

    func playRecording() {
        guard let url = audioFileURL else {
            print("Audio file not found")
            return
        }

        do {

            try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .defaultToSpeaker)
            try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            try? AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Error playing audio: \(error)")
        }
    }
}

struct PointsData: Identifiable {
    // 点群データの構造体

    var xValue: Float
    var yValue: Float
    var id = UUID()
}
