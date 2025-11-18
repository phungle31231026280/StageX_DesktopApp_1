using StageX_DesktopApp.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using Microsoft.EntityFrameworkCore;
using LiveCharts;
using LiveCharts.Wpf;
using System.Windows.Media;


namespace StageX_DesktopApp
{
    public partial class DashboardPage : Page
    {
        public DashboardPage()
        {
            InitializeComponent();
        }

        /// <summary>
        /// Sự kiện tải trang: tải dữ liệu bảng điều khiển.
        /// </summary>
        private async void Page_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadDashboardDataAsync();
        }

        /// <summary>
        /// Gọi tất cả các hàm tải dữ liệu cần thiết khi khởi tạo trang.
        /// </summary>
        private async Task LoadDashboardDataAsync()
        {
            try
            {
                await LoadSummaryAsync();
                await LoadRevenueChartAsync();
                await LoadTicketChartAsync("day");
                await LoadRatingChartAsync();
                await LoadTopShowsAsync();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Lỗi khi tải dữ liệu bảng điều khiển: {ex.Message}");
            }
        }

        /// <summary>
        /// Tải dữ liệu tổng quan (doanh thu, số đơn, số vở diễn, số thể loại).
        /// </summary>
        private async Task LoadSummaryAsync()
        {
            using var context = new AppDbContext();
            // Sử dụng thủ tục lưu trữ để lấy một hàng dữ liệu
            var results = await context.DashboardSummaries
                                       .FromSqlRaw("CALL proc_dashboard_summary()")
                                       .ToListAsync();
            var summary = results.FirstOrDefault();
            if (summary != null)
            {
                // Định dạng số theo chuẩn VNĐ
                RevenueTotalText.Text = string.Format(System.Globalization.CultureInfo.GetCultureInfo("vi-VN"), "{0:N0}đ", summary.total_revenue);
                OrderTotalText.Text = summary.total_bookings.ToString();
                ShowTotalText.Text = summary.total_shows.ToString();
                GenreTotalText.Text = summary.total_genres.ToString();
            }
        }

        /// <summary>
        /// Tải dữ liệu doanh thu theo tháng và cập nhật biểu đồ.
        /// </summary>
        private async Task LoadRevenueChartAsync()
        {
            using var context = new AppDbContext();
            var data = await context.RevenueMonthlies
                                    .FromSqlRaw("CALL proc_revenue_monthly()")
                                    .ToListAsync();

            // Chuẩn bị dữ liệu cho LiveCharts
            // LiveCharts yêu cầu kiểu double cho biểu đồ nên chuyển đổi sang double
            var revenueValues = new ChartValues<double>(data.Select(d => Convert.ToDouble(d.total_revenue)));
            RevenueChart.Series = new SeriesCollection
            {
                new ColumnSeries
                {
                    Title = "Doanh thu (đ)",
                    Values = revenueValues,
                    Fill = new SolidColorBrush(Color.FromRgb(255, 193, 7)),
                    MaxColumnWidth = 50
                }
            };
            RevenueChart.AxisX.Clear();
            RevenueChart.AxisX.Add(new Axis
            {
                Labels = data.Select(d => d.month).ToArray(),
                Foreground = Brushes.White
            });
            RevenueChart.AxisY.Clear();
            RevenueChart.AxisY.Add(new Axis
            {
                LabelFormatter = val => val.ToString("N0"),
                Foreground = Brushes.White
            });
        }

        /// <summary>
        /// Tải dữ liệu số vé bán theo bộ lọc và cập nhật biểu đồ.
        /// </summary>
        /// <param name="filter">Các giá trị hợp lệ: "day", "week", "month", "year".</param>
        private async Task LoadTicketChartAsync(string filter)
        {
            using var context = new AppDbContext();
            string procName = filter switch
            {
                "week" => "proc_sold_tickets_weekly",
                "month" => "proc_sold_tickets_monthly",
                "year" => "proc_sold_tickets_yearly",
                _ => "proc_sold_tickets_daily"
            };
            string sql = filter switch
            {
                "week" => "CALL proc_sold_tickets_weekly()",
                "month" => "CALL proc_sold_tickets_monthly()",
                "year" => "CALL proc_sold_tickets_yearly()",
                _ => "CALL proc_sold_tickets_daily()"
            };
            var data = await context.TicketSolds
                                     .FromSqlRaw(sql)
                                     .ToListAsync();

            // Chuẩn bị dữ liệu cho LiveCharts
            var ticketValues = new ChartValues<double>(data.Select(d => Convert.ToDouble(d.sold_tickets)));
            TicketsChart.Series = new SeriesCollection
            {
                new ColumnSeries
                {
                    Title = "Số vé",
                    Values = ticketValues,
                    Fill = new SolidColorBrush(Color.FromRgb(3, 169, 244)),
                    MaxColumnWidth = 50
                }
            };
            TicketsChart.AxisX.Clear();
            TicketsChart.AxisX.Add(new Axis
            {
                Labels = data.Select(d => d.period?.ToString() ?? string.Empty).ToArray(),
                Foreground = Brushes.White,
                LabelsRotation = 45
            });
            TicketsChart.AxisY.Clear();
            TicketsChart.AxisY.Add(new Axis
            {
                LabelFormatter = val => val.ToString("N0"),
                Foreground = Brushes.White
            });
        }

        /// <summary>
        /// Tải dữ liệu phân bố đánh giá theo sao và vẽ biểu đồ donut.
        /// </summary>
        private async Task LoadRatingChartAsync()
        {
            using var context = new AppDbContext();
            var data = await context.RatingDistributions
                                    .FromSqlRaw("CALL proc_rating_distribution()")
                                    .ToListAsync();
            var series = new SeriesCollection();
            // Mảng màu cho 5 mức sao (có thể thay đổi tùy ý)
            Color[] colors = new Color[]
            {
                Color.FromRgb(244, 67, 54),   // Đỏ (1 sao)
                Color.FromRgb(255, 152, 0),  // Cam (2 sao)
                Color.FromRgb(255, 235, 59), // Vàng (3 sao)
                Color.FromRgb(76, 175, 80),  // Xanh lá (4 sao)
                Color.FromRgb(33, 150, 243)  // Xanh lam (5 sao)
            };
            for (int i = 0; i < data.Count; i++)
            {
                var item = data[i];
                // Bảo vệ nếu thiếu màu
                var color = colors[i % colors.Length];
                series.Add(new PieSeries
                {
                    Title = $"{item.star} sao",
                    Values = new ChartValues<double> { Convert.ToDouble(item.rating_count) },
                    Fill = new SolidColorBrush(color),
                    DataLabels = true,
                    LabelPoint = chartPoint => chartPoint.Y.ToString("N0")
                });
            }
            RatingChart.Series = series;
        }

        /// <summary>
        /// Tải danh sách top 5 vở diễn bán chạy nhất và gán vào DataGrid.
        /// </summary>
        private async Task LoadTopShowsAsync()
        {
            using var context = new AppDbContext();
            var shows = await context.TopShows
                                     .FromSqlRaw("CALL proc_top5_shows_by_tickets()")
                                     .ToListAsync();
            // Thêm chỉ số thứ tự để hiển thị STT
            var withIndex = shows.Select((item, index) => new { Index = index + 1, item.show_name, item.sold_tickets }).ToList();
            TopShowsGrid.ItemsSource = withIndex;
        }

        /// <summary>
        /// Xử lý sự kiện thay đổi bộ lọc biểu đồ vé bán.
        /// </summary>
        private async void FilterChanged(object sender, RoutedEventArgs e)
        {
            if (!IsLoaded) return;
            string filter = "day";
            if (WeekFilterButton.IsChecked == true) filter = "week";
            else if (MonthFilterButton.IsChecked == true) filter = "month";
            else if (YearFilterButton.IsChecked == true) filter = "year";
            await LoadTicketChartAsync(filter);
        }

        /// <summary>
        /// Hiển thị chỉ số thứ tự ở cột STT. (Không bắt buộc vì đã tính Index trong ItemsSource.)
        /// </summary>
        private void TopShowsGrid_LoadingRow(object sender, DataGridRowEventArgs e)
        {
            // Cột STT được bind với thuộc tính Index nên không cần xử lý riêng. Tuy nhiên,
            // nếu muốn đánh số hàng ở header cũng có thể sử dụng:
            // e.Row.Header = (e.Row.GetIndex() + 1).ToString();
        }
    }
}