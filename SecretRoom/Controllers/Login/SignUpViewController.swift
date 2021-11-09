//
//  SignUpViewController.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 31.08.2021.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

class SignUpViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var profileImageLabel: UILabel!
    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    @IBOutlet weak var loginTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmedPasswordTextField: UITextField!
    @IBOutlet weak var signUpButton: UIButton!
    private let spinner = JGProgressHUD(style: .dark)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Configuring Profile Image
        profileImageView.layer.cornerRadius = profileImageView.frame.height / 2
        profileImageView.layer.masksToBounds = false
        profileImageView.clipsToBounds = true
        
        // Configuring textFields
        firstNameTextField.configureTextField()
        lastNameTextField.configureTextField()
        loginTextField.configureTextField()
        passwordTextField.configureTextField()
        confirmedPasswordTextField.configureTextField()
        
        // Configuring signInButton
        signUpButton.layer.cornerRadius = 18.0
        signUpButton.backgroundColor = .link
        signUpButton.setTitleColor(.white, for: .normal)
        signUpButton.titleLabel!.font = UIFont.boldSystemFont(ofSize: 20)
        
        profileImageView.isUserInteractionEnabled = true
        let imageTap = UITapGestureRecognizer(target: self, action: #selector(didTapChangeProfileImage))
        profileImageView.addGestureRecognizer(imageTap)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)
    }
    
    @objc private func handleTap() {
        loginTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
        confirmedPasswordTextField.resignFirstResponder()
        firstNameTextField.resignFirstResponder()
        lastNameTextField.resignFirstResponder()
        
    }
    
    private func alertUserSignUp(with message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Try again", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    @IBAction func signUpButtonTapped(_ sender: Any) {
        guard let firstName = firstNameTextField.text,
              let lastName = lastNameTextField.text,
              let email = loginTextField.text,
              let password = passwordTextField.text,
              let confirmedPassword = confirmedPasswordTextField.text,
              !firstName.isEmpty,
              !lastName.isEmpty,
              !email.isEmpty,
              !password.isEmpty,
              !confirmedPassword.isEmpty else {
            alertUserSignUp(with: "Please, enter all text fields to create a new account")
            return
        }
        guard password.count > 6 else {
            alertUserSignUp(with: "Sorry, the password is too short")
            return
        }
        guard email.count > 6 else {
            alertUserSignUp(with: "Please, enter correct email adress")
            return
        }
        guard password == confirmedPassword else {
            alertUserSignUp(with: "Ooops, the password and confirm password do not match")
            return
        }
        spinner.show(in: view)
        DatabaseManager.shared.isUserAlreadyExist(with: email, completion: { [weak self] exist in
            guard let strongSelf = self else {
                return
            }
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            guard !exist else {
                strongSelf.alertUserSignUp(with: "User with such email adress already exist")
                return
            }
            FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password, completion: { authResult, error in
                guard error == nil else {
                    // User not created
                    print("User not created")
                    return
                }
                let chatUser = User(email: email,
                                    firstName: firstName,
                                    lastName: lastName)
                
                DatabaseManager.shared.insertNewUser(with: chatUser, completion: { success in
                    if success {
                        guard  let image = strongSelf.profileImageView.image,
                               let data = image.pngData() else {
                            return
                        }
                        let fileName = chatUser.profileImageFileName
                        StorageManager.shared.uploadProfilePicture(with: data, fileName: fileName, completion: { result in
                            switch result {
                            case .success(let downloadUrl):
                                UserDefaults.standard.set(downloadUrl, forKey: "profile_picture_url")
                                print(downloadUrl)
                            case .failure(let error):
                                print("Storage manager error: \(error)")
                                
                            }
                        })
                    }
                })
                strongSelf.dismiss(animated: true)
            })
        })
    }
    
    @objc func didTapChangeProfileImage() {
        presentPhotoActionSheet()
    }
}

extension SignUpViewController: UIImagePickerControllerDelegate, UIPageViewControllerDelegate {
    
    func presentPhotoActionSheet() {
        let actionSheet = UIAlertController(title: "Profile photo",
                                            message: "How would you like to choose a picture?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Take photo",
                                            style: .default,
                                            handler: { [weak self] _ in
                                                self?.presentCamera()
                                            }))
        actionSheet.addAction(UIAlertAction(title: "Choose photo",
                                            style: .default,
                                            handler: { [weak self] _ in
                                                self?.presentPhotoLibrary()
                                            }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        present(actionSheet, animated: true)
    }
    
    func presentCamera() {
        let vc = UIImagePickerController()
        vc.allowsEditing = true
        vc.sourceType = .camera
        vc.delegate = self
        present(vc, animated: true)
        
    }
    
    func presentPhotoLibrary() {
        let vc = UIImagePickerController()
        vc.allowsEditing = true
        vc.sourceType = .photoLibrary
        vc.delegate = self
        present(vc, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let selectedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        self.profileImageView.image = selectedImage
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
}


extension UITextField {
    func configureTextField() {
        self.backgroundColor = #colorLiteral(red: 0.9417448621, green: 0.9417448621, blue: 0.9417448621, alpha: 1)
        self.layer.cornerRadius = 6.0
        self.textAlignment = .center
        self.font = UIFont(name: "System", size: 22)
    }
    
}


