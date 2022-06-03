// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import Shared
import WebKit
import BraveCore

private let log = Logger.braveCoreLogger

class RequestBlockingContentHelper: TabContentScript {
  private struct RequestBlockingDTO: Decodable {
    enum CodingKeys: String, CodingKey {
      case resourceURL, sourceURL, resourceType, securityToken
    }
    
    let securityToken: String
    let resourceType: AdblockEngine.ResourceType
    let resourceURL: URL
    let sourceURL: URL
    
    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.securityToken = try container.decode(String.self, forKey: .securityToken)
      let resourceURLString = try container.decode(String.self, forKey: .resourceURL)
      let sourceURLString = try container.decode(String.self, forKey: .sourceURL)
      let resourceTypeString = try container.decode(String.self, forKey: .resourceType)
      
      guard let resourceURL = URL(string: resourceURLString) else {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "`resourceURL` is not a valid URL. Fix the `RequestBlocking.js` script"))
      }
      guard let sourceURL = URL(string: sourceURLString) else {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "`sourceURL` is not a valid URL. Fix the `RequestBlocking.js` script"))
      }
      guard let resourceType = AdblockEngine.ResourceType(rawValue: resourceTypeString) else {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "`resourceType` is not a valid `AdblockEngine.ResourceType`. Fix the `RequestBlocking.js` script"))
      }
      
      self.resourceType = resourceType
      self.resourceURL = resourceURL
      self.sourceURL = sourceURL
    }
  }
  
  static func name() -> String {
    return "ContentBlockerHelper"
  }
  
  static func scriptMessageHandlerName() -> String {
    return ["contentBlockerHelper", UserScriptManager.messageHandlerTokenString].joined(separator: "_")
  }
  
  func scriptMessageHandlerName() -> String? {
    return Self.scriptMessageHandlerName()
  }
  
  func userContentController(_ userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
    do {
      let data = try JSONSerialization.data(withJSONObject: message.body)
      let dto = try JSONDecoder().decode(RequestBlockingDTO.self, from: data)
      
      guard dto.securityToken == UserScriptManager.securityTokenString else {
        assertionFailure("Invalid security token. Fix the `RequestBlocking.js` script")
        replyHandler(false, nil)
        return
      }
      
      let shouldBlock = AdBlockStats.shared.shouldBlock(
        requestURL: dto.resourceURL,
        sourceURL: dto.sourceURL,
        resourceType: dto.resourceType
      )
      replyHandler(shouldBlock, nil)
    } catch {
      assertionFailure("Invalid type of message. Fix the `RequestBlocking.js` script")
      replyHandler(false, nil)
    }
  }
}
