//
//  User.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 03.09.2021.
//

import UIKit

struct User {
    
    let email: String
    var firstName: String
    var lastName: String
    var profileImageFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
    var safeEmail: String {
        let safeEmail = email.replacingOccurrences(of: ".", with: "-")
        return safeEmail
    }
}
