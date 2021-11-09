//
//  Chat.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 31.08.2021.
//

import UIKit

struct Chat {
    let chatID: String
    let companion: [String: Any]
    let lastMessage: LastMessage
}

struct LastMessage {
    let sentDate: String
    let text: String
    let isRead: Bool
}
