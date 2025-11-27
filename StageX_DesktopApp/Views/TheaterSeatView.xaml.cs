using StageX_DesktopApp.Models;
using StageX_DesktopApp.ViewModels;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace StageX_DesktopApp.Views
{
    public partial class TheaterSeatView : UserControl
    {
        private List<Seat> _selectedSeats = new List<Seat>();

        public TheaterSeatView()
        {
            InitializeComponent();

            if (this.DataContext is TheaterSeatViewModel currentVM)
            {
                SubscribeToViewModel(currentVM);
            }

            this.DataContextChanged += (s, e) =>
            {
                if (e.NewValue is TheaterSeatViewModel newVM)
                {
                    SubscribeToViewModel(newVM);
                }
            };
        }

        private void SubscribeToViewModel(TheaterSeatViewModel vm)
        {
            vm.RequestDrawSeats -= OnViewModelRequestDraw;
            vm.RequestDrawSeats += OnViewModelRequestDraw;
        }

        private void OnViewModelRequestDraw(List<Seat> seatList)
        {
            _selectedSeats.Clear();
            BuildSeatMapSafe(seatList);
        }

        private void BuildSeatMapSafe(List<Seat> seatList)
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                try
                {
                    SeatMapGrid.Children.Clear();
                    UpdateAssignComboBoxes(seatList);

                    if (seatList == null || seatList.Count == 0) return;

                    int maxSeatNum = seatList.Max(s => s.SeatNumber);

                    var rowsGroup = seatList
                        .Where(s => !string.IsNullOrEmpty(s.RowChar))
                        .GroupBy(s => s.RowChar.Trim().ToUpper())
                        .OrderBy(g => g.Key.Length).ThenBy(g => g.Key)
                        .ToList();

                    // Sử dụng StackPanel để xếp các hàng dọc
                    StackPanel mainPanel = new StackPanel
                    {
                        Orientation = Orientation.Vertical,
                        HorizontalAlignment = HorizontalAlignment.Center,
                        VerticalAlignment = VerticalAlignment.Top
                    };

                    foreach (var group in rowsGroup)
                    {
                        // StackPanel ngang cho từng hàng ghế
                        StackPanel rowPanel = new StackPanel
                        {
                            Orientation = Orientation.Horizontal,
                            Margin = new Thickness(0, 0, 0, 4), // Khoảng cách giữa các hàng
                            HorizontalAlignment = HorizontalAlignment.Center
                        };

                        // Tên Hàng (A, B...)
                        TextBlock rowLabel = new TextBlock
                        {
                            Text = group.Key,
                            Width = 25,
                            VerticalAlignment = VerticalAlignment.Center,
                            FontWeight = FontWeights.Bold,
                            Foreground = Brushes.Gray,
                            FontSize = 12, // Chữ tên hàng vừa phải
                            Margin = new Thickness(0, 0, 8, 0), // Cách ghế ra một chút
                            TextAlignment = TextAlignment.Right
                        };
                        rowPanel.Children.Add(rowLabel);

                        // Logic đếm lại số ghế thực tế
                        int realCount = 1;

                        for (int i = 1; i <= maxSeatNum; i++)
                        {
                            var seat = group.FirstOrDefault(s => s.SeatNumber == i);

                            if (seat != null)
                            {
                                seat.RealSeatNumber = realCount;
                                realCount++;

                                var btn = CreateSeatButton(seat);
                                rowPanel.Children.Add(btn);
                            }
                            else
                            {
                                // Vẽ ghế trống (Spacer) để giữ vị trí cột
                                var spacer = new Border
                                {
                                    Width = 30,  // Bằng kích thước nút
                                    Height = 26, // Bằng kích thước nút
                                    Margin = new Thickness(2), // Bằng margin nút
                                    Background = Brushes.Transparent
                                };
                                rowPanel.Children.Add(spacer);
                            }
                        }
                        mainPanel.Children.Add(rowPanel);
                    }
                    SeatMapGrid.Children.Add(mainPanel);
                }
                catch (Exception ex) { MessageBox.Show("Lỗi vẽ sơ đồ: " + ex.Message); }
            });
        }

        private Button CreateSeatButton(Seat seat)
        {
            var btn = new Button
            {
                Content = $"{seat.RowChar}{seat.RealSeatNumber}",
                Tag = seat,
                // [ĐIỀU CHỈNH KÍCH THƯỚC TẠI ĐÂY]
                Width = 30,   // Chiều rộng chuẩn (nhỏ hơn 35 của bản cũ)
                Height = 26,  // Chiều cao chuẩn (nhỏ hơn 30 của bản cũ)
                Margin = new Thickness(2), // Khoảng cách giữa các ghế
                FontSize = 10, // Cỡ chữ vừa vặn

                Foreground = Brushes.Black,
                FontWeight = FontWeights.SemiBold, // Đậm vừa phải
                BorderThickness = new Thickness(1),
                BorderBrush = Brushes.Gray,
                Padding = new Thickness(0),
                Cursor = System.Windows.Input.Cursors.Hand
            };

            // Tô màu nền
            if (seat.SeatCategory != null && !string.IsNullOrEmpty(seat.SeatCategory.ColorClass))
            {
                try
                {
                    string hex = seat.SeatCategory.ColorClass.StartsWith("#") ? seat.SeatCategory.ColorClass : "#" + seat.SeatCategory.ColorClass;
                    btn.Background = (SolidColorBrush)new BrushConverter().ConvertFrom(hex);
                }
                catch { btn.Background = Brushes.Teal; }
            }
            else
            {
                btn.Background = new SolidColorBrush(Color.FromRgb(50, 50, 50));
                btn.Foreground = Brushes.White; // Ghế chưa gán hạng thì chữ trắng
            }

            // Tô viền đỏ nếu đang chọn
            if (_selectedSeats.Any(s => (s.SeatId > 0 && s.SeatId == seat.SeatId) || (s.RowChar == seat.RowChar && s.SeatNumber == seat.SeatNumber)))
            {
                btn.BorderThickness = new Thickness(2);
                btn.BorderBrush = Brushes.Red;
            }

            btn.Click += SeatButton_Click;
            return btn;
        }

        private void SeatButton_Click(object sender, RoutedEventArgs e)
        {
            var btn = sender as Button;
            var seat = btn?.Tag as Seat;
            if (seat == null) return;

            if (DataContext is TheaterSeatViewModel vm && vm.IsReadOnlyMode) return;

            var existing = _selectedSeats.FirstOrDefault(s => s.RowChar == seat.RowChar && s.SeatNumber == seat.SeatNumber);

            if (existing != null)
            {
                _selectedSeats.Remove(existing);
                btn.BorderThickness = new Thickness(1);
                btn.BorderBrush = Brushes.Gray;
            }
            else
            {
                _selectedSeats.Add(seat);
                btn.BorderThickness = new Thickness(2);
                btn.BorderBrush = Brushes.Red;
            }
        }

        private void UpdateAssignComboBoxes(List<Seat> seats)
        {
            if (seats == null) return;
            var rows = seats.Select(s => s.RowChar.Trim().ToUpper()).Distinct().OrderBy(r => r.Length).ThenBy(r => r).ToList();
            var nums = seats.Select(s => s.SeatNumber).Distinct().OrderBy(n => n).ToList();

            AssignRowComboBox.ItemsSource = rows;
            AssignSeatStartComboBox.ItemsSource = nums;
            AssignSeatEndComboBox.ItemsSource = nums;
        }

        private void SelectRangeButton_Click(object sender, RoutedEventArgs e)
        {
            if (AssignRowComboBox.SelectedValue == null)
            {
                MessageBox.Show("Vui lòng chọn Hàng ghế!"); return;
            }

            string row = AssignRowComboBox.SelectedValue.ToString();
            int start = (int)(AssignSeatStartComboBox.SelectedValue ?? 0);
            int end = (int)(AssignSeatEndComboBox.SelectedValue ?? 1000);

            if (DataContext is TheaterSeatViewModel vm)
            {
                var range = vm.CurrentSeats.Where(s => s.RowChar.Trim().ToUpper() == row && s.SeatNumber >= start && s.SeatNumber <= end).ToList();
                int count = 0;
                foreach (var s in range)
                {
                    if (!_selectedSeats.Any(sel => sel.RowChar == s.RowChar && sel.SeatNumber == s.SeatNumber))
                    {
                        _selectedSeats.Add(s);
                        count++;
                    }
                }

                // Vẽ lại để hiện viền đỏ (Không xóa _selectedSeats)
                BuildSeatMapSafe(vm.CurrentSeats);

                if (count > 0)
                    MessageBox.Show($"Đã thêm {count} ghế vào lựa chọn. Hãy chọn Hạng ghế và bấm Áp dụng!");
                else
                    MessageBox.Show("Không tìm thấy ghế nào mới trong khoảng này.");
            }
        }

        private async void AssignSeatButton_Click(object sender, RoutedEventArgs e)
        {
            if (AssignCategoryComboBox.SelectedValue == null || _selectedSeats.Count == 0)
            {
                MessageBox.Show("Chưa chọn ghế hoặc chưa chọn hạng ghế!");
                return;
            }

            int catId = (int)AssignCategoryComboBox.SelectedValue;

            if (DataContext is TheaterSeatViewModel vm)
            {
                await vm.ApplyCategoryToSeats(catId, _selectedSeats);
                _selectedSeats.Clear();
                BuildSeatMapSafe(vm.CurrentSeats);
            }
        }

        private void RemoveSelectedSeats_Click(object sender, RoutedEventArgs e)
        {
            if (DataContext is TheaterSeatViewModel vm)
            {
                if (!vm.IsCreatingNew) { MessageBox.Show("Chỉ được xóa ghế khi tạo rạp mới!"); return; }
                if (_selectedSeats.Count == 0) return;

                vm.RemoveSeats(_selectedSeats);
                _selectedSeats.Clear();
            }
        }
    }
}