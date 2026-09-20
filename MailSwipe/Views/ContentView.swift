import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: MailDeckViewModel
    let onDisconnect: () -> Void

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

                            Divider()

                            Button("iCloudアカウント設定を削除", role: .destructive) {
                                onDisconnect()
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
                .sheet(item: $viewModel.attachmentPreview) { preview in
                    QuickLookPreview(url: preview.url)
                }
        }
    }
}
