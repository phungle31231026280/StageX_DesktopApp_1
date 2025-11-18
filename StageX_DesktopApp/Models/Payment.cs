using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("payments")] // Ánh xạ đúng tên bảng "payments"
    public class Payment
    {
        [Key]
        [Column("payment_id")]
        public int PaymentId { get; set; }

        [Column("booking_id")]
        public int BookingId { get; set; }

        [Column("amount")]
        public decimal Amount { get; set; }

        [Column("status")]
        public string Status { get; set; } // 'Thành công', 'Thất bại'...

        [Column("payment_method")]
        public string PaymentMethod { get; set; }

        [Column("created_at")]
        public DateTime CreatedAt { get; set; }

        public virtual Booking Booking { get; set; }
    }
}