using StageX_DesktopApp.Models; // <-- Thêm để dùng User và AuthSession
using System.Windows;
using System.Windows.Controls; // <-- Thêm để dùng Page

namespace StageX_DesktopApp
{
    public partial class MainWindow : Window
    {
        // Ghi chú: Khai báo các trang (Pages)
        // (Sẽ báo lỗi đỏ cho đến khi chúng ta tạo các file này)
        private GenreManagementPage _genreManagementPage;
        private ShowManagementPage _showManagementPage;
        private ProfilePage _profilePage;
        private SeatCategoryPage _seatCategoryPage;
        private TheaterSeatPage _theaterSeatPage;

        public MainWindow()
        {
            InitializeComponent();

            // Ghi chú: Khởi tạo các trang
            //(Tạm thời vô hiệu hóa cho đến khi tạo file)
             _genreManagementPage = new GenreManagementPage();
            _showManagementPage = new ShowManagementPage();
            _profilePage = new ProfilePage();
            _seatCategoryPage = new SeatCategoryPage();
            _theaterSeatPage = new TheaterSeatPage();

            // Chạy hàm phân quyền (ẩn/hiện nút)
            LoadUserInfo();

            // Gắn sự kiện Click cho các nút
            AttachClickEvents();

            // Tải trang mặc định
            if (AuthSession.CurrentUser?.Role == "Admin")
            {
                // Tạm thời vô hiệu hóa
                // MainContentFrame.Navigate(_genreManagementPage); 
            }
        }

        /// <summary>
        /// Ghi chú: Hàm này ẩn/hiện các nút trên menu
        /// dựa theo vai trò (Role) của User
        /// </summary>
        private void LoadUserInfo()
        {
            if (AuthSession.CurrentUser == null)
            {
                MessageBox.Show("Phiên đăng nhập không hợp lệ!");
                // Mở lại LoginWindow khi có lỗi
                LoginWindow loginWindow = new LoginWindow();
                loginWindow.Show();
                this.Close();
                return;
            }

            var user = AuthSession.CurrentUser;
            this.Title = $"StageX - Đã đăng nhập: {user.AccountName} ({user.Role})";

            // --- 1. Ẩn TẤT CẢ các nút nghiệp vụ ---
            NavDashboard.Visibility = Visibility.Collapsed;
            NavAdminBookingMgmt.Visibility = Visibility.Collapsed;
            NavGenreMgmt.Visibility = Visibility.Collapsed;
            NavShowMgmt.Visibility = Visibility.Collapsed;
            NavTheaterMgmt.Visibility = Visibility.Collapsed;
            NavPerformanceMgmt.Visibility = Visibility.Collapsed;
            NavAccountMgmt.Visibility = Visibility.Collapsed;
            NavSellTicket.Visibility = Visibility.Collapsed;
            NavStaffBookingMgmt.Visibility = Visibility.Collapsed;



            // --- 2. Hiện các nút dựa trên vai trò ---
            if (user.Role == "Admin")
            {
                // Hiện các nút Admin
                NavDashboard.Visibility = Visibility.Visible;
                NavAdminBookingMgmt.Visibility = Visibility.Visible;
                NavGenreMgmt.Visibility = Visibility.Visible;
                NavShowMgmt.Visibility = Visibility.Visible;
                NavTheaterMgmt.Visibility = Visibility.Visible;
                NavPerformanceMgmt.Visibility = Visibility.Visible;
                NavAccountMgmt.Visibility = Visibility.Visible;
            }
            else if (user.Role == "Nhân viên")
            {
                // Hiện các nút Nhân viên
                NavSellTicket.Visibility = Visibility.Visible;
                NavStaffBookingMgmt.Visibility = Visibility.Visible;
            }
        }

        /// <summary>
        /// Ghi chú: Hàm này gán sự kiện "Click" cho các nút
        /// </summary>
        private void AttachClickEvents()
        {
            // === Nhóm Admin ===
            NavDashboard.Click += (s, e) => MessageBox.Show("Sẽ mở trang Dashboard...");
            NavAdminBookingMgmt.Click += (s, e) => MessageBox.Show("Sẽ mở trang Tra cứu Đơn hàng (Admin)...");
            //(Vô hiệu hóa 2 dòng này cho đến khi tạo Page)
            NavGenreMgmt.Click += (s, e) => MainContentFrame.Navigate(_genreManagementPage);
            NavShowMgmt.Click += (s, e) => MainContentFrame.Navigate(_showManagementPage);
            NavTheaterMgmt.Click += (s, e) => MessageBox.Show("Sẽ mở trang Quản lý Rạp/Ghế...");
            NavPerformanceMgmt.Click += (s, e) => MessageBox.Show("Sẽ mở trang Quản lý Suất diễn...");
            NavAccountMgmt.Click += (s, e) => MessageBox.Show("Sẽ mở trang Quản lý Tài khoản...");
            NavTheaterMgmt.Click += (s, e) => MainContentFrame.Navigate(_theaterSeatPage);

            // === Nhóm Nhân viên ===
            NavSellTicket.Click += (s, e) => MessageBox.Show("Sẽ mở trang Bán vé...");
            NavStaffBookingMgmt.Click += (s, e) => MessageBox.Show("Sẽ mở trang QL Đơn hàng (Nhân viên)...");

            // === Nhóm Chung ===
            // (Vô hiệu hóa dòng này cho đến khi tạo Page)
            NavProfile.Click += (s, e) => MainContentFrame.Navigate(_profilePage);
            NavLogout.Click += NavLogout_Click;
        }

        /// <summary>
        /// Ghi chú: Xử lý sự kiện nhấn nút Đăng xuất
        /// </summary>
        private void NavLogout_Click(object sender, RoutedEventArgs e)
        {
            AuthSession.Logout();
            LoginWindow loginWindow = new LoginWindow();
            loginWindow.Show();
            this.Close();
        }
    }
}