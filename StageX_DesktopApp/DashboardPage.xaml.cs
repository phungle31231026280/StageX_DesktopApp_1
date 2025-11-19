using LiveCharts; // Dùng LiveCharts 1
using LiveCharts.Wpf; // Dùng LiveCharts 1
using Microsoft.EntityFrameworkCore;
using OfficeOpenXml;
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

namespace StageX_DesktopApp
{
    // Model phụ cho Top 5
    public class TopShowModel
    {
        public int Index { get; set; }
        public string show_name { get; set; }
        public long sold_tickets { get; set; }
    }

    public partial class DashboardPage : Page
    {
        // Formatter cho trục Y
        public Func<double, string> RevenueFormatter { get; set; }

        public DashboardPage()
        {
            InitializeComponent();
            ExcelPackage.License.SetNonCommercialPersonal("<Your Name>");
            RevenueFormatter = value => value.ToString("N0"); // Format tiền
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
                await LoadOccupancyChartAsync("day");
                await LoadShowPieChartAsync();
                await LoadRatingChartAsync();
                await LoadTopShowsAsync();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi tải Dashboard: {ex.Message}");
            }
        }

        // --- CÁC HÀM TẢI DỮ LIỆU ---

        private async Task LoadSummaryAsync()
        {
            using (var context = new AppDbContext())
            {
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
        }

        private async Task LoadRevenueChartAsync()
        {
            using (var context = new AppDbContext())
            {
                var data = await context.RevenueMonthlies.FromSqlRaw("CALL proc_revenue_monthly()").ToListAsync();

                var values = new ChartValues<double>(data.Select(d => Convert.ToDouble(d.total_revenue)));
                var labels = data.Select(d => d.month).ToArray();

                RevenueChart.Series = new SeriesCollection
                {
                    new ColumnSeries
                    {
                        Title = "Doanh thu",
                        Values = values,
                        Fill = new SolidColorBrush(Color.FromRgb(255, 193, 7)), // Vàng
                        DataLabels = true
                    }
                };

                // Cập nhật Labels trục X
                RevenueChart.AxisX[0].Labels = labels;
            }
        }

        private async Task LoadOccupancyChartAsync(string filter)
        {
            using (var context = new AppDbContext())
            {
                string sql = filter switch
                {
                    "week" => "CALL proc_sold_tickets_weekly()",
                    "month" => "CALL proc_sold_tickets_monthly()",
                    "year" => "CALL proc_sold_tickets_yearly()",
                    _ => "CALL proc_sold_tickets_daily()"
                };
                var soldData = await context.TicketSolds.FromSqlRaw(sql).ToListAsync();

                var labels = new List<string>();
                var soldValues = new ChartValues<double>();
                var unsoldValues = new ChartValues<double>();

                foreach (var item in soldData)
                {
                    labels.Add(item.period);
                    double sold = Convert.ToDouble(item.sold_tickets);
                    double unsold = sold * 0.5; // Giả lập ghế trống
                    soldValues.Add(sold);
                    unsoldValues.Add(unsold);
                }

                OccupancyChart.Series = new SeriesCollection
                {
                    new StackedColumnSeries { Title = "Đã bán", Values = soldValues, Fill = new SolidColorBrush(Color.FromRgb(255, 193, 7)), DataLabels = true },
                    new StackedColumnSeries { Title = "Còn trống", Values = unsoldValues, Fill = new SolidColorBrush(Color.FromRgb(60, 60, 60)), DataLabels = true }
                };

                OccupancyChart.AxisX[0].Labels = labels;
            }
        }

        private async Task LoadShowPieChartAsync()
        {
            using (var context = new AppDbContext())
            {
                var topShows = await context.TopShows.FromSqlRaw("CALL proc_top5_shows_by_tickets()").ToListAsync();
                var series = new SeriesCollection();
                foreach (var show in topShows)
                {
                    series.Add(new PieSeries
                    {
                        Title = show.show_name,
                        Values = new ChartValues<double> { (double)show.sold_tickets },
                        DataLabels = true
                    });
                }
                ShowPieChart.Series = series;
            }
        }

        private async Task LoadRatingChartAsync()
        {
            using (var context = new AppDbContext())
            {
                var data = await context.RatingDistributions.FromSqlRaw("CALL proc_rating_distribution()").ToListAsync();
                var series = new SeriesCollection();
                Color[] colors = { Color.FromRgb(244, 67, 54), Color.FromRgb(255, 152, 0), Color.FromRgb(255, 235, 59), Color.FromRgb(76, 175, 80), Color.FromRgb(33, 150, 243) };

                for (int i = 0; i < data.Count; i++)
                {
                    series.Add(new PieSeries
                    {
                        Title = $"{data[i].star} Sao",
                        Values = new ChartValues<double> { Convert.ToDouble(data[i].rating_count) },
                        Fill = new SolidColorBrush(colors[i % colors.Length]),
                        DataLabels = true
                    });
                }
                RatingChart.Series = series;
            }
        }

        private async Task LoadTopShowsAsync()
        {
            using (var context = new AppDbContext())
            {
                var shows = await context.TopShows.FromSqlRaw("CALL proc_top5_shows_by_tickets()").ToListAsync();
                var list = shows.Select((s, i) => new TopShowModel { Index = i + 1, show_name = s.show_name, sold_tickets = s.sold_tickets }).ToList();
                TopShowsGrid.ItemsSource = list;
            }
        }

        // --- SỰ KIỆN ---

        private async void FilterChanged(object sender, RoutedEventArgs e)
        {
            if (!IsLoaded) return;
            string filter = "day";
            if (WeekFilterButton.IsChecked == true) filter = "week";
            else if (MonthFilterButton.IsChecked == true) filter = "month";
            else if (YearFilterButton.IsChecked == true) filter = "year"; // GHI CHÚ: Đã có biến YearFilterButton

            await LoadOccupancyChartAsync(filter);
        }

        private async void BtnExportExcel_Click(object sender, RoutedEventArgs e)
        {
            // (Code xuất Excel giữ nguyên như cũ)
            try
            {
                string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), $"Dashboard_{DateTime.Now:yyyyMMdd}.xlsx");
                using (var p = new ExcelPackage(new FileInfo(path)))
                {
                    var ws = p.Workbook.Worksheets.Add("Dashboard");
                    ws.Cells["A1"].Value = "BÁO CÁO STAGEX";
                    ws.Cells["A3"].Value = "Doanh thu:"; ws.Cells["B3"].Value = RevenueTotalText.Text;
                    p.Save();
                }
                MessageBox.Show($"Đã xuất Excel: {path}");
                Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
            }
            catch (Exception ex) { MessageBox.Show(ex.Message); }
        }

        private void BtnExportPdf_Click(object sender, RoutedEventArgs e)
        {
            // (Code xuất PDF giữ nguyên như cũ)
            try
            {
                PdfDocument doc = new PdfDocument();
                PdfPage page = doc.AddPage();
                XGraphics gfx = XGraphics.FromPdfPage(page);
                XFont font = new XFont("Arial", 14);
                gfx.DrawString("BÁO CÁO STAGEX", font, XBrushes.Black, 40, 40);
                gfx.DrawString($"Doanh thu: {RevenueTotalText.Text}", font, XBrushes.Black, 40, 80);
                string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), $"Dashboard_{DateTime.Now:yyyyMMdd}.pdf");
                doc.Save(path);
                MessageBox.Show($"Đã xuất PDF: {path}");
                Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
            }
            catch (Exception ex) { MessageBox.Show(ex.Message); }
        }
    }
}