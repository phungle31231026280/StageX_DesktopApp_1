using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json;
using RestSharp;
using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Input;
using System.Windows.Media.Imaging;

namespace StageX_DesktopApp
{
    /// <summary>
    /// Code-behind cho trang Bán vé. Trang này cho phép nhân viên chọn vở diễn, suất chiếu,
    /// chọn ghế trực quan trên sơ đồ và thực hiện thanh toán.
    /// </summary>
    public partial class SellTicketPage : Page
    {
        // Vở diễn đang được chọn (chỉ dùng trong chế độ Mặc định)
        private ShowInfo? selectedShow;
        // Thay thế selectedPerformance bằng các trường cơ bản để dùng cho cả hai chế độ
        // Mã suất đang được chọn và giá cơ bản của suất
        private int? selectedPerformanceId = null;
        private decimal selectedPerformancePrice = 0;
        private string selectedPerformanceDisplay = string.Empty;
        // Danh sách ghế và trạng thái (bao gồm cả ghế đã bán) trả về từ DB
        private List<SeatStatus> seatList = new();
        // Danh sách ghế đã chọn để tính tiền
        private ObservableCollection<BillSeat> billSeats = new();
        private string selectedPaymentMethod = "Tiền mặt";

        // Chế độ bán vé hiện tại (false = Mặc định, true = Giờ cao điểm)
        // Khi ở chế độ Giờ cao điểm, chúng ta ẩn combobox vở diễn và chỉ hiển thị TOP 3 suất diễn gần nhất.
        private bool isPeakMode = false;
        private bool isPageLoaded = false;

        // Biến lưu hệ số phóng to/thu nhỏ của sơ đồ ghế. Giá trị mặc định = 1.0
        private double seatScale = 1.0;

        // Nút TOP suất diễn hiện đang được chọn ở chế độ Giờ cao điểm (dùng để tô viền)
        private Button? selectedPeakButton = null;

        // Danh sách TOP suất diễn được nạp ở chế độ Giờ cao điểm
        private List<PeakPerformanceInfo> _peakPerformances = new();

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
            isPageLoaded = true;
        }

        /// <summary>
        /// Sự kiện thay đổi chế độ bán vé (Mặc định/Giờ cao điểm).
        /// Khi ở chế độ Giờ cao điểm: ẩn phần chọn Vở diễn, nạp TOP 3 suất diễn gần nhất và đặt phương thức thanh toán mặc định là Chuyển khoản.
        /// Khi quay lại Mặc định: hiển thị lại combobox Vở diễn và nạp danh sách vở như bình thường, đồng thời đặt lại phương thức thanh toán là Tiền mặt.
        /// </summary>
        private async void ModeRadio_Checked(object sender, RoutedEventArgs e)
        {
            if (!isPageLoaded) return;
            // xác định chế độ hiện tại dựa vào RadioButton
            isPeakMode = PeakModeRadio.IsChecked == true;
            if (isPeakMode)
            {
                // Ẩn panel vở diễn và panel combobox suất, hiển thị panel top3
                if (ShowPanel != null) ShowPanel.Visibility = Visibility.Collapsed;
                if (PerformancePanel != null) PerformancePanel.Visibility = Visibility.Collapsed;
                if (PeakPerformancePanel != null) PeakPerformancePanel.Visibility = Visibility.Visible;
                // Đặt phương thức thanh toán mặc định là Chuyển khoản (tự động bấm nút Chuyển khoản)
                PaymentButton_Click(BankButton, null);
                // Đặt lại nút đã chọn trong chế độ Giờ cao điểm
                selectedPeakButton = null;
                // Nạp TOP 3 suất diễn gần nhất
                await LoadTopPerformancesAsync();
                SeatLegendPanel.Visibility = Visibility.Collapsed;
                SeatLegendPanel.Children.Clear();
                // Làm sạch QR và ô nhập tiền mặt
                CustomerCashTextBox.Text = string.Empty;
                ChangeTextBlock.Text = "0đ";
                QrImage.Source = null;
            }
            else
            {
                // Hiện panel chọn vở diễn và combobox suất, ẩn panel top3
                if (ShowPanel != null) ShowPanel.Visibility = Visibility.Visible;
                if (PerformancePanel != null) PerformancePanel.Visibility = Visibility.Visible;
                if (PeakPerformancePanel != null) PeakPerformancePanel.Visibility = Visibility.Collapsed;
                // Đặt phương thức thanh toán mặc định là Tiền mặt (tự động bấm nút Tiền mặt)
                PaymentButton_Click(CashButton, null);
                // Xóa lựa chọn vở diễn và suất chiếu, làm sạch sơ đồ và hoá đơn
                selectedPeakButton = null;
                selectedShow = null;
                selectedPerformanceId = null;
                selectedPerformanceDisplay = string.Empty;
                selectedPerformancePrice = 0;
                ShowComboBox.SelectedItem = null;
                PerformanceComboBox.ItemsSource = null;
                SelectedShowText.Text = string.Empty;
                SelectedPerformanceText.Text = string.Empty;
                seatList.Clear();
                billSeats.Clear();
                BuildSeatMap();
                UpdateTotal();
                // Xoá dữ liệu nhập tiền mặt và QR
                CustomerCashTextBox.Text = string.Empty;
                ChangeTextBlock.Text = "0đ";
                QrImage.Source = null;
                // Nạp danh sách vở diễn như bình thường
                await LoadShowsAsync();
            }
        }

        /// <summary>
        /// Nạp TOP 3 suất diễn gần nhất cho chế độ Giờ cao điểm.
        /// Hàm này sẽ gọi stored procedure proc_top3_nearest_performances, thiết lập lại các lựa chọn và làm sạch sơ đồ ghế và bill.
        /// </summary>
        private async Task LoadTopPerformancesAsync()
        {
            // Hàm này nạp TOP 3 suất diễn gần nhất, bao gồm tên vở diễn và thông tin vé. Sau đó gán cho các button trong PeakPerformancePanel.
            using var context = new AppDbContext();
            try
            {
                var performances = await context.PeakPerformanceInfos.FromSqlRaw("CALL proc_top3_nearest_performances_extended()").ToListAsync();
                // Đảm bảo có đúng 3 phần tử (nếu ít hơn thì thêm phần tử rỗng)
                while (performances.Count < 3)
                {
                    performances.Add(new PeakPerformanceInfo());
                }
                // Lưu trữ danh sách này để sử dụng khi click
                _peakPerformances = performances;
                // Gán nội dung và trạng thái cho từng nút
                var buttons = new[] { PeakButton1, PeakButton2, PeakButton3 };
                for (int i = 0; i < buttons.Length; i++)
                {
                    var perf = performances[i];
                    var btn = buttons[i];
                    if (perf.performance_id == 0)
                    {
                        // Nếu không có đủ suất, ẩn nút
                        btn.Visibility = Visibility.Collapsed;
                        continue;
                    }
                    btn.Visibility = Visibility.Visible;
                    btn.Content = perf.Display;
                    btn.Tag = perf;
                    // Nếu suất đã bán hết vé thì vô hiệu hóa
                    btn.IsEnabled = !perf.IsSoldOut;
                    // Màu sắc: nếu sold out thì xám, ngược lại nền xanh dương
                    if (perf.IsSoldOut)
                    {
                        btn.Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(80, 80, 80));
                    }
                    else
                    {
                        btn.Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(33, 150, 243));
                    }
                    // Viền mặc định: sử dụng màu vàng và độ dày 1
                    btn.BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromRgb(255, 193, 7));
                    btn.BorderThickness = new Thickness(1);
                    btn.Foreground = Brushes.White;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi nạp suất diễn: {ex.Message}");
            }

            // Đặt lại lựa chọn vở diễn và suất diễn
            selectedShow = null;
            selectedPerformanceId = null;
            selectedPerformanceDisplay = string.Empty;
            selectedPerformancePrice = 0;
            ShowComboBox.ItemsSource = null;
            SelectedShowText.Text = string.Empty;
            SelectedPerformanceText.Text = string.Empty;
            // Xoá danh sách ghế và bill
            seatList.Clear();
            billSeats.Clear();
            BuildSeatMap();
            UpdateTotal();
        }

        /// <summary>
        /// Xử lý click vào một trong ba nút suất diễn ở chế độ Giờ cao điểm. Khi click,
        /// gán performance được chọn, cập nhật thông tin hiển thị và nạp sơ đồ ghế.
        /// </summary>
        private async void PeakPerformanceButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender is not Button btn) return;
            // Mỗi Button chứa một đối tượng PeakPerformanceInfo ở thuộc tính Tag
            if (btn.Tag is not PeakPerformanceInfo perf) return;
            // Nếu suất đã bán hết vé thì không xử lý gì thêm
            if (perf.IsSoldOut) return;

            // Tô viền đậm cho nút được chọn và trả viền mỏng cho nút trước đó
            if (selectedPeakButton != null)
            {
                selectedPeakButton.BorderThickness = new Thickness(1);
            }
            btn.BorderThickness = new Thickness(3);
            selectedPeakButton = btn;

            // Gán thông tin suất chọn
            selectedPerformanceId = perf.performance_id;
            selectedPerformancePrice = perf.price;
            selectedPerformanceDisplay = perf.Display;

            // Hiển thị lại thông tin vở diễn và suất diễn ở khu vực 3
            SelectedShowText.Text = $"Vở diễn: {perf.show_title}";
            SelectedPerformanceText.Text = $"Suất chiếu: {selectedPerformanceDisplay}";

            // Xóa bill cũ và danh sách ghế
            billSeats.Clear();
            seatList.Clear();
            BuildSeatMap();
            UpdateTotal();

            // Nạp lại ghế cho suất vừa chọn
            if (selectedPerformanceId != null)
            {
                await LoadSeatsAsync(selectedPerformanceId.Value);
                SeatLegendPanel.Visibility = Visibility.Visible;
                await LoadSeatLegendAsync();
            }
        }

        /// <summary>
        /// Nạp danh sách ghế và trạng thái (đã bán/chưa bán) cho suất diễn. Dùng chung cho mọi chế độ.
        /// </summary>
        private async Task LoadSeatsAsync(int performanceId)
        {
            using var context = new AppDbContext();
            try
            {
                seatList = await context.SeatStatuses
                                        .FromSqlInterpolated($"CALL proc_seats_with_status({performanceId})")
                                        .ToListAsync();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi nạp ghế: {ex.Message}");
            }
            BuildSeatMap();
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
        private async Task LoadSeatLegendAsync()
        {
            SeatLegendPanel.Children.Clear();
            SeatLegendPanel.Visibility = Visibility.Collapsed;

            if (selectedPerformanceId == null)
                return;

            using (var context = new AppDbContext())
            {
                // Lấy theater_id của suất diễn
                var perf = await context.Performances
                    .Where(p => p.PerformanceId == selectedPerformanceId)
                    .Select(p => p.TheaterId)
                    .FirstOrDefaultAsync();

                if (perf == 0)
                    return;

                int theaterId = perf;

                // Lấy danh sách category thực sự có ghế trong rạp đó
                var categories = await context.Seats
                    .Where(s => s.TheaterId == theaterId)
                    .Include(s => s.SeatCategory)
                    .Select(s => s.SeatCategory)
                    .Distinct()
                    .OrderBy(c => c.CategoryName)
                    .ToListAsync();

                if (categories.Count == 0)
                    return;

                SeatLegendPanel.Visibility = Visibility.Visible;

                foreach (var cat in categories)
                {
                    var panel = new StackPanel
                    {
                        Orientation = Orientation.Horizontal,
                        Margin = new Thickness(10, 0, 10, 0),
                        VerticalAlignment = VerticalAlignment.Center
                    };

                    // Ô màu – dùng DisplayColor (đã xử lý # + fallback)
                    var rect = new Border
                    {
                        Width = 22,
                        Height = 22,
                        CornerRadius = new CornerRadius(4),
                        Background = cat.DisplayColor,
                        BorderBrush = Brushes.White,
                        BorderThickness = new Thickness(1),
                        Margin = new Thickness(0, 0, 5, 0)
                    };

                    var text = new TextBlock
                    {
                        Text = $"{cat.CategoryName} (+{cat.BasePrice:N0}đ)",
                        VerticalAlignment = VerticalAlignment.Center
                    };

                    panel.Children.Add(rect);
                    panel.Children.Add(text);

                    SeatLegendPanel.Children.Add(panel);
                }
            }
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
            // Xóa thông tin suất diễn đang chọn
            selectedPerformanceId = null;
            selectedPerformancePrice = 0;
            selectedPerformanceDisplay = string.Empty;
            SelectedPerformanceText.Text = string.Empty;
            seatList.Clear();
            billSeats.Clear();
            BuildSeatMap();
            UpdateTotal();
            SeatLegendPanel.Visibility = Visibility.Collapsed;
            SeatLegendPanel.Children.Clear();
            if (selectedShow == null) return;
            using var context = new AppDbContext();
            // Gọi stored procedure với tham số thông qua FromSqlInterpolated để tránh SQL injection
            var performances = await context.PerformanceInfos
                                           .FromSqlInterpolated($"CALL proc_performances_by_show({selectedShow.show_id})")
                                           .ToListAsync();
            PerformanceComboBox.ItemsSource = performances;
        }

        /// <summary>
        /// Khi chọn suất chiếu: xoá thông tin cũ, đặt SelectedPerformanceText, nạp danh sách ghế trống.
        /// </summary>
        private async void PerformanceComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            var perf = PerformanceComboBox.SelectedItem as PerformanceInfo;
            // Thiết lập thông tin suất diễn được chọn
            if (perf != null)
            {
                selectedPerformanceId = perf.performance_id;
                selectedPerformancePrice = perf.price;
                selectedPerformanceDisplay = perf.Display;
            }
            else
            {
                selectedPerformanceId = null;
                selectedPerformancePrice = 0;
                selectedPerformanceDisplay = string.Empty;
            }
            SelectedPerformanceText.Text = selectedPerformanceId != null ? $"Suất chiếu: {selectedPerformanceDisplay}" : string.Empty;
            // Xóa ghế và bill cũ
            billSeats.Clear();
            seatList.Clear();
            BuildSeatMap();
            UpdateTotal();
            if (selectedPerformanceId == null) return;
            // Nạp sơ đồ ghế đầy đủ (kể cả ghế đã bán)
            await LoadSeatsAsync(selectedPerformanceId.Value);
            SeatLegendPanel.Visibility = Visibility.Visible;
            await LoadSeatLegendAsync();
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

            // Không dùng bản đồ màu cố định nữa. Màu ghế sẽ dựa trên trường color_class trả về từ CSDL.
            // Nếu color_class rỗng hoặc null, sẽ dùng màu mặc định tối.

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
                    Foreground = Brushes.White,
                    BorderThickness = new Thickness(1),
                    BorderBrush = Brushes.Transparent
                };
                // Đặt nền và trạng thái tùy theo ghế đã bán hay chưa
                if (seat.is_sold)
                {
                    // Ghế đã bán: tô xám và vô hiệu hóa
                    btn.Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(100, 100, 100));
                    btn.IsEnabled = false;
                    btn.ToolTip = "Ghế đã bán";
                }
                else
                {
                    // Ghế còn trống: màu theo mã color_class (hex) hoặc màu mặc định nếu không có thông tin
                    if (!string.IsNullOrWhiteSpace(seat.color_class))
                    {
                        try
                        {
                            // Thêm dấu # để tạo mã màu hợp lệ WPF
                            var brush = (SolidColorBrush)new BrushConverter().ConvertFrom($"#{seat.color_class.Trim()}");
                            btn.Background = brush;
                        }
                        catch
                        {
                            btn.Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(30, 40, 60));
                        }
                    }
                    else
                    {
                        btn.Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(30, 40, 60));
                    }
                    btn.IsEnabled = true;
                    btn.ToolTip = $"{seat.category_name}(+{seat.base_price:N0}đ)";
                }
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
            // Không yêu cầu selectedShow; chỉ cần có suất đã chọn
            if (selectedPerformanceId == null) return;
            if (sender is not Button btn) return;
            if (btn.Tag is not SeatStatus seat) return;
            var existing = billSeats.FirstOrDefault(x => x.seat_id == seat.seat_id);
            if (existing != null)
            {
                // Ghế đang được chọn, bỏ chọn
                billSeats.Remove(existing);
                btn.BorderBrush = Brushes.Transparent;
                btn.BorderThickness = new Thickness(1);
            }
            else
            {
                // Ghế chưa chọn, thêm vào bill
                billSeats.Add(new BillSeat
                {
                    seat_id = seat.seat_id,
                    SeatLabel = seat.SeatLabel,
                    Price = seat.base_price + selectedPerformancePrice
                });
                // Tô viền nổi bật
                btn.BorderBrush = new SolidColorBrush(System.Windows.Media.Color.FromRgb(255, 193, 7));
                btn.BorderThickness = new Thickness(2);
            }
            UpdateTotal();
        }

        /// <summary>
        /// Xử lý sự kiện cuộn chuột trên ScrollViewer của sơ đồ ghế để phóng to/thu nhỏ. Khi cuộn lên sẽ tăng
        /// độ zoom, cuộn xuống sẽ giảm. Giới hạn từ 0.5x tới 3x. Thiết lập LayoutTransform của SeatMapGrid.
        /// </summary>
        private void SeatScrollViewer_PreviewMouseWheel(object sender, MouseWheelEventArgs e)
        {
            // Điều chỉnh tỉ lệ zoom mỗi lần cuộn khoảng 10%
            double factor = e.Delta > 0 ? 1.1 : 0.9;
            seatScale *= factor;
            // Giới hạn thu phóng
            if (seatScale < 0.5) seatScale = 0.5;
            if (seatScale > 3.0) seatScale = 3.0;
            // Áp dụng scale cho lưới ghế
            SeatMapGrid.LayoutTransform = new ScaleTransform(seatScale, seatScale);
            e.Handled = true;
        }

        /// <summary>
        /// Cập nhật tổng tiền và tiền thừa khi có thay đổi trong billSeats hoặc input tiền mặt.
        /// </summary>
        private void UpdateTotal()
        {
            decimal total = billSeats.Sum(x => x.Price);
            TotalTextBlock.Text = $"Thành tiền: {total:N0}đ";

            if (selectedPaymentMethod == "Tiền mặt" && decimal.TryParse(CustomerCashTextBox.Text, out decimal given))
            {
                decimal change = given - total;
                ChangeTextBlock.Text = change >= 0 ? $"{change:N0}đ" : $"-{Math.Abs(change):N0}đ";
            }
            else
            {
                ChangeTextBlock.Text = "0đ";
            }

            // Nếu chọn Chuyển khoản và có tổng tiền > 0, tạo QR
            if (selectedPaymentMethod == "Chuyển khoản" && total > 0)
            {
                GenerateQrCode((int)total);
            }
            else if (selectedPaymentMethod == "Chuyển khoản" && total <= 0)
            {
                // Khi không có tổng tiền, xoá mã QR cũ để tránh hiển thị sai
                QrImage.Source = null;
            }
        }
        private void GenerateQrCode(int amount)
        {
            // Hardcode thông tin tài khoản nhận tiền của bạn (thay đổi giá trị này)
            string accountNo = "1010101010"; // Ví dụ: "123456789"
            string accountName = "NGUYEN VAN A"; // Ví dụ: "NGUYEN VAN A"
            int acqId = 970436; // Vietcombank/...
            string addInfo = $"Thanh toan ve kich STAGEX"; // Nội dung chuyển khoản (có thể thay đổi)

            var apiRequest = new APIRequest
            {
                acqId = acqId,
                accountNo = accountNo,
                accountName = accountName,
                amount = amount,
                addInfo = addInfo,
                template = "compact2"
            };

            var jsonRequest = JsonConvert.SerializeObject(apiRequest);

            var client = new RestClient("https://api.vietqr.io/v2/generate");
            var request = new RestRequest("", RestSharp.Method.Post);
            request.AddHeader("Accept", "application/json");
            request.AddParameter("application/json", jsonRequest, ParameterType.RequestBody);

            try
            {
                RestResponse response = client.Execute(request);
                if (response != null && response.IsSuccessful)
                {
                    var dataResult = JsonConvert.DeserializeObject<ApiResponse>(response.Content);
                    string base64 = dataResult.data.qrDataURL.Replace("data:image/png;base64,", "");
                    byte[] imageBytes = Convert.FromBase64String(base64);
                    using (var ms = new MemoryStream(imageBytes))
                    {
                        var bitmap = new BitmapImage();
                        bitmap.BeginInit();
                        bitmap.CacheOption = BitmapCacheOption.OnLoad;
                        bitmap.StreamSource = ms;
                        bitmap.EndInit();
                        QrImage.Source = bitmap;
                    }
                }
                else
                {
                    // Không thể tạo QR do lỗi từ API hoặc không có mạng
                    QrImage.Source = null;
                    MessageBox.Show("Không thể tạo mã QR, vui lòng kiểm tra kết nối mạng.");
                }
            }
            catch (Exception ex)
            {
                // Bắt mọi lỗi bất ngờ (ví dụ không tìm thấy host)
                QrImage.Source = null;
                MessageBox.Show("Không thể tạo mã QR: " + ex.Message);
            }
        }

        private void PaymentButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender is not Button btn) return;

            // Đặt lại BorderThickness của tất cả buttons về mặc định (1) và nền giữ nguyên màu tối
            CashButton.BorderThickness = new Thickness(1);
            BankButton.BorderThickness = new Thickness(1);

            // Tô viền đậm cho button được chọn
            btn.BorderThickness = new Thickness(3);

            // Lưu lại phương thức thanh toán được chọn
            selectedPaymentMethod = btn.Content.ToString();

            // Hiển thị panel tiền mặt hoặc QR tùy theo lựa chọn
            if (selectedPaymentMethod == "Tiền mặt")
            {
                CashPanel.Visibility = Visibility.Visible;
                QrPanel.Visibility = Visibility.Collapsed;
            }
            else // Chuyển khoản
            {
                CashPanel.Visibility = Visibility.Collapsed;
                QrPanel.Visibility = Visibility.Visible;
                UpdateTotal(); // Gọi để tạo QR ngay
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
            // Khi không ở chế độ Giờ cao điểm thì cần chọn vở diễn
            if (!isPeakMode && selectedShow == null)
            {
                MessageBox.Show("Vui lòng chọn vở diễn.");
                return;
            }
            if (selectedPerformanceId == null)
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
            string paymentMethod = selectedPaymentMethod;
            if (paymentMethod == "Tiền mặt")
            {
                // GHI CHÚ: Đảm bảo số tiền khách đưa là số tròn nghìn và đủ để thanh toán
                if (!decimal.TryParse(CustomerCashTextBox.Text, out decimal given))
                {
                    MessageBox.Show("Số tiền khách đưa không hợp lệ.");
                    return;
                }
                // Kiểm tra số tiền có phải là bội số của 1.000 hay không
                if (given % 1000 != 0)
                {
                    MessageBox.Show("Số tiền phải là số tròn nghìn");
                    return;
                }
                if (given < total)
                {
                    MessageBox.Show("Số tiền khách đưa không đủ.");
                    return;
                }
            }
            try
            {
                using var context = new AppDbContext();

                int staffId = AuthSession.CurrentUser?.UserId ?? 0; // the currently logged-in staff
                                                                    // Determine customer id: if the sale is for an online customer, set customerId; 
                                                                    // for offline POS leave null (or 0 -> will be passed as null later)
                int? customerId = null; // for POS offline
                                        // if you have a selected customer, set customerId = selectedCustomer.Id;
                // call stored proc -- pass customerId (nullable), performance id, total, createdBy (staff)
                // we use FromSqlInterpolated; EF will pass null correctly when customerId is null
                var results = await context.CreateBookingResults
                    .FromSqlInterpolated($@"CALL proc_create_booking_pos(
            {customerId}, {selectedPerformanceId}, {total}, {staffId})")
                    .ToListAsync();

                int bookingId = results.FirstOrDefault()?.booking_id ?? 0;
                if (bookingId <= 0)
                {
                    MessageBox.Show("Không thể tạo đơn hàng.");
                    return;
                }

                await context.Database.ExecuteSqlInterpolatedAsync(
                    $"CALL proc_create_payment({bookingId}, {total}, {"Thành công"}, {""}, {paymentMethod})");

                // create ticket per selected seat
                foreach (var item in billSeats)
                {
                    string code = Guid.NewGuid().ToString().Substring(0, 8).ToUpper();
                    await context.Database.ExecuteSqlInterpolatedAsync(
                        $"CALL proc_create_ticket({bookingId}, {item.seat_id}, {code})");
                }

                MessageBox.Show("Đã lưu đơn hàng thành công!");
                // refresh seats for selected performance
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
        public class APIRequest
        {
            public string accountNo { get; set; }
            public string accountName { get; set; }
            public int acqId { get; set; }
            public int amount { get; set; }
            public string addInfo { get; set; }
            public string format { get; set; }
            public string template { get; set; }
        }

        public class Data
        {
            public int acpId { get; set; }
            public string accountName { get; set; }
            public string qrCode { get; set; }
            public string qrDataURL { get; set; }
        }

        public class ApiResponse
        {
            public string code { get; set; }
            public string desc { get; set; }
            public Data data { get; set; }
        }
    }
}