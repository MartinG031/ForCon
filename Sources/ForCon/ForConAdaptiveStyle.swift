import SwiftUI

extension View {
    @ViewBuilder
    func forConAdaptiveSurface(cornerRadius: CGFloat = 18) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.forConMaterialSurface(cornerRadius: cornerRadius)
        }
        #else
        self.forConMaterialSurface(cornerRadius: cornerRadius)
        #endif
    }

    @ViewBuilder
    func forConAdaptiveInteractiveSurface(cornerRadius: CGFloat = 16) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self.forConMaterialSurface(cornerRadius: cornerRadius)
        }
        #else
        self.forConMaterialSurface(cornerRadius: cornerRadius)
        #endif
    }

    @ViewBuilder
    func forConAdaptiveProminentButton() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
        #else
        self.buttonStyle(.borderedProminent)
        #endif
    }

    @ViewBuilder
    func forConAdaptiveButton() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
        #else
        self.buttonStyle(.bordered)
        #endif
    }

    @ViewBuilder
    private func forConMaterialSurface(cornerRadius: CGFloat) -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 0.5)
            }
    }
}
