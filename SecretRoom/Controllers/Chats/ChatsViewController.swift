//
//  ChatsViewController.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 02.09.2021.
//

import UIKit
import Firebase
import JGProgressHUD

final class ChatsViewController: UIViewController {
    
    @IBOutlet weak var chatsTableView: UITableView!
    
    private let spinner = JGProgressHUD(style: .dark)
    private let noChatsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Chats"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        
        return label
    }()
    
    var chats: [Chat] = []
    private func configureNoChatsLabel() {
        view.addSubview(noChatsLabel)
        noChatsLabel.translatesAutoresizingMaskIntoConstraints = false
        noChatsLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        noChatsLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        noChatsLabel.textAlignment = .center
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureNoChatsLabel()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(didTapComposeButton))
        chatsTableView.register(UINib(nibName: "ChatCell", bundle: .main), forCellReuseIdentifier: "ChatCell")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.startListeningForChats()
    }
    
    
    private func startListeningForChats() {
        guard  let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let currentUserSafeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        DatabaseManager.shared.getAllChats(for: currentUserSafeEmail) { [weak self] result in
            switch result {
            case .success(let chats):
                guard !chats.isEmpty else {
                    return
                }
                
                self?.chats = chats
                self?.noChatsLabel.isHidden = true
                self?.chatsTableView.isHidden = false
                
                
                DispatchQueue.main.async {
                    self?.chatsTableView.reloadData()
                }
            case .failure(let error):
                self?.chats.removeAll()
                self?.chatsTableView.isHidden = true
                self?.noChatsLabel.isHidden = false
                print("Error \(error)")
            }
        }
    }
    
    @objc private func didTapComposeButton() {
        let vc = NewChatViewController()
        vc.completion = { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            let currentChats = strongSelf.chats
            // Check if chat is already exist
            if let existedChat = currentChats.first(where: {
                $0.companion["safeEmail"] as? String == result["safeEmail"]
            }) {
                let view = ChatInfoViewController.fromStoryboard(with: existedChat)
                view.isNewChat = false
                strongSelf.navigationController?.pushViewController(view, animated: true)
            } else {
                strongSelf.createNewChat(companion: result)
            }
        }
        let navVC = UINavigationController(rootViewController: vc)
        present(navVC, animated: true)
        
    }
    
    private func createNewChat(companion: [String: String]) {
        let view = ChatInfoViewController.fromSearchController(with: companion)
        view.isNewChat = true
        navigationController?.pushViewController(view, animated: true)
    }
}

extension ChatsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        chats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = chatsTableView.dequeueReusableCell(withIdentifier: "ChatCell", for: indexPath) as! ChatTableViewCell
        cell.configure(with: chats[indexPath.row])
        return cell
    }
    
}

extension ChatsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        chatsTableView.deselectRow(at: indexPath, animated: true)
        let chat = chats[indexPath.row]
        let view = ChatInfoViewController.fromStoryboard(with: chat)
        navigationController?.pushViewController(view, animated: true)
    }
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let chatID = chats[indexPath.row].chatID
            guard let companionSafeEmail = chats[indexPath.row].companion["safeEmail"] as? String else {
                return
            }
            //Start deleting process
            tableView.beginUpdates()
            let actionSheet = UIAlertController(title: "Do you really want to delete chat?",
                                                message: nil,
                                                preferredStyle: .actionSheet)
            actionSheet.addAction(UIAlertAction(title: "Delete",
                                                style: .destructive,
                                                handler: { [weak self] _ in
                                                    DatabaseManager.shared.deleteChat(with: chatID, companionSafeEmail: companionSafeEmail) { [weak self] success in
                                                        guard let strongSelf = self else {
                                                            return
                                                        }
                                                        switch success {
                                                        case true:
                                                            strongSelf.chats.remove(at: indexPath.row)
                                                        case false:
                                                            return
                                                        }
                                                    }
                                                }))
            actionSheet.addAction(UIAlertAction(title: "Cancel",
                                                style: .cancel,
                                                handler: nil))
            present(actionSheet, animated: true)
            tableView.endUpdates()
        }
    }
}

