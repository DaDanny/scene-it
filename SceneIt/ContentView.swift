import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Scene It")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Virtual Camera with Overlays")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Scene It is running in your menu bar.")
                    .font(.body)
                
                HStack {
                    Text("Look for the")
                    Image(systemName: "video.circle")
                        .foregroundColor(.blue)
                    Text("icon in the top-right corner of your screen.")
                }
                .font(.body)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Hide Window") {
                NSApplication.shared.hide(nil)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(width: 400, height: 300)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}