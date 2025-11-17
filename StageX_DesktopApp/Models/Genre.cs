using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace StageX_DesktopApp.Models
{
    [Table("genres")] // Ánh xạ tới bảng 'genres'
    public class Genre
    {
        [Key]
        [Column("genre_id")]
        public int GenreId { get; set; }

        [Column("genre_name")]
        public string GenreName { get; set; }

        // Ghi chú: Mối quan hệ Nhiều-Nhiều
        public virtual ICollection<Show> Shows { get; set; }
    }
}