//
//  FindID.swift
//  ToMyongJi-iOS
//
//  Created by JunKyu Lee on 2/23/25.
//

import Foundation

// 아이디 찾기
public struct FindIDRequest: Codable {
    let email: String
    
    public init(email: String) {
        self.email = email
    }
}

public struct FindIDResponse: Codable {
    let statusCode: Int
    let message: String
    let data: String
    
    public init(statusCode: Int, message: String, data: String) {
        self.statusCode = statusCode
        self.message = message
        self.data = data
    }
}

