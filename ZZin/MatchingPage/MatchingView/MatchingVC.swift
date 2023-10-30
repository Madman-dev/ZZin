import UIKit
import SnapKit
import Then
import Firebase
import NMapsMap


class MatchingVC: UIViewController {
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setDataManager()
        setView()
        configureUI()
        locationSetting()
        currentLocation = LocationService.shared.getCurrentLocation()
        getAddress()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        setKeywordButtonTitle()
    }
    
    
    // MARK: - Settings
    func locationSetting() {
        LocationService.shared.delegate = self
    }
    
    func getAddress() {
        self.currentLocation = LocationService.shared.getCurrentLocation()
        LocationService.shared.getAddressFromLocation(lat: self.currentLocation?.lat ?? 0, lng: self.currentLocation?.lng ?? 0) { (address, error) in
            if let error = error {
                print("Error getting address: \(error.localizedDescription)")
                return
            }
            
            if let address = address {
                print("Current address: \(address)")
                
                if let city = address.first, city.count >= 2 {
                    self.locationPickerVC.selectedCity = String(city.prefix(2))
                }
                
                self.locationPickerVC.selectedTown = address.last
                
                print("@@@@@@@\(self.locationPickerVC.selectedCity),\(self.locationPickerVC.selectedTown)")
            } else {
                print("Address not found.")
            }
        }
    }
    
    func setDataManager(){
        // 플레이스 데이터 불러오기
        dataManager.getPlaceData { [weak self] result in
            if let placeData = result {
                self?.place = placeData
                self?.collectionView.collectionView.reloadData()
            }
        }
    }
    
    private func setView(){
        view.backgroundColor = .white
        
        setMapView()
        setlocationView()
        setPickerView()
        setCollectionViewAttribute()
        setKeywordView()
        configureUI()
    }
    
    private func setMapView(){
        matchingView.mapButton.addTarget(self, action: #selector(mapButtonTapped), for: .touchUpInside)
    }
    
    private func setlocationView(){
        matchingView.locationButton.addTarget(self, action: #selector(locationButtonTapped), for: .touchUpInside)
    }
    
    private func setPickerView(){
        matchingView.setLocationButton.addTarget(self, action: #selector(setPickerViewTapped), for: .touchUpInside)
    }

    
    private func setCollectionViewAttribute(){
        collectionView.collectionView.delegate = self
        collectionView.collectionView.dataSource = self
    }
    
    
    func fetchPlacesWithKeywords(companion: String? = nil, condition: String? = nil, kindOfFood: String? = nil, city: String? = nil, town: String? = "전체") {
        let actualCompanion = companion ?? self.companionKeyword?.first ?? nil
        let actualCondition = condition ?? self.conditionKeyword?.first ?? nil
        let actualKindOfFood = kindOfFood ?? self.kindOfFoodKeyword?.first ?? nil
        let actualCity = city ?? locationPickerVC.selectedCity ?? nil
        let actualTown = town ?? locationPickerVC.selectedTown ?? "전체"
                
        FireStoreManager().fetchPlacesWithKeywords(companion: actualCompanion, condition: actualCondition, kindOfFood: actualKindOfFood, city: actualCity, town: actualTown) { result in
            switch result {
            case .success(let places):
                self.place = places
                
                print("----------", self.place?.count ?? "")
                
                DispatchQueue.main.async {
                    self.collectionView.collectionView.reloadData()
                }
                
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
    }
  
    //MARK: - Properties
    
    // FirestoreManager
    let dataManager = FireStoreManager()
    var place: [Place?]?
    var review: [Review]?
    var pidArr: [String]? = []
    
    var companionKeyword : [String?]?
    var conditionKeyword : [String?]?
    var kindOfFoodKeyword : [String?]?
   
    var currentLocation: NMGLatLng?
    
    private let matchingView = MatchingView()
    private let locationPickerVC = MatchingLocationPickerVC()
    private let collectionView = MatchingResultCollectionView()
    
    private let keywordVC = MatchingKeywordVC()
    
        
    // MARK: - Actions
    @objc private func mapButtonTapped() {
        print("지도 버튼 탭")
        let mapViewController = SearchMapViewController()
        mapViewController.companionKeyword = companionKeyword
        mapViewController.conditionKeyword = conditionKeyword
        mapViewController.kindOfFoodKeyword = kindOfFoodKeyword
        mapViewController.selectedCity = locationPickerVC.selectedCity
        mapViewController.selectedTown = locationPickerVC.selectedTown
        mapViewController.mapViewDelegate = self
        self.navigationController?.pushViewController(mapViewController, animated: true)
    }
    
    @objc private func locationButtonTapped() {
        print("현재 위치 버튼 탭")
        getAddress()
//        updateLocationTitle()
    }
    
    @objc private func setPickerViewTapped() {
        print("위치 설정 피커뷰 탭")

        let pickerViewVC = MatchingLocationPickerVC()
        pickerViewVC.pickerViewDelegate = self
        
        if let sheet = pickerViewVC.sheetPresentationController {
            sheet.preferredCornerRadius = 15
            sheet.prefersGrabberVisible = true
            if #available(iOS 16.0, *) {
                sheet.detents = [
                    .custom(resolver: {
                        0.65 * $0.maximumDetentValue
                    })]
            } else { }
            sheet.largestUndimmedDetentIdentifier = .large
        }
        present(pickerViewVC, animated: true)
    }
    
    @objc func companionKeywordButtonTapped() {
        print("첫 번째 키워드 버튼이 탭됨")
        
        let keywordVC = MatchingKeywordVC()
        keywordVC.selectedMatchingKeywordType = .with
        keywordVC.noticeLabel.text = "누구랑\n가시나요?"
        keywordVC.delegate = self
        
        present(keywordVC, animated: true)
    }
    
    @objc func conditionKeywordButtonTapped() {
        print("두 번째 키워드 버튼이 탭됨")
        
        let keywordVC = MatchingKeywordVC()
        keywordVC.selectedMatchingKeywordType = .condition
        keywordVC.noticeLabel.text = "어떤 분위기를\n원하시나요?"
        keywordVC.delegate = self
        
        navigationController?.present(keywordVC, animated: true)
    }
    
    @objc func kindOfFoodKeywordButtonTapped() {
        print("메뉴 키워드 버튼이 탭됨")
        
        let keywordVC = MatchingKeywordVC()
        keywordVC.selectedMatchingKeywordType = .menu
        keywordVC.noticeLabel.text = "메뉴는\n무엇인가요?"
        keywordVC.delegate = self
        
        navigationController?.present(keywordVC, animated: true)
    }
    
    
    
    //MARK: - Configure UI
    
    private func configureUI(){
        addSubViews()
        setSearchViewConstraints()
        setCollectionViewConstraints()
    }
    
    private func addSubViews(){
        view.addSubview(matchingView)
        view.addSubview(collectionView)
    }
    
    private func setSearchViewConstraints(){
        matchingView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(232)
        }
    }
    
    private func setCollectionViewConstraints(){
        collectionView.snp.makeConstraints {
            $0.top.equalTo(matchingView.snp.bottom)
            $0.bottom.equalToSuperview().offset(-90)
            $0.leading.equalToSuperview()
            $0.trailing.equalToSuperview()
        }
    }
    
    private func setKeywordView(){
        matchingView.companionKeywordButton.addTarget(self, action: #selector(companionKeywordButtonTapped), for: .touchUpInside)
        matchingView.conditionKeywordButton.addTarget(self, action: #selector(conditionKeywordButtonTapped), for: .touchUpInside)
        matchingView.kindOfFoodKeywordButton.addTarget(self, action: #selector(kindOfFoodKeywordButtonTapped), for: .touchUpInside)
    }
    
    func setKeywordButtonTitle() {
        let firstCompanionKeyword = companionKeyword?.first ?? nil ?? nil
        matchingView.companionKeywordButton.setTitle(firstCompanionKeyword ?? "키워드", for: .normal)
        matchingView.companionKeywordButton.setTitleColor(.darkGray, for: .normal)
        
        let firstConditionKeyword = conditionKeyword?.first ?? nil ?? nil
        matchingView.conditionKeywordButton.setTitle(firstConditionKeyword ?? "키워드", for: .normal)
        matchingView.conditionKeywordButton.setTitleColor(.darkGray, for: .normal)
        
        let firstKindOfFoodKeyword = kindOfFoodKeyword?.first ?? nil ?? nil
        matchingView.kindOfFoodKeywordButton.setTitle(firstKindOfFoodKeyword ?? "키워드", for: .normal)
        matchingView.kindOfFoodKeywordButton.setTitleColor(.darkGray, for: .normal)
    }
    
}

//MARK: - Matching Keyword Delegate

extension MatchingVC: LocationPickerViewDelegate {
    func updateLocation(city: String?, town: String?) {
        let updateCity = city
        let updateTown = town
        
        matchingView.setLocationButton.setTitle("\(updateCity ?? "") \(updateTown ?? "")", for: .normal)
        
        print("asdfsdfsdfsdfsdfsdfsdfsdf\(updateCity ?? "") \(updateTown ?? "")")
        
        fetchPlacesWithKeywords()
    }
}

//MARK: - Matching Keyword Delegate

extension MatchingVC: MatchingKeywordDelegate {
    func updateKeywords(keyword: [String], keywordType: MatchingKeywordType) {
        let keywordType = keywordType
        
        switch keywordType {
        case .with:
            if let updateKeyword = keyword.first {
                matchingView.companionKeywordButton.setTitle(updateKeyword, for: .normal)
                matchingView.companionKeywordButton.setTitleColor(.darkGray, for: .normal)
                self.companionKeyword = keyword
            }
            
        case .condition:
            if let updateKeyword = keyword.first {
                matchingView.conditionKeywordButton.setTitle(updateKeyword, for: .normal)
                matchingView.conditionKeywordButton.setTitleColor(.darkGray, for: .normal)
                self.conditionKeyword = keyword
            }
            
        case .menu:
            if let updateKeyword = keyword.first {
                matchingView.kindOfFoodKeywordButton.setTitle(updateKeyword, for: .normal)
                matchingView.kindOfFoodKeywordButton.setTitleColor(.darkGray, for: .normal)
                self.kindOfFoodKeyword = keyword
            }
        }
        
        fetchPlacesWithKeywords()
    }
}

//MARK: - CollectionView Delegate, DataSource, Layout

extension MatchingVC: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    // 셀 크기 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width / 2 - 28, height: collectionView.frame.width / 2 + 40)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 20, left: 20, bottom: 0, right: 20)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // 등록된 플레이스 개수만큼 컬렉션뷰셀 반환
        return place?.count ?? 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MatchingSearchResultCell.identifier ,for: indexPath) as? MatchingSearchResultCell else {
            return UICollectionViewCell()
        }

        // 플레이스에 등록된 플레이스 네임을 컬렉션뷰 셀의 제목에 반환
        if let placeData = place {
            let placeName = placeData[indexPath.item]?.placeName
            cell.recommendPlaceReview.titleLabel.text = placeName
        }
        
        let reviewID = place?[indexPath.item]?.rid[0] ?? "타이틀"
        let placeImg = place?[indexPath.item]?.placeImg[0]

        FireStoreManager.shared.fetchDataWithRid(rid: reviewID) { (result) in
            switch result {
            case .success(let review):
                cell.recommendPlaceReview.descriptionLabel.text = review.title
                FireStorageManager().bindPlaceImgWithPath(path: placeImg, imageView: cell.recommendPlaceReview.img)

            case .failure(let error):
                print("Error fetching review: \(error.localizedDescription)")
            }
        }
       
        return cell
    }
    
    // 위 아래 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    // 양 옆 간격
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("매칭 업체 페이지로 이동합니다.")
        if collectionView.cellForItem(at: indexPath) is MatchingSearchResultCell {
            let matchingVC = MatchingPlaceVC()
            self.navigationController?.pushViewController(matchingVC, animated: true)
            
            matchingVC.placeID = place?[indexPath.item]?.pid
        }
    }
}


// MARK: - SearchMapVC Delegate

extension MatchingVC: SearchMapViewControllerDelegate {
    func didUpdateSearchData(companionKeyword: [String?]?, conditionKeyword: [String?]?, kindOfFoodKeyword: [String?]?, selectedCity: String?, selectedTown: String?) {
        self.companionKeyword = companionKeyword
        self.conditionKeyword = conditionKeyword
        self.kindOfFoodKeyword = kindOfFoodKeyword
        locationPickerVC.selectedCity = locationPickerVC.selectedCity
        locationPickerVC.selectedTown = locationPickerVC.selectedTown
    }
}

extension MatchingVC: LocationServiceDelegate {
    func didUpdateLocation(lat: Double, lng: Double) {
        print("\(lat)")
    }
    
    func didFailWithError(error: Error) {
        print("\(error)")
    }
    
    
}
