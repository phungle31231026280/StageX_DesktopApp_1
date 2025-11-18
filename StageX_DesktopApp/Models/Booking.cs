using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Net.Sockets;

namespace StageX_DesktopApp.Models
{
    [Table("bookings")] // Ghi chú: Ánh xạ đúng tên bảng "bookings"
    public class Booking
    {
        [Key]
        [Column("booking_id")]
        public int BookingId { get; set; }

        [Column("user_id")]
        public int UserId { get; set; }

        [Column("performance_id")]
        public int PerformanceId { get; set; }

        [Column("total_amount")]
        public decimal TotalAmount { get; set; }

        [Column("booking_status")]
        public string Status { get; set; } // 'Đang xử lý', 'Đã hoàn thành'...

        [Column("created_at")]
        public DateTime CreatedAt { get; set; }

        // Quan hệ
        public virtual ICollection<Ticket> Tickets { get; set; }
        public virtual ICollection<Payment> Payments { get; set; }

        // Để lấy thông tin Performance (suất diễn)
        public virtual Performance Performance { get; set; }
    }
}