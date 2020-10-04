import UIKit
import FirebaseStorage
import FirebaseFirestore
import GoogleSignIn
import Firebase

class UserPageViewController: UIViewController,UITableViewDelegate,UITableViewDataSource,UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout ,UIImagePickerControllerDelegate,UINavigationControllerDelegate{
    
    
    let space:CGFloat = 1
    var userId:String!
    //タブバーから表示されたかsegueから表示されたかを保持
    var fromSegue:Bool = false
    var followFlag:Bool = false{
        didSet{
            if followFlag{
                //フォロー中
                followButton.setTitle("フォロー中", for: .normal)
                
            }else{
                //フォローしていない
                followButton.setTitle("フォローする", for: .normal)
            }
        }
    }
    
    var followAry:[Dictionary<String,String>] = []
    var followerAry:[Dictionary<String,String>] = []
    var bestShopNameAry:[String] = []
    var bestShopIdAry:[String] = []
    var userAry:[Dictionary<String,String>] = []
    var postsAry:[Dictionary<String,Any>] = []
    
    let db = Firestore.firestore()
    let storage = Storage.storage().reference(forURL: "gs://bestramen-90259.appspot.com")
    var handle: AuthStateDidChangeListenerHandle?
    var logOutButton: UIBarButtonItem!
    var editButton: UIBarButtonItem!
    var googleSignInButton = GIDSignInButton()
    var currentUser:User!
    var relationId:String!
    var alertController:UIAlertController!
    
    @IBOutlet weak var postButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var horizontalStackView: UIStackView!
    @IBOutlet weak var verticalStackView: UIStackView!
    @IBOutlet weak var userImageView: UIImageView!
    @IBOutlet weak var followerListButton: UIButton!
    @IBOutlet weak var followListButton: UIButton!
    @IBOutlet weak var profileLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var followButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableViewConstraintHeight: NSLayoutConstraint!
    @IBOutlet weak var collectionViewConstraintHeight: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //投稿ボタンの設定
        self.view.bringSubviewToFront(postButton)
        postButton.backgroundColor = UIColor.orange
        postButton.layer.cornerRadius = 50.0
        postButton.contentMode = .scaleAspectFit
        postButton.imageEdgeInsets = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        postButton.addTarget(self, action: #selector(self.postButtonTapped(_:)), for: UIControl.Event.touchUpInside)
        postButton.isHidden = true
        
        GIDSignIn.sharedInstance()?.presentingViewController = self
        tableView.delegate = self
        tableView.dataSource = self
        collectionView.register(UINib(nibName: "CustomCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "postCell")
        collectionView.delegate = self
        collectionView.dataSource = self
        followListButton.setTitle("フォロー\n0", for: .normal)
        //ボタンのテキストが改行可能に
        followListButton.titleLabel?.numberOfLines = 2
        //ボタンのテキスト中央寄せ
        followListButton.titleLabel!.textAlignment = NSTextAlignment.center
        followerListButton.setTitle("フォロワー\n0", for: .normal)
        followerListButton.titleLabel?.numberOfLines = 2
        followerListButton.titleLabel!.textAlignment = NSTextAlignment.center
        tableView.isScrollEnabled = false
        
        self.followListButton.addTarget(self,action: #selector(self.tapFollowListButton(_ :)),for: .touchUpInside)
        self.followerListButton.addTarget(self,action: #selector(self.tapFollowerListButton(_ :)),for: .touchUpInside)
        logOutButton = UIBarButtonItem(title: "ログアウト", style: .done, target: self, action: #selector(logOutButtonTapped(_:)))
        self.navigationItem.leftBarButtonItem = logOutButton
        editButton = UIBarButtonItem(title: "編集", style: .done, target: self, action: #selector(editButtonTapped(_:)))
        self.navigationItem.rightBarButtonItem = editButton
        googleSignInButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(googleSignInButton)
        googleSignInButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        googleSignInButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        self.googleSignInButton.isHidden = true
        googleSignInButton.isEnabled = false
        logOutButton.isEnabled = false
        logOutButton.tintColor = UIColor.clear
        editButton.isEnabled = false
        editButton.tintColor = UIColor.clear
        followButton.addTarget(self, action: #selector(self.followButtonTapped(_:)), for: .touchUpInside)
        alertController = UIAlertController(title: "ログインが必要です", message: nil, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        
        
    }
    override func viewWillAppear(_ animated: Bool) {
        currentUser = Auth.auth().currentUser
        //タブバーから表示されたかsegueから表示されたかで分岐
        if fromSegue{
            //segueから
            self.verticalStackView.isHidden = false
            self.profileLabel.isHidden = false
            self.followListButton.isHidden = false
            self.followerListButton.isHidden = false
            self.storage.child("users").child("\(self.userId ?? "").jpg").getData(maxSize: 1024 * 1024 * 10) { (data: Data?, error: Error?) in
                if error != nil {
                    return
                }
                if let imageData = data {
                    let userImg = UIImage(data: imageData)
                    self.userImageView.image = userImg
                }
            }
            self.setFollow()
            self.setFollower()
            self.setPosts()
            self.setUser()
            //userIdとログインしているユーザー(currentUser)のuidが一致するかで分岐
            if userId == currentUser?.uid{
                //ログインユーザーのページの場合
                self.followButton.isHidden = true
            }else{
                //その他のユーザーのページの場合
                self.followButton.isHidden = false
                if currentUser != nil{
                    self.db.collection("relationships").whereField("followedId", isEqualTo: userId!).whereField("followerId", isEqualTo:currentUser!.uid ).getDocuments{(queryDocumentSnapshot,error) in
                        if let queryDocumentSnapshot = queryDocumentSnapshot,queryDocumentSnapshot.documents.count != 0 {
                            print("フォローしている")
                            self.followFlag = true
                            for document in queryDocumentSnapshot.documents{
                                self.relationId = document.documentID
                                
                            }
                        }else{
                            print("フォローしてない")
                            self.followFlag = false
                        }
                    }
                    
                }
            }
        }else{
            //タブバーから
            //ログイン状態で分岐
                handle = Auth.auth().addStateDidChangeListener { (auth, user) in
                    if user != nil {
                        //ログインの状態
                        self.verticalStackView.isHidden = false
                        self.followButton.isHidden = true
                        self.profileLabel.isHidden = false
                        self.followListButton.isHidden = false
                        self.followerListButton.isHidden = false
                        self.googleSignInButton.isHidden = true
                        self.googleSignInButton.isEnabled = false
                        self.userId = auth.currentUser?.uid
                        self.storage.child("users").child("\(self.userId ?? "").jpg").getData(maxSize: 1024 * 1024 * 10) { (data: Data?, error: Error?) in
                            if error != nil {
                                return
                            }
                            if let imageData = data {
                                let userImg = UIImage(data: imageData)
                                self.userImageView.image = userImg
                            }
                        }
                        self.setFollow()
                        self.setFollower()
                        self.setPosts()
                        self.setUser()
                        self.logOutButton.isEnabled = true
                        self.logOutButton.tintColor = UIColor.init(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0)
                        self.editButton.isEnabled = true
                        self.editButton.tintColor = UIColor.init(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0)
                        self.postButton.isHidden = false
                        self.followButton.isEnabled = false
                        
                    } else {
                        //ログアウトの状態
                        self.verticalStackView.isHidden = true
                        self.followButton.isHidden = true
                        self.profileLabel.isHidden = true
                        self.followListButton.isHidden = true
                        self.followerListButton.isHidden = true
                        self.googleSignInButton.isHidden = false
                        self.googleSignInButton.isEnabled = true
                        self.nameLabel.text = "ログインされていません"
                        self.userImageView.image = nil
                        self.userImageView.backgroundColor = UIColor.gray
                        self.logOutButton.isEnabled = false
                        self.logOutButton.tintColor = UIColor.clear
                        self.editButton.isEnabled = false
                        self.editButton.tintColor = UIColor.clear
                        self.postButton.isHidden = true
                        self.followButton.isEnabled = false
                    }
            }
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if let handle = handle{
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    func setFollow(){
        self.db.collection("relationships").whereField("followerId", isEqualTo: userId!).getDocuments{(querySnapshot, error) in
            self.followAry = []
            if let error = error{
                print(error)
            } else{
                if querySnapshot!.documents.isEmpty{
                    self.followListButton.isEnabled = false
                    self.followListButton.setTitle("フォロー\n0", for: .normal)
                }else{
                    for document in querySnapshot!.documents{
                        var followDic:Dictionary<String, String> = [:]
                        followDic["userId"] = document["followedId"] as? String
                        followDic["userName"] = document["followedName"] as? String
                        self.followAry.append(followDic)
                        self.followListButton.setTitle("フォロー\n\(String(self.followAry.count))", for: .normal)
                        self.followListButton.isEnabled = true
                    }
                    
                }
            }
        }
    }
    
    func setFollower(){
        self.db.collection("relationships").whereField("followedId", isEqualTo: userId!).getDocuments{(querySnapshot, error) in
            self.followerAry = []
            if let error = error{
                print(error)
            } else{
                if querySnapshot!.documents.isEmpty{
                    self.followerListButton.isEnabled = false
                    self.followerListButton.setTitle("フォロワー\n0", for: .normal)
                }else{
                    for document in querySnapshot!.documents{
                        var followerDic:Dictionary<String, String> = [:]
                        followerDic["userId"] = document["followerId"] as? String
                        followerDic["userName"] = document["followerName"] as? String
                        self.followerAry.append(followerDic)
                        self.followerListButton.setTitle("フォロワー\n\(String(self.followerAry.count))", for: .normal)
                        self.followerListButton.isEnabled = true
                    }
                }
                
            }
        }
    }

    
    func setUser(){
        self.db.collection("users").document(userId).getDocument{(document,error) in
            self.bestShopNameAry = []
            self.bestShopIdAry = []
            if let document = document{
                self.profileLabel.text = document.data()?["userProfile"] as? String
                self.bestShopNameAry = (document.data()?["bestShopName"]as? Array) ?? []
                self.bestShopIdAry = (document.data()?["bestShopId"] as? Array) ?? []
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()
                self.tableViewConstraintHeight.constant = self.tableView.contentSize.height
                self.nameLabel.text = document.data()?["userName"] as? String
            }
        }
    }
    
    func setPosts(){
        db.collection("posts").whereField("userId", isEqualTo: userId!).getDocuments(){(querySnapshot, error) in
            self.postsAry = []
            if let querySnapshot = querySnapshot{
                for document in querySnapshot.documents{
                    var postDic:Dictionary<String, Any> = [:]
                    postDic["userName"] = document.data()["userName"] as? String
                    postDic["userId"] = document.data()["userId"] as? String
                    postDic["shopName"] = document.data()["shopName"] as? String
                    postDic["shopId"] = document.data()["shopId"] as? String
                    postDic["postContent"] = document.data()["postContent"] as? String
                    postDic["postId"] = document.documentID
                    self.postsAry.append(postDic)
                    self.collectionView.reloadData()
                    if let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                        self.collectionViewConstraintHeight.constant = layout.collectionViewContentSize.height
                        self.view.layoutIfNeeded()
                    }
                }
            }
        }
    }
    
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bestShopNameAry.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "shopCell", for: indexPath)
        cell.textLabel?.text = "MyBest\(indexPath.row + 1): " + bestShopNameAry[indexPath.row]
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "toShopPageView", sender: nil)
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return postsAry.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "postCell", for: indexPath) as! CustomCollectionViewCell
        storage.child("posts").child("\(String(describing: postsAry[indexPath.row]["postId"]!)).jpg").getData(maxSize: 1024 * 1024 * 10) { (data: Data?, error: Error?) in
            if error != nil {
                return
            }
            if let imageData = data {
                let postImage = UIImage(data: imageData)!
                let cellSize:CGFloat = (self.view.bounds.width - (self.space * 2))/3
                cell.imageView.image = postImage.resized(toWidth: cellSize)
            }
        }
        return cell
        
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return space
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return space
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // 横方向のスペース調整
        let cellSize:CGFloat = (self.view.bounds.width - (space * 2))/3
        // 正方形で返すためにwidth,heightを同じにする
        return CGSize(width: cellSize, height: cellSize)
    }
    
    var collectionSelectedNum:Int?
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        collectionSelectedNum = indexPath.row
        performSegue(withIdentifier: "toPostViewController", sender: nil)
    }
    
    
    @objc func tapFollowListButton(_ sender: UIButton){
        userAry = followAry
        self.performSegue(withIdentifier: "toFollowListViewController", sender: nil)
    }
    @objc func tapFollowerListButton(_ sender: UIButton){
        userAry = followerAry
        self.performSegue(withIdentifier: "toFollowListViewController", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toPostViewController" {
            let nextVC = segue.destination as! PostViewController
            nextVC.userName = postsAry[collectionSelectedNum!]["userName"] as? String
            nextVC.userId = userId
            nextVC.shopName = postsAry[collectionSelectedNum!]["shopName"] as? String
            nextVC.shopId = postsAry[collectionSelectedNum!]["shopId"] as? String
            nextVC.postContent = postsAry[collectionSelectedNum!]["postContent"] as? String
            nextVC.postId = postsAry[collectionSelectedNum!]["postId"] as? String
        }
        else if segue.identifier == "toFollowListViewController"{
            let nextVC = segue.destination as! FollowListViewController
            nextVC.userAry = userAry
        }else if segue.identifier == "toEditView"{
            let nextVC = segue.destination as! EditViewController
            nextVC.userId = userId
            nextVC.userName = nameLabel.text
            nextVC.userProfile = profileLabel.text
            nextVC.bestShopNameAry = bestShopNameAry
            nextVC.bestShopIdAry = bestShopIdAry
        }else if segue.identifier == "toShopPageView"  {
            let nextVC = segue.destination as! ShopPageViewController
            let row = self.tableView.indexPathForSelectedRow?.row
            nextVC.shopId = bestShopIdAry[row!]
        }
    }
    @objc func logOutButtonTapped(_ sender: UIBarButtonItem) {
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
        } catch let signOutError as NSError {
            print ("Error signing out: %@", signOutError)
        }
    }
    @objc func editButtonTapped(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "toEditView", sender: nil)
    }
    @objc func followButtonTapped(_ sender: UIBarButtonItem) {
        if followFlag{
            db.collection("relationships").document(relationId).delete() { err in
                if let err = err {
                    print("Error removing document: \(err)")
                } else {
                    print("Document successfully removed!")
                    self.followFlag = false
                    self.setFollower()
                }
            }
        }else{
            if currentUser != nil{
                //ログイン中
                var ref: DocumentReference?
                ref = db.collection("relationships").addDocument(data: [
                    "followedId": userId!,
                    "followedName": self.nameLabel.text!,
                    "followerId": currentUser.uid,
                    "followerName":currentUser.displayName!
                ]) { err in
                    if let err = err {
                        print("Error adding document: \(err)")
                    } else {
                        print("Document successfully added!")
                        self.followFlag = true
                        self.relationId = ref?.documentID
                        self.setFollower()
                    }
                }
            }else{
                //ログアウト中はポップアップを表示
                //アラートコントローラーを作成する。
                
                self.present(alertController, animated: true, completion:nil)
                
            }
        }
    }
    @objc func postButtonTapped(_ sender: UIBarButtonItem) {
        //カメラがフォトライブラリーどちらから画像を取得するか選択
        let alertController = UIAlertController(title: "確認", message: "選択してください", preferredStyle: .actionSheet)
        //カメラが利用可能かチェック
        if UIImagePickerController.isSourceTypeAvailable(.camera){
            //カメラを起動するための選択肢を定義
            let cameraAction = UIAlertAction(title: "カメラ", style: .default, handler: {(action) in
                //カメラを起動
                let imagePickerController = UIImagePickerController()
                imagePickerController.sourceType = .camera
                imagePickerController.delegate = self
                self.present(imagePickerController, animated: true, completion: nil)
                
            })
            alertController.addAction(cameraAction)
        }
        //フォトライブラリーが利用可能かチェック
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary){
            //フォトライブラリーを起動するための選択肢を定義
            let photoLibraryAction = UIAlertAction(title: "フォトライブラリー", style: .default, handler: {(action) in
                //カメラを起動
                let imagePickerController = UIImagePickerController()
                imagePickerController.sourceType = .photoLibrary
                imagePickerController.delegate = self
                self.present(imagePickerController, animated: true, completion: nil)
                
            })
            alertController.addAction(photoLibraryAction)
        }
        //キャンセルの選択肢を定義
        let cancelAction = UIAlertAction(title: "キャンセル", style: .default, handler: nil)
        alertController.addAction(cancelAction)
        //iPadで落ちてしまう対策
        alertController.popoverPresentationController?.sourceView = view
        //選択肢を画面に表示
        present(alertController, animated: true, completion: nil)
    }
    //撮影が終わった後呼ばれるdelegateメソッド
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//        //撮影した画像をuserImageViewに設定
//        userImageView.image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
//        //saveButtonを使用可能にする
//        changeFlag["userImage"] = true
        //モーダルビューを閉じる
        dismiss(animated: true, completion: nil)
    }
    
}
extension UIImage{
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
