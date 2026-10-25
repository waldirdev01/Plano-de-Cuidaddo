import Foundation
import PDFKit

/// Local-only extraction. Never follows links, executes PDF actions or performs OCR.
enum LeitorPdfNativo {
  static let limiteBytes = 10 * 1024 * 1024

  enum Falha: LocalizedError {
    case tamanho, invalido, protegido, paginas, texto
    var errorDescription: String? {
      switch self {
      case .tamanho: return "Selecione um PDF de até 10 MB."
      case .invalido: return "Não foi possível ler este PDF. O arquivo pode estar danificado."
      case .protegido: return "Este PDF é protegido por senha. Selecione uma cópia sem senha."
      case .paginas: return "Selecione um PDF com até 40 páginas."
      case .texto: return "Este PDF não contém texto legível. PDFs escaneados não são reconhecidos nesta etapa."
      }
    }
  }

  static func extrair(_ data: Data) throws -> [String: Any] {
    guard data.count <= limiteBytes else { throw Falha.tamanho }
    guard data.starts(with: Data("%PDF-".utf8)), let document = PDFDocument(data: data) else {
      throw Falha.invalido
    }
    guard !document.isLocked else { throw Falha.protegido }
    guard document.pageCount > 0, document.pageCount <= 40 else { throw Falha.paginas }
    var pages: [String] = []
    var links: [String] = []
    var characters = 0
    for i in 0..<document.pageCount {
      guard let page = document.page(at: i) else { throw Falha.invalido }
      let text = page.string ?? ""
      characters += text.count
      guard characters <= 400_000 else { throw Falha.tamanho }
      pages.append(text)
      for annotation in page.annotations {
        if let action = annotation.action as? PDFActionURL,
           let url = action.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
          let value = url.absoluteString
          if value.count <= 8192, !links.contains(value) { links.append(value) }
        }
      }
    }
    guard pages.joined().trimmingCharacters(in: .whitespacesAndNewlines).count >= 100 else {
      throw Falha.texto
    }
    return ["paginas": pages, "links": links]
  }
}
