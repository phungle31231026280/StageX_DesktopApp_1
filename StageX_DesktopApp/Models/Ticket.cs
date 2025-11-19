using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("tickets")] // Ánh xạ đúng tên bảng "tickets"
    public class Ticket
    {
        [Key]
        [Column("ticket_id")]
        public int TicketId { get; set; }

        [Column("booking_id")]
        public int BookingId { get; set; }

        [Column("seat_id")]
        public int SeatId { get; set; }

        [Column("ticket_code")]
        public string TicketCode { get; set; }

        [Column("status")]
        public string Status { get; set; }

        public virtual Booking Booking { get; set; }
        public virtual Seat Seat { get; set; }
    }
}