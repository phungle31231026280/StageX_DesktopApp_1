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
        public DbSet<Performance> Performances { get; set; }
        public DbSet<Booking> Bookings { get; set; }
        public DbSet<Payment> Payments { get; set; }
        public DbSet<Ticket> Tickets { get; set; }

        // Các DbSet không ánh xạ tới bảng thực tế, dùng cho thống kê (dashboard)
        public DbSet<DashboardSummary> DashboardSummaries { get; set; }
        public DbSet<RevenueMonthly> RevenueMonthlies { get; set; }
        public DbSet<TicketSold> TicketSolds { get; set; }
        public DbSet<TopShow> TopShows { get; set; }

        public DbSet<Actor> Actors { get; set; }

        // Phân bố đánh giá theo sao. Lớp này phục vụ biểu đồ donut
        public DbSet<RatingDistribution> RatingDistributions { get; set; }
        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            string connectionString = "Server=localhost;Database=stagex_db;User=root;Password=;";
            optionsBuilder.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString));
        }

        // Dữ liệu trang bán vé
        public DbSet<ShowInfo> ShowInfos { get; set; }
        public DbSet<PerformanceInfo> PerformanceInfos { get; set; }
        public DbSet<AvailableSeat> AvailableSeats { get; set; }
        // Kết quả trả về khi tạo booking qua stored procedure
        public DbSet<CreateBookingResult> CreateBookingResults { get; set; }

        // Dữ liệu ghế kèm trạng thái (đã bán/chưa) cho trang bán vé
        public DbSet<SeatStatus> SeatStatuses { get; set; }
        // Dữ liệu top 3 suất diễn mở bán/đang diễn cho chế độ Giờ cao điểm
        public DbSet<PeakPerformanceInfo> PeakPerformanceInfos { get; set; }
        public DbSet<ChartDataModel> ChartDatas { get; set; }
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            modelBuilder.Entity<User>().ToTable("users");

            modelBuilder.Entity<UserDetail>(entity =>
            {
                entity.ToTable("user_detail"); // Tên bảng trong MySQL
                entity.HasKey(e => e.UserId);  // Khóa chính
            });

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

            modelBuilder.Entity<Performance>()
                .HasOne(p => p.Show) // 1 Suất diễn thuộc 1 Vở diễn
                .WithMany() // (Vở diễn có nhiều Suất diễn)
                .HasForeignKey(p => p.ShowId);

            modelBuilder.Entity<Performance>()
                .HasOne(p => p.Theater)
                .WithMany(t => t.Performances) // <-- Thêm t.Performances vào đây
                .HasForeignKey(p => p.TheaterId);

            modelBuilder.Entity<Booking>()
                .HasMany(b => b.Payments)
                .WithOne(p => p.Booking)
                .HasForeignKey(p => p.BookingId);

            modelBuilder.Entity<Booking>()
                .HasMany(b => b.Tickets)
                .WithOne(t => t.Booking)
                .HasForeignKey(t => t.BookingId);

            modelBuilder.Entity<Booking>()
               .HasOne(b => b.Performance)
               .WithMany()
               .HasForeignKey(b => b.PerformanceId);
            modelBuilder.Entity<Booking>()
                .HasOne(b => b.CreatedByUser)
                .WithMany()
                .HasForeignKey(b => b.CreatedBy)
                .OnDelete(DeleteBehavior.SetNull); ;

            modelBuilder.Entity<Ticket>()
            .HasOne(t => t.Seat)
            .WithMany()
            .HasForeignKey(t => t.SeatId);

            // Định nghĩa các thực thể không có khóa cho truy vấn báo cáo
            modelBuilder.Entity<DashboardSummary>().HasNoKey().ToView(null);
            modelBuilder.Entity<RevenueMonthly>().HasNoKey().ToView(null);
            modelBuilder.Entity<TicketSold>().HasNoKey().ToView(null);
            modelBuilder.Entity<TopShow>().HasNoKey().ToView(null);
            modelBuilder.Entity<RatingDistribution>().HasNoKey().ToView(null);

            // Thực thể cho trang bán vé (không có khóa chính)
            modelBuilder.Entity<ShowInfo>().HasNoKey().ToView(null);
            modelBuilder.Entity<PerformanceInfo>().HasNoKey().ToView(null);
            modelBuilder.Entity<AvailableSeat>().HasNoKey().ToView(null);
            modelBuilder.Entity<CreateBookingResult>().HasNoKey().ToView(null);
            modelBuilder.Entity<CreateBookingResult>().Property<int>("booking_id");

            // Thực thể trạng thái ghế và top suất diễn không có khóa. Chỉ dùng để map dữ liệu từ stored procedure.
            modelBuilder.Entity<SeatStatus>().HasNoKey().ToView(null);
            modelBuilder.Entity<PeakPerformanceInfo>().HasNoKey().ToView(null);

            modelBuilder.Entity<Actor>().ToTable("actors");
            modelBuilder.Entity<Show>()
                .HasMany(s => s.Actors)
                .WithMany(a => a.Shows)
                .UsingEntity<Dictionary<string, object>>(
                    "show_actors", // Tên bảng trong CSDL
                    j => j.HasOne<Actor>().WithMany().HasForeignKey("actor_id"),
                    j => j.HasOne<Show>().WithMany().HasForeignKey("show_id")
                );

            modelBuilder.Entity<ChartDataModel>().HasNoKey();
        }
    }
}