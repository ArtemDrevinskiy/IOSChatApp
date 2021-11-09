//
//  UserProfileViewController.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 31.08.2021.
//

import UIKit
import FirebaseAuth
class UserProfileViewController: UIViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fillCurrentUserInfo()
        userProfileImageView.layer.cornerRadius = userProfileImageView.frame.width/2
    }


    @IBOutlet weak var userProfileImageView: UIImageView!
 
    @IBOutlet weak var usernameLabel: UILabel!
    
    private func fillCurrentUserInfo() {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String,
              let userName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        usernameLabel.text = userName
        usernameLabel.textColor = .black
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        let fileName = safeEmail + "_profile_picture.png"
        let profileImagePath = "images/" + fileName
        
        StorageManager.shared.downloadUrl(for: profileImagePath, completion: { [weak self] result in
            switch result {
            case .success(let url):
                self?.downloadProfileImage(imageView: self!.userProfileImageView, url: url)
            case .failure(let error):
                print("Failed to get download url: \(error)")
            }
        })
    }
    
    private func downloadProfileImage(imageView: UIImageView, url: URL) {
        URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
            guard let data = data, error == nil else {
                return
            }
            DispatchQueue.main.async {
                let image = UIImage(data: data)
                imageView.image = image
            }
        }).resume()
    }
    
    @IBAction func logOutButtonTapped(_ sender: Any) {
        
        let actionSheet = UIAlertController(title: nil,
                                            message: "Do you really want to log out?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Log Out",
                                            style: .destructive,
                                            handler: { [weak self]_ in
                                                guard let strongSelf = self else {
                                                    return
                                                }
                                                do {
                                                    try FirebaseAuth.Auth.auth().signOut()
                                                    
                                                    let storyboard = UIStoryboard(name: "Main", bundle: .main)
                                                    let view = storyboard.instantiateViewController(identifier: "LoginViewController")
                                                    view.modalPresentationStyle = .fullScreen
                                                    strongSelf.present(view, animated: true)
                                                    
                                                } catch  {
                                                    print("Error")
                                                }
                                            }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        present(actionSheet, animated: true)
        
    }
    
}
