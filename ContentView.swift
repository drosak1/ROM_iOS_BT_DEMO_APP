import SwiftUI
import CoreBluetooth

struct ContentView: View {
    
    @StateObject var ble = BLEManager()
    @State private var customMessage = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Image("logo.jpg")
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            
            Text("ROM DEMO iOS APP")
                .font(.title)
            
            Button(ble.isScanning ? "Skanowanie..." : "Szukaj urządzeń") {
                ble.startScan()
            }
            
            List(ble.devices, id: \.identifier) { device in
                Button {
                    ble.connect(to: device)
                } label: {
                    VStack(alignment: .leading) {
                        Text(device.name ?? "Bez nazwy")
                            .font(.headline)
                        
                        Text(device.identifier.uuidString)
                            .font(.caption)
                    }
                }
            }
            
            Divider()
            
            Text("Status: \(ble.status)")
                .font(.headline)
            
            Text("Odebrane dane:")
                .font(.headline)
            
            ScrollView {
                Text(ble.receivedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(height: 50)
            .border(Color.gray)
            
            HStack {
                Button("WYJAZD") {
                    ble.send("#Y[M1(m1)_0_300][M2(m1)_200_100][M3(m1)_150_500]*")
                }
                
                Button("WJAZD") {
                    ble.send("#J[M2(m1)_0_0][M1(m2)_0_0][M3(m1)_0_100]*")
                }
            }
            
            Divider()
            
            Text("Własna wiadomość Bluetooth")
                .font(.headline)
            
            TextEditor(text: $customMessage)
                .frame(height: 40)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
            
            Button("Wyślij własną wiadomość") {
                ble.send(customMessage)
                customMessage = ""
            }
            .buttonStyle(.borderedProminent)
            .disabled(customMessage.isEmpty)
            
            Spacer()
        }
        .padding()
    }
}
