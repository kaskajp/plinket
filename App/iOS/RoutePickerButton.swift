import AVKit
import SwiftUI

/// The system AirPlay / output route picker.
struct RoutePickerButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let pickerView = AVRoutePickerView()
        pickerView.prioritizesVideoDevices = false
        return pickerView
    }

    func updateUIView(_ pickerView: AVRoutePickerView, context: Context) {}
}
