import SwiftUI

struct AccountSetupView: View {
    @ObservedObject var appModel: MailSwipeAppModel
    @State private var emailAddress = ""
    @State private var appSpecificPassword = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("iCloudメール") {
                    TextField("メールアドレス", text: $emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)

                    SecureField("アプリ用パスワード", text: $appSpecificPassword)
                        .textContentType(.password)
                }

                Section {
                    Button {
                        Task {
                            await appModel.connect(
                                emailAddress: emailAddress,
                                appSpecificPassword: appSpecificPassword
                            )
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if appModel.isConnecting {
                                ProgressView()
                            } else {
                                Text("iCloudメールに接続")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(
                        appModel.isConnecting ||
                        emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        appSpecificPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }

                Section("安全性") {
                    Text("アプリ用パスワードはこのiPhoneのKeychainにだけ保存されます。Apple Account本体のパスワードは入力しないでください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("MailSwipeの設定")
            .alert(
                "接続できません",
                isPresented: Binding(
                    get: { appModel.setupErrorMessage != nil },
                    set: { if !$0 { appModel.setupErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(appModel.setupErrorMessage ?? "不明なエラー")
            }
        }
    }
}
