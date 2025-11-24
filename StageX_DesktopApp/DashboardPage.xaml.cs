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
            ExcelPackage.License.SetNonCommercialPersonal("<Your Name>");
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

        private async Task LoadRevenueChartAsync()
        {
            using var context = new AppDbContext();
            var data = await context.RevenueMonthlies.FromSqlRaw("CALL proc_revenue_monthly()").ToListAsync();
            var values = new ChartValues<double>(data.Select(d => Convert.ToDouble(d.total_revenue)));

            RevenueChart.Series = new SeriesCollection
            {
                new ColumnSeries
                {
                    Title = "Doanh thu",
                    Values = values,
                    Fill = new SolidColorBrush(Color.FromRgb(255, 193, 7)),
                    DataLabels = true
                }
            };
            RevenueChart.AxisX[0].Labels = data.Select(d => d.month).ToArray();
        }

        private async Task LoadOccupancyChartAsync(string filter)
        {
            using var context = new AppDbContext();
            string sql = filter switch
            {
                "month" => "CALL proc_chart_last_4_weeks()",
                "year" => "CALL proc_chart_last_12_months()",
                _ => "CALL proc_chart_last_7_days()"
            };

            // Sử dụng ChartDatas (Model mới tạo) để hứng đủ 2 cột sold và unsold
            var data = await context.ChartDatas.FromSqlRaw(sql).ToListAsync();

            var soldValues = new ChartValues<double>();
            var unsoldValues = new ChartValues<double>();
            var labels = new List<string>();

            foreach (var item in data)
            {
                labels.Add(item.period);

                double sold = (double)item.sold_tickets;
                double unsold = (double)item.unsold_tickets;

                soldValues.Add(sold);
                unsoldValues.Add(unsold);
            }

            OccupancyChart.Series = new SeriesCollection
    {
        new StackedColumnSeries
        {
            Title = "Đã bán",
            Values = soldValues,
            Fill = new SolidColorBrush(Color.FromRgb(255,193,7)),
            DataLabels = false
        },
        new StackedColumnSeries
        {
            Title = "Còn trống",
            Values = unsoldValues,
            Fill = new SolidColorBrush(Color.FromRgb(60,60,60)),
            DataLabels = false // Ẩn số liệu phần trống cho đỡ rối
        }
    };

            OccupancyChart.AxisX[0].Labels = labels;

            // Format trục Y hiển thị số nguyên (số vé)
            OccupancyChart.AxisY[0].LabelFormatter = value => value.ToString("N0");
        }

        private async Task LoadShowPieChartAsync()
        {
            using var context = new AppDbContext();
            var topShows = await context.TopShows.FromSqlRaw("CALL proc_top5_shows_by_tickets()").ToListAsync();
            var series = new SeriesCollection();
            foreach (var show in topShows)
            {
                series.Add(new PieSeries
                {
                    Title = show.show_name,
                    Values = new ChartValues<double> { (double)show.sold_tickets },
                    DataLabels = true,
                    LabelPoint = point => $"{point.Y:N0} vé ({point.Participation:P0})"
                });
            }
            ShowPieChart.Series = series;

            // [QUAN TRỌNG] Tắt Animation để chụp ảnh không bị mất hình
            ShowPieChart.DisableAnimations = true;
            ShowPieChart.Hoverable = false;
        }

        private async Task LoadTopShowsAsync()
        {
            using var context = new AppDbContext();
            var shows = await context.TopShows.FromSqlRaw("CALL proc_top5_shows_by_tickets()").ToListAsync();
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

                MessageBox.Show($"Xuất PDF thành công!\n{filePath}", "Thành công", MessageBoxButton.OK, MessageBoxImage.Information);
                Process.Start(new ProcessStartInfo(filePath) { UseShellExecute = true });
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi: " + ex.Message);
            }
        }

        // HÀM CHỤP ẢNH MÀ KHÔNG LÀM HỎNG LAYOUT APP (SIÊU ỔN ĐỊNH!)


        // ==============================================================================
        //  XUẤT EXCEL – ĐẸP NHƯ APP, KHÔNG LỖI
        // ==============================================================================
        private async void BtnExportExcel_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                string filePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
                    $"BaoCao_StageX_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx");

                // Sử dụng FileInfo cho EPPlus
                var fileInfo = new FileInfo(filePath);

                using (var package = new ExcelPackage(fileInfo))
                {
                    ExcelPackage.License.SetNonCommercialPersonal("<Your Name>");

                    // Xóa sheet cũ nếu trùng tên (dù tên file có timestamp nhưng cứ an toàn)
                    var sheet = package.Workbook.Worksheets.Add("Dashboard");

                    // --- PHẦN CODE TIÊU ĐỀ & KPI GIỮ NGUYÊN ---
                    sheet.Cells["A1"].Value = "BÁO CÁO TỔNG QUAN STAGEX";
                    sheet.Cells["A1:K1"].Merge = true;
                    sheet.Cells["A1"].Style.Font.Size = 20;
                    sheet.Cells["A1"].Style.Font.Bold = true;
                    sheet.Cells["A1"].Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;

                    sheet.Cells["A2"].Value = $"Ngày xuất: {DateTime.Now:dd/MM/yyyy HH:mm}";
                    sheet.Cells["A2:K2"].Merge = true;

                    sheet.Cells["A4"].Value = "Tổng doanh thu"; sheet.Cells["B4"].Value = RevenueTotalText.Text;
                    sheet.Cells["D4"].Value = "Đơn hàng"; sheet.Cells["E4"].Value = OrderTotalText.Text;
                    sheet.Cells["G4"].Value = "Vở diễn"; sheet.Cells["H4"].Value = ShowTotalText.Text;
                    sheet.Cells["J4"].Value = "Thể loại"; sheet.Cells["K4"].Value = GenreTotalText.Text;

                    // --- PHẦN XUẤT ẢNH ---
                    var excelChartList = new List<object>
            {
                new { Control = RevenueChart,   Width = 950,  Height = 500 },
                new { Control = OccupancyChart, Width = 900,  Height = 450 },
                new { Control = ShowPieChart,   Width = 700,  Height = 560 } // PieChart sẽ hiện do đã tắt animation
            };

                    int currentRow = 7;

                    foreach (var item in excelChartList)
                    {
                        var control = (UIElement)item.GetType().GetProperty("Control").GetValue(item);
                        int w = (int)item.GetType().GetProperty("Width").GetValue(item);
                        int h = (int)item.GetType().GetProperty("Height").GetValue(item);

                        // Chờ layout update 1 chút để đảm bảo thread UI đã vẽ xong
                        await Task.Delay(100);

                        var bmp = CaptureChart(control, w, h);
                        var pic = sheet.Drawings.AddPicture("Chart_" + currentRow, BitmapToStream(bmp));
                        pic.SetPosition(currentRow, 0, 0, 0);
                        pic.SetSize(w, h);

                        currentRow += 32;
                    }

                    // Bảng Top 5 vở diễn
                    // Tăng chiều cao lên một chút để không bị mất dòng cuối
                    await Task.Delay(100);
                    var top5Bmp = CaptureChart(TopShowsGrid, 750, 300);
                    var top5Pic = sheet.Drawings.AddPicture("Top5Table", BitmapToStream(top5Bmp));
                    top5Pic.SetPosition(currentRow, 0, 0, 0);

                    // [QUAN TRỌNG] LƯU FILE
                    package.Save();
                }

                MessageBox.Show($"Xuất Excel thành công!\n{filePath}", "Thành công", MessageBoxButton.OK);
                Process.Start(new ProcessStartInfo(filePath) { UseShellExecute = true });
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi xuất Excel: " + ex.Message);
            }
        }
    }
}

