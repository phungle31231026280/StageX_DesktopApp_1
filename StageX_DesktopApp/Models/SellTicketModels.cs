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

    /// <summary>
    /// Mô tả trạng thái ghế cho một suất diễn cụ thể. Khác với AvailableSeat vì nó bao gồm
    /// cả ghế đã bán. Trường is_sold cho biết ghế đã được đặt hay chưa. Được trả về từ
    /// thủ tục proc_seats_with_status.
    /// </summary>
    public class SeatStatus
    {
        public int seat_id { get; set; }
        public string row_char { get; set; } = string.Empty;
        public int seat_number { get; set; }
        public string? category_name { get; set; }
        public decimal base_price { get; set; }
        public bool is_sold { get; set; }

        /// <summary>
        /// Mã màu hex cho hạng ghế. Thuộc tính này được trả về từ thủ tục
        /// <c>proc_seats_with_status</c>. Giá trị thường là chuỗi 6 ký tự (ví dụ "0d6efd").
        /// Nếu để trống hoặc null, mã sẽ được ánh xạ sang màu mặc định trong UI.
        /// </summary>
        public string? color_class { get; set; }

        // Tên ghế hiển thị (hàng + số)
        public string SeatLabel => $"{row_char}{seat_number}";
    }

    /// <summary>
    /// Mô tả thông tin suất diễn mở bán/đang diễn dùng cho chế độ Giờ cao điểm. Thủ tục
    /// proc_top3_nearest_performances_extended trả về các trường này. Bao gồm tên vở diễn,
    /// thời gian, giá vé, số ghế đã bán và tổng số ghế để xác định đã bán hết hay chưa.
    /// Thuộc tính Display dùng để hiển thị lên nút, và IsSoldOut để vô hiệu hoá nút khi
    /// suất diễn đã hết vé.
    /// </summary>
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

        /// <summary>
        /// Xác định suất đã bán hết vé hay chưa.
        /// </summary>
        public bool IsSoldOut => total_count > 0 && sold_count >= total_count;

        /// <summary>
        /// Chuỗi hiển thị trên nút: gồm tên vở diễn và thời gian bắt đầu. Dùng dấu xuống dòng để tách 2 dòng.
        /// </summary>
        public string Display => $"{show_title}\n{performance_date:yyyy-MM-dd} {start_time:hh\\:mm}";
    }
}