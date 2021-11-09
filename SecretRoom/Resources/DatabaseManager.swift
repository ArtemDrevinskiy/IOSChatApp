//
//  DatabaseManager.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 03.09.2021.
//

import UIKit
import FirebaseDatabase

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    
    static func safeEmail(email: String) -> String {
        let safeEmail = email.replacingOccurrences(of: ".", with: "-")
        return safeEmail
    }
    
}

extension DatabaseManager {
    
    public func isUserAlreadyExist(with email: String, completion: @escaping ((Bool) -> Void)) {
        let safeEmail = DatabaseManager.safeEmail(email: email)
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? [String: Any] != nil else {
                completion(false)
                return
            }
            completion(true)
        })
        
    }
    
    /// Add new user to firebase database
    public func insertNewUser(with user: User, completion: @escaping (Bool) -> Void) {
        database.child(user.safeEmail).setValue([
            "first_name" : user.firstName,
            "last_name" : user.lastName,
        ], withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            self.database.child("appUsers").observeSingleEvent(of: .value, with: { snapshot in
                if var appUsersCollection = snapshot.value as? [[String: String]] {
                    let newAppUser = [
                        "name": user.firstName + " " + user.lastName,
                        "safeEmail": user.safeEmail
                    ]
                    appUsersCollection.append(newAppUser)
                    self.database.child("appUsers").setValue(appUsersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                } else {
                    let newAppUsersCollection: [[String: String]] = [
                        [
                            "name": user.firstName + " " + user.lastName,
                            "safeEmail": user.safeEmail
                        ]
                    ]
                    self.database.child("appUsers").setValue(newAppUsersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    
    public func getAllAppUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("appUsers").observeSingleEvent(of: .value, with: { snapshot in
            guard let returnedUsers = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            completion(.success(returnedUsers))
        })
        
    }
    
    /// Gets user data from database
    public func getUser(with email: String, completion: @escaping (Result<Any, Error>) -> Void) {
        self.database.child("\(email)").observeSingleEvent(of: .value) { snapshot in
             guard let userData = snapshot.value as? [String: Any] else {
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            completion(.success(userData))
        }
    }
    
    public enum DatabaseErrors: Error {
        case failedToFetch
    }
}

extension DatabaseManager {
    /// Creates a new chat with target companion and first message sent
    public func createNewChat(with companion: [String: Any], firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentUserName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let currentUserSafeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        let userNodeRef = database.child("\(currentUserSafeEmail)")
        userNodeRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                print("User not found")
                return
            }
            let messageDate = firstMessage.sentDate
            let stringMessageDate = ChatInfoViewController.dateFormatter.string(from: messageDate)
            var message = ""
            switch firstMessage.kind {
            
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            guard let companionName = companion["name"] as? String,
                  let companionEmail = companion["safeEmail"] as? String else {
                print("No companion")
                return
            }
            let chatID = "chat_\(currentUserSafeEmail)_\(companionEmail)"
            
            // Updating companion chats entry

            let companionNewChatData: [String: Any] = [
                "id": chatID,
                "companion": [ "name": currentUserName,
                               "safeEmail": currentUserSafeEmail
                ],
                "last_message": [
                    "sent_date": stringMessageDate,
                    "message": message,
                    "is_read": false
                ]
            ]
            self?.database.child("\(companionEmail)/chats").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var chats = snapshot.value as? [[String: Any]] {
                    // append current chat to existing chats
                    chats.append(companionNewChatData)
                    self?.database.child("\(companionEmail)/chats").setValue(chats)
                } else {
                    // create new chat
                    self?.database.child("\(companionEmail)/chats").setValue([companionNewChatData])
                }
                
            })
            
            // Updating current user chats entry

            let newChatData: [String: Any] = [
                "id": chatID,
                "companion": [ "name": companionName,
                               "safeEmail": companionEmail
                ],
                "last_message": [
                    "sent_date": stringMessageDate,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            if var chats = userNode["chats"] as? [[String: Any]] {
                // append chat
                chats.append(newChatData)
                userNode["chats"] = chats
                userNodeRef.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishChatCreating(with: companionName, chatID: chatID, firstMessage: firstMessage, completion: completion)
                }
            } else {
                // create new array of chats for current user
                userNode["chats"] = [
                    newChatData
                ]
                userNodeRef.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishChatCreating(with: companionName, chatID: chatID, firstMessage: firstMessage, completion: completion)
                }
            }
        }
    }
    
    private func finishChatCreating(with companionName: String, chatID: String, firstMessage: Message,  completion: @escaping (Bool) -> Void) {
        
        let messageDate = firstMessage.sentDate
        let stringMessageDate = ChatInfoViewController.dateFormatter.string(from: messageDate)
        
        var message = ""
        switch firstMessage.kind {
        
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentUsername = UserDefaults.standard.value(forKey: "name") as? String else {
            completion(false)
            return
        }
        let currentUserSafeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        
        let messageColletion: [String: Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "sent_date": stringMessageDate,
            "sender_email": currentUserSafeEmail,
            "sender_name": currentUsername,
            "is_read": false
        ]
        let chat: [String: Any] = [
            "messages": [
                messageColletion
            ]
        ]
        database.child("\(chatID)").setValue(chat, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
        
    }
    /// Fetches and returns  all chats for wanted user email
    public func getAllChats(for email: String, completion: @escaping (Result<[Chat], Error>) -> Void) {
        database.child("\(email)/chats").observe(.value) { snapshot in
            guard let chats = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            let chatsCollection: [Chat] = chats.compactMap { dictionary in
                guard let companion = dictionary["companion"] as? [String: Any],
                      let chatID = dictionary["id"] as? String,
                      let lastMessage = dictionary["last_message"] as? [String: Any],
                      let sentDate = lastMessage["sent_date"] as? String,
                      let message = lastMessage["message"] as? String,
                      let isRead = lastMessage["is_read"] as? Bool else {
                    return nil
                }
                let lastMessageObject = LastMessage(sentDate: sentDate,
                                                    text: message,
                                                    isRead: isRead)
                return Chat(chatID: chatID,
                            companion: companion,
                            lastMessage: lastMessageObject)
                
            }
            completion(.success(chatsCollection)) 
        }
    }
    /// Returns all messages for wanted chat
    public func getAllMessagesForChat(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value) { snapshot in
            guard let messages = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseErrors.failedToFetch))
                return
            }
            let messagesCollection: [Message] = messages.compactMap { dictionary in
                guard let senderName = dictionary["sender_name"] as? String,
                      let message = dictionary["content"] as? String,
                      let messageID = dictionary["id"] as? String,
                      let _ = dictionary["is_read"] as? Bool,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let messageSentDate = dictionary["sent_date"] as? String,
                      let _ = dictionary["type"] as? String,
                      let sentDate = ChatInfoViewController.dateFormatter.date(from: messageSentDate) else {
                    return nil
                }
                
                let sender = Sender(imageURL: "",
                                    senderId: senderEmail,
                                    displayName: senderName)
                return Message(sender: sender,
                               messageId: messageID,
                               sentDate: sentDate,
                               kind: .text(message))
                
                
            }
            completion(.success(messagesCollection))
        }
    }
    /// Sends a message to target chat
    public func sendMessage(to chatID: String, newMessage: Message, companion: [String: Any], completion: @escaping (Bool) -> Void) {
        database.child("\(chatID)/messages").observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let strongSelf = self,
                  var currentMessages = snapshot.value as? [[String: Any]] else {
                return
            }
            let messageDate = newMessage.sentDate
            let stringMessageDate = ChatInfoViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch newMessage.kind {
            
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
                  let currentUsername = UserDefaults.standard.value(forKey: "name") as? String else {
                completion(false)
                return
            }
            let currentUserSafeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
            
            let newMessageToAppend: [String: Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "sent_date": stringMessageDate,
                "sender_email": currentUserSafeEmail,
                "sender_name": currentUsername,
                "is_read": false
            ]
            currentMessages.append(newMessageToAppend)
            
            // adding new message to messages
            strongSelf.database.child("\(chatID)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                completion(true)
            }
            // updating last messages of current user and companion
            self?.updateLastMessage(with: chatID, newMessage: newMessage, companion: companion) { result in
                completion(result)
            }
        }
    }
    
    private func updateLastMessage(with chatID: String, newMessage: Message, companion: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let companionSafeEmail = companion["safeEmail"] as? String else {
            completion(false)
            return
        }
        let messageDate = newMessage.sentDate
        let stringMessageDate = ChatInfoViewController.dateFormatter.string(from: messageDate)
        
        var message = ""
        switch newMessage.kind {
        
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        let currentUserSafeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        
        // update current user last message

        database.child("\(currentUserSafeEmail)/chats").observeSingleEvent(of: .value) { snapshot in
            guard var chatsCollection = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
           
            let lastMessage: [String: Any]
            var newChatData: [String: Any]
            var chatIndexToRemove = 0
            for chat in chatsCollection {
                if chat["id"] as! String == chatID {
                    newChatData = chat
                    chatsCollection.remove(at: chatIndexToRemove)
                    lastMessage = [
                        "sent_date": stringMessageDate,
                        "is_read": false,
                        "message": message
                    ]
                    newChatData["last_message"] = lastMessage
                    chatsCollection.insert(newChatData, at: 0)
                    completion(true)
                    break
                }
                chatIndexToRemove += 1
            }
            
            self.database.child("\(currentUserSafeEmail)/chats").setValue(chatsCollection) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
            }
        }
        
        // update companion last message

        database.child("\(companionSafeEmail)/chats").observeSingleEvent(of: .value) { snapshot in
            guard var chatsCollection = snapshot.value as? [[String: Any]] else {
                return
            }
            let lastMessage: [String: Any]
            var newChatData: [String: Any]
            var chatIndexToRemove = 0
            for chat in chatsCollection {
                if chat["id"] as! String == chatID {
                    newChatData = chat
                    chatsCollection.remove(at: chatIndexToRemove)
                    lastMessage = [
                        "sent_date": stringMessageDate,
                        "is_read": false,
                        "message": message
                    ]
                    newChatData["last_message"] = lastMessage
                    chatsCollection.insert(newChatData, at: 0)
                    break
                }
                chatIndexToRemove += 1
            }
            
            self.database.child("\(companionSafeEmail)/chats").setValue(chatsCollection) { error, _ in
                guard error == nil else {
                    return
                }
            }
        }
    }
}

extension DatabaseManager {
    public func deleteChat(with chatID: String, companionSafeEmail: String, completion: @escaping (Bool) -> Void) {
        var result = true
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentUserSafeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        // Reset current user chats in database
        result = resetUsersChat(with: chatID, userSafeEmail: currentUserSafeEmail)
        guard result else {
            completion(false)
            return
        }
        // Reset companion`s chats in database
        result = resetUsersChat(with: chatID, userSafeEmail: companionSafeEmail)
        // Delete chat with target chatID
        database.child("\(chatID)").removeValue { error, _ in
            guard error == nil else {
                result = false
                return
            }
            result = true
        }
        completion(result)
    }
    
    private func resetUsersChat(with chatID: String, userSafeEmail: String) -> Bool {
        var result = true
        // Get all chat for current user
        let currentUserChatsRef =  database.child("\(userSafeEmail)/chats")
        currentUserChatsRef.observeSingleEvent(of: .value) { snapshot in
            if var chats = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for chat in chats {
                    if let id = chat["id"] as? String, id == chatID {
                        break
                    }
                    positionToRemove += 1
                }
                // Delete chat with target id
                chats.remove(at: positionToRemove)
                // Reset user`s chats in database
                currentUserChatsRef.setValue(chats) { error, _ in
                    guard error == nil else {
                        result = false
                        return
                    }
                    result = true
                }
            }
        }
        return result
    }
    
}

