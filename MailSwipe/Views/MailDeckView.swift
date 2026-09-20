import SwiftUI

struct MailDeckView: View {
    @ObservedObject var viewModel: MailDeckViewModel
    @State private var dragOffset: CGSize = .zero
    @State private var isAnimating = false

    private let horizontalThreshold: CGFloat = 110
    private let downwardThreshold: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                instructionBar

                if viewModel.isLoading {
                    Spacer()
                    ProgressView("未読メールを確認中…")
                    Spacer()
                } else if let message = viewModel.currentMessage {
                    ZStack {
                        MailCardView(
                            message: message,
                            onAttachmentTap: { attachment in
                                Task {
                                    await viewModel.openAttachment(attachment)
                                }
                            }
                        )
                        .id(message.id)
                        .offset(dragOffset)
                        .rotationEffect(.degrees(Double(dragOffset.width / 24)))
                        .overlay(alignment: dragOffset.width >= 0 ? .topLeading : .topTrailing) {
                            swipeBadge
                        }
                        .gesture(dragGesture(in: geometry.size))
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: viewModel.currentIndex)

                    Text(viewModel.progressText)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    completionView
                        .contentShape(Rectangle())
                        .gesture(completionDragGesture)
                }
            }
            .padding()
        }
    }

    private var instructionBar: some View {
        HStack(spacing: 14) {
            Label("未読のまま", systemImage: "arrow.left")
                .foregroundStyle(.orange)
            Spacer()
            Label("戻る", systemImage: "arrow.down")
                .foregroundStyle(viewModel.canGoBack ? .blue : .secondary)
            Spacer()
            Label("既読", systemImage: "arrow.right")
                .foregroundStyle(.green)
        }
        .font(.caption.bold())
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var swipeBadge: some View {
        if abs(dragOffset.width) > 40 {
            Text(dragOffset.width > 0 ? "既読" : "未読のまま")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(dragOffset.width > 0 ? Color.green : Color.orange)
                .clipShape(Capsule())
                .padding(20)
                .opacity(min(abs(dragOffset.width) / horizontalThreshold, 1))
        }
    }

    private var completionView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("新しい未読メールはありません")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            if viewModel.canGoBack {
                Label("下にスワイプすると1通前に戻ります", systemImage: "arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isAnimating else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isAnimating else { return }

                let horizontal = value.translation.width
                let vertical = value.translation.height

                if abs(horizontal) > abs(vertical), abs(horizontal) >= horizontalThreshold {
                    let decision: SwipeDecision = horizontal > 0 ? .read : .keepUnread
                    animateHorizontalSwipe(decision, width: size.width)
                } else if vertical > abs(horizontal), vertical >= downwardThreshold, viewModel.canGoBack {
                    animateGoBack()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private var completionDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                if value.translation.height >= downwardThreshold, viewModel.canGoBack {
                    animateGoBack()
                }
            }
    }

    private func animateHorizontalSwipe(_ decision: SwipeDecision, width: CGFloat) {
        isAnimating = true
        let direction: CGFloat = decision == .read ? 1 : -1

        withAnimation(.easeIn(duration: 0.18)) {
            dragOffset = CGSize(width: direction * width * 1.4, height: dragOffset.height)
        }

        Task {
            try? await Task.sleep(for: .milliseconds(190))
            await viewModel.processCurrentMessage(as: decision)
            dragOffset = .zero
            isAnimating = false
        }
    }

    private func animateGoBack() {
        isAnimating = true

        Task {
            await viewModel.goBack()
            dragOffset = CGSize(width: 0, height: -180)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                dragOffset = .zero
            }
            isAnimating = false
        }
    }
}

