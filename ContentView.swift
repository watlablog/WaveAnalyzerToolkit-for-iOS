import SwiftUI
import Charts

struct ContentView: View {
    
    init(){
        // タブ背景色を変更
        UITabBar.appearance().backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.2)
    }
    
    // UIの宣言
    @State private var selectedFs = 2048
    let FsOptions = [1024, 2048, 4096, 8192]
    
    @State private var text_overlapRatio: String = "50"
    @State private var text_dbref: String = "2e-5"
    
    // データ構造関係の宣言
    @State private var data: [PointsData] = []
    @State private var x: [Float] = []
    @State private var y: [Float] = []
    @State private var dataFreq: [PointsData] = []
    @State private var x_freq: [Float] = []
    @State private var y_freq: [Float] = []
    
    // 録音関係の宣言
    @StateObject private var recorder = Recorder()
    private var dt: Float { Float(1.0 / recorder.sampleRate) }
    @State private var isDisplayingData = false
    
    // 平均化フーリエ変換の宣言
    @State private var Fs: Int = 2048
    @State private var overlapRatio: Float = 50
    @State private var dbref: Float = 2e-5
    
    var body: some View {
        // UIとイベント
        
        TabView() {
            VStack{
                // 録音と再生の画面
                
                
                Text("Amplitude[Lin.]")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.all, 1)
                
                
                Chart {
                    // データ構造からx, y値を取得して散布図プロット
                    
                    ForEach(data) { shape in
                        // 折れ線グラフをプロット
                        
                        LineMark(
                            x: .value("x", shape.xValue),
                            y: .value("y", shape.yValue)
                        )
                    }
                }
                
                
                .padding(.all, 10)
                Text("Time [s]")
                    .font(.caption)
                    .padding(.all, 1)
                
                HStack{
                    if recorder.isRecording {
                        // 録音している時
                        
                        Button(action: {
                            // 停止ボタンが押されたらデータをChartsに表示させる
                            
                            // 録音の実行
                            print("Stop")
                            recorder.stopRecording()
                            
                            
                            // データ取得
                            y = recorder.waveformData
                            
                            // 時間波形
                            let samplePoints = Float(y.count)
                            x = Array(stride(from: 0.0, to: samplePoints * dt, by: dt))
                            
                            // 時間波形プロットデータの追加
                            data.removeAll()
                            dataFreq.removeAll()
                            data = zip(x, y).map { PointsData(xValue: $0, yValue: $1) }
                            isDisplayingData = false
                            
                            // FFT用パラメータの読み込み
                            guard let overlapRatio = Float(text_overlapRatio), let dbref = Float(text_dbref) else {
                                print("Invalid input")
                                isDisplayingData = false
                                return
                            }
                            
                            // バックグラウンドでデータ処理を行う
                            DispatchQueue.global(qos: .userInitiated).async {
                                
                                
                                // 平均化FFT
                                let (averageAmplitude, freq) = DSP.averagedFFT(y: y, samplerate: Float(recorder.sampleRate), Fs: Fs, overlapRatio: overlapRatio)
                                
                                // dB変換
                                let dBAmplitudes = DSP.db(x: averageAmplitude, dBref: dbref)
                                
                                // Aスケール聴感補正
                                let correctedAmplitudes = DSP.aweightings(frequencies: freq, dB: dBAmplitudes).enumerated().map { dBAmplitudes[$0.offset] + $0.element }
                                
                                // メインと同期させる
                                DispatchQueue.main.async {
                                    // FFT波形のプロット
                                    dataFreq = zip(freq, correctedAmplitudes).map { PointsData(xValue: $0, yValue: $1) }
                                    isDisplayingData = false
                                }
                            }
                        }) {
                            Text("Stop Recording")
                                .padding()
                                .background(Color.red)
                                .foregroundColor(Color.white)
                                .cornerRadius(10)
                                .padding(.all, 10)
                        }
                    } else {
                        // 録音していない時
                        
                        Button(action: {
                            print("Start")
                            isDisplayingData = true
                            recorder.startRecording()
                            
                        }) {
                            Text("Start Recording")
                                .padding()
                                .background(Color.green)
                                .foregroundColor(Color.white)
                                .cornerRadius(10)
                                .padding(.all, 10)
                        }
                        .opacity(isDisplayingData ? 0.5 : 1.0)
                        .disabled(isDisplayingData)
                    }
                    Button("Play"){
                        // 音声を再生する
                        
                        recorder.playRecording()
                        
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(Color.white)
                    .cornerRadius(10)
                    .padding(.all, 10)
                }
            }
            .padding()
            .tabItem{
                Image(systemName: "mic.circle.fill")
                Text("REC")
            }
            
            VStack{
                // 周波数分析の画面
                
                Text("Amplitude[dBA]")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.all, 1)
                Chart {
                    // データ構造からx, y値を取得して散布図プロット
                    
                    ForEach(dataFreq) { shape in
                        // 折れ線グラフをプロット
                        
                        LineMark(
                            x: .value("x", shape.xValue),
                            y: .value("y", shape.yValue)
                        )
                    }
                }
                
                Text("Frequency [Hz]")
                    .font(.caption)
                    .padding(.bottom, 10)
                
            }
            .padding()
            .tabItem{
                Image(systemName: "chart.bar.xaxis")
                Text("Freq.")
            }
            
            VStack{
                // 設定画面
                
                GroupBox(label: Text("Frame size").font(.headline)) {
                    Picker("Select Fs", selection: $selectedFs) {
                        ForEach(FsOptions, id: \.self) {
                            Text("\($0)")
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding(.bottom, 10)
                
                GroupBox(label: Text("Overlap ratio[%]").font(.headline)) {
                    TextField("Enter Overlap ratio[%].", text:$text_overlapRatio)
                        .keyboardType(.default)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.bottom, 10)
                
                GroupBox(label: Text("dBref").font(.headline)) {
                    TextField("Enter dBref.", text:$text_dbref)
                        .keyboardType(.default)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .padding()
            .tabItem{
                Image(systemName: "gear")
                Text("Setting")
            }
        }
        .accentColor(.blue)
        .edgesIgnoringSafeArea(.top)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // プレビュー
        ContentView()
    }
}
