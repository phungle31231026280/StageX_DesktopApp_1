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

            // Đăng ký sự kiện ngay khi DataContext được gán
            this.DataContextChanged += (s, e) =>
            {
                if (this.DataContext is TheaterSeatViewModel vm)
                {
                    vm.RequestDrawSeats -= BuildSeatMapSafe;
                    vm.RequestDrawSeats += BuildSeatMapSafe;
                }
            };

            // Kiểm tra DataContext ban đầu (quan trọng)
            if (this.DataContext is TheaterSeatViewModel currentVM)
            {
                currentVM.RequestDrawSeats += BuildSeatMapSafe;
            }
        }

        // Hàm vẽ ghế An Toàn (Robust)
        private void BuildSeatMapSafe(List<Seat> seatList)
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                try
                {
                    SeatMapGrid.Children.Clear();
                    _selectedSeats.Clear();
                    UpdateAssignComboBoxes(seatList);

                    if (seatList == null || seatList.Count == 0) return;

                    // 1. Nhóm ghế theo Hàng (Trim và ToUpper để tránh lỗi dữ liệu)
                    var rowsGroup = seatList
                        .Where(s => !string.IsNullOrEmpty(s.RowChar))
                        .GroupBy(s => s.RowChar.Trim().ToUpper())
                        .OrderBy(g => g.Key.Length).ThenBy(g => g.Key)
                        .ToList();

                    // 2. Dùng StackPanel để xếp gạch (An toàn hơn Grid)
                    StackPanel mainPanel = new StackPanel
                    {
                        Orientation = Orientation.Vertical,
                        HorizontalAlignment = HorizontalAlignment.Center
                    };

                    foreach (var group in rowsGroup)
                    {
                        StackPanel rowPanel = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 5), HorizontalAlignment = HorizontalAlignment.Center };

                        // Tên Hàng
                        TextBlock rowLabel = new TextBlock
                        {
                            Text = group.Key,
                            Width = 30,
                            VerticalAlignment = VerticalAlignment.Center,
                            FontWeight = FontWeights.Bold,
                            Foreground = Brushes.Gray,
                            FontSize = 14,
                            Margin = new Thickness(0, 0, 10, 0),
                            TextAlignment = TextAlignment.Right
                        };
                        rowPanel.Children.Add(rowLabel);

                        // Nút Ghế
                        foreach (var seat in group.OrderBy(s => s.SeatNumber))
                        {
                            var btn = new Button
                            {
                                Content = $"{seat.RowChar}{seat.RealSeatNumber}",
                                Tag = seat,
                                Width = 35,
                                Height = 30,
                                Margin = new Thickness(2),
                                Foreground = Brushes.Black,
                                FontWeight = FontWeights.Bold,
                                FontSize = 11
                            };

                            // Tô màu
                            if (seat.SeatCategory != null && seat.SeatCategory.DisplayColor != null)
                                btn.Background = seat.SeatCategory.DisplayColor;
                            else
                                btn.Background = Brushes.Gray; // Chưa gán hạng

                            btn.Click += SeatButton_Click;
                            rowPanel.Children.Add(btn);
                        }
                        mainPanel.Children.Add(rowPanel);
                    }
                    SeatMapGrid.Children.Add(mainPanel);
                }
                catch (Exception ex) { MessageBox.Show("Lỗi vẽ ghế: " + ex.Message); }
            });
        }

        private void SeatButton_Click(object sender, RoutedEventArgs e)
        {
            var btn = sender as Button; var seat = btn?.Tag as Seat;
            if (seat == null) return;

            if (_selectedSeats.Contains(seat))
            {
                _selectedSeats.Remove(seat);
                btn.BorderThickness = new Thickness(0);
            }
            else
            {
                _selectedSeats.Add(seat);
                btn.BorderThickness = new Thickness(3);
                btn.BorderBrush = Brushes.Red;
            }
        }

        private void UpdateAssignComboBoxes(List<Seat> seats)
        {
            if (seats == null) return;
            // Cập nhật dữ liệu cho Combobox chọn vùng
            var rows = seats.Select(s => s.RowChar.Trim().ToUpper()).Distinct().OrderBy(r => r.Length).ThenBy(r => r).ToList();
            var nums = seats.Select(s => s.SeatNumber).Distinct().OrderBy(n => n).ToList();

            AssignRowComboBox.ItemsSource = rows;
            AssignSeatStartComboBox.ItemsSource = nums;
            AssignSeatEndComboBox.ItemsSource = nums;
        }

        private void SelectRangeButton_Click(object sender, RoutedEventArgs e)
        {
            if (AssignRowComboBox.SelectedValue == null) return;
            string row = AssignRowComboBox.SelectedValue.ToString();
            int start = (int)(AssignSeatStartComboBox.SelectedValue ?? 0);
            int end = (int)(AssignSeatEndComboBox.SelectedValue ?? 100);

            if (this.DataContext is TheaterSeatViewModel vm)
            {
                var rangeSeats = vm.CurrentSeats
                    .Where(s => s.RowChar.Trim().ToUpper() == row && s.SeatNumber >= start && s.SeatNumber <= end)
                    .ToList();

                foreach (var s in rangeSeats) if (!_selectedSeats.Contains(s)) _selectedSeats.Add(s);

                // Vẽ lại để thấy viền đỏ
                BuildSeatMapSafe(vm.CurrentSeats);
                MessageBox.Show($"Đã chọn {rangeSeats.Count} ghế. Nhấn 'Áp dụng' để gán hạng.");
            }
        }

        private async void AssignSeatButton_Click(object sender, RoutedEventArgs e)
        {
            if (AssignCategoryComboBox.SelectedValue == null || _selectedSeats.Count == 0)
            {
                MessageBox.Show("Chưa chọn hạng hoặc chưa chọn ghế!"); return;
            }
            int catId = (int)AssignCategoryComboBox.SelectedValue;
            if (this.DataContext is TheaterSeatViewModel vm)
            {
                await vm.ApplyCategoryToSeats(catId, _selectedSeats);
                _selectedSeats.Clear();
            }
        }

        private void RemoveSelectedSeats_Click(object sender, RoutedEventArgs e)
        {
            if (this.DataContext is TheaterSeatViewModel vm)
            {
                if (!vm.IsCreatingNew) { MessageBox.Show("Chỉ được xóa ghế khi tạo mới!"); return; }
                vm.RemoveSeats(_selectedSeats);
                _selectedSeats.Clear();
            }
        }

        private void TextBox_GotFocus(object sender, RoutedEventArgs e)
        {
            if (sender is TextBox tb && (tb.Text.Contains("Tên") || tb.Text.Contains("Số") || tb.Text.Contains("Giá")))
            {
                tb.Text = ""; tb.Foreground = Brushes.White;
            }
        }
        private void TextBox_LostFocus(object sender, RoutedEventArgs e)
        {
            if (sender is TextBox tb && string.IsNullOrWhiteSpace(tb.Text))
            {
                tb.Foreground = Brushes.Gray;
                if (tb.Name.Contains("Name")) tb.Text = "Tên...";
                else tb.Text = "0";
            }
        }
    }
}