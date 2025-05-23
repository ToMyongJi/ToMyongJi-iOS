//
//  AdminViewModel.swift
//  ToMyongJi-iOS
//
//  Created by JunKyu Lee on 2/8/25.
//

import Foundation
import Combine
import Core

@Observable
class AdminViewModel {
    // 단과대학 및 소속
    var colleges: [College] = []
    var collegeName: String?
    var selectedCollege: College?
    var selectedClubId: Int = 0
    var selectedClub: Club? {
        didSet {
            if let club = selectedClub {
                selectedClubId = club.studentClubId
                print("Club Selected: \(club.studentClubName), ID: \(selectedClubId)")
                fetchPresident()
                fetchMember()  // 소속 선택 시 멤버 목록도 함께 가져오기
            }
        }
    }
    
    // 현재 회장 정보
    var currentPresidentStudentNum: String = ""
    var currentPresidentName: String = ""
    
    // 새 회장 정보
    var newPresidentStudentNum: String = ""
    var newPresidentName: String = ""
    
    // 새 소속부원 정보
    var newMemberStudentNum: String = ""
    var newMemberName: String = ""
    var members: [Member] = []
    
    // 알림 관련
    var showAlert: Bool = false
    var alertTitle: String = ""
    var alertMessage: String = ""
    
    // 로딩 상태
    var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var networkingManager = AlamofireNetworkingManager.shared
    
    // 알림
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
    
    // 단과대학 및 소속 정보 가져오기
    func fetchCollegesAndClubs() {
        isLoading = true
        networkingManager.run(AdminEndpoint.getCollegesAndClubs, type: CollegesAndClubsResponse.self)
            .sink { [weak self] completion in
                guard let self = self else {return}
                self.isLoading = false
                switch completion {
                case .failure:
                    self.showAlert(title: "실패", message: "단과대학 및 소속 정보를 가져오는데 실패했습니다.")
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else {return}
                self.isLoading = false
                self.colleges = response.data
            }
            .store(in: &cancellables)
    }
    
    /// 회장
    // 소속 회장 정보 조회
    func fetchPresident() {
        isLoading = true
        networkingManager.run(AdminEndpoint.getPresident(clubId: selectedClubId), type: GetPresidentResponse.self)
            .sink { [weak self] completion in
                guard let self = self else {return}
                self.isLoading = false
                switch completion {
                case .failure:
                    self.showAlert(title: "실패", message: "소속 회장 정보를 조회하는데 실패했습니다.")
                    self.currentPresidentStudentNum = ""
                    self.currentPresidentName = ""
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else {return}
                self.isLoading = false
                self.currentPresidentStudentNum = response.data.studentNum
                self.currentPresidentName = response.data.name
            }
            .store(in: &cancellables)
    }
    
    // 소속 회장 정보 추가
    func addPresident() {
        isLoading = true
        networkingManager.run(AdminEndpoint.addPresident(clubId: selectedClubId, studentNum: newPresidentStudentNum, name: newPresidentName), type: AddPresidentResponse.self)
            .sink { [weak self] completion in
                guard let self = self else {return}
                self.isLoading = false
                switch completion {
                case .failure:
                    self.showAlert(title: "실패", message: "소속 회장을 추가하는데 실패했습니다.")
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else {return}
                self.isLoading = false
                self.currentPresidentStudentNum = response.data.studentNum
                self.currentPresidentName = response.data.name
                self.newPresidentStudentNum = ""
                self.newPresidentName = ""
                self.fetchPresident()
                self.showAlert(title: "성공", message: "소속 회장이 정상적으로 추가되었습니다.")
            }
            .store(in: &cancellables)
    }
    
    // 소속 회장 정보 변경
    func updatePresident() {
        isLoading = true
        networkingManager.run(AdminEndpoint.updatePresident(clubId: selectedClubId, studentNum: newPresidentStudentNum, name: newPresidentName), type: UpdatePresidentResponse.self)
            .sink { [weak self] completion in
                guard let self = self else {return}
                self.isLoading = false
                switch completion {
                case .failure:
                    self.showAlert(title: "실패", message: "회원가입이 되어있지 않은 회장은 변경할 수 없습니다.")
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else {return}
                self.isLoading = false
                self.currentPresidentStudentNum = response.data.studentNum
                self.currentPresidentName = response.data.name
                self.newPresidentStudentNum = ""
                self.newPresidentName = ""
                self.fetchPresident()
                self.fetchMember()
                self.showAlert(title: "성공", message: "소속 회장이 정상적으로 변경되었습니다.")
            }
            .store(in: &cancellables)
    }

    /// 소속부원
    // 소속부원 정보 조회
    func fetchMember() {
        isLoading = true
        networkingManager.run(AdminEndpoint.getMember(clubId: selectedClubId), type: GetMemberResponse.self)
            .sink { [weak self] completion in
                guard let self = self else {return}
                self.isLoading = false
                switch completion {
                case .failure:
                    self.showAlert(title: "실패", message: "소속부원 정보를 조회하는데 실패했습니다.")
                    self.members = []
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else {return}
                self.isLoading = false
                self.members = response.data
            }
            .store(in: &cancellables)
    }
    
    // 소속부원 정보 추가
    func addMember() {
        isLoading = true
        networkingManager.run(AdminEndpoint.addMember(clubId: selectedClubId, studentNum: newMemberStudentNum, name: newMemberName), type: AddMemberResponse.self)
            .sink { [weak self] completion in
                guard let self = self else {return}
                self.isLoading = false
                switch completion {
                case .failure:
                    self.showAlert(title: "실패", message: "소속부원을 추가하는데 실패했습니다.")
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else {return}
                self.isLoading = false
                self.newMemberStudentNum = ""
                self.newMemberName = ""
                self.fetchMember()
                self.showAlert(title: "성공", message: "소속부원이 정상적으로 추가되었습니다.")
            }
            .store(in: &cancellables)
    }
    
    // 소속부원 삭제
    func deleteMember(memberId: Int) {
        isLoading = true
        networkingManager.run(AdminEndpoint.deleteMember(memberId: memberId), type: DeleteMemberResponse.self)
            .sink { [weak self] completion in
                guard let self = self else {return}
                self.isLoading = false
                switch completion {
                case .failure:
                    self.showAlert(title: "실패", message: "소속부원 삭제에 실패했습니다.")
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else {return}
                self.isLoading = false
                self.fetchMember()
                self.showAlert(title: "성공", message: "소속부원이 정상적으로 삭제되었습니다.")
            }
            .store(in: &cancellables)
    }
}
