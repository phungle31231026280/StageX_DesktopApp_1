using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
namespace StageX_DesktopApp.Models
{
    [Table("user_detail")]
    public class UserDetail
    {
        [Key]
        [Column("user_id")]
        public int UserId { get; set; }
        [Column("full_name")]
        public string? FullName { get; set; }
        [Column("date_of_birth")]
        public DateTime? DateOfBirth { get; set; }
        [Column("address")]
        public string? Address { get; set; }
        [Column("phone")]
        public string? Phone { get; set; }

        public virtual User User { get; set; }
    }
}