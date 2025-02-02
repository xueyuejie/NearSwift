//
//  Account.swift
//  
//
//  Created by mathwallet on 2022/7/14.
//

import Foundation
import PromiseKit

public struct AccountState: Codable {
    public let accountId: String?
    public let staked: String?
    public let locked: String
    public let amount: String
    public let code_hash: String
    public let block_hash: String
    public let block_height: UInt64
    public let storage_paid_at: Int64
    public let storage_usage: Int64
    
    private enum CodingKeys: String, CodingKey {
      case accountId,
           staked,
           locked,
           amount,
           code_hash,
           block_hash,
           block_height,
           storage_paid_at,
           storage_usage
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try container.decodeIfPresent(String.self, forKey: .accountId)
        staked = try container.decodeIfPresent(String.self, forKey: .staked)
        locked = try container.decode(String.self, forKey: .locked)
        amount = try container.decode(String.self, forKey: .amount)
        code_hash = try container.decode(String.self, forKey: .code_hash)
        block_hash = try container.decode(String.self, forKey: .block_hash)
        block_height = try container.decode(UInt64.self, forKey: .block_height)
        storage_paid_at = try container.decode(Int64.self, forKey: .storage_paid_at)
        storage_usage = try container.decode(Int64.self, forKey: .storage_usage)
    }
    
}

public struct AccountAccessKey: Decodable {
    public let accessKey: AccessKey
    public let publicKey: PublicKey
}

public struct AccountAccessKeyList: Decodable {
    public let keys: [AccountAccessKey]
}

public struct AccountBalance {
    public let total: String
    public let stateStaked: String
    public let staked: String
    public let available: String
}

public final class Account {
    public let provider: Provider
    public let accountId: String
    
    public init(provider: Provider, accountId: String) {
      self.provider = provider
      self.accountId = accountId
    }
    
    public func viewState() -> Promise<AccountState> {
        let params = [
            "request_type": "view_account",
            "finality": Finality.optimistic.rawValue,
            "account_id": accountId
        ]
        return provider.query(params: params)
    }
    
    public func viewAccessKey(publicKey: PublicKey) -> Promise<AccessKey> {
        let params = [
            "request_type": "view_access_key",
            "finality": Finality.optimistic.rawValue,
            "account_id": accountId,
            "public_key": publicKey.description
        ]
        return provider.query(params: params)
    }
    
    public func viewAccessKeyList() -> Promise<AccountAccessKeyList> {
        let params = [
            "request_type": "view_access_key_list",
            "finality": Finality.optimistic.rawValue,
            "account_id": accountId
        ]
        return provider.query(params: params)
    }
    
    public func balance() -> Promise<AccountBalance> {
        firstly {
            when(fulfilled: provider.experimentalProtocolConfig(blockQuery: .finality(.final)), viewState())
        }.map { (protocolConfig, state) -> AccountBalance in
            guard let storageAmountPerByte = protocolConfig.runtime_config?.storage_amount_per_byte else {
                throw NearError.providerError("Protocol Config Error")
            }
            let costPerByte = UInt128(stringLiteral: storageAmountPerByte)
            let stateStaked = UInt128(integerLiteral: UInt64(state.storage_usage)) * costPerByte
            let staked = UInt128(stringLiteral: state.locked)
            let totalBalance = UInt128(stringLiteral: state.amount) + staked
            let availableBalance = totalBalance - max(staked, stateStaked)
            
            return AccountBalance(total: totalBalance.toString(), stateStaked: stateStaked.toString(), staked: staked.toString(), available: availableBalance.toString())
        }
    }
}
