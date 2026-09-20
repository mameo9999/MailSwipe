import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: MailDeckViewModel

    var body: some View {
        NavigationStack {
            MailDeckView(viewModel: viewModel)
                .navigationTitle("MailSwipe")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("確認済み履歴をリセット", role: .destructive) {
                                Task {
                                    await viewModel.resetReviewedHistory()
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .task {
                    await viewModel.load()
                }
                .alert(
                    "エラー",
                    isPresented: Binding(
                        get: { viewModel.errorMessage != nil },
                        set: { if !$0 { viewModel.errorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(viewModel.errorMessage ?? "不明なエラー")
                }
        }
    }
}

