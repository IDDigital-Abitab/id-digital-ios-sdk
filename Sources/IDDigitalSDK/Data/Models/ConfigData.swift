//
//  ConfigData.swift
//  IDDigitalSDK
//
//  Created by Jeremias Araujo on 14/8/25.
//


struct ConfigData: Decodable {
    let cognitoAppClientId: String
    let cognitoUserPoolId: String
    let cognitoIdentityPoolId: String
    let region: String
}
