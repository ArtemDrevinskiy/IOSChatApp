//
//  LogInViewController.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 31.08.2021.
//

import UIKit
import Firebase
import JGProgressHUD

class LogInViewController: UIViewController {

    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var loginTextField: UITextField!
    
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var logInButton: UIButton!
    private let spinner = JGProgressHUD(style: .dark)
    override func viewDidLoad() {
        super.viewDidLoad()
        validateAuth()
        configureTextFields()
        configureButtons()
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)
    }
    
    @objc func handleTap() {
        loginTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
    }
    
    private func validateAuth() {
        guard FirebaseAuth.Auth.auth().currentUser == nil else {
            let storyboard = UIStoryboard(name: "Main", bundle: .main)
            let view = storyboard.instantiateViewController(identifier: "MainWindowTabBarController")
            view.modalPresentationStyle = .fullScreen
            present(view, animated: true)
            return
        }
        
    }
    
    private func alertUserLogIn(with message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Try again", style: .cancel, handler: nil))
        present(alert, animated: true)
    }
    
    @IBAction func logInButtonTapped(_ sender: Any) {
        guard let email = loginTextField.text,
              let password = passwordTextField.text,
              !email.isEmpty,
              !password.isEmpty else {
            alertUserLogIn(with: "Please, enter all text fields correctly to log in")
            return
        }
        spinner.show(in: view)
        Firebase.Auth.auth().signIn(withEmail: email, password: password) { [weak self] authDataResult, error in
            guard let strongSelf = self else {
                return
            }
            DispatchQueue.main.async {
                strongSelf.spinner.dismiss()
            }
            guard authDataResult != nil, error == nil else {
                strongSelf.alertUserLogIn(with: "Failed to log in")
                return
            }
            UserDefaults.standard.set(email, forKey: "email")
            let currentUserSafeEmail = DatabaseManager.safeEmail(email: email)

            DatabaseManager.shared.getUser(with: currentUserSafeEmail) { result in
                switch result {
                case .failure(let error):
                    print(error)
                case .success(let userData):
                    guard let currentUserData = userData as? [String: Any],
                          let userFirstName = currentUserData["first_name"] as? String,
                          let userLastName = currentUserData["last_name"] as? String else {
                        return
                    }
                    UserDefaults.standard.set("\(userFirstName) \(userLastName)", forKey: "name")
                }
            }
            self?.validateAuth()
        }
    }
    
    @IBAction func doNotHaveAccountButtonTapped(_ sender: Any) {
        
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let vc = storyboard.instantiateViewController(identifier: "SignUpViewController")
        vc.modalPresentationStyle = .popover
        present(vc, animated: true)
    }
    
    func configureTextFields() {
        loginTextField.backgroundColor = #colorLiteral(red: 0.9417448621, green: 0.9417448621, blue: 0.9417448621, alpha: 1)
        loginTextField.placeholder = "Login"
        loginTextField.layer.cornerRadius = 6.0
        loginTextField.textAlignment = .center
        loginTextField.font = UIFont(name: "System", size: 22)
        
        passwordTextField.backgroundColor = #colorLiteral(red: 0.9417448621, green: 0.9417448621, blue: 0.9417448621, alpha: 1)
        passwordTextField.placeholder = "Password"
        passwordTextField.layer.cornerRadius = 6.0
        passwordTextField.textAlignment = .center
        passwordTextField.font = UIFont(name: "System", size: 22)

    }
    
    func configureButtons() {
        logInButton.layer.cornerRadius = 18.0
        logInButton.backgroundColor = .link
        logInButton.setTitleColor(.white, for: .normal)
        logInButton.titleLabel!.font = UIFont.boldSystemFont(ofSize: 20)
    }
}

 
