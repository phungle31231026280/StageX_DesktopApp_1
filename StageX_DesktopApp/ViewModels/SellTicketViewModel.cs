using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using StageX_DesktopApp.Models;
using StageX_DesktopApp.Services;
using StageX_DesktopApp.Utilities;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace StageX_DesktopApp.ViewModels
{
    public class BillSeatItem
    {
        public int SeatId { get; set; }
        public string SeatLabel { get; set; }
        public decimal Price { get; set; }
    }

    public class LegendItem
    {
        public string Name { get; set; }
        public SolidColorBrush Color { get; set; }
    }

    public partial class SellTicketViewModel : ObservableObject
    {
        private readonly DatabaseService _dbService;
        private readonly VietQRService _qrService;

        [ObservableProperty] private List<ShowInfo> _shows;
        [ObservableProperty] private List<PerformanceInfo> _performances;
        [ObservableProperty] private ObservableCollection<PeakPerformanceInfo> _topPerformances;
        [ObservableProperty] private ObservableCollection<BillSeatItem> _billSeats = new();
        [ObservableProperty] private ObservableCollection<LegendItem> _legendItems = new();

        [ObservableProperty] private bool _isPeakMode = false;
        [ObservableProperty] private ShowInfo _selectedShow;
        [ObservableProperty] private PerformanceInfo _selectedPerformance;

        [ObservableProperty] private string _selectedShowText;
        [ObservableProperty] private string _selectedPerfText;
        [ObservableProperty] private string _totalText = "Thành tiền: 0đ";
        [ObservableProperty] private string _changeText = "0đ";
        [ObservableProperty] private string _cashGiven;
        [ObservableProperty] private bool _isCashPayment = true;
        [ObservableProperty] private bool _isQrVisible = false;
        [ObservableProperty] private BitmapImage _qrImageSource;

        public event Action<List<SeatStatus>> RequestDrawSeats;

        private int _currentPerfId;
        private decimal _currentPrice;

        public SellTicketViewModel()
        {
            _dbService = new DatabaseService();
            _qrService = new VietQRService();
            Task.Run(async () => await InitData());
        }

        private async Task InitData()
        {
            await Application.Current.Dispatcher.InvokeAsync(async () =>
            {
                IsPeakMode = false;
                IsCashPayment = true;
                Shows = await _dbService.GetActiveShowsAsync();
            });
        }

        [RelayCommand]
        private async Task SwitchMode(string mode)
        {
            IsPeakMode = (mode == "Peak");
            ClearAllData();

            if (IsPeakMode)
            {
                IsCashPayment = false;
                var tops = await _dbService.GetTopPerformancesAsync();
                var list = new List<PeakPerformanceInfo>(tops);
                while (list.Count < 3) list.Add(new PeakPerformanceInfo { performance_id = 0 });
                TopPerformances = new ObservableCollection<PeakPerformanceInfo>(list);
            }
            else
            {
                IsCashPayment = true;
                Shows = await _dbService.GetActiveShowsAsync();
            }
        }

        partial void OnSelectedShowChanged(ShowInfo value)
        {
            if (value == null) return;
            SelectedShowText = $"Vở diễn: {value.title}";
            LoadPerformances(value.show_id);
        }

        private async void LoadPerformances(int showId)
        {
            Performances = await _dbService.GetPerformancesByShowAsync(showId);
        }

        partial void OnSelectedPerformanceChanged(PerformanceInfo value)
        {
            if (value == null) return;
            SelectPerformanceLogic(value.performance_id, value.price, value.Display);
        }

        [RelayCommand]
        private void SelectPeakPerformance(PeakPerformanceInfo p)
        {
            if (p == null || p.performance_id == 0) return;
            SelectedShowText = $"Vở diễn: {p.show_title}";
            SelectPerformanceLogic(p.performance_id, p.price, p.Display);
        }

        private async void SelectPerformanceLogic(int perfId, decimal price, string display)
        {
            _currentPerfId = perfId;
            _currentPrice = price;
            SelectedPerfText = $"Suất chiếu: {display}";

            BillSeats.Clear();
            UpdateTotal();

            try
            {
                // 1. Gọi DB lấy ghế (Đã map vào SeatStatus mới)
                var seats = await _dbService.GetSeatsWithStatusAsync(perfId);

                // 2. Báo View vẽ
                await Application.Current.Dispatcher.InvokeAsync(() => RequestDrawSeats?.Invoke(seats));

                // 3. Tạo Legend
                var legends = new List<LegendItem>();
                var distinctCats = seats.Where(s => !string.IsNullOrEmpty(s.CategoryName))
                                        .Select(s => new { s.CategoryName, s.BasePrice, s.ColorClass })
                                        .Distinct().OrderBy(x => x.BasePrice);

                foreach (var cat in distinctCats)
                {
                    SolidColorBrush brush = Brushes.Gray;
                    try
                    {
                        string hex = cat.ColorClass?.Trim() ?? "333";
                        if (!hex.StartsWith("#")) hex = "#" + hex;
                        brush = (SolidColorBrush)new BrushConverter().ConvertFrom(hex);
                    }
                    catch { }

                    legends.Add(new LegendItem { Name = $"{cat.CategoryName} (+{cat.BasePrice:N0}đ)", Color = brush });
                }
                LegendItems = new ObservableCollection<LegendItem>(legends);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi tải ghế: " + ex.Message);
            }
        }

        public void ToggleSeat(SeatStatus seat)
        {
            var existing = BillSeats.FirstOrDefault(x => x.SeatId == seat.SeatId);
            if (existing != null) BillSeats.Remove(existing);
            else BillSeats.Add(new BillSeatItem { SeatId = seat.SeatId, SeatLabel = seat.SeatLabel, Price = seat.BasePrice + _currentPrice });
            UpdateTotal();
        }

        partial void OnCashGivenChanged(string value) => UpdateTotal();

        private async void UpdateTotal()
        {
            decimal total = BillSeats.Sum(x => x.Price);
            TotalText = $"Thành tiền: {total:N0}đ";

            if (decimal.TryParse(CashGiven, out decimal given))
            {
                decimal change = given - total;
                ChangeText = change >= 0 ? $"{change:N0}đ" : $"-{Math.Abs(change):N0}đ";
            }
            else ChangeText = "0đ";

            if (!IsCashPayment && total > 0)
            {
                IsQrVisible = true;
                QrImageSource = await _qrService.GenerateQrCodeAsync((int)total, "Thanh toan STAGEX");
            }
            else
            {
                IsQrVisible = false;
                QrImageSource = null;
            }
        }

        [RelayCommand]
        private void SelectPayment(string method)
        {
            IsCashPayment = (method == "Cash");
            UpdateTotal();
        }

        [RelayCommand]
        private async Task SaveOrder()
        {
            if (_currentPerfId == 0 || !BillSeats.Any()) { MessageBox.Show("Vui lòng chọn suất và ghế!"); return; }
            decimal total = BillSeats.Sum(x => x.Price);

            if (IsCashPayment)
            {
                if (!decimal.TryParse(CashGiven, out decimal given) || given < total) { MessageBox.Show("Tiền khách đưa thiếu!"); return; }
            }

            try
            {
                int staffId = AuthSession.CurrentUser?.UserId ?? 0;
                int bookingId = await _dbService.CreateBookingPOSAsync(null, _currentPerfId, total, staffId);

                if (bookingId > 0)
                {
                    string method = IsCashPayment ? "Tiền mặt" : "Chuyển khoản";
                    var seatIds = BillSeats.Select(s => s.SeatId).ToList();
                    await _dbService.CreatePaymentAndTicketsAsync(bookingId, total, method, seatIds);

                    MessageBox.Show("Thanh toán thành công!");
                    if (IsPeakMode) SwitchMode("Peak");
                    else SelectPerformanceLogic(_currentPerfId, _currentPrice, SelectedPerfText.Replace("Suất chiếu: ", ""));
                }
            }
            catch (Exception ex) { MessageBox.Show("Lỗi: " + ex.Message); }
        }

        private void ClearAllData()
        {
            SelectedShow = null; SelectedPerformance = null;
            _currentPerfId = 0; _currentPrice = 0;
            SelectedShowText = ""; SelectedPerfText = "";
            BillSeats.Clear(); LegendItems.Clear();
            CashGiven = ""; UpdateTotal();
            RequestDrawSeats?.Invoke(new List<SeatStatus>());
        }
    }
}