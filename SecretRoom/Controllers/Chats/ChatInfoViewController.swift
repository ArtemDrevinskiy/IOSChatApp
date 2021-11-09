//
//  ChatInfoViewController.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 31.08.2021.
//

import UIKit
import MessageKit
import InputBarAccessoryView

struct Message: MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
}

extension MessageKind {
    var messageKindString: String {
        switch self {
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "linkPreview"
        case .custom(_):
            return "custom"
        }
    }
}

struct Sender: SenderType {
    public var imageURL: String
    public var senderId: String
    public var displayName: String
}

final class ChatInfoViewController: MessagesViewController {
    
    private var messages = [Message]()
    private var selfSender: Sender? {
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let senderName = UserDefaults.standard.value(forKey: "name") as? String else {
            return nil
        }
        let senderSafeEmail = DatabaseManager.safeEmail(email: senderEmail)
        return Sender(imageURL: "",
                      senderId: senderSafeEmail,
                      displayName: senderName)
    }
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        formatter.timeZone = .current
        return formatter
    }()
    
    public var chat: Chat?
    public var newCompanion: [String: String]?
    private var chatID: String?
    public var isNewChat: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        title = chat?.companion["name"] as? String ?? newCompanion?["name"]
        if let currentChatID = chatID {
            listenForMessages(with: currentChatID, shouldScrollToBottom: true)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
    }
    private func listenForMessages(with chatId: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForChat(with: chatId) {[weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else {
                    return
                }
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                }
            case .failure(let error):
                print("Failed to get messages: \(error)")
            }
        }
    }
}

extension ChatInfoViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender,
              let messageID = createMessageID() else {
            return
        }
        let message = Message(sender: selfSender,
                              messageId: messageID,
                              sentDate: Date(),
                              kind: .text(text))
        guard let companion = newCompanion ?? chat?.companion else {
            print("no companion")
            return
        }
        if isNewChat {
            // create new chat in database
            DatabaseManager.shared.createNewChat(with: companion, firstMessage: message) { [weak self] success in
                if success {
                    self?.messageInputBar.inputTextView.text = " "
                    self?.isNewChat = false
                    self?.navigationController?.popToRootViewController(animated: true)
                } else {
                    print("Failed to sent message")
                }
                
            }
        } else {
            // append to existing chat
            DatabaseManager.shared.sendMessage(to: chatID!, newMessage: message, companion: companion) { success in
                if success {
                    self.listenForMessages(with: self.chatID!, shouldScrollToBottom: true)
                    print("Message have been sent")
                    self.messageInputBar.inputTextView.text = " "
                } else {
                    print("Failed to send message")
                }
            }
        }
    }
    private func createMessageID() -> String? {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let companionEmail = newCompanion?["safeEmail"] ?? chat?.companion["safeEmail"] else {
            return nil
        }
        let currentUserSafeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(companionEmail)_\(currentUserSafeEmail)_\(dateString)"
        return newIdentifier
    }
}

extension ChatInfoViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        if let sender = selfSender{
            return sender
        }
        fatalError("Self sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    
}
extension ChatInfoViewController {
    /// Open view controller with existing chat
    static func fromStoryboard(with chat: Chat) -> ChatInfoViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let view = storyboard.instantiateViewController(identifier: "ChatInfoViewController") as! ChatInfoViewController
        view.chatID = chat.chatID
        view.chat = chat
        return view
    }
    /// Open view controller for new chat
    static func fromSearchController(with companion: [String: String]) -> ChatInfoViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let view = storyboard.instantiateViewController(identifier: "ChatInfoViewController") as! ChatInfoViewController
        view.newCompanion = companion
        return view
    }
}
