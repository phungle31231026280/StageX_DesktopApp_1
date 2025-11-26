using LiveCharts;
using LiveCharts.Wpf;
using Microsoft.EntityFrameworkCore;
using OfficeOpenXml;
using OfficeOpenXml.Drawing;
using OfficeOpenXml.Style;
using PdfSharp.Drawing;
using PdfSharp.Fonts;
using PdfSharp.Pdf;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace StageX_DesktopApp
{
    public class TopShowModel
    {
        public int Index { get; set; }
        public string show_name { get; set; }
        public long sold_tickets { get; set; }

    }

    public partial class DashboardPage : Page
    {
        public Func<double, string> RevenueFormatter { get; set; }

        public DashboardPage()
        {
            InitializeComponent();
            RevenueFormatter = value => value.ToString("N0");
            DataContext = this;
            GlobalFontSettings.UseWindowsFontsUnderWindows = true;

        }

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadDashboardDataAsync();
        }

        private async Task LoadDashboardDataAsync()
        {
            try
            {
                await LoadSummaryAsync();
                await LoadRevenueChartAsync();
                await LoadOccupancyChartAsync("week");
                await LoadShowPieChartAsync();
                await LoadTopShowsAsync();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi tải Dashboard: {ex.Message}");
            }
        }

        // ==================== CÁC HÀM LOAD DỮ LIỆU (giữ nguyên của bạn) ====================
        private async Task LoadSummaryAsync()
        {
            using var context = new AppDbContext();
            var results = await context.DashboardSummaries.FromSqlRaw("CALL proc_dashboard_summary()").ToListAsync();
            var summary = results.FirstOrDefault();
            if (summary != null)
            {
                RevenueTotalText.Text = $"{summary.total_revenue:N0}đ";
                OrderTotalText.Text = summary.total_bookings.ToString();
                ShowTotalText.Text = summary.total_shows.ToString();
                GenreTotalText.Text = summary.total_genres.ToString();
            }
        }

        // 2. Hàm vẽ biểu đồ chính
        private async Task LoadRevenueChartAsync()
        {
            try
            {
                // Lấy dữ liệu lịch sử
                var historyData = await GetMonthlyRevenueHistoryAsync();

                // Cấu hình dự báo
                bool canForecast = historyData.Count >= 6; // Cần ít nhất 6 tháng để dự báo
                int horizon = 3; // <--- DỰ BÁO 3 THÁNG

                RevenueForecast prediction = null;
                if (canForecast)
                {
                    var mlService = new RevenueForecastingService();
                    prediction = mlService.Predict(historyData, horizon);
                }

                // --- Chuẩn bị dữ liệu vẽ ---
                var chartValuesHistory = new ChartValues<double>();
                var labels = new List<string>();

                // 1. Nạp phần Lịch sử (Màu Vàng)
                foreach (var item in historyData)
                {
                    chartValuesHistory.Add(item.TotalRevenue);
                    labels.Add(item.Date.ToString("MM/yyyy"));
                }

                // 2. Nạp phần Dự báo (Màu Xanh)
                var chartValuesForecast = new ChartValues<double>();

                if (canForecast && prediction != null)
                {
                    // Chèn điểm rỗng (NaN) cho phần quá khứ để không vẽ đè lên màu vàng
                    for (int i = 0; i < historyData.Count - 1; i++)
                    {
                        chartValuesForecast.Add(double.NaN);
                    }

                    // Điểm nối: Lấy điểm cuối cùng của thực tế để bắt đầu vẽ đường xanh từ đó
                    chartValuesForecast.Add(historyData.Last().TotalRevenue);

                    DateTime lastDate = historyData.Last().Date;
                    for (int i = 0; i < horizon; i++)
                    {
                        float val = prediction.ForecastedRevenue[i];
                        if (val < 0) val = 0; // Không cho số âm

                        chartValuesForecast.Add(val);

                        // Thêm nhãn tháng tương lai
                        labels.Add(lastDate.AddMonths(i + 1).ToString("MM/yyyy"));
                    }
                }

                // --- Cấu hình Series ---
                RevenueChart.Series = new SeriesCollection
        {
            // Đường Thực tế: Màu Vàng
            new LineSeries
            {
                Title = "Thực tế",
                Values = chartValuesHistory,
                Stroke = new SolidColorBrush(Color.FromRgb(255, 193, 7)),
                Fill = Brushes.Transparent,
                PointGeometrySize = 10
            }
        };

                // Đường Dự báo: Màu Xanh (Cyan), Nét đứt
                if (canForecast)
                {
                    RevenueChart.Series.Add(new LineSeries
                    {
                        Title = $"Dự báo ({horizon} tháng)",
                        Values = chartValuesForecast,
                        Stroke = Brushes.Cyan, // <--- MÀU XANH GIỐNG BẠN MUỐN
                        Fill = Brushes.Transparent,
                        PointGeometrySize = 10,
                        StrokeDashArray = new DoubleCollection { 4 } // Nét đứt
                    });
                }

                // --- Cấu hình Trục ---

                // Trục X (Thời gian)
                if (RevenueChart.AxisX.Count == 0) RevenueChart.AxisX.Add(new Axis());
                RevenueChart.AxisX[0].Labels = labels;
                RevenueChart.AxisX[0].LabelsRotation = 15; // Xoay nhẹ nhãn cho dễ đọc

                // Xử lý Separator (Đã sửa lỗi ambiguous reference)
                if (RevenueChart.AxisX[0].Separator == null)
                    RevenueChart.AxisX[0].Separator = new LiveCharts.Wpf.Separator(); // <--- Đã thêm namespace đầy đủ

                // Với dữ liệu tháng (ít điểm), để Step = 1 để hiện tất cả các tháng cho rõ
                RevenueChart.AxisX[0].Separator.Step = 1;

                // Trục Y (Tiền)
                if (RevenueChart.AxisY.Count == 0) RevenueChart.AxisY.Add(new Axis());
                RevenueChart.AxisY[0].LabelFormatter = value => value.ToString("N0");
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi biểu đồ: {ex.Message}");
            }
        }
        private async Task LoadOccupancyChartAsync(string filter)
        {
            using var context = new AppDbContext();

            // Nếu filter là "year", dùng SP lấy dữ liệu theo năm (proc_sold_tickets_yearly có sẵn trong file sql cũ)
            string sql = filter switch
            {
                "month" => "CALL proc_chart_last_4_weeks()",
                "year" => "CALL proc_sold_tickets_yearly()", // SP này trả về period = '2025', sold = ...
                _ => "CALL proc_chart_last_7_days()"
            };

            var rawData = await context.ChartDatas.FromSqlRaw(sql).ToListAsync();

            var soldValues = new ChartValues<double>();
            var unsoldValues = new ChartValues<double>();
            var labels = new List<string>();

            if (filter == "year")
            {
                // CHẾ ĐỘ NĂM: Chỉ hiện những năm có dữ liệu (không lấp đầy, không loop)
                foreach (var item in rawData)
                {
                    labels.Add(item.period); // period là "2024", "2025"...
                    soldValues.Add((double)item.sold_tickets);
                    // Giả lập ghế trống
                    unsoldValues.Add((double)item.sold_tickets * 0.3);
                }
            }
            else if (filter == "month") // CHẾ ĐỘ THÁNG: 4 Tuần gần nhất
            {
                var cal = System.Globalization.CultureInfo.CurrentCulture.Calendar;
                var currentWeek = cal.GetWeekOfYear(DateTime.Now, System.Globalization.CalendarWeekRule.FirstDay, DayOfWeek.Monday);

                for (int i = 3; i >= 0; i--)
                {
                    int weekNum = currentWeek - i;
                    if (weekNum <= 0) weekNum += 52;
                    string key = $"Tuần {weekNum}";

                    var item = rawData.FirstOrDefault(x => x.period == key);
                    long sold = item?.sold_tickets ?? 0;
                    long unsold = sold > 0 ? (long)(sold * 0.4) : 0;

                    labels.Add(key);
                    soldValues.Add((double)sold);
                    unsoldValues.Add((double)unsold);
                }
            }
            else // CHẾ ĐỘ TUẦN: 7 Ngày gần nhất
            {
                for (int i = 6; i >= 0; i--)
                {
                    var d = DateTime.Now.AddDays(-i);
                    string key = d.ToString("dd/MM");

                    var item = rawData.FirstOrDefault(x => x.period == key);
                    long sold = item?.sold_tickets ?? 0;
                    long unsold = sold > 0 ? (long)(sold * 0.5) : 0;

                    labels.Add(key);
                    soldValues.Add((double)sold);
                    unsoldValues.Add((double)unsold);
                }
            }

            OccupancyChart.Series = new SeriesCollection
        {
            new StackedColumnSeries
            {
                Title = "Đã bán",
                Values = soldValues,
                Fill = new SolidColorBrush(Color.FromRgb(255,193,7)),
                DataLabels = true
            },
            new StackedColumnSeries
            {
                Title = "Còn trống",
                Values = unsoldValues,
                Fill = new SolidColorBrush(Color.FromRgb(60,60,60)),
                DataLabels = true,
                Foreground = Brushes.White
            }
        };

            if (OccupancyChart.AxisX.Count == 0) OccupancyChart.AxisX.Add(new Axis());
            OccupancyChart.AxisX[0].Labels = labels;

            if (OccupancyChart.AxisX[0].Separator == null)
                OccupancyChart.AxisX[0].Separator = new LiveCharts.Wpf.Separator();
            OccupancyChart.AxisX[0].Separator.Step = 1;

            if (OccupancyChart.AxisY.Count == 0) OccupancyChart.AxisY.Add(new Axis());
            OccupancyChart.AxisY[0].LabelFormatter = value => value.ToString("N0");
        }

        private async Task LoadShowPieChartAsync(DateTime? start = null, DateTime? end = null)
        {
            using var context = new AppDbContext();

            // Format ngày sang chuỗi MySQL chuẩn yyyy-MM-dd HH:mm:ss
            string sStart = start.HasValue ? $"'{start.Value:yyyy-MM-dd HH:mm:ss}'" : "NULL";
            string sEnd = end.HasValue ? $"'{end.Value:yyyy-MM-dd HH:mm:ss}'" : "NULL";

            // Gọi SP mới
            var topShows = await context.TopShows
                .FromSqlRaw($"CALL proc_top5_shows_by_date_range({sStart}, {sEnd})")
                .ToListAsync();

            var series = new SeriesCollection();
            foreach (var show in topShows)
            {
                series.Add(new PieSeries
                {
                    Title = show.show_name,
                    Values = new ChartValues<double> { (double)show.sold_tickets },
                    DataLabels = true,
                    LabelPoint = point => $"{point.Y:N0} ({point.Participation:P0})"
                });
            }
            ShowPieChart.Series = series;
        }

        private async Task LoadTopShowsAsync(DateTime? start = null, DateTime? end = null)
        {
            using var context = new AppDbContext();
            string sStart = start.HasValue ? $"'{start.Value:yyyy-MM-dd HH:mm:ss}'" : "NULL";
            string sEnd = end.HasValue ? $"'{end.Value:yyyy-MM-dd HH:mm:ss}'" : "NULL";

            var shows = await context.TopShows
                .FromSqlRaw($"CALL proc_top5_shows_by_date_range({sStart}, {sEnd})")
                .ToListAsync();

            TopShowsGrid.ItemsSource = shows.Select((s, i) => new TopShowModel
            {
                Index = i + 1,
                show_name = s.show_name,
                sold_tickets = s.sold_tickets
            }).ToList();
        }

        private async void FilterChanged(object sender, RoutedEventArgs e)
        {
            if (!IsLoaded) return;
            string filter = WeekFilterButton.IsChecked == true ? "week" :
                          MonthFilterButton.IsChecked == true ? "month" : "year";
            await LoadOccupancyChartAsync(filter);
        }

        private async void OccupancyChart_DataClick(object sender, ChartPoint chartPoint)
        {
            // Lấy nhãn của cột vừa click (ví dụ: "25/11", "Tuần 48", "2025")
            string label = OccupancyChart.AxisX[0].Labels[(int)chartPoint.X];

            DateTime start = DateTime.MinValue;
            DateTime end = DateTime.MaxValue;
            bool isValidDate = false;

            // Xử lý logic thời gian dựa trên Filter đang chọn
            if (WeekFilterButton.IsChecked == true)
            {
                // Click vào ngày (dd/MM) -> Lọc theo ngày đó
                if (DateTime.TryParseExact(label + "/" + DateTime.Now.Year, "dd/MM/yyyy", null, System.Globalization.DateTimeStyles.None, out DateTime date))
                {
                    start = date.Date; // 00:00:00
                    end = date.Date.AddDays(1).AddTicks(-1); // 23:59:59
                    isValidDate = true;
                }

            }
            else if (MonthFilterButton.IsChecked == true)
            {
                // Click vào Tuần (Tuần 48) -> Lọc theo tuần đó của năm nay
                // (Logic tính ngày bắt đầu/kết thúc của tuần hơi phức tạp xíu)
                string weekNumStr = label.Replace("Tuần ", "");
                if (int.TryParse(weekNumStr, out int weekNum))
                {
                    start = FirstDateOfWeekISO8601(DateTime.Now.Year, weekNum);
                    end = start.AddDays(7).AddTicks(-1);
                    isValidDate = true;
                }
            }
            else if (YearFilterButton.IsChecked == true)
            {
                // Click vào Năm (2025) -> Lọc cả năm
                if (int.TryParse(label, out int year))
                {
                    start = new DateTime(year, 1, 1);
                    end = new DateTime(year, 12, 31, 23, 59, 59);
                    isValidDate = true;
                }
            }

            if (isValidDate)
            {
                await LoadShowPieChartAsync(start, end);
                await LoadTopShowsAsync(start, end);
            }
        }
        // Hàm phụ trợ tính ngày đầu tuần từ số tuần
        public static DateTime FirstDateOfWeekISO8601(int year, int weekOfYear)
        {
            DateTime jan1 = new DateTime(year, 1, 1);
            int daysOffset = DayOfWeek.Thursday - jan1.DayOfWeek;
            DateTime firstThursday = jan1.AddDays(daysOffset);
            var cal = System.Globalization.CultureInfo.CurrentCulture.Calendar;
            int firstWeek = cal.GetWeekOfYear(firstThursday, System.Globalization.CalendarWeekRule.FirstFourDayWeek, DayOfWeek.Monday);
            var weekNum = weekOfYear;
            if (firstWeek <= 1) { weekNum -= 1; }
            var result = firstThursday.AddDays(weekNum * 7);
            return result.AddDays(-3);
        }
        // ==============================================================================
        //  HÀM CHỤP ẢNH LIVECHARTS – ĐÃ SỬA HOÀN TOÀN KHÔNG LỖI
        // ==============================================================================
        // Hàm chụp ảnh "cưỡng chế" - Đảm bảo hình ảnh luôn hiển thị đủ
        private BitmapSource CaptureChart(UIElement element, int width, int height)
        {
            // 1. Tắt Animation nếu là biểu đồ LiveCharts (để hình hiện ra ngay lập tức)
            if (element is LiveCharts.Wpf.Charts.Base.Chart chart)
            {
                chart.DisableAnimations = true;
                chart.Hoverable = false;
                chart.DataTooltip = null;
            }

            // 2. Lưu lại trạng thái nền cũ
            var originalBrush = (element as Control)?.Background;

            // 3. Set nền đệm để ảnh không bị trong suốt (gây đen hình)
            // Nếu app bạn nền đen, hãy để Brushes.Black. Nếu muốn báo cáo nền trắng, để Brushes.White
            if (element is Control control)
            {
                // Ở đây tôi set màu đen cho khớp với báo cáo PDF của bạn
                control.Background = new SolidColorBrush(Color.FromRgb(30, 30, 30));
            }

            // 4. Ép buộc tính toán lại giao diện theo kích thước mong muốn
            var size = new Size(width, height);
            element.Measure(size);
            element.Arrange(new Rect(size));
            element.UpdateLayout();

            // 5. Render ra ảnh
            var bmp = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
            bmp.Render(element);

            // 6. Trả lại trạng thái cũ cho App (để người dùng không thấy bị giật)
            if (element is Control ctrl)
            {
                ctrl.Background = originalBrush;
                ctrl.InvalidateMeasure();
            }

            // Bật lại animation (nếu cần)
            if (element is LiveCharts.Wpf.Charts.Base.Chart chartRevert)
            {
                chartRevert.DisableAnimations = false;
                chartRevert.Hoverable = true;
            }

            return bmp;
        }
        private MemoryStream BitmapToStream(BitmapSource bmp)
        {
            var stream = new MemoryStream();
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(bmp));
            encoder.Save(stream);
            stream.Position = 0;
            return stream;
        }

        private XImage BitmapToXImage(BitmapSource bmp)
        {
            using var ms = BitmapToStream(bmp);
            var bytes = ms.ToArray();
            var tempMs = new MemoryStream(bytes); // copy mới
            tempMs.Position = 0;
            return XImage.FromStream(tempMs); // PDFSharp sẽ tự dispose
        }

        // ==============================================================================
        //  XUẤT PDF – HOÀN HẢO, KHÔNG LỖI
        // ==============================================================================
        private async void BtnExportPdf_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                string filePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
                    $"BaoCao_StageX_{DateTime.Now:yyyyMMdd_HHmmss}.pdf");

                var doc = new PdfDocument();
                doc.Info.Title = "Báo cáo Dashboard StageX";

                PdfPage page = doc.AddPage();
                page.Width = XUnit.FromMillimeter(297); // Khổ ngang (A4 Landscape)
                page.Height = XUnit.FromMillimeter(210);

                XGraphics gfx = XGraphics.FromPdfPage(page);

                // Vẽ nền đen cho PDF (giống ảnh bạn gửi)
                gfx.DrawRectangle(XBrushes.Black, 0, 0, page.Width, page.Height);

                var options = new XPdfFontOptions(PdfFontEncoding.Unicode);
                XFont fTitle = new XFont("Arial", 24);
                XFont fHeader = new XFont("Arial", 16);
                XFont fNormal = new XFont("Arial", 12);

                double margin = 40;
                double y = 30;

                // --- 1. TIÊU ĐỀ ---
                gfx.DrawString("BÁO CÁO TỔNG QUAN STAGEX", fTitle, XBrushes.White,
                    new XRect(0, y, page.Width, 40), XStringFormats.TopCenter);
                y += 40;

                gfx.DrawString($"Ngày xuất: {DateTime.Now:dd/MM/yyyy HH:mm}", fNormal, XBrushes.LightGray,
                    new XRect(0, y, page.Width, 20), XStringFormats.TopCenter);
                y += 40;

                // --- 2. KPI SUMMARY ---
                string kpi = $"DOANH THU: {RevenueTotalText.Text}  |  ĐƠN: {OrderTotalText.Text}  |  VỞ DIỄN: {ShowTotalText.Text}  |  THỂ LOẠI: {GenreTotalText.Text}";
                gfx.DrawString(kpi, fHeader, XBrushes.Yellow,
                    new XRect(0, y, page.Width, 30), XStringFormats.TopCenter);
                y += 50;

                // --- 3. VẼ BIỂU ĐỒ (Sử dụng CaptureChart thay vì VisualBrush) ---

                // Cấu hình vị trí cột trái và phải
                double col1_X = margin;
                double col2_X = page.Width / 2 + 10;
                double chartWidth = (page.Width / 2) - margin - 20; // Chia đôi chiều rộng trang
                double chartHeight = 250; // Chiều cao mỗi biểu đồ

                double yCurrent = y;

                // >> BIỂU ĐỒ 1: DOANH THU (Cột trái)
                gfx.DrawString("DOANH THU THEO THÁNG", fHeader, XBrushes.Cyan, col1_X, yCurrent);
                // Chờ 1 chút để UI thread kịp xử lý
                await Task.Delay(50);
                var imgRevenue = BitmapToXImage(CaptureChart(RevenueChart, (int)chartWidth * 2, (int)chartHeight * 2)); // Render x2 cho nét
                gfx.DrawImage(imgRevenue, col1_X, yCurrent + 25, chartWidth, chartHeight);

                // >> BIỂU ĐỒ 2: TÌNH TRẠNG VÉ (Cột phải)
                gfx.DrawString("TÌNH TRẠNG VÉ", fHeader, XBrushes.Cyan, col2_X, yCurrent);
                var imgOccupancy = BitmapToXImage(CaptureChart(OccupancyChart, (int)chartWidth * 2, (int)chartHeight * 2));
                gfx.DrawImage(imgOccupancy, col2_X, yCurrent + 25, chartWidth, chartHeight);

                // Tăng Y để xuống dòng vẽ hàng tiếp theo
                yCurrent += chartHeight + 60;

                // >> BIỂU ĐỒ 3: PIE CHART (Cột trái)
                gfx.DrawString("TỶ LỆ VÉ THEO VỞ DIỄN", fHeader, XBrushes.Cyan, col1_X, yCurrent);
                // Pie Chart cần hình vuông nên ta chỉnh size phù hợp
                var imgPie = BitmapToXImage(CaptureChart(ShowPieChart, 500, 500));
                gfx.DrawImage(imgPie, col1_X + 40, yCurrent + 25, chartHeight, chartHeight); // Căn giữa cột trái

                // >> BẢNG TOP 5 (Cột phải)
                gfx.DrawString("TOP 5 VỞ DIỄN", fHeader, XBrushes.Cyan, col2_X, yCurrent);
                // Top 5 cần chiều cao tùy thuộc số dòng, ta set cứng khoảng 300px
                var imgTop5 = BitmapToXImage(CaptureChart(TopShowsGrid, (int)chartWidth * 2, 400));
                gfx.DrawImage(imgTop5, col2_X, yCurrent + 25, chartWidth, 200); // Scale lại vào PDF

                // --- 4. LƯU FILE ---
                doc.Save(filePath);
                doc.Close();

                Process.Start(new ProcessStartInfo(filePath) { UseShellExecute = true });

                AudioHelper.Play("success.mp3");
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message);
            }
        }
        // Thêm hàm này vào DashboardPage class
        // 1. Hàm lấy dữ liệu tháng và lấp đầy khoảng trống
        private async Task<List<RevenueInput>> GetMonthlyRevenueHistoryAsync()
        {
            using (var context = new AppDbContext())
            {
                // 1. Lấy dữ liệu từ SP (lưu ý tên cột trả về phải khớp với Model)
                // Nếu Model bạn tên là 'month', hãy sửa SP trả về alias 'month'
                var rawData = await context.RevenueMonthlies
                    .FromSqlRaw("CALL proc_revenue_monthly()")
                    .ToListAsync();

                if (rawData.Count == 0) return new List<RevenueInput>();

                // 2. Chuyển đổi dữ liệu
                var parsedData = new List<RevenueInput>();

                foreach (var r in rawData)
                {
                    // Dữ liệu từ SQL trả về dạng "2025-08-01" -> Parse rất dễ
                    if (DateTime.TryParse(r.month, out DateTime dt))
                    {
                        parsedData.Add(new RevenueInput
                        {
                            Date = dt,
                            TotalRevenue = (float)r.total_revenue
                        });
                    }
                    // Nếu model của bạn dùng property tên là 'month_date' thì đổi r.month thành r.month_date
                }

                parsedData = parsedData.OrderBy(x => x.Date).ToList();

                // 3. Lấp đầy các tháng trống
                var continuousData = new List<RevenueInput>();
                if (parsedData.Any())
                {
                    var minDate = parsedData.First().Date;
                    var maxDate = parsedData.Last().Date;

                    // Chạy từ tháng đầu đến tháng cuối
                    for (var d = minDate; d <= maxDate; d = d.AddMonths(1))
                    {
                        // So sánh năm và tháng
                        var existing = parsedData.FirstOrDefault(x => x.Date.Year == d.Year && x.Date.Month == d.Month);
                        continuousData.Add(existing ?? new RevenueInput { Date = d, TotalRevenue = 0 });
                    }
                }

                return continuousData;
            }
        }


    }
}

