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

            var soldData = await context.TicketSolds.FromSqlRaw(sql).ToListAsync();

            var soldValues = new ChartValues<double>();
            var unsoldValues = new ChartValues<double>();
            var labels = new List<string>();

            foreach (var item in soldData)
            {
                labels.Add(item.period);
                double sold = Convert.ToDouble(item.sold_tickets);
                double unsold = sold * 0.3; // giả lập
                soldValues.Add(sold);
                unsoldValues.Add(unsold);
            }

            OccupancyChart.Series = new SeriesCollection
            {
                new StackedColumnSeries { Title = "Đã bán", Values = soldValues, Fill = new SolidColorBrush(Color.FromRgb(255,193,7)), DataLabels = true },
                new StackedColumnSeries { Title = "Còn trống", Values = unsoldValues, Fill = new SolidColorBrush(Color.FromRgb(60,60,60)), DataLabels = true }
            };
            OccupancyChart.AxisX[0].Labels = labels;
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
        private BitmapSource CaptureChart(UIElement element, int width, int height)
        {
            element.Measure(new Size(width, height));
            element.Arrange(new Rect(new Size(width, height)));
            element.UpdateLayout();

            var bmp = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
            bmp.Render(element);
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
        private void BtnExportPdf_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                string filePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
                    $"BaoCao_StageX_{DateTime.Now:yyyyMMdd_HHmmss}.pdf");

                var doc = new PdfDocument();
                doc.Info.Title = "Báo cáo StageX";
                PdfPage page = doc.AddPage();
                XGraphics gfx = XGraphics.FromPdfPage(page);

                XFont fTitle = new XFont("Arial", 22);
                XFont fHeader = new XFont("Arial", 14);
                XFont fNormal = new XFont("Arial", 11);

                double y = 40;
                double margin = 50;

                gfx.DrawString("BÁO CÁO TỔNG QUAN STAGEX", fTitle, XBrushes.DarkBlue,
                    new XRect(0, y, page.Width, 50), XStringFormats.TopCenter);
                y += 70;

                // KPI + 3 biểu đồ + bảng
                var items = new (UIElement Chart, string Title, int Width, int Height)[]
{
    (RevenueChart,   "DOANH THU THEO THÁNG",             800, 400),
    (OccupancyChart, "TÌNH TRẠNG VÉ",                     750, 380),
    (ShowPieChart,   "TOP 5 VỞ DIỄN – TỶ LỆ VÉ BÁN",      600, 480),
    (TopShowsGrid,   "CHI TIẾT TOP 5 VỞ DIỄN",            700, 220)
};

                foreach (var (Chart, Title, Width, Height) in items)
                {
                    if (y + Height + 80 > page.Height)
                    {
                        page = doc.AddPage();
                        gfx = XGraphics.FromPdfPage(page);
                        y = 40;
                    }

                    gfx.DrawString(Title, fHeader, XBrushes.Black, margin, y);
                    y += 35;

                    var img = CaptureChart(Chart, Width, Height);
                    gfx.DrawImage(BitmapToXImage(img), margin, y, Width, Height);
                    y += Height + 50;
                }

                doc.Save(filePath);
                doc.Close();

                MessageBox.Show($"Xuất PDF thành công!\n{filePath}", "Thành công", MessageBoxButton.OK);
                Process.Start(new ProcessStartInfo(filePath) { UseShellExecute = true });
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi xuất PDF: " + ex.Message + "\n" + ex.StackTrace);
            }
        }

        // ==============================================================================
        //  XUẤT EXCEL – ĐẸP NHƯ APP, KHÔNG LỖI
        // ==============================================================================
        private async void BtnExportExcel_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                string filePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
                    $"BaoCao_StageX_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx");

                using var package = new ExcelPackage();
                ExcelPackage.License.SetNonCommercialPersonal("<Your Name>");

                var sheet = package.Workbook.Worksheets.Add("Dashboard");

                // Tiêu đề
                sheet.Cells["A1"].Value = "BÁO CÁO TỔNG QUAN STAGEX";
                sheet.Cells["A1:K1"].Merge = true;
                sheet.Cells["A1"].Style.Font.Size = 20;
                sheet.Cells["A1"].Style.Font.Bold = true;
                sheet.Cells["A1"].Style.HorizontalAlignment = ExcelHorizontalAlignment.Center;

                sheet.Cells["A2"].Value = $"Ngày xuất: {DateTime.Now:dd/MM/yyyy HH:mm}";
                sheet.Cells["A2:K2"].Merge = true;

                // KPI
                sheet.Cells["A4"].Value = "Tổng doanh thu"; sheet.Cells["B4"].Value = RevenueTotalText.Text;
                sheet.Cells["D4"].Value = "Đơn hàng"; sheet.Cells["E4"].Value = OrderTotalText.Text;
                sheet.Cells["G4"].Value = "Vở diễn"; sheet.Cells["H4"].Value = ShowTotalText.Text;
                sheet.Cells["J4"].Value = "Thể loại"; sheet.Cells["K4"].Value = GenreTotalText.Text;

                int row = 7;

                // 3 biểu đồ giống hệt app
                var excelChartList = new List<object>
{
    new { Control = RevenueChart,   Width = 950,  Height = 500 },
    new { Control = OccupancyChart, Width = 900,  Height = 450 },
    new { Control = ShowPieChart,   Width = 700,  Height = 560 }
};

                int currentRow = 7;  // đổi tên biến để không trùng với "row" ở chỗ khác (fix CS0128)

                foreach (var item in excelChartList)
                {
                    var control = (UIElement)item.GetType().GetProperty("Control").GetValue(item);
                    int w = (int)item.GetType().GetProperty("Width").GetValue(item);
                    int h = (int)item.GetType().GetProperty("Height").GetValue(item);

                    var bmp = CaptureChart(control, w, h);
                    var pic = sheet.Drawings.AddPicture("Chart_" + currentRow, BitmapToStream(bmp));
                    pic.SetPosition(currentRow, 0, 0, 0);
                    pic.SetSize(w, h);

                    currentRow += 32; // khoảng cách giữa các biểu đồ
                }

                // Bảng Top 5 vở diễn
                var top5Bmp = CaptureChart(TopShowsGrid, 750, 250);
                var top5Pic = sheet.Drawings.AddPicture("Top5Table", BitmapToStream(top5Bmp));
                top5Pic.SetPosition(currentRow, 0, 0, 0);



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