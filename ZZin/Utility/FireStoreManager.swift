//
//  FireStoreManager.swift
//  ZZin
//
//  Created by t2023-m0055 on 2023/10/23.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct User : Codable {
    var profileImg: String?
    var uid: String
    var nickname: String
    var phoneNum: String
    var rid: [String]? // [UUID.uuidString]
    var pid: [String]? // [UUID.uuidString]
    var password: String?
    
    enum CodingKeys: String, CodingKey {
        case profileImg
        case uid
        case nickname
        case phoneNum
        case rid
        case pid
        case password
    }
}

struct Review : Codable {
    var rid: String // UUID.uuidString
    var uid: String
    var pid: String // UUID.uuidString
    var reviewImg: String?
    var title: String
    var like: Int
    var dislike: Int
    var content: String
    var rate: Double
    var createdAt: Date
    var companion: String // 추후 enum case로 정리 필요
    var condition: String // 추후 enum case로 정리 필요
    var kindOfFood: String // 추후 enum case로 정리 필요
    
    enum CodingKeys: String, CodingKey {
        case rid
        case uid
        case pid
        case reviewImg
        case title
        case like
        case dislike
        case content
        case rate
        case createdAt
        case companion
        case condition
        case kindOfFood
    }
}

struct Place : Codable {
    var pid: String // UUID.uuidString
    var rid: [String] // [UUID.uuidString]
    var placeName: String
    var placeImg: [String]
    var placeTelNum: String
    var city: String
    var town: String
    var address: String
    var lat: Double?
    var long: Double?
    var companion: String
    var condition: String
    var kindOfFood: String
    
    enum CodingKeys: String, CodingKey {
        case pid
        case rid
        case placeName
        case placeImg
        case placeTelNum
        case city
        case town
        case address
        case lat
        case long
        case companion
        case condition
        case kindOfFood
    }
}

class FireStoreManager {
    
    let db = Firestore.firestore()
    static let shared = FireStoreManager()
    
    func fetchDocument<T: Decodable>(from collection: String, documentId: String, completion: @escaping (Result<T, Error>) -> Void) {
        let docRef = db.collection(collection).document(documentId)
        docRef.getDocument { (document, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let document = document, document.exists, var data = document.data() else {
                completion(.failure(NSError(domain: "FirestoreError", code: -1, userInfo: ["description": "No document or data"])))
                return
            }
            
            // FIRTimestamp를 Date로 변환하고, Date를 문자열로 변환
            if let timestamp = data["createdAt"] as? Timestamp {
                let date = timestamp.dateValue()
                let formatter = ISO8601DateFormatter()
                let dateString = formatter.string(from: date)
                data["createdAt"] = dateString
            }
            
            let dataAsJSON = try! JSONSerialization.data(withJSONObject: data, options: [])
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let obj = try decoder.decode(T.self, from: dataAsJSON)
                completion(.success(obj))
            } catch let decodeError {
                completion(.failure(decodeError))
            }
        }
    }
    
    func fetchDataWithPid(pid: String, completion: @escaping (Result<Place, Error>) -> Void) {
        fetchDocument(from: "places", documentId: pid, completion: completion)
    }
    
    func fetchDataWithRid(rid: String, completion: @escaping (Result<Review, Error>) -> Void) {
        fetchDocument(from: "reviews", documentId: rid, completion: completion)
    }
    
    // 별도의 함수로 데이터 변환 로직을 분리
    func convertFirestoreData(data: [String: Any], objectType: Decodable.Type) -> Result<Decodable, Error> {
        var mutableData = data
        
        if let timestamp = mutableData["createdAt"] as? Timestamp {
            let date = timestamp.dateValue()
            let formatter = ISO8601DateFormatter()
            let dateString = formatter.string(from: date)
            mutableData["createdAt"] = dateString
        }
        
        let dataAsJSON = try! JSONSerialization.data(withJSONObject: mutableData, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let obj = try decoder.decode(objectType, from: dataAsJSON)
            return .success(obj)
        } catch let decodeError {
            return .failure(decodeError)
        }
    }
    
    
    
    func fetchCollectionData<T: Decodable>(from collection: String, objectType: T.Type, completion: @escaping (Result<[T], Error>) -> Void) {
        db.collection(collection).getDocuments { (querySnapshot, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            var objects: [T] = []
            
            for document in querySnapshot!.documents {
                let data = document.data()
                switch self.convertFirestoreData(data: data, objectType: objectType) {
                case .success(let obj):
                    if let objT = obj as? T {
                        objects.append(objT)
                    }
                case .failure(let error):
                    completion(.failure(error))
                    return
                }
            }
            completion(.success(objects))
        }
    }
    
    
    func getReviewData(completion: @escaping (Result<[Review], Error>) -> Void) {
        fetchCollectionData(from: "reviews", objectType: Review.self, completion: completion)
    }
    
    func getPlaceData(completion: @escaping (Result<[Place], Error>) -> Void) {
        fetchCollectionData(from: "places", objectType: Place.self, completion: completion)
    }
    
    // 전체 데이터 저장 및 업데이트
    func setData(uid: String, dataWillSet: [String: Any?]){
        // 1. rid 생성
        let rid = UUID().uuidString
        
        // 2. rid를 이용해서 firebase Storage에 업로드
        let imgData = dataWillSet["imgData"] as! Data // nil 처리를 어떻게 해야할지 모르겠음
        uploadImgToFirebase(imgData: imgData, rid: rid) // 업로드 method
        
        // 3. pid 생성
        let pid = UUID().uuidString
        
        // 4. reviewData 생성
        let reviewDictionary: [String: Any] = ["rid": rid,
                                               "uid": uid,
                                               "pid": pid,
                                               "reviewImg": "reviews/\(rid).jpeg",
                                               "title": dataWillSet["title"] as? String ?? "나의 리뷰",
                                               "like": 0,
                                               "dislike": 0,
                                               "content": dataWillSet["content"] as? String ?? "내용 없음",
                                               "rate": 100, // 추후 계산하는 알고리즘 추가
                                               "createdAt": Timestamp(date: Date()),
                                               "companion": dataWillSet["companion"] as? String ?? "nil",
                                               "condition": dataWillSet["condition"] as? String ?? "nil",
                                               "kindOfFood": dataWillSet["kindOfFood"] as? String ?? "nil"]
        
        // 5. reviewData 저장
        setReviewData(reviewDictionary: reviewDictionary)
        
        // 6. uid를 이용해서 rid 배열과 pid 배열 업데이트
        updateUserRidAndPid(pid: pid, rid: rid, uid: uid)
        
        // 7. place데이터 저장
        let path = "reviews/\(rid).jpeg"
        setPlaceData(dataWillSet: dataWillSet, pid: pid, uid: uid, rid: rid, path: path)
    }
    
    func uploadImgToFirebase(imgData: Data, rid: String) {
        print("uploadImgToFirebase")
        let storage = Storage.storage()
        let storageRef = storage.reference()
        var imagesRef = storageRef.child("images")
        let imageName = rid // reviewID와 같아야 함
        let storagePath = "gs://zzin-ios-application.appspot.com//reviews/\(imageName).jpeg"
        imagesRef = storage.reference(forURL: storagePath)
        
        
        let uploadTask = imagesRef.putData(imgData, metadata: nil) { (metadata, error) in
            guard let metadata = metadata else {
                print("Uh-oh, an error occurred!")
                return
            }
            // Metadata contains file metadata such as size, content-type.
            let size = metadata.size
            // You can also access to download URL after upload.
            imagesRef.downloadURL { (url, error) in
                guard let downloadURL = url else {
                    print("Uh-oh, an error occurred! in down")
                    return
                }
            }
        }
    }
    
    func setReviewData(reviewDictionary: [String: Any]){
        // FireStoreManager 안으로 옮기고 난 후에 수정
        let db = FireStoreManager.shared.db
        let reviewRef = db.collection("reviews").document(reviewDictionary["rid"] as! String)
        
        reviewRef.setData(reviewDictionary){ err in
            if let err = err {
                print("setReviewData: Error writing document: \(err)")
            } else {
                print("setReviewData: Document successfully written!")
            }
        }
    }



    func fetchDataWithPid(pid: String, completion: @escaping (Result<Place, Error>) -> Void) {
        fetchDocument(from: "places", documentId: pid, completion: completion)
    }
    

    func updateUserRidAndPid(pid: String?, rid: String, uid: String){
        let userRef = db.collection("users").document(uid)
        
        userRef.updateData(["rid": FieldValue.arrayUnion([rid]),
                            "pid": FieldValue.arrayUnion([pid] as? [String] ?? [])]){ err in
            if let err = err {
                print("updateUserAppendingRid: Error adding document: \(err)")
            } else {
                print("updateUserAppendingRid: Document added with ID: \(userRef.documentID)")
            }
        }
    }
    
    func setPlaceData(dataWillSet: [String: Any?], pid: String, uid: String, rid: String, path: String) {
        let placeRef = db.collection("places").document(pid)
        placeRef.setData(["pid": pid,
                          "uid": uid,
                          "rid": FieldValue.arrayUnion([rid]),
                          "placeImg": FieldValue.arrayUnion([path]),
                          "city": "인천광역시",
                          "town": "부평구",
                          "address": dataWillSet["address"] as! String,
                          "placeName": dataWillSet["placeName"] as! String,
                          "placeTelNum": dataWillSet["placeTelNum"] as! String,
                          "lat": dataWillSet["mapx"] as! Double,
                          "long": dataWillSet["mapy"] as! Double,
                          "companion": dataWillSet["companion"] as! String,
                          "condition": dataWillSet["condition"] as! String,
                          "kindOfFood": dataWillSet["kindOfFood"] as! String]){ err in
            if let err = err {
                print("setPlaceData: Error writing document: \(err)")
            } else {
                print("setPlaceData: Document successfully written!")
            }
        }
        
    }
    
    /**
     @brief placeData를 불러온다 >> 주연님 코드에서 현재 적용중인 상황
     */
    func getPlaceData(completion: @escaping ([Place]?) -> Void) {
        var placeData: [[String:Any]] = [[:]]
        var place: [Place]?
        
        db.collection("places").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error getting documents: \(error)")
                completion(place) // 호출하는 쪽에 빈 배열 전달
                return
            }
            
            for document in querySnapshot!.documents {
                placeData.append(document.data())
            }
            placeData.remove(at: 0)
            place = self.dictionaryToObject(objectType: Place.self, dictionary: placeData)
            print(place?.count)
            completion(place) // 성공 시 배열 전달
        }
    }
    
    //MARK: - 로그인/회원가입 Page
    func fetchUserUID(completion: @escaping ([String]) -> Void) {
        var uids: [String] = []
        db.collection("users").getDocuments { result, error in
            if let error = error {
                print("오류가 발생했습니다.")
            } else {
                for document in result!.documents {
                    if document.exists {
                        if let uid = document.get("uid") as? String {
                            print(uid)
                            uids.append(uid)
                        }
                    }
                }
                completion(uids)
            }
        }
    }
    
    //MARK: - 유효성 검사 관련
    // 중복 UID 확인
    func crossCheckDB(_ id: String, completion: @escaping (Bool) -> Void) {
        fetchUserUID { uids in
            if uids.contains(id) {
                print("아이디가 데이터베이스에 이미 있습니다.")
                completion(true)
            } else {
                print("아이디가 데이터베이스에 없습니다.")
                completion(false)
            }
        }
    }
    
    //MARK: - Auth 관련
    // 로그인
    func loginUser(with email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("로그인하는데 에러가 발생했습니다.")
            }
        }
    }
    
    // 회원가입
    func signIn(with email: String, password: String, completion: @escaping ((Bool) -> Void)) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                print("여기가 문제인가요 유저를 생성하는데 에러가 발생했습니다. \(error.localizedDescription)")
                completion(false)
            }
            print("결과값은 아래와 같습니다 - \(result?.description)")
            completion(true)
        }
    }
}

extension FireStoreManager {
    func dictionaryToObject<T:Decodable>(objectType:T.Type, dictionary:[[String:Any]]) -> [T]? {
        do {
            let dictionaries = try JSONSerialization.data(withJSONObject: dictionary)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let objects = try decoder.decode([T].self, from: dictionaries)
            return objects
            
        } catch let serializationError as NSError where serializationError.domain == NSCocoaErrorDomain {
            print("JSON Serialization Error: \(serializationError.localizedDescription)")
        } catch let decodingError as DecodingError {
            print("Decoding Error: \(decodingError)")
        } catch {
            print("Unexpected error: \(error)")
        }
        return nil
    }
    
    func dicToObject<T:Decodable>(objectType:T.Type,dictionary:[String:Any]) -> T? {
        
        guard let dictionaries = try? JSONSerialization.data(withJSONObject: dictionary) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let objects = try? decoder.decode(T.self, from: dictionaries) else { return nil }
        return objects
        
    }
}
