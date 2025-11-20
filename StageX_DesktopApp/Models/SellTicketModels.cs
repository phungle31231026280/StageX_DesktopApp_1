using System;

namespace StageX_DesktopApp.Models
{
    /// <summary>
    /// Đại diện cho vở diễn cơ bản để hiển thị trong combobox bán vé.
    /// </summary>
    public class ShowInfo
    {
        public int show_id { get; set; }
        public string title { get; set; } = string.Empty;
    }

    /// <summary>
    /// Đại diện cho suất diễn để chọn khi bán vé.
    /// </summary>
    public class PerformanceInfo
    {
        public int performance_id { get; set; }
        public DateTime performance_date { get; set; }
        public TimeSpan start_time { get; set; }
        /// <summary>
        /// Giờ kết thúc của suất diễn. Có thể NULL trong cơ sở dữ liệu, do đó dùng kiểu nullable.
        /// </summary>
        public TimeSpan? end_time { get; set; }
        public decimal price { get; set; }

        // Thuộc tính trợ giúp để hiển thị ngắn gọn trong ComboBox (ngày + giờ)
        public string Display
        {
            get
            {
                return $"{performance_date:yyyy-MM-dd} {start_time:hh\\:mm}";
            }
        }
    }

    /// <summary>
    /// Đại diện cho ghế còn trống và thông tin hạng ghế.
    /// </summary>
    public class AvailableSeat
    {
        public int seat_id { get; set; }
        public string row_char { get; set; } = string.Empty;
        public int seat_number { get; set; }
        public string category_name { get; set; } = string.Empty;
        public decimal base_price { get; set; }

        // Tên ghế hiển thị (kết hợp hàng + số)
        public string SeatLabel => $"{row_char}{seat_number}";
    }

    /// <summary>
    /// Kết quả trả về từ thủ tục proc_create_booking_pos (booking_id).
    /// </summary>
    public class CreateBookingResult
    {
        public int booking_id { get; set; }
    }
}