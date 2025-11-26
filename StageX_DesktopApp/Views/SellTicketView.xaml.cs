using StageX_DesktopApp.Models;
using StageX_DesktopApp.ViewModels;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace StageX_DesktopApp.Views
{
    public partial class SellTicketView : UserControl
    {
        private double seatScale = 1.0;

        public SellTicketView()
        {
            InitializeComponent();

            // 1. Kiểm tra DataContext ngay lập tức (FIX LỖI)
            if (this.DataContext is SellTicketViewModel currentVM)
            {
                SubcribeToViewModel(currentVM);
            }

            // 2. Lắng nghe nếu DataContext thay đổi sau này
            this.DataContextChanged += (s, e) =>
            {
                if (e.NewValue is SellTicketViewModel newVM)
                {
                    SubcribeToViewModel(newVM);
                }
            };
        }

        private void SubcribeToViewModel(SellTicketViewModel vm)
        {
            // Hủy đăng ký cũ trước để an toàn
            vm.RequestDrawSeats -= OnRequestDrawSeats;
            // Đăng ký sự kiện vẽ
            vm.RequestDrawSeats += OnRequestDrawSeats;
        }

        private void OnRequestDrawSeats(List<SeatStatus> seatList)
        {
            // Chạy trên luồng UI
            Application.Current.Dispatcher.Invoke(() =>
            {
                BuildSeatMapSafe(seatList);
            });
        }

        private void BuildSeatMapSafe(List<SeatStatus> seatList)
        {
            try
            {
                // Dọn dẹp cũ
                SeatMapGrid.Children.Clear();
                SeatMapGrid.RowDefinitions.Clear();
                SeatMapGrid.ColumnDefinitions.Clear();

                // Reset Zoom
                seatScale = 1.0;
                SeatMapGrid.LayoutTransform = new ScaleTransform(seatScale, seatScale);

                if (seatList == null || seatList.Count == 0) return;

                // --- DEBUG: Kiểm tra dữ liệu ---
                // MessageBox.Show($"Đã nhận {seatList.Count} ghế. Bắt đầu vẽ..."); 
                // (Bạn có thể bỏ comment dòng trên để test xem hàm này có được gọi không)

                // 1. Nhóm ghế theo Hàng
                var rowsGroup = seatList
                    .Where(s => !string.IsNullOrEmpty(s.RowChar))
                    .GroupBy(s => s.RowChar.Trim().ToUpper())
                    .OrderBy(g => g.Key.Length).ThenBy(g => g.Key) // A, B... AA
                    .ToList();

                if (rowsGroup.Count == 0)
                {
                    // Nếu code chạy vào đây nghĩa là cột RowChar trong DB bị rỗng
                    MessageBox.Show("Lỗi: Dữ liệu ghế thiếu thông tin Hàng (RowChar).");
                    return;
                }

                // 2. Dùng StackPanel dọc để chứa các hàng ghế
                StackPanel mainPanel = new StackPanel
                {
                    Orientation = Orientation.Vertical,
                    HorizontalAlignment = HorizontalAlignment.Left,
                    VerticalAlignment = VerticalAlignment.Top
                };

                foreach (var group in rowsGroup)
                {
                    // Panel ngang cho 1 hàng
                    StackPanel rowPanel = new StackPanel
                    {
                        Orientation = Orientation.Horizontal,
                        Margin = new Thickness(0, 0, 0, 10)
                    };

                    // Tên Hàng (A, B...)
                    TextBlock rowLabel = new TextBlock
                    {
                        Text = group.Key,
                        Width = 30,
                        VerticalAlignment = VerticalAlignment.Center,
                        FontWeight = FontWeights.Bold,
                        Foreground = Brushes.Gray,
                        FontSize = 14,
                        Margin = new Thickness(0, 0, 10, 0)
                    };
                    rowPanel.Children.Add(rowLabel);

                    // Vẽ các nút ghế trong hàng
                    var seatsInRow = group.OrderBy(s => s.SeatNumber).ToList();
                    foreach (var seat in seatsInRow)
                    {
                        var btn = CreateSeatButton(seat);
                        rowPanel.Children.Add(btn);
                    }

                    mainPanel.Children.Add(rowPanel);
                }

                // Thêm toàn bộ vào Grid
                SeatMapGrid.Children.Add(mainPanel);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Lỗi vẽ ghế: " + ex.Message);
            }
        }

        private Button CreateSeatButton(SeatStatus seat)
        {
            var btn = new Button
            {
                Content = seat.SeatLabel, // A1, A2...
                Tag = seat,
                Width = 45,
                Height = 40,
                Margin = new Thickness(0, 0, 6, 0), // Khoảng cách phải
                Foreground = Brushes.White,
                BorderThickness = new Thickness(1),
                BorderBrush = Brushes.Gray,
                Cursor = Cursors.Hand,
                FontSize = 12,
                FontWeight = FontWeights.SemiBold
            };

            // Màu sắc
            if (seat.IsSold)
            {
                btn.Background = new SolidColorBrush(Color.FromRgb(80, 80, 80));
                btn.Foreground = Brushes.DarkGray;
                btn.IsEnabled = false;
                btn.ToolTip = "Đã bán";
                btn.BorderThickness = new Thickness(0);
            }
            else
            {
                if (seat.SeatColor != null)
                    btn.Background = seat.SeatColor;
                else
                    btn.Background = new SolidColorBrush(Color.FromRgb(30, 40, 60));

                btn.IsEnabled = true;
                btn.ToolTip = $"{seat.CategoryName}(+{seat.BasePrice:N0}đ)";
            }

            btn.Click += SeatButton_Click;
            return btn;
        }

        private void SeatButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is SeatStatus seat && DataContext is SellTicketViewModel vm)
            {
                vm.ToggleSeat(seat);

                // Hiệu ứng chọn
                if (btn.BorderThickness.Top == 1)
                {
                    btn.BorderBrush = new SolidColorBrush(Color.FromRgb(255, 193, 7)); // Vàng
                    btn.BorderThickness = new Thickness(3);
                }
                else
                {
                    btn.BorderBrush = Brushes.Gray;
                    btn.BorderThickness = new Thickness(1);
                }
            }
        }

        private void SeatScrollViewer_PreviewMouseWheel(object sender, MouseWheelEventArgs e)
        {
            if (Keyboard.Modifiers == ModifierKeys.Control)
            {
                e.Handled = true;
                double factor = e.Delta > 0 ? 1.1 : 0.9;
                seatScale *= factor;
                if (seatScale < 0.5) seatScale = 0.5;
                if (seatScale > 3.0) seatScale = 3.0;
                SeatMapGrid.LayoutTransform = new ScaleTransform(seatScale, seatScale);
            }
        }
    }
}