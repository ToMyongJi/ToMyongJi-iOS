//
//  TossVerify.swift
//  Feature
//
//  Created by JunnKyuu on 8/4/25.
//  Copyright © 2025 ToMyongJi. All rights reserved.
//

import Foundation

// MARK: - 토스 거래내역서 인증 관련 모델

public struct TossVerifyRequest: Codable {
    let file: Data // 실제 PDF 파일 데이터
    let userId: String // 사용자 로그인 아이디
    let keyword: String // 키워드
    
    public init(file: Data, userId: String, keyword: String) {
        self.file = file
        self.userId = userId
        self.keyword = keyword
    }
}

public struct TossVerifyResponse: Codable {
    let statusCode: Int
    let message: String?
    let data: [TossVerifyData]
    
    public init(statusCode: Int, message: String?, data: [TossVerifyData]) {
        self.statusCode = statusCode
        self.message = message
        self.data = data
    }
    
    // MARK: - CodingKeys (서버 응답과 정확히 매칭)
    enum CodingKeys: String, CodingKey {
        case statusCode
        case message
        case data
    }
    
    // MARK: - Custom Decoder (필드가 없을 경우 처리)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        statusCode = try container.decode(Int.self, forKey: .statusCode)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        data = try container.decodeIfPresent([TossVerifyData].self, forKey: .data) ?? []
    }
    
    // MARK: - 편의 메서드
    var errorMessage: String? {
        return message
    }
}

// MARK: - 대안 응답 모델 (서버 응답 구조가 다를 경우)
public struct TossVerifyAlternativeResponse: Codable {
    let code: Int?
    let message: String?
    let result: [TossVerifyData]?
    
    // 기존 응답 모델로 변환
    func toTossVerifyResponse() -> TossVerifyResponse {
        return TossVerifyResponse(
            statusCode: code ?? 0,
            message: message,
            data: result ?? []
        )
    }
}

public struct TossVerifyData: Codable {
    let receiptId: Int
    let date: String
    let content: String
    let deposit: Int
    let withdrawal: Int
    
    public init(receiptId: Int, date: String, content: String, deposit: Int, withdrawal: Int) {
        self.receiptId = receiptId
        self.date = date
        self.content = content
        self.deposit = deposit
        self.withdrawal = withdrawal
    }
    
    // MARK: - CodingKeys (서버 응답과 정확히 매칭)
    enum CodingKeys: String, CodingKey {
        case receiptId
        case date
        case content
        case deposit
        case withdrawal
    }
}


