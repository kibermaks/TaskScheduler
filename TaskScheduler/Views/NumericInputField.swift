import SwiftUI

struct NumericInputField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var unit: String = ""
    
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $textValue)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .focused($isFocused)
                .onSubmit {
                    validateAndSet()
                }
                .frame(width: 44, height: 22)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .onChange(of: textValue) { _, newValue in
                    // Allow intermediate empty state but only update binding on valid parse
                    if let intValue = Int(newValue.filter { "0123456789".contains($0) }) {
                        if range.contains(intValue) {
                            value = intValue
                        }
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        validateAndSet()
                    }
                }
            
            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(height: 28)
        .onAppear {
            textValue = "\(value)"
        }
        .onChange(of: value) { _, newValue in
            textValue = "\(newValue)"
        }
    }
    
    private func validateAndSet() {
        if let intValue = Int(textValue.filter { "0123456789".contains($0) }) {
            let clamped = min(max(intValue, range.lowerBound), range.upperBound)
            value = clamped
            textValue = "\(clamped)"
        } else {
            textValue = "\(value)"
        }
    }
}
