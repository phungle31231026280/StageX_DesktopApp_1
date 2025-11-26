using CommunityToolkit.Mvvm.ComponentModel;
using LiveCharts;
using LiveCharts.Wpf;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Media;

namespace StageX_DesktopApp.ViewModels
{
    public partial class DashboardViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;

        // KPI
        [ObservableProperty] private string _revenueText = "0đ";
        [ObservableProperty] private string _orderText = "0";
        [ObservableProperty] private string _showText = "0";
        [ObservableProperty] private string _genreText = "0";

        // Charts
        [ObservableProperty] private SeriesCollection _revenueSeries;
        [ObservableProperty] private string[] _revenueLabels;
        public Func<double, string> RevenueFormatter { get; set; } = value => value.ToString("N0");

        [ObservableProperty] private SeriesCollection _occupancySeries;
        [ObservableProperty] private List<string> _occupancyLabels;

        [ObservableProperty] private SeriesCollection _pieSeries;

        // Top Shows
        [ObservableProperty] private List<TopShowModel> _topShowsList;

        public DashboardViewModel()
        {
            _dbService = new DatabaseService();
            // Chạy trên UI thread để tránh lỗi Threading khi cập nhật Collection
            System.Windows.Application.Current.Dispatcher.Invoke(async () => await LoadData());
        }

        private async Task LoadData()
        {
            await LoadSummary();
            await LoadRevenueChart();
            await LoadOccupancy("week");
            await LoadPieChart();
            await LoadTopShows();
        }

        private async Task LoadSummary()
        {
            var sum = await _dbService.GetDashboardSummaryAsync();
            if (sum != null)
            {
                RevenueText = $"{sum.total_revenue:N0}đ";
                OrderText = sum.total_bookings.ToString();
                ShowText = sum.total_shows.ToString();
                GenreText = sum.total_genres.ToString();
            }
        }

        // --- LOGIC BIỂU ĐỒ DOANH THU (GIỐNG CODE CŨ) ---
        private async Task LoadRevenueChart()
        {
            var rawData = await _dbService.GetRevenueMonthlyAsync();

            // 1. Parse dữ liệu
            var parsedData = rawData
                .Select(r => new { Date = DateTime.ParseExact(r.month, "MM/yyyy", null), Total = r.total_revenue })
                .OrderBy(x => x.Date)
                .ToList();

            // 2. Lấp đầy khoảng trống (Fill Gaps) - Logic từ code cũ
            var chartValues = new ChartValues<double>();
            var labels = new List<string>();

            if (parsedData.Any())
            {
                var minDate = parsedData.First().Date;
                var maxDate = parsedData.Last().Date;

                // Chạy từ tháng đầu đến tháng cuối
                for (var d = minDate; d <= maxDate; d = d.AddMonths(1))
                {
                    var existing = parsedData.FirstOrDefault(x => x.Date.Year == d.Year && x.Date.Month == d.Month);
                    double val = existing != null ? (double)existing.Total : 0;

                    chartValues.Add(val);
                    labels.Add(d.ToString("MM/yyyy"));
                }
            }

            RevenueSeries = new SeriesCollection
            {
                new LineSeries
                {
                    Title = "Doanh thu",
                    Values = chartValues,
                    Stroke = new SolidColorBrush(Color.FromRgb(255, 193, 7)), // Vàng
                    Fill = Brushes.Transparent, // Không tô nền dưới
                    PointGeometrySize = 10
                }
            };
            RevenueLabels = labels.ToArray();
        }

        // --- LOGIC BIỂU ĐỒ TÌNH TRẠNG VÉ ---
        public async Task LoadOccupancy(string filter)
        {
            var data = await _dbService.GetOccupancyDataAsync(filter);

            var sold = new ChartValues<double>();
            var unsold = new ChartValues<double>();
            var labels = new List<string>();

            foreach (var item in data)
            {
                labels.Add(item.period);
                sold.Add((double)item.sold_tickets);
                // Giả lập unsold (như code cũ) hoặc lấy từ DB nếu có
                double u = item.unsold_tickets > 0 ? item.unsold_tickets : (double)item.sold_tickets * 0.3;
                unsold.Add(u);
            }

            OccupancySeries = new SeriesCollection
            {
                new StackedColumnSeries { Title = "Đã bán", Values = sold, Fill = new SolidColorBrush(Color.FromRgb(255,193,7)), DataLabels = true },
                new StackedColumnSeries { Title = "Còn trống", Values = unsold, Fill = new SolidColorBrush(Color.FromRgb(60,60,60)), DataLabels = true, Foreground = Brushes.White }
            };
            OccupancyLabels = labels;
        }

        private async Task LoadPieChart()
        {
            var topShows = await _dbService.GetTopShowsAsync();
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
            PieSeries = series;
        }

        private async Task LoadTopShows()
        {
            var shows = await _dbService.GetTopShowsAsync();
            TopShowsList = shows.Select((s, i) => new TopShowModel
            {
                Index = i + 1,
                show_name = s.show_name,
                sold_tickets = s.sold_tickets
            }).ToList();
        }
    }
}