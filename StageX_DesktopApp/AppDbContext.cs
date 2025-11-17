using Microsoft.EntityFrameworkCore;
using StageX_DesktopApp.Models;

namespace StageX_DesktopApp
{
    public class AppDbContext : DbContext
    {
        // Khai báo các bảng
        public DbSet<User> Users { get; set; }
        public DbSet<UserDetail> UserDetails { get; set; }

        // GHI CHÚ: THÊM 2 BẢNG MỚI
        public DbSet<Genre> Genres { get; set; }
        public DbSet<Show> Shows { get; set; }

        public DbSet<SeatCategory> SeatCategories { get; set; }

        public DbSet<Theater> Theaters { get; set; }
        public DbSet<Seat> Seats { get; set; }
        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            string connectionString = "Server=localhost;Database=stagex_db;User=root;Password=;";
            optionsBuilder.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString));
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Mối quan hệ 1-1 (User/UserDetail)
            modelBuilder.Entity<User>()
                .HasOne(u => u.UserDetail)
                .WithOne(ud => ud.User)
                .HasForeignKey<UserDetail>(ud => ud.UserId);

            // GHI CHÚ: THÊM MỐI QUAN HỆ NHIỀU-NHIỀU (Show/Genre)
            modelBuilder.Entity<Show>()
                .HasMany(s => s.Genres)
                .WithMany(g => g.Shows)
                // Ghi chú: Cấu hình bảng trung gian 'show_genres'
                .UsingEntity<Dictionary<string, object>>(
                    "show_genres", // Tên bảng trong MySQL
                    j => j.HasOne<Genre>().WithMany().HasForeignKey("genre_id"),
                    j => j.HasOne<Show>().WithMany().HasForeignKey("show_id")
                );
            modelBuilder.Entity<Seat>()
                .HasOne(s => s.Theater) // 1 Ghế thuộc 1 Rạp
                .WithMany() // (Rạp có nhiều Ghế, nhưng chúng ta chưa cần định nghĩa ngược lại)
                .HasForeignKey(s => s.TheaterId);

            modelBuilder.Entity<Seat>()
                .HasOne(s => s.SeatCategory) // 1 Ghế có 1 Hạng ghế
                .WithMany()
                .HasForeignKey(s => s.CategoryId);
        }
    }
}