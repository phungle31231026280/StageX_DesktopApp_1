using StageX_DesktopApp.Models;
using System.Collections.Generic; // Cần cái này để dùng List
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media; // Cần cái này để dùng màu (Brush, Color)

namespace StageX_DesktopApp
{
    public partial class MainWindow : Window
    {
        // Khai báo các trang
        private DashboardPage _dashboardPage = new DashboardPage();
        private GenreManagementPage _genreManagementPage = new GenreManagementPage();
        private ShowManagementPage _showManagementPage = new ShowManagementPage();
        private TheaterSeatPage _theaterSeatPage = new TheaterSeatPage();
        private PerformancePage _performancePage = new PerformancePage();
        private AccountPage _accountPage = new AccountPage();
        private BookingManagementPage _bookingPage = new BookingManagementPage();
        private ProfilePage _profilePage = new ProfilePage();
        private SellTicketPage _sellTicketPage = new SellTicketPage();
        private ActorManagementPage _actorPage = new ActorManagementPage();

        public MainWindow()
        {
            InitializeComponent();
            LoadUserInfo();

            // Mặc định chọn Dashboard nếu là Admin
            if (AuthSession.CurrentUser?.Role == "Admin")
            {
                SetActiveButton(NavDashboard);
                MainContentFrame.Navigate(_dashboardPage);
            }
        }

        // --- HÀM TÔ MÀU NÚT  ---
        private void SetActiveButton(object sender)
        {
            var activeButton = sender as Button;
            if (activeButton == null) return;

            AudioHelper.Play("click.mp3");

            // 1. Danh sách tất cả các nút
            var allButtons = new List<Button>
    {
        NavDashboard, NavGenreMgmt, NavShowMgmt, NavActorMgmt,
        NavTheaterMgmt, NavPerformanceMgmt, NavAccountMgmt,
        NavSellTicket, NavStaffBookingMgmt, NavProfile
    };

            // 2. Trả lại trạng thái mặc định cho tất cả các nút (để XAML lo việc Hover)
            foreach (var btn in allButtons)
            {
                // [QUAN TRỌNG] Dùng ClearValue thay vì gán Brushes.Transparent
                // Điều này giúp Style trong XAML hoạt động trở lại (hiện màu xanh xám khi rê chuột)
                btn.ClearValue(Button.BackgroundProperty);
                btn.ClearValue(Button.ForegroundProperty);
            }

            // 3. Tô màu vàng cứng cho nút ĐANG ĐƯỢC CHỌN (cái này sẽ đè lên hiệu ứng hover, đúng ý muốn)
            activeButton.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#FFffc107")); // Vàng
            activeButton.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#FF0C1220")); // Đen
        }

        private void LoadUserInfo()
        {
            if (AuthSession.CurrentUser == null) return; // Tránh lỗi nếu chưa login

            var user = AuthSession.CurrentUser;
            this.Title = $"StageX - Đã đăng nhập: {user.AccountName} ({user.Role})";

            // Ẩn hết trước
            NavDashboard.Visibility = Visibility.Collapsed;
            NavGenreMgmt.Visibility = Visibility.Collapsed;
            NavShowMgmt.Visibility = Visibility.Collapsed;
            NavTheaterMgmt.Visibility = Visibility.Collapsed;
            NavPerformanceMgmt.Visibility = Visibility.Collapsed;
            NavAccountMgmt.Visibility = Visibility.Collapsed;
            NavActorMgmt.Visibility = Visibility.Collapsed;
            NavSellTicket.Visibility = Visibility.Collapsed;
            NavStaffBookingMgmt.Visibility = Visibility.Collapsed;

            // Hiện theo quyền
            if (user.Role == "Admin")
            {
                NavDashboard.Visibility = Visibility.Visible;
                NavGenreMgmt.Visibility = Visibility.Visible;
                NavShowMgmt.Visibility = Visibility.Visible;
                NavTheaterMgmt.Visibility = Visibility.Visible;
                NavPerformanceMgmt.Visibility = Visibility.Visible;
                NavAccountMgmt.Visibility = Visibility.Visible;
                NavActorMgmt.Visibility = Visibility.Visible;
            }
            else if (user.Role == "Nhân viên")
            {
                NavSellTicket.Visibility = Visibility.Visible;
                NavStaffBookingMgmt.Visibility = Visibility.Visible;
            }
        }

        // ==========================================================
        // KHU VỰC SỰ KIỆN CLICK (Phải giữ nguyên tên hàm như XAML)
        // ==========================================================

        private void NavDashboard_Click(object sender, RoutedEventArgs e)
        {
            SetActiveButton(sender);
            MainContentFrame.Navigate(_dashboardPage);
        }

        private void NavGenreMgmt_Click(object sender, RoutedEventArgs e)
        {
            SetActiveButton(sender);
            MainContentFrame.Navigate(_genreManagementPage);
        }

        private void NavShowMgmt_Click(object sender, RoutedEventArgs e)
        {
            SetActiveButton(sender);
            MainContentFrame.Navigate(_showManagementPage);
        }

        private void NavActorMgmt_Click(object sender, RoutedEventArgs e)
        {
            SetActiveButton(sender);
            MainContentFrame.Navigate(_actorPage);
        }

        private void NavTheaterMgmt_Click(object sender, RoutedEventArgs e)
        {
            SetActiveButton(sender);
            MainContentFrame.Navigate(_theaterSeatPage);
        }

        private void NavPerformanceMgmt_Click(object sender, RoutedEventArgs e)
        {
            SetActiveButton(sender);
            MainContentFrame.Navigate(_performancePage);
        }

        private void NavAccountMgmt_Click(object sender, RoutedEventArgs e)
        {
            SetActiveButton(sender);
            MainContentFrame.Navigate(_accountPage);
        }

        private void NavSellTicket_Click(object sender, RoutedEventArgs e)
        {
            SetActiveButton(sender);
            MainContentFrame.Navigate(_sellTicketPage);
        }

        private void NavStaffBookingMgmt_Click(object sender, RoutedEventArgs e)
        {
            SetActiveButton(sender);
            MainContentFrame.Navigate(_bookingPage);
        }

        private void NavProfile_Click(object sender, RoutedEventArgs e)
        {
            SetActiveButton(sender);
            MainContentFrame.Navigate(_profilePage);
        }

        private void NavLogout_Click(object sender, RoutedEventArgs e)
        {
            AudioHelper.Play("log out.mp3");
            AuthSession.Logout();
            new LoginWindow().Show();
            this.Close();
        }
    }
}