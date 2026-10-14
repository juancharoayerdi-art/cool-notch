//
//  MiniShelfView.swift
//  Cool Notch
//
//  Compact shelf preview shown next to the music player on the Home view,
//  so files stay one tap (or one drag) away without leaving the music.
//

import SwiftUI

struct MiniShelfView: View {
    @ObservedObject var shelf = ShelfStateViewModel.shared
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @State private var isHovering = false

    private var previewItems: [ShelfItem] {
        Array(shelf.items.suffix(3))
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                ForEach(Array(previewItems.enumerated()), id: \.element.id) { index, item in
                    let depth = previewItems.count - 1 - index
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                        .rotationEffect(.degrees(Double(depth) * (isHovering ? -14 : -8)))
                        .offset(x: CGFloat(depth) * (isHovering ? -9 : -5), y: CGFloat(depth) * -2)
                        .onDrag { dragProvider(for: item) }
                }
            }
            .frame(width: 64, height: 56)

            Text(shelf.items.count == 1 ? "1 archivo" : "\(shelf.items.count) archivos")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.gray)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(isHovering ? 0.08 : 0.04))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.2)) { isHovering = hovering }
        }
        .onTapGesture {
            withAnimation(.smooth) { coordinator.currentView = .shelf }
        }
        .help("Abrir el estante")
    }

    private func dragProvider(for item: ShelfItem) -> NSItemProvider {
        if let url = shelf.resolveFileURL(for: item) ?? item.URL {
            return NSItemProvider(object: url as NSURL)
        }
        if case let .text(string) = item.kind {
            return NSItemProvider(object: string as NSString)
        }
        return NSItemProvider()
    }
}
