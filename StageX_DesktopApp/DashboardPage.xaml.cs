using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore;
using System.IO;
using OxyPlot;
using OxyPlot.Series;
using OxyPlot.Axes;

// GHI CHÚ: Thêm thư viện OxyPlot
using OxyPlot;
using OxyPlot.Series;
using OxyPlot.Axes;

namespace StageX_DesktopApp
{
    public partial class DashboardPage : Page
    {
        // Khai báo Model cho OxyPlot
        public PlotModel RevenueModel { get; set; }
        public PlotModel TicketModel { get; set; }

        public DashboardPage()
        {
            InitializeComponent();
            DataContext = this;
        }

        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadDashboardDataAsync();
        }

        private async Task LoadDashboardDataAsync()
        {
            try
            {
                using (var context = new AppDbContext())
                {
                    // --- 1. Tải KPI (Giữ nguyên) ---
                    var paidBookings = await context.Bookings
                        .Include(b => b.Payments)
                        .Where(b => b.Payments.Any(p => p.Status == "Thành công"))
                        .AsNoTracking()
                        .ToListAsync();

                    var totalRevenue = paidBookings.Sum(b => b.TotalAmount);
                    var totalBookings = paidBookings.Count();
                    var totalShows = await context.Shows.CountAsync();
                    var totalPerformances = await context.Performances.CountAsync();

                    TotalRevenueText.Text = $"{totalRevenue:N0}đ";
                    TotalBookingsText.Text = totalBookings.ToString();
                    TotalShowsText.Text = totalShows.ToString();
                    TotalPerformancesText.Text = totalPerformances.ToString();

                    // --- 2. Biểu đồ Doanh thu (OxyPlot ColumnSeries) ---
                    var monthlyRevenue = paidBookings
                        .GroupBy(b => new { b.CreatedAt.Year, b.CreatedAt.Month })
                        .Select(g => new
                        {
                            Month = new DateTime(g.Key.Year, g.Key.Month, 1),
                            Revenue = g.Sum(b => b.TotalAmount)
                        })
                        .OrderBy(x => x.Month)
                        .ToList();

                    // Tạo Model
                    var revModel = new PlotModel
                    {
                        PlotAreaBorderColor = OxyColors.Transparent,
                        TextColor = OxyColors.White
                    };

                    // Trục X (Tháng)
                    var categoryAxis = new CategoryAxis { Position = AxisPosition.Bottom, TextColor = OxyColors.Gray };
                    // Trục Y (Tiền)
                    var valueAxis = new LinearAxis { Position = AxisPosition.Left, TextColor = OxyColors.Gray, StringFormat = "N0" };

                    var columnSeries = new ColumnSeries { FillColor = OxyColor.Parse("#FFffc107"), StrokeThickness = 0 };

                    foreach (var item in monthlyRevenue)
                    {
                        categoryAxis.Labels.Add(item.Month.ToString("MM/yyyy"));
                        columnSeries.Items.Add(new ColumnItem((double)item.Revenue));
                    }

                    revModel.Axes.Add(categoryAxis);
                    revModel.Axes.Add(valueAxis);
                    revModel.Series.Add(columnSeries);
                    RevenueModel = revModel; // Gán vào thuộc tính để hiện lên UI

                    // --- 3. Biểu đồ Vé (OxyPlot PieSeries) ---
                    var ticketsThisMonth = await context.Tickets
                        .Include(t => t.Booking.Performance.Show)
                        .Where(t => t.Booking.Payments.Any(p => p.Status == "Thành công") &&
                                    t.Booking.CreatedAt.Month == DateTime.Now.Month &&
                                    t.Booking.CreatedAt.Year == DateTime.Now.Year)
                        .GroupBy(t => t.Booking.Performance.Show.Title)
                        .Select(g => new { ShowTitle = g.Key, TicketCount = g.Count() })
                        .ToListAsync();

                    var tickModel = new PlotModel { TextColor = OxyColors.White };
                    var pieSeries = new PieSeries { StrokeThickness = 1, AngleSpan = 360, StartAngle = 0 };

                    foreach (var item in ticketsThisMonth)
                    {
                        pieSeries.Slices.Add(new PieSlice(item.ShowTitle, item.TicketCount) { IsExploded = true });
                    }

                    tickModel.Series.Add(pieSeries);
                    TicketModel = tickModel; // Gán vào thuộc tính

                    // Cập nhật UI
                    // (Mẹo nhỏ: Gán lại DataContext để làm mới Binding)
                    DataContext = null;
                    DataContext = this;
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải Dashboard: {ex.Message}");
            }
        }

        private async void ExportReportButton_Click(object sender, RoutedEventArgs e)
        {
            // (Giữ nguyên code xuất báo cáo Excel/CSV của bạn)
            try
            {
                using (var context = new AppDbContext())
                {
                    var paidBookings = await context.Bookings
                        .Include(b => b.Payments)
                        .Where(b => b.Payments.Any(p => p.Status == "Thành công"))
                        .AsNoTracking()
                        .ToListAsync();

                    var monthlyRevenue = paidBookings
                        .GroupBy(b => new { b.CreatedAt.Year, b.CreatedAt.Month })
                        .Select(g => new
                        {
                            Month = new DateTime(g.Key.Year, g.Key.Month, 1).ToString("MM/yyyy"),
                            Revenue = g.Sum(b => b.TotalAmount)
                        })
                        .OrderBy(x => x.Month)
                        .ToList();

                    string csvContent = "Tháng,Doanh thu (VND)\n";
                    foreach (var item in monthlyRevenue)
                    {
                        csvContent += $"{item.Month},{item.Revenue}\n";
                    }

                    string filePath = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Desktop), $"BaoCao_{DateTime.Now:yyyyMMdd}.csv");
                    File.WriteAllText(filePath, csvContent, System.Text.Encoding.UTF8);
                    MessageBox.Show($"Đã xuất báo cáo tại: {filePath}");
                }
            }
            catch (Exception ex) { MessageBox.Show(ex.Message); }
        }
    }
}