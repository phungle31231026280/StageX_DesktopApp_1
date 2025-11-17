using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("theaters")] // Ánh xạ tới bảng 'theaters'
    public class Theater
    {
        [Key]
        [Column("theater_id")]
        public int TheaterId { get; set; }

        [Column("name")]
        public string Name { get; set; }

        [Column("total_seats")]
        public int TotalSeats { get; set; }

        [Column("status")]
        public string Status { get; set; }

        // Ghi chú: Cột 'created_at' trong CSDL,
        // chúng ta không cần dùng nó trong app Admin
    }
}