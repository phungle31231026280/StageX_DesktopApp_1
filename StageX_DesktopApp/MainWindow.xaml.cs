using StageX_DesktopApp.Models;
using System.Windows;
using System.Windows.Controls;

namespace StageX_DesktopApp
{
    public partial class MainWindow : Window
    {
        // Khai báo các trang (Pages)
        private DashboardPage _dashboardPage;
        private GenreManagementPage _genreManagementPage;
        private ShowManagementPage _showManagementPage;
        private TheaterSeatPage _theaterSeatPage;
        private PerformancePage _performancePage;
        private AccountPage _accountPage;
        private BookingManagementPage _bookingPage; // <-- GHI CHÚ: Trang mới
        private ProfilePage _profilePage;
        private SellTicketPage _sellTicketPage;
        private ActorManagementPage _actorPage;

        public MainWindow()
        {
            InitializeComponent();

            // Khởi tạo các trang (Cache lại để không phải load lại nhiều lần)
            _dashboardPage = new DashboardPage();
            _genreManagementPage = new GenreManagementPage();
            _showManagementPage = new ShowManagementPage();
            _theaterSeatPage = new TheaterSeatPage();
            _performancePage = new PerformancePage();
            _accountPage = new AccountPage();
            _bookingPage = new BookingManagementPage(); // <-- GHI CHÚ: Khởi tạo trang mới
            _profilePage = new ProfilePage();
            _sellTicketPage = new SellTicketPage();
            _actorPage = new ActorManagementPage();

            LoadUserInfo();
            AttachClickEvents();

            // Mở trang mặc định (Dashboard) nếu là Admin
            if (AuthSession.CurrentUser?.Role == "Admin")
            {
                MainContentFrame.Navigate(_dashboardPage);
            }
        }

        private void LoadUserInfo()
        {
            if (AuthSession.CurrentUser == null)
            {
                MessageBox.Show("Phiên đăng nhập không hợp lệ!");
                LoginWindow loginWindow = new LoginWindow();
                loginWindow.Show();
                this.Close();
                return;
            }

            var user = AuthSession.CurrentUser;
            this.Title = $"StageX - Đã đăng nhập: {user.AccountName} ({user.Role})";

            // 1. Ẩn TẤT CẢ các nút nghiệp vụ trước
            NavDashboard.Visibility = Visibility.Collapsed;
            NavGenreMgmt.Visibility = Visibility.Collapsed;
            NavShowMgmt.Visibility = Visibility.Collapsed;
            NavTheaterMgmt.Visibility = Visibility.Collapsed;
            NavPerformanceMgmt.Visibility = Visibility.Collapsed;
            NavAccountMgmt.Visibility = Visibility.Collapsed;
            //NavAdminBookingMgmt.Visibility = Visibility.Collapsed;
            NavActorMgmt.Visibility = Visibility.Collapsed;
            NavSellTicket.Visibility = Visibility.Collapsed;
            NavStaffBookingMgmt.Visibility = Visibility.Collapsed;

            // 2. Hiện các nút dựa trên vai trò
            if (user.Role == "Admin")
            {
                NavDashboard.Visibility = Visibility.Visible;
                NavGenreMgmt.Visibility = Visibility.Visible;
                NavShowMgmt.Visibility = Visibility.Visible;
                NavTheaterMgmt.Visibility = Visibility.Visible;
                NavPerformanceMgmt.Visibility = Visibility.Visible;
                NavAccountMgmt.Visibility = Visibility.Visible;
                NavActorMgmt.Visibility = Visibility.Visible;
                //NavAdminBookingMgmt.Visibility = Visibility.Visible; // Nút quản lý đơn hàng
            }
            else if (user.Role == "Nhân viên")
            {
                NavSellTicket.Visibility = Visibility.Visible;
                NavStaffBookingMgmt.Visibility = Visibility.Visible;
            }
        }

        private void AttachClickEvents()
        {
            // === Nhóm Admin ===
            NavDashboard.Click += (s, e) => MainContentFrame.Navigate(_dashboardPage);
            NavGenreMgmt.Click += (s, e) => MainContentFrame.Navigate(_genreManagementPage);
            NavShowMgmt.Click += (s, e) => MainContentFrame.Navigate(_showManagementPage);
            NavTheaterMgmt.Click += (s, e) => MainContentFrame.Navigate(_theaterSeatPage);
            NavPerformanceMgmt.Click += (s, e) => MainContentFrame.Navigate(_performancePage);
            NavAccountMgmt.Click += (s, e) => MainContentFrame.Navigate(_accountPage);
            NavActorMgmt.Click += (s, e) => MainContentFrame.Navigate(new ActorManagementPage());

            // === Nhóm Nhân viên ===
            NavSellTicket.Click += (s, e) => MainContentFrame.Navigate(_sellTicketPage);
            NavStaffBookingMgmt.Click += (s, e) => MainContentFrame.Navigate(_bookingPage);

            // === Nhóm Chung ===
            NavProfile.Click += (s, e) => MainContentFrame.Navigate(_profilePage);
            NavLogout.Click += NavLogout_Click;
        }

        private void NavLogout_Click(object sender, RoutedEventArgs e)
        {
            AuthSession.Logout();
            LoginWindow loginWindow = new LoginWindow();
            loginWindow.Show();
            this.Close();
        }
    }
}