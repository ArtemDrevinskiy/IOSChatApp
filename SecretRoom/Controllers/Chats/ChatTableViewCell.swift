//
//  ChatCellViewController.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 31.08.2021.
//

import UIKit
import SDWebImage

final class ChatTableViewCell: UITableViewCell {
    
   
    @IBOutlet weak var personImageView: UIImageView!
    @IBOutlet weak var personNameLabel: UILabel!
    
    @IBOutlet weak var lastMessageLabel: UILabel!
    
    @IBOutlet weak var timeLabel: UILabel!
    
    
    func configure(with chat: Chat) {
        guard let companionEmail = chat.companion["safeEmail"] else {
            return
        }
        let path = "images/\(companionEmail)_profile_picture.png"
        StorageManager.shared.downloadUrl(for: path) { [weak self] result in
            switch result {
            case .failure(let error):
                print("Failed to download url: \(error)")
            case .success(let url):
                DispatchQueue.main.async {
                    self?.personImageView.sd_setImage(with: url, completed: nil)
                }
            }
        }
        personImageView.layer.cornerRadius = personImageView.frame.height / 2
        personImageView.layer.masksToBounds = false
        personImageView.clipsToBounds = true
        personNameLabel.text = chat.companion["name"] as? String
        personNameLabel.font = UIFont.boldSystemFont(ofSize: 17)
        lastMessageLabel.text = chat.lastMessage.text
        // TO DO: Change sentDate format to shorter one
        //timeLabel.text = chat.lastMessage.sentDate
        
    }
    
   
}
