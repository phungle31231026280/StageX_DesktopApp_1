using System;
using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;

namespace StageX_DesktopApp.Utilities
{
    // 1. Converter cho màu nền (Background)
    public class MenuBackgroundConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            string selectedMenu = value as string;
            string targetMenu = parameter as string;

            // Nếu Menu đang chọn trùng với tham số truyền vào -> Tô màu Vàng
            if (selectedMenu == targetMenu)
            {
                return (SolidColorBrush)new BrushConverter().ConvertFrom("#FFffc107");
            }

            // Ngược lại -> Trong suốt
            return Brushes.Transparent;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => null;
    }

    // 2. Converter cho màu chữ (Foreground)
    public class MenuForegroundConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            string selectedMenu = value as string;
            string targetMenu = parameter as string;

            // Nếu đang chọn -> Chữ màu Đen (cho nổi trên nền vàng)
            if (selectedMenu == targetMenu)
            {
                return (SolidColorBrush)new BrushConverter().ConvertFrom("#FF0C1220");
            }

            // Ngược lại -> Chữ màu Trắng
            return Brushes.White;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => null;
    }

    // 3. Converter cho Font Weight (Chữ đậm hơn khi chọn)
    public class MenuFontWeightConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            string selectedMenu = value as string;
            string targetMenu = parameter as string;

            if (selectedMenu == targetMenu) return System.Windows.FontWeights.Bold;
            return System.Windows.FontWeights.SemiBold;
        }
        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => null;
    }
}