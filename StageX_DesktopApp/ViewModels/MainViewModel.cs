using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Utilities;
using StageX_DesktopApp.Views;
using System.Windows;

namespace StageX_DesktopApp.ViewModels
{
    public partial class MainViewModel : ObservableObject
    {
        // View hiện tại đang hiển thị bên phải
        [ObservableProperty] private object _currentView;

        // Tiêu đề cửa sổ
        [ObservableProperty] private string _windowTitle;

        // Ẩn hiện menu theo quyền
        [ObservableProperty] private Visibility _adminVisibility = Visibility.Collapsed;
        [ObservableProperty] private Visibility _staffVisibility = Visibility.Collapsed;

        // [QUAN TRỌNG] Biến lưu tên menu đang chọn (để Converter tô màu vàng)
        [ObservableProperty] private string _selectedMenu;

        public MainViewModel()
        {
            LoadUserInfo();
        }

        private void LoadUserInfo()
        {
            var user = AuthSession.CurrentUser;
            if (user == null) return;

            WindowTitle = $"StageX - Đã đăng nhập: {user.AccountName} ({user.Role})";

            if (user.Role == "Admin")
            {
                AdminVisibility = Visibility.Visible;
                NavigateDashboard(); // Mặc định vào Dashboard
            }
            else
            {
                StaffVisibility = Visibility.Visible;
                NavigateSellTicket(); // Mặc định vào Bán vé
            }
        }
        private void NavigateTo(object view, string menuName)
        {
            CurrentView = view;
            SelectedMenu = menuName;
            SoundManager.PlayClick(); 
        }

        // --- CÁC COMMAND ĐIỀU HƯỚNG ---
        // Mỗi hàm làm 2 việc: Đổi View và Gán tên Menu

        [RelayCommand] 
        private void NavigateDashboard() => NavigateTo(new DashboardView(), "Dashboard");

        [RelayCommand]
        private void NavigatePerformance() => NavigateTo(new PerformanceView(), "Performance");

        [RelayCommand]
        private void NavigateShow() => NavigateTo(new ShowManagementView(), "Show");

        [RelayCommand]
        private void NavigateTheater() => NavigateTo(new TheaterSeatView(), "Theater");

        [RelayCommand]
        private void NavigateActor() => NavigateTo(new ActorManagementView(), "Actor");

        [RelayCommand]
        private void NavigateGenre() => NavigateTo(new GenreManagementView(), "Genre");

        [RelayCommand]
        private void NavigateAccount() => NavigateTo(new AccountView(), "Account");

        [RelayCommand]
        private void NavigateSellTicket() => NavigateTo(new SellTicketView(), "SellTicket");

        [RelayCommand]
        private void NavigateBooking() => NavigateTo(new BookingManagementView(), "Booking");

        [RelayCommand]
        private void NavigateProfile() => NavigateTo(new ProfileView(), "Profile");
        [RelayCommand]
        private void Logout()
        {
            SoundManager.PlayLogout();
            AuthSession.Logout();
            var loginWindow = new LoginView();
            loginWindow.Show();
            foreach (Window window in Application.Current.Windows)
            {
                if (window is MainWindow)
                {
                    window.Close();
                    break; // Đóng xong thì thoát vòng lặp ngay
                }
            }
        }
    }
}