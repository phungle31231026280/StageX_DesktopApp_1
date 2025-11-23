using StageX_DesktopApp.Models;
using System;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore; // <-- Dùng EF Core
using MimeKit;                // Thư viện gửi mail
using MailKit.Net.Smtp;       // MailKit SMTP client
using MailKit.Security;

namespace StageX_DesktopApp
{
    public partial class AccountPage : Page
    {
        public AccountPage()
        {
            InitializeComponent();
        }

        #region SMTP cấu hình và gửi mail

        /// <summary>
        /// Cấu hình SMTP để gửi email thông báo tài khoản mới. Các giá trị này được
        /// thiết lập dựa trên thông tin người dùng cung cấp. Bạn có thể thay đổi
        /// chúng trong file mã nguồn hoặc trích xuất ra tệp cấu hình riêng.
        /// </summary>
        private static class SmtpSettings
        {
            public const string Host = "smtp.gmail.com";
            public const int Port = 587;
            // Tài khoản Gmail sử dụng để xác thực SMTP
            public const string Username = "dtngoc.video@gmail.com";
            // Mật khẩu ứng dụng (không có khoảng trắng) – bạn cần tạo mật khẩu ứng dụng trên Gmail
            public const string Password = "yfdcojadkfblargt";
            // Địa chỉ email và tên hiển thị khi gửi đi
            public const string FromEmail = "no-reply@stagex.local";
            public const string FromName = "StageX";
        }

        /// <summary>
        /// Gửi email thông báo tài khoản mới cho nhân viên. Nội dung bao gồm tên tài khoản
        /// và mật khẩu (chưa mã hoá). Sử dụng MailKit với giao thức TLS trên cổng 587.
        /// Hàm này trả về true nếu gửi thành công, false nếu có lỗi.
        /// </summary>
        /// <param name="toEmail">Địa chỉ email của nhân viên</param>
        /// <param name="accountName">Tên tài khoản</param>
        /// <param name="plainPassword">Mật khẩu gốc (chưa hash)</param>
        private static async Task<bool> SendNewAccountEmail(string toEmail, string accountName, string plainPassword)
        {
            try
            {
                var message = new MimeMessage();
                message.From.Add(new MailboxAddress(SmtpSettings.FromName, SmtpSettings.FromEmail));
                message.To.Add(new MailboxAddress(string.Empty, toEmail));
                message.Subject = "Thông báo tài khoản mới";
                message.Body = new TextPart("plain")
                {
                    Text = $"Bạn đã được StageX cung cấp tài khoản mới,\nTên tài khoản là: {accountName}\nMật khẩu là: {plainPassword}"
                };

                using var client = new SmtpClient();
                await client.ConnectAsync(SmtpSettings.Host, SmtpSettings.Port, SecureSocketOptions.StartTls);
                await client.AuthenticateAsync(SmtpSettings.Username, SmtpSettings.Password);
                await client.SendAsync(message);
                await client.DisconnectAsync(true);
                return true;
            }
            catch (Exception ex)
            {
                return false;
            }
        }

        #endregion

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadAccountsAsync();
            StatusComboBox.SelectedIndex = 0;
        }

        /// <summary>
        /// Ghi chú: Tải danh sách Tài khoản (Chỉ Admin/Nhân viên)
        /// </summary>
        private async Task LoadAccountsAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    // Gọi stored procedure để lấy danh sách tài khoản Admin và Nhân viên
                    var accounts = await context.Users
                                                 .FromSqlRaw("CALL proc_get_admin_staff_users()")
                                                 .ToListAsync();
                    AccountsGrid.ItemsSource = accounts;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải tài khoản: {ex.Message}");
            }
        }

        /// <summary>
        /// Ghi chú: Thêm STT cho bảng
        /// </summary>
        private void AccountsGrid_LoadingRow(object sender, DataGridRowEventArgs e)
        {
            e.Row.Header = (e.Row.GetIndex() + 1).ToString();
        }

        /// <summary>
        /// Ghi chú: Nút "Hủy" hoặc "Làm mới"
        /// </summary>
        private void ClearButton_Click(object sender, RoutedEventArgs e)
        {
            FormTitle.Text = "Thêm tài khoản mới";
            SaveButton.Content = "Thêm tài khoản";
            ClearButton.Visibility = Visibility.Collapsed;

            UserIdTextBox.Text = "";
            AccountNameTextBox.Text = "";
            EmailTextBox.Text = "";
            PasswordBox.Password = "";
            RoleComboBox.SelectedIndex = -1;
            // Khi tạo tài khoản mới, mặc định trạng thái là "hoạt động" và không cho phép sửa
            StatusComboBox.SelectedIndex = 0; // lựa chọn "hoạt động"
            StatusComboBox.IsEnabled = false;

            AccountNameTextBox.IsEnabled = true;
            EmailTextBox.IsEnabled = true;
            PasswordBox.IsEnabled = true;

            AccountsGrid.SelectedItem = null;
        }

        /// <summary>
        /// Ghi chú: Nút "Cập nhật" (trong Bảng)
        /// </summary>
        private void EditButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is User userToEdit)
            {
                // 1. Đổ dữ liệu lên Form
                FormTitle.Text = "Chỉnh sửa tài khoản";
                UserIdTextBox.Text = userToEdit.UserId.ToString();
                AccountNameTextBox.Text = userToEdit.AccountName;
                EmailTextBox.Text = userToEdit.Email;

                //2. Không thể chỉnh sửa email, Tên tài khoản và mật khẩu
                AccountNameTextBox.IsEnabled = false;
                EmailTextBox.IsEnabled = false;
                PasswordBox.IsEnabled = false;

                // 2. Chọn đúng ComboBox
                RoleComboBox.SelectedIndex = (userToEdit.Role == "Admin") ? 1 : 0;
                StatusComboBox.SelectedIndex = (userToEdit.Status == "khóa") ? 1 : 0;

                // Cho phép thay đổi trạng thái khi chỉnh sửa tài khoản
                StatusComboBox.IsEnabled = true;

                // 3. Đổi nút
                SaveButton.Content = "Lưu thay đổi";
                ClearButton.Visibility = Visibility.Visible;
            }
        }

        /// <summary>
        /// Ghi chú: (Dùng tạm) Click vào Bảng cũng là Sửa
        /// </summary>
        private void AccountsGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (AccountsGrid.SelectedItem is User userToEdit)
            {
                // 1. Đổ dữ liệu lên Form
                FormTitle.Text = "Chỉnh sửa tài khoản";
                UserIdTextBox.Text = userToEdit.UserId.ToString();
                AccountNameTextBox.Text = userToEdit.AccountName;
                EmailTextBox.Text = userToEdit.Email;

                //2. Không thể chỉnh sửa email, Tên tài khoản và mật khẩu
                AccountNameTextBox.IsEnabled = false;
                EmailTextBox.IsEnabled = false;
                PasswordBox.IsEnabled = false;

                // 2. Chọn đúng ComboBox
                RoleComboBox.SelectedIndex = (userToEdit.Role == "Admin") ? 1 : 0;
                StatusComboBox.SelectedIndex = (userToEdit.Status == "khóa") ? 1 : 0;

                // Cho phép thay đổi trạng thái khi chỉnh sửa tài khoản
                StatusComboBox.IsEnabled = true;

                // 3. Đổi nút
                SaveButton.Content = "Lưu thay đổi";
                ClearButton.Visibility = Visibility.Visible;
            }
        }


        /// <summary>
        /// Ghi chú: Nút "Lưu" (Xử lý cả Thêm + Sửa)
        /// </summary>
        private async void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            // 1. Lấy dữ liệu
            string accountName = AccountNameTextBox.Text.Trim();
            string email = EmailTextBox.Text.Trim();
            string password = PasswordBox.Password;
            string role = (RoleComboBox.SelectedItem as ComboBoxItem)?.Content.ToString();
            string status = (StatusComboBox.SelectedItem as ComboBoxItem)?.Content.ToString();

            // 2. Kiểm tra (Validate)
            if (string.IsNullOrEmpty(accountName) || string.IsNullOrEmpty(email) ||
                string.IsNullOrEmpty(role) || string.IsNullOrEmpty(status))
            {
                MessageBox.Show("Vui lòng nhập Tên tài khoản, Email, Vai trò và Trạng thái!");
                return;
            }

            try
            {
                using (var context = new AppDbContext())
                {
                    // Logic SỬA (UPDATE)
                    if (int.TryParse(UserIdTextBox.Text, out int userId) && userId > 0)
                    {
                        var userToUpdate = await context.Users.FindAsync(userId);
                        if (userToUpdate == null) return;

                        // Cập nhật thông tin
                        userToUpdate.AccountName = accountName;
                        userToUpdate.Email = email;
                        userToUpdate.Role = role;
                        userToUpdate.Status = status;

                        // Chỉ cập nhật mật khẩu NẾU người dùng nhập
                        if (!string.IsNullOrEmpty(password))
                        {
                            userToUpdate.PasswordHash = BCrypt.Net.BCrypt.HashPassword(password);
                        }
                    }
                    // Logic THÊM MỚI (ADD)
                    else
                    {
                        // Mặc định trạng thái của tài khoản mới là "hoạt động"
                        status = "hoạt động";
                        StatusComboBox.SelectedIndex = 0;

                        if (string.IsNullOrEmpty(password))
                        {
                            MessageBox.Show("Mật khẩu là bắt buộc khi thêm tài khoản mới!");
                            return;
                        }
                        bool mailSent = await SendNewAccountEmail(email, accountName, password);
                        if (!mailSent)
                        {
                            MessageBox.Show("Không thể gửi email xác thực. Dừng tạo tài khoản.");
                            return;
                        }

                        // Hash mật khẩu mới
                        string newHash = BCrypt.Net.BCrypt.HashPassword(password);

                        var newUser = new User
                        {
                            AccountName = accountName,
                            Email = email,
                            PasswordHash = newHash,
                            Role = role,
                            Status = status,
                            IsVerified = true
                        };
                        context.Users.Add(newUser);
                    }

                    await context.SaveChangesAsync();
                    // Hiển thị thông báo tuỳ theo ngữ cảnh: nếu có UserId thì là cập nhật, ngược lại là thêm mới
                    int parsedId;
                    if (int.TryParse(UserIdTextBox.Text, out parsedId) && parsedId > 0)
                    {
                        MessageBox.Show("Lưu tài khoản thành công!");
                    }
                    else
                    {
                        MessageBox.Show("Tạo tài khoản mới thành công!");
                    }
                }

                // 5. Tải lại Bảng và Làm mới Form
                await LoadAccountsAsync();
                ClearButton_Click(null, null);
            }
            catch (DbUpdateException ex) // Bắt lỗi (ví dụ: Trùng Email)
            {
                MessageBox.Show($"Lỗi khi lưu tài khoản: {ex.InnerException?.Message ?? ex.Message}");
            }
        }

        /// <summary>
        /// Ghi chú: Nút "Xóa"
        /// </summary>
        private async void DeleteButton_Click(object sender, RoutedEventArgs e)
        {
            if ((sender as Button)?.DataContext is User userToDelete)
            {
                // Ngăn người dùng tự xóa chính mình
                if (userToDelete.UserId == AuthSession.CurrentUser.UserId)
                {
                    MessageBox.Show("Bạn không thể tự xóa chính mình!");
                    return;
                }

                var result = MessageBox.Show($"Bạn có chắc muốn xóa tài khoản '{userToDelete.AccountName}'?",
                                             "Xác nhận xóa", MessageBoxButton.YesNo, MessageBoxImage.Warning);

                if (result == MessageBoxResult.Yes)
                {
                    try
                    {
                        using (var context = new AppDbContext())
                        {
                            var userToRemove = new User { UserId = userToDelete.UserId };
                            context.Users.Remove(userToRemove);
                            await context.SaveChangesAsync();
                        }
                        await LoadAccountsAsync();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Lỗi khi xóa: {ex.Message}");
                    }
                }
            }
        }
    }
}