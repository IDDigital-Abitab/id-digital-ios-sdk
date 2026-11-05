import Foundation

/// Intercepts `URLSession` requests so SDK tests can answer the backend without a device.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    do {
      let (response, data) = try StubHTTP.shared.handle(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

final class StubHTTP: @unchecked Sendable {
  static let shared = StubHTTP()

  private let lock = NSLock()
  private var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
  private var requests: [(URLRequest, Data?)] = []

  func reset() {
    lock.lock()
    handler = nil
    requests = []
    lock.unlock()
  }

  func stub(status: Int, json: String) {
    setHandler { request in
      let response = HTTPURLResponse(
        url: request.url ?? URL(string: "https://example.test")!,
        statusCode: status,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (response, Data(json.utf8))
    }
  }

  func fail(_ error: URLError) {
    setHandler { _ in throw error }
  }

  var lastRequest: URLRequest? {
    lock.lock()
    defer { lock.unlock() }
    return requests.last?.0
  }

  var lastBody: String {
    lock.lock()
    defer { lock.unlock() }
    guard let data = requests.last?.1 else { return "" }
    return String(data: data, encoding: .utf8) ?? ""
  }

  func handle(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
    let body = Self.readBody(request)
    lock.lock()
    requests.append((request, body))
    let handler = self.handler
    lock.unlock()
    guard let handler else {
      throw URLError(.badServerResponse)
    }
    return try handler(request)
  }

  private func setHandler(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) {
    lock.lock()
    self.handler = handler
    lock.unlock()
  }

  private static func readBody(_ request: URLRequest) -> Data? {
    if let body = request.httpBody {
      return body
    }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
      let count = stream.read(buffer, maxLength: 1024)
      if count <= 0 { break }
      data.append(buffer, count: count)
    }
    return data
  }
}
