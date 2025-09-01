struct ApiResponse<T: Decodable>: Decodable {
    let data: T
    // Add other fields like `success`, `message`, etc. if they exist.
}
