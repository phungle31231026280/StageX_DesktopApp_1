using Microsoft.EntityFrameworkCore;
using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace StageX_DesktopApp
{
    /// <summary>
    /// Code-behind cho trang Bán vé. Trang này cho phép nhân viên chọn vở diễn, suất chiếu,
    /// chọn ghế trực quan trên sơ đồ và thực hiện thanh toán.
    /// </summary>
    public partial class SellTicketPage : Page
    {
        // Vở diễn và suất chiếu đang được chọn
        private ShowInfo? selectedShow;
        private PerformanceInfo? selectedPerformance;
        // Danh sách ghế trống trả về từ DB
        private List<AvailableSeat> seatList = new();
        // Danh sách ghế đã chọn để tính tiền
        private ObservableCollection<BillSeat> billSeats = new();

        public SellTicketPage()
        {
            InitializeComponent();
            BillGrid.ItemsSource = billSeats;
        }

        /// <summary>
        /// Sự kiện trang được tải: nạp danh sách vở diễn và cập nhật panel thanh toán.
        /// </summary>
        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadShowsAsync();
            UpdatePaymentVisibility();
        }

        /// <summary>
        /// Nạp danh sách vở diễn đang mở bán bằng stored procedure.
        /// </summary>
        private async Task LoadShowsAsync()
        {
            using var context = new AppDbContext();
            var shows = await context.ShowInfos.FromSqlRaw("CALL proc_active_shows()").ToListAsync();
            ShowComboBox.ItemsSource = shows;
        }

        /// <summary>
        /// Khi chọn vở diễn: xoá thông tin cũ, đặt SelectedShowText và nạp danh sách suất chiếu.
        /// </summary>
        private async void ShowComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            selectedShow = ShowComboBox.SelectedItem as ShowInfo;
            SelectedShowText.Text = selectedShow != null ? $"Vở diễn: {selectedShow.title}" : string.Empty;
            // Xoá dữ liệu cũ
            PerformanceComboBox.ItemsSource = null;
            selectedPerformance = null;
            SelectedPerformanceText.Text = string.Empty;
            seatList.Clear();
            billSeats.Clear();
            BuildSeatMap();
            UpdateTotal();
            if (selectedShow == null) return;
            using var context = new AppDbContext();
            var performances = await context.PerformanceInfos.FromSqlRaw($"CALL proc_performances_by_show({selectedShow.show_id})").ToListAsync();
            PerformanceComboBox.ItemsSource = performances;
        }

        /// <summary>
        /// Khi chọn suất chiếu: xoá thông tin cũ, đặt SelectedPerformanceText, nạp danh sách ghế trống.
        /// </summary>
        private async void PerformanceComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            selectedPerformance = PerformanceComboBox.SelectedItem as PerformanceInfo;
            SelectedPerformanceText.Text = selectedPerformance != null ? $"Suất chiếu: {selectedPerformance.Display}" : string.Empty;
            billSeats.Clear();
            seatList.Clear();
            BuildSeatMap();
            UpdateTotal();
            if (selectedPerformance == null) return;
            using var context = new AppDbContext();
            seatList = await context.AvailableSeats.FromSqlRaw($"CALL proc_available_seats({selectedPerformance.performance_id})").ToListAsync();
            BuildSeatMap();
        }

        /// <summary>
        /// Xây dựng sơ đồ ghế theo seatList. Mỗi ghế là một Button, click để chọn/bỏ chọn.
        /// </summary>
        private void BuildSeatMap()
        {
            SeatMapGrid.Children.Clear();
            SeatMapGrid.RowDefinitions.Clear();
            SeatMapGrid.ColumnDefinitions.Clear();
            if (seatList == null || seatList.Count == 0)
            {
                return;
            }
            var rows = seatList.Select(s => s.row_char).Distinct().OrderBy(c => c).ToList();
            var cols = seatList.Select(s => s.seat_number).Distinct().OrderBy(n => n).ToList();
            foreach (var _ in rows)
            {
                SeatMapGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            }
            foreach (var _ in cols)
            {
                SeatMapGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(35) });
            }

            // Bản đồ màu cho từng hạng ghế (A, B, C). Sử dụng màu sáng để dễ phân biệt.
            var categoryColors = new Dictionary<string, Color>(StringComparer.OrdinalIgnoreCase)
            {
                { "A", Color.FromRgb(33, 150, 243) },   // Màu xanh dương
                { "B", Color.FromRgb(76, 175, 80) },    // Màu xanh lá
                { "C", Color.FromRgb(103, 58, 183) }    // Màu tím
            };

            foreach (var seat in seatList)
            {
                int rowIndex = rows.IndexOf(seat.row_char);
                int colIndex = cols.IndexOf(seat.seat_number);
                var btn = new Button
                {
                    Content = seat.SeatLabel,
                    Tag = seat,
                    Width = 35,
                    Height = 35,
                    Margin = new Thickness(2),
                    // Màu nền theo hạng ghế; nếu không xác định thì dùng màu tối mặc định
                    Background = new SolidColorBrush(
                        categoryColors.TryGetValue(seat.category_name?.Trim() ?? string.Empty, out var col)
                            ? col
                            : Color.FromRgb(30, 40, 60)),
                    Foreground = Brushes.White,
                    BorderThickness = new Thickness(1),
                    BorderBrush = Brushes.Transparent
                };
                btn.Click += SeatButton_Click;
                Grid.SetRow(btn, rowIndex);
                Grid.SetColumn(btn, colIndex);
                SeatMapGrid.Children.Add(btn);
            }
        }

        /// <summary>
        /// Khi click vào ghế: chọn hoặc bỏ chọn ghế khỏi billSeats và đổi màu.
        /// </summary>
        private void SeatButton_Click(object sender, RoutedEventArgs e)
        {
            if (selectedShow == null || selectedPerformance == null) return;
            if (sender is not Button btn) return;
            if (btn.Tag is not AvailableSeat seat) return;
            var existing = billSeats.FirstOrDefault(x => x.seat_id == seat.seat_id);
            if (existing != null)
            {
                billSeats.Remove(existing);
                // Bỏ chọn: trả lại viền trong suốt
                btn.BorderBrush = Brushes.Transparent;
                btn.BorderThickness = new Thickness(1);
            }
            else
            {
                billSeats.Add(new BillSeat
                {
                    seat_id = seat.seat_id,
                    SeatLabel = seat.SeatLabel,
                    Price = seat.base_price
                });
                // Chọn: tô viền nổi bật (giữ nguyên màu nền)
                btn.BorderBrush = new SolidColorBrush(Color.FromRgb(255, 193, 7));
                btn.BorderThickness = new Thickness(2);
            }
            UpdateTotal();
        }

        /// <summary>
        /// Cập nhật tổng tiền và tiền thừa khi có thay đổi trong billSeats hoặc input tiền mặt.
        /// </summary>
        private void UpdateTotal()
        {
            decimal total = billSeats.Sum(x => x.Price);
            TotalTextBlock.Text = $"Thành tiền: {total:N0}đ";
            if (CashPanel.Visibility == Visibility.Visible && decimal.TryParse(CustomerCashTextBox.Text, out decimal given))
            {
                decimal change = given - total;
                ChangeTextBlock.Text = change >= 0 ? $"{change:N0}đ" : $"-{Math.Abs(change):N0}đ";
            }
            else
            {
                ChangeTextBlock.Text = "0đ";
            }
        }

        /// <summary>
        /// Xử lý khi thay đổi phương thức thanh toán.
        /// </summary>
        private void PaymentRadioButton_Checked(object sender, RoutedEventArgs e)
        {
            UpdatePaymentVisibility();
        }

        /// <summary>
        /// Hiển thị panel tiền mặt nếu chọn Tiền mặt, ẩn khi chọn Chuyển khoản.
        /// </summary>
        private void UpdatePaymentVisibility()
        {
            if (CashPanel == null) return;
            if (CashRadioButton.IsChecked == true)
            {
                CashPanel.Visibility = Visibility.Visible;
            }
            else
            {
                CashPanel.Visibility = Visibility.Collapsed;
                ChangeTextBlock.Text = "0đ";
            }
        }

        /// <summary>
        /// Khi thay đổi số tiền khách đưa: cập nhật tiền thừa.
        /// </summary>
        private void CustomerCashTextBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            UpdateTotal();
        }

        /// <summary>
        /// Lưu đơn hàng và thanh toán. Gọi các thủ tục để tạo booking, payment và ticket.
        /// </summary>
        private async void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            if (selectedShow == null)
            {
                MessageBox.Show("Vui lòng chọn vở diễn.");
                return;
            }
            if (selectedPerformance == null)
            {
                MessageBox.Show("Vui lòng chọn suất chiếu.");
                return;
            }
            if (billSeats.Count == 0)
            {
                MessageBox.Show("Vui lòng chọn ít nhất một ghế.");
                return;
            }
            decimal total = billSeats.Sum(x => x.Price);
            string paymentMethod = CashRadioButton.IsChecked == true ? "Tiền mặt" : "Chuyển khoản";
            if (paymentMethod == "Tiền mặt")
            {
                if (!decimal.TryParse(CustomerCashTextBox.Text, out decimal given) || given < total)
                {
                    MessageBox.Show("Số tiền khách đưa không đủ.");
                    return;
                }
            }
            try
            {
                using var context = new AppDbContext();
                int userId = AuthSession.CurrentUser?.UserId ?? 0;
                // tạo đơn hàng POS
                var results = await context.CreateBookingResults.FromSqlRaw($"CALL proc_create_booking_pos({userId}, {selectedPerformance.performance_id}, {total})").ToListAsync();
                int bookingId = results.FirstOrDefault()?.booking_id ?? 0;
                if (bookingId <= 0)
                {
                    MessageBox.Show("Không thể tạo đơn hàng.");
                    return;
                }
                // tạo payment
                await context.Database.ExecuteSqlRawAsync($"CALL proc_create_payment({bookingId}, {total}, 'Thành công', '', '{paymentMethod}')");
                // tạo vé cho từng ghế
                foreach (var item in billSeats)
                {
                    string code = Guid.NewGuid().ToString().Substring(0, 8).ToUpper();
                    await context.Database.ExecuteSqlRawAsync($"CALL proc_create_ticket({bookingId}, {item.seat_id}, '{code}')");
                }
                MessageBox.Show("Đã lưu đơn hàng thành công!");
                // refresh seats of current performance
                PerformanceComboBox_SelectionChanged(null, null);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi lưu đơn hàng: {ex.Message}");
            }
        }

        /// <summary>
        /// Lớp lồng để hiển thị ghế đã chọn trong DataGrid.
        /// </summary>
        private class BillSeat
        {
            public int seat_id { get; set; }
            public string SeatLabel { get; set; } = string.Empty;
            public decimal Price { get; set; }
        }
    }
}