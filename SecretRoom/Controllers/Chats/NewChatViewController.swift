//
//  NewChatViewController.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 14.09.2021.
//

import UIKit
import JGProgressHUD

final class NewChatViewController: UIViewController {
    
    public var completion: (([String: String]) -> (Void))?
    private let spinner = JGProgressHUD(style: .light)
    private var appUsers = [[String: String]]()
    private var foundAppUsers = [[String: String]?]()
    private var hasFetchedUsers = false
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search for user"
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        return table
    }()
    
    private let noResultsLabel: UILabel = {
        let label = UILabel()
        label.text = "No Results"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
        
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        view.addSubview(noResultsLabel)
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        view.backgroundColor = .tertiarySystemBackground
        navigationController?.navigationBar.topItem?.titleView = searchBar
        searchBar.searchTextField.addTarget(self, action: #selector(editingChanged(_:)), for: .editingChanged)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(dismissSelf))
        searchBar.becomeFirstResponder()
    }
    @objc private func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
    @objc private func editingChanged(_ textfield: UISearchBar) {
        searchBarSearchButtonClicked(textfield)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.frame.width/4,
                                      y: (view.frame.height - 200)/2,
                                      width: view.frame.width/2,
                                      height: 200)
    }
}
extension NewChatViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return foundAppUsers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = foundAppUsers[indexPath.row]?["name"]
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let targetUserData = foundAppUsers[indexPath.row] else {
            return
        }
        dismiss(animated: true, completion: { [weak self] in
            self?.completion?(targetUserData)
        })

    }
    
    
}

extension NewChatViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else {
            return
        }
        searchBar.resignFirstResponder()
        foundAppUsers.removeAll()
        spinner.show(in: view)
        self.searchUsers(with: text)
    }
    
    private func searchUsers(with name: String) {
        if hasFetchedUsers {
            filterAppUsers(with: name)
        } else {
            DatabaseManager.shared.getAllAppUsers(completion: { [weak self] result in
                switch result {
                case .success(let appUsersCollection):
                    self?.hasFetchedUsers = true
                    self?.appUsers = appUsersCollection
                    self?.filterAppUsers(with: name)
                case .failure(let error):
                    print("Failed to get users: \(error)")
                }
            })
        }
    }
    
    private func filterAppUsers(with term: String) {
        guard hasFetchedUsers else {
            return
        }
        self.spinner.dismiss()
        for user in appUsers {
            guard let name = user["name"]?.lowercased() else {
                return
            }
            guard name.hasPrefix(term.lowercased()) else {
                continue
            }
            self.foundAppUsers.append(user)
        }
        self.updateUI()
        
    }

    private func updateUI() {
        if foundAppUsers.isEmpty {
            tableView.isHidden = true
            noResultsLabel.isHidden = false
            searchBar.searchTextField.becomeFirstResponder()
        } else {
            noResultsLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
            searchBar.searchTextField.becomeFirstResponder()
        }
    }
}
