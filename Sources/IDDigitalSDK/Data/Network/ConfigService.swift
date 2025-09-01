//
//  ConfigService.swift
//  IDDigitalSDK
//
//  Created by Jeremias Araujo on 14/8/25.
//

import Foundation
import FactoryKit


final class ConfigService {
    @Injected(\.networkClient) private var networkClient

    func getConfiguration() async throws -> ConfigData {
        return try await networkClient.get(path: "initialize/")
    }
}
