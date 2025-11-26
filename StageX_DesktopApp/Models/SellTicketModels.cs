using System;
using System.ComponentModel.DataAnnotations.Schema;
using System.Windows.Media;

namespace StageX_DesktopApp.Models
{
    // Class dùng cho ComboBox chọn Vở diễn
    public class ShowInfo
    {
        public int show_id { get; set; }
        public string title { get; set; } = string.Empty;
    }

    // Class dùng cho ComboBox chọn Suất diễn
    public class PerformanceInfo
    {
        public int performance_id { get; set; }
        public DateTime performance_date { get; set; }
        public TimeSpan start_time { get; set; }
        public TimeSpan? end_time { get; set; }
        public decimal price { get; set; }
        public string Display => $"{performance_date:yyyy-MM-dd} {start_time:hh\\:mm}";
    }

    // [CLASS BỊ THIẾU GÂY RA LỖI]
    // Dùng để hứng dữ liệu từ Stored Procedure cũ (nếu còn dùng)
    public class AvailableSeat
    {
        public int seat_id { get; set; }
        public string row_char { get; set; }
        public int seat_number { get; set; }
        public string category_name { get; set; }
        public decimal base_price { get; set; }

        [NotMapped]
        public string SeatLabel => $"{row_char}{seat_number}";
    }

    // Kết quả tạo Booking
    public class CreateBookingResult { public int booking_id { get; set; } }

    // Thông tin suất diễn Giờ cao điểm
    public class PeakPerformanceInfo
    {
        public int performance_id { get; set; }
        public string show_title { get; set; } = string.Empty;
        public DateTime performance_date { get; set; }
        public TimeSpan start_time { get; set; }
        public TimeSpan? end_time { get; set; }
        public decimal price { get; set; }
        public int sold_count { get; set; }
        public int total_count { get; set; }
        public bool IsSoldOut => total_count > 0 && sold_count >= total_count;
        public string Display => $"{show_title}\n{performance_date:yyyy-MM-dd} {start_time:hh\\:mm}";
    }

    // Class trạng thái ghế (Dùng chính cho sơ đồ ghế)
    public class SeatStatus
    {
        [Column("seat_id")] public int SeatId { get; set; }
        [Column("row_char")] public string RowChar { get; set; } = string.Empty;
        [Column("seat_number")] public int SeatNumber { get; set; }
        [Column("category_name")] public string? CategoryName { get; set; }
        [Column("base_price")] public decimal BasePrice { get; set; }
        [Column("is_sold")] public bool IsSold { get; set; }
        [Column("color_class")] public string? ColorClass { get; set; }

        [NotMapped] public string SeatLabel => $"{RowChar?.Trim()}{SeatNumber}";

        [NotMapped]
        public SolidColorBrush SeatColor
        {
            get
            {
                if (string.IsNullOrWhiteSpace(ColorClass)) return new SolidColorBrush(Color.FromRgb(30, 40, 60));
                try
                {
                    string hex = ColorClass.Trim();
                    if (!hex.StartsWith("#")) hex = "#" + hex;
                    return (SolidColorBrush)new BrushConverter().ConvertFrom(hex);
                }
                catch { return new SolidColorBrush(Color.FromRgb(30, 40, 60)); }
            }
        }
    }
}