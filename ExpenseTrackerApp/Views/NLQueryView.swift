import SwiftUI

struct NLQueryView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Input Region
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Ask about your expenses...", text: $appViewModel.queryInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit {
                        appViewModel.runNLQuery(appViewModel.queryInput)
                    }
                
                if appViewModel.isRunningQuery {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.trailing, 4)
                } else if !appViewModel.queryInput.isEmpty {
                    Button(action: {
                        appViewModel.queryInput = ""
                        appViewModel.queryResult = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            // Output Region
            if let result = appViewModel.queryResult {
                ScrollView {
                    Text(result)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 150)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut, value: appViewModel.queryResult)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, appViewModel.queryResult == nil ? 4 : 12)
    }
}
