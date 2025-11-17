using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("seats")] // Ánh xạ tới bảng 'seats'
    public class Seat
    {
        [Key]
        [Column("seat_id")]
        public int SeatId { get; set; }

        [Column("theater_id")]
        public int TheaterId { get; set; }

        [Column("category_id")]
        public int? CategoryId { get; set; } // Dùng ? vì nó có thể NULL

        [Column("row_char")]
        public string RowChar { get; set; }

        [Column("seat_number")]
        public int SeatNumber { get; set; }

        [Column("real_seat_number")]
        public int RealSeatNumber { get; set; }

        // Ghi chú: Mối quan hệ với Rạp và Hạng ghế
        public virtual Theater Theater { get; set; }
        public virtual SeatCategory SeatCategory { get; set; }
    }
}