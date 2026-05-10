import SwiftUI

struct PhotoListView: View {
    @ObservedObject var viewModel: AnalysisViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.documents) { document in
                    Button {
                        viewModel.select(document: document)
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: document.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.fileName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(document.pixelSizeText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(rowBackground(for: document))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func rowBackground(for document: PhotoAnalysisDocument) -> Color {
        document.id == viewModel.selectedDocumentID
            ? Color.accentColor.opacity(0.18)
            : Color.clear
    }
}
