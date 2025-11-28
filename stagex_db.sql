-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Nov 28, 2025 at 11:22 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `stagex_db`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_active_shows` ()   BEGIN
    -- Cập nhật trạng thái suất diễn và vở diễn trước khi lấy dữ liệu
    CALL proc_update_statuses();

    -- Trả về các vở diễn đang chiếu (chỉ những vở có ít nhất một suất đang mở bán hoặc đang diễn)
    SELECT show_id, title
    FROM shows
    WHERE status = 'Đang chiếu';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_add_show_genre` (IN `in_show_id` INT, IN `in_genre_id` INT)   BEGIN
    INSERT INTO show_genres (show_id, genre_id)
    VALUES (in_show_id, in_genre_id);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_approve_theater` (IN `in_theater_id` INT)   BEGIN
    UPDATE theaters
    SET status = 'Đã hoạt động'
    WHERE theater_id = in_theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_available_seats` (IN `in_performance_id` INT)   BEGIN
    SELECT s.seat_id,
           s.row_char,
           s.seat_number,
           IFNULL(sc.category_name, '') AS category_name,
           IFNULL(sc.base_price, 0)      AS base_price
    FROM seats s
    JOIN seat_performance sp ON sp.seat_id = s.seat_id
    LEFT JOIN seat_categories sc ON sc.category_id = s.category_id
    WHERE sp.performance_id = in_performance_id
      AND sp.status = 'trống';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_can_delete_seat_category` (IN `in_category_id` INT)   BEGIN
    SELECT COUNT(*) AS cnt
    FROM seats s
    JOIN performances p ON s.theater_id = p.theater_id
    WHERE s.category_id = in_category_id
      AND p.status = 'Đang mở bán';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_can_delete_theater` (IN `in_theater_id` INT)   BEGIN
    SELECT COUNT(*) AS cnt
    FROM performances
    WHERE theater_id = in_theater_id
      AND status = 'Đang mở bán';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_chart_last_12_months` ()   BEGIN
    SELECT 
        DATE_FORMAT(p.performance_date, '%m/%Y') as period,
        SUM(CASE WHEN sp.status != 'trống' THEN 1 ELSE 0 END) as sold_tickets,
        SUM(CASE WHEN sp.status = 'trống' THEN 1 ELSE 0 END) as unsold_tickets
    FROM performances p
    JOIN seat_performance sp ON p.performance_id = sp.performance_id
    WHERE p.performance_date >= DATE_SUB(NOW(), INTERVAL 11 MONTH)
    GROUP BY YEAR(p.performance_date), MONTH(p.performance_date)
    ORDER BY p.performance_date ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_chart_last_4_weeks` ()   BEGIN
    SELECT 
        CONCAT('Tuần ', WEEK(b.created_at, 1)) as period,
        COUNT(t.ticket_id) as sold_tickets,
        0 as unsold_tickets -- <--- Thêm cột giả này để khớp code C#
    FROM bookings b
    JOIN tickets t ON b.booking_id = t.booking_id
    JOIN payments p ON b.booking_id = p.booking_id
    WHERE p.status = 'Thành công'
      AND b.created_at >= DATE_SUB(NOW(), INTERVAL 4 WEEK)
    GROUP BY YEAR(b.created_at), WEEK(b.created_at, 1)
    ORDER BY b.created_at ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_chart_last_7_days` ()   BEGIN
    SELECT 
        DATE_FORMAT(b.created_at, '%d/%m') as period,
        COUNT(t.ticket_id) as sold_tickets,
        0 as unsold_tickets -- <--- Thêm cột giả
    FROM bookings b
    JOIN tickets t ON b.booking_id = t.booking_id
    JOIN payments p ON b.booking_id = p.booking_id
    WHERE p.status = 'Thành công'
      AND b.created_at >= DATE(NOW()) - INTERVAL 6 DAY
    GROUP BY DATE(b.created_at)
    ORDER BY b.created_at ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_check_user_exists` (IN `in_email` VARCHAR(255), IN `in_account_name` VARCHAR(255))   BEGIN
    SELECT COUNT(*) AS exists_count
    FROM users
    WHERE email = in_email OR account_name = in_account_name;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_count_performances_by_show` (IN `in_show_id` INT)   BEGIN
    SELECT COUNT(*) AS performance_count
    FROM performances
    WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_count_tickets_by_booking` (IN `in_booking_id` INT)   BEGIN
    SELECT COUNT(*) AS ticket_count
    FROM tickets
    WHERE booking_id = in_booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_booking` (IN `p_user_id` INT, IN `p_performance_id` INT, IN `p_total` DECIMAL(10,2))   BEGIN
   
    INSERT INTO bookings (
        user_id,
        performance_id,
        total_amount,
        booking_status,
        created_at
    )
    VALUES (
        p_user_id,
        p_performance_id,
        p_total,
        'Đang xử lý',
        NOW()
    );

    SELECT LAST_INSERT_ID() AS booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_booking_pos` (IN `in_user_id` INT, IN `in_performance_id` INT, IN `in_total_amount` DECIMAL(10,2), IN `in_created_by` INT)   BEGIN
    INSERT INTO bookings (user_id, performance_id, total_amount, booking_status, created_at, created_by)
    VALUES (in_user_id, in_performance_id, in_total_amount, 'Đã hoàn thành', NOW(), in_created_by);

    SELECT LAST_INSERT_ID() AS booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_genre` (IN `in_name` VARCHAR(100))   BEGIN
    INSERT INTO genres (genre_name) VALUES (in_name);
    SELECT LAST_INSERT_ID() AS genre_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_payment` (IN `in_booking_id` INT, IN `in_amount` DECIMAL(10,3), IN `in_status` VARCHAR(20), IN `in_txn_ref` VARCHAR(255), IN `in_payment_method` VARCHAR(50))   BEGIN
    INSERT INTO payments (booking_id, amount, status, vnp_txn_ref, payment_method, created_at, updated_at)
    VALUES (in_booking_id, in_amount, in_status, in_txn_ref, in_payment_method, NOW(), NOW());
    SELECT LAST_INSERT_ID() AS payment_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_performance` (IN `in_show_id` INT, IN `in_theater_id` INT, IN `in_performance_date` DATE, IN `in_start_time` TIME, IN `in_end_time` TIME, IN `in_price` DECIMAL(10,3))   BEGIN
   
    DECLARE new_pid INT;
    INSERT INTO performances (show_id, theater_id, performance_date, start_time, end_time, price, status)
    VALUES (in_show_id, in_theater_id, in_performance_date, in_start_time, in_end_time, in_price, 'Đang mở bán');
    SET new_pid = LAST_INSERT_ID();
    INSERT INTO seat_performance (seat_id, performance_id, status)
    SELECT s.seat_id, new_pid, 'trống'
    FROM seats s
    WHERE s.theater_id = in_theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_review` (IN `in_show_id` INT, IN `in_user_id` INT, IN `in_rating` INT, IN `in_content` TEXT)   BEGIN
    INSERT INTO reviews (show_id, user_id, rating, content, created_at)
    VALUES (in_show_id, in_user_id, in_rating, in_content, NOW());
    SELECT LAST_INSERT_ID() AS review_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_seat_category` (IN `in_name` VARCHAR(100), IN `in_base_price` DECIMAL(10,3), IN `in_color_class` VARCHAR(50))   BEGIN
    INSERT INTO seat_categories (category_name, base_price, color_class)
    VALUES (in_name, in_base_price, in_color_class);
    SELECT LAST_INSERT_ID() AS category_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_show` (IN `in_title` VARCHAR(255), IN `in_description` TEXT, IN `in_duration` INT, IN `in_director` VARCHAR(255), IN `in_poster` VARCHAR(255), IN `in_status` VARCHAR(50))   BEGIN
    INSERT INTO shows (title, description, duration_minutes, director, poster_image_url, status, created_at)
    VALUES (in_title, in_description, in_duration, in_director, in_poster, in_status, NOW());
    SELECT LAST_INSERT_ID() AS show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_theater` (IN `in_name` VARCHAR(255), IN `in_rows` INT, IN `in_cols` INT)   BEGIN
 
    DECLARE new_tid INT;
    DECLARE r INT DEFAULT 1;
    DECLARE c INT;

    INSERT INTO theaters (name, total_seats, status)
    VALUES (in_name, in_rows * in_cols, 'Chờ xử lý');
    SET new_tid = LAST_INSERT_ID();

   
    WHILE r <= in_rows DO
        SET c = 1;
        WHILE c <= in_cols DO
            
            INSERT INTO seats (theater_id, row_char, seat_number, real_seat_number, category_id)
            VALUES (new_tid, CHAR(64 + r), c, c, NULL);
            SET c = c + 1;
        END WHILE;
        SET r = r + 1;
    END WHILE;

   
    SELECT new_tid AS theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_ticket` (IN `p_booking_id` INT, IN `p_seat_id` INT)   BEGIN
    DECLARE v_performance_id INT;
    DECLARE v_new_code BIGINT;
    DECLARE v_exists INT DEFAULT 1;

    -- Vòng lặp sinh mã để đảm bảo không trùng
    WHILE v_exists > 0 DO
        -- Sinh số ngẫu nhiên 13 chữ số
        SET v_new_code = FLOOR(1000000000000 + RAND() * 8999999999999);
        
        -- Kiểm tra xem mã này đã tồn tại chưa
        SELECT COUNT(*) INTO v_exists FROM tickets WHERE ticket_code = v_new_code;
    END WHILE;

    -- Thêm vé mới
    INSERT INTO tickets (booking_id, seat_id, ticket_code, status, created_at)
    VALUES (p_booking_id, p_seat_id, v_new_code, 'Đang chờ', NOW());

    -- Cập nhật trạng thái ghế trong bảng seat_performance
    SELECT performance_id INTO v_performance_id
    FROM bookings
    WHERE booking_id = p_booking_id;

    IF v_performance_id IS NOT NULL THEN
        UPDATE seat_performance
        SET status = 'đã đặt'
        WHERE seat_id = p_seat_id
          AND performance_id = v_performance_id;
    END IF;
    
    -- Trả về mã vé vừa tạo (nếu cần dùng ngay)
    SELECT v_new_code AS new_ticket_code;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_user` (IN `in_email` VARCHAR(255), IN `in_password` VARCHAR(255), IN `in_account_name` VARCHAR(100), IN `in_user_type` VARCHAR(20), IN `in_verified` TINYINT(1))   BEGIN
    INSERT INTO users (email, password, account_name, user_type, status, is_verified)
    VALUES (in_email, in_password, in_account_name, in_user_type, 'hoạt động', in_verified);
    SELECT LAST_INSERT_ID() AS user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_dashboard_summary` ()   BEGIN
    SELECT 
        (SELECT COALESCE(SUM(total_amount), 0) FROM bookings b JOIN payments p ON b.booking_id = p.booking_id WHERE p.status = 'Thành công') as total_revenue,
        (SELECT COUNT(*) FROM bookings) as total_bookings,
        (SELECT COUNT(*) FROM shows) as total_shows,
        (SELECT COUNT(*) FROM genres) as total_genres;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_actor` (IN `in_actor_id` INT)   BEGIN
    DELETE FROM actors WHERE actor_id = in_actor_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_genre` (IN `in_id` INT)   BEGIN
    DELETE FROM genres WHERE genre_id = in_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_performance_if_ended` (IN `in_performance_id` INT)   BEGIN
    DELETE FROM performances
    WHERE performance_id = in_performance_id AND status = 'Đã kết thúc';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_review` (IN `in_review_id` INT)   BEGIN
    DELETE FROM reviews WHERE review_id = in_review_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_seats_by_theater` (IN `in_theater_id` INT)   BEGIN
    DELETE FROM seats WHERE theater_id = in_theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_seat_category` (IN `in_category_id` INT)   BEGIN
    DELETE FROM seat_categories WHERE category_id = in_category_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_show` (IN `in_show_id` INT)   BEGIN
    DELETE FROM shows WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_show_genres` (IN `in_show_id` INT)   BEGIN
    DELETE FROM show_genres WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_staff` (IN `in_user_id` INT)   BEGIN
    DELETE FROM users
    WHERE user_id = in_user_id
      AND user_type = 'Nhân viên';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_delete_theater` (IN `in_theater_id` INT)   BEGIN
    DELETE FROM theaters WHERE theater_id = in_theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_expire_pending_payments` ()   BEGIN
  
    UPDATE payments p
    JOIN bookings b ON p.booking_id = b.booking_id
    SET p.status = 'Thất bại',
        p.updated_at = NOW(),
        b.booking_status = 'Đã hủy'
    WHERE p.status = 'Đang chờ'
      AND TIMESTAMPDIFF(MINUTE, p.created_at, NOW()) >= 15;

    UPDATE tickets t
    JOIN payments p2 ON p2.booking_id = t.booking_id
    SET t.status = 'Đã hủy'
    WHERE p2.status = 'Thất bại'
      AND TIMESTAMPDIFF(MINUTE, p2.created_at, NOW()) >= 15
      AND t.status IN ('Đang chờ', 'Hợp lệ');

    UPDATE seat_performance sp
    JOIN tickets t2 ON sp.seat_id = t2.seat_id
    JOIN payments p3 ON p3.booking_id = t2.booking_id
    JOIN bookings b2 ON b2.booking_id = p3.booking_id
    SET sp.status = 'trống'
    WHERE p3.status = 'Thất bại'
      AND TIMESTAMPDIFF(MINUTE, p3.created_at, NOW()) >= 15
      AND sp.performance_id = b2.performance_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_actors` (IN `in_keyword` VARCHAR(255))   BEGIN
    SELECT actor_id, full_name, nick_name, avatar_url, status
    FROM actors
    WHERE in_keyword IS NULL
          OR in_keyword = ''
          OR full_name LIKE CONCAT('%', in_keyword, '%')
          OR nick_name LIKE CONCAT('%', in_keyword, '%')
    ORDER BY actor_id DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_admin_staff_users` ()   BEGIN
    SELECT *
    FROM users
    WHERE user_type IN ('Nhân viên','Admin')
    ORDER BY user_id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_bookings` ()   BEGIN
    SELECT b.*, u.email
    FROM bookings b
    JOIN users u ON b.user_id = u.user_id
    ORDER BY b.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_genres` ()   BEGIN
   
    SELECT * FROM genres ORDER BY genre_id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_performances_detailed` ()   BEGIN
    SELECT p.*, s.title, t.name AS theater_name
    FROM performances p
    JOIN shows s ON p.show_id = s.show_id
    JOIN theaters t ON p.theater_id = t.theater_id
    ORDER BY p.performance_date, p.start_time;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_reviews` ()   BEGIN
 
    SELECT r.*, r.show_id AS show_id, u.account_name AS account_name, s.title
    FROM reviews r
    JOIN users u ON r.user_id = u.user_id
    JOIN shows s ON r.show_id = s.show_id
    ORDER BY r.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_seat_categories` ()   BEGIN
    SELECT * FROM seat_categories ORDER BY category_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_shows` ()   BEGIN
    SELECT s.*, GROUP_CONCAT(g.genre_name SEPARATOR ', ') AS genres
    FROM shows s
    LEFT JOIN show_genres sg ON s.show_id = sg.show_id
    LEFT JOIN genres g ON sg.genre_id = g.genre_id
    GROUP BY s.show_id
    ORDER BY s.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_all_theaters` ()   BEGIN

    SELECT * FROM theaters ORDER BY theater_id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_average_rating_by_show` (IN `in_show_id` INT)   BEGIN
    SELECT AVG(rating) AS avg_rating
    FROM reviews
    WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_booked_seat_ids` (IN `in_performance_id` INT)   BEGIN

    SELECT sp.seat_id
    FROM seat_performance sp
    WHERE sp.performance_id = in_performance_id
      AND sp.status = 'đã đặt';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_bookings_by_user` (IN `in_user_id` INT)   BEGIN
    SELECT * FROM bookings
    WHERE user_id = in_user_id
    ORDER BY created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_booking_with_tickets` (IN `in_booking_id` INT)   BEGIN
 
    SELECT b.*, t.ticket_id, t.ticket_code, s.row_char, s.real_seat_number AS seat_number,
           sc.category_name, sc.color_class,
           (p.price + sc.base_price) AS ticket_price
    FROM bookings b
    LEFT JOIN tickets t ON b.booking_id = t.booking_id
    LEFT JOIN seats s ON t.seat_id = s.seat_id
    LEFT JOIN seat_categories sc ON s.category_id = sc.category_id
    LEFT JOIN performances p ON b.performance_id = p.performance_id
    WHERE b.booking_id = in_booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_genre_ids_by_show` (IN `in_show_id` INT)   BEGIN
    SELECT genre_id
    FROM show_genres
    WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_latest_reviews` (IN `in_limit` INT)   BEGIN
    SELECT r.*, u.account_name AS account_name, s.title AS show_title
    FROM reviews r
    JOIN users u ON r.user_id = u.user_id
    JOIN shows s ON r.show_id = s.show_id
    ORDER BY r.created_at DESC
    LIMIT in_limit;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_payments_by_booking` (IN `in_booking_id` INT)   BEGIN
    SELECT * FROM payments WHERE booking_id = in_booking_id ORDER BY created_at ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_payment_by_txn` (IN `in_txn_ref` VARCHAR(255))   BEGIN
    SELECT * FROM payments WHERE vnp_txn_ref = in_txn_ref LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_performances_by_show` (IN `in_show_id` INT)   BEGIN
    SELECT p.*, t.name AS theater_name
    FROM performances p
    JOIN theaters t ON p.theater_id = t.theater_id
 
    WHERE p.show_id = in_show_id AND p.status = 'Đang mở bán'
    ORDER BY p.performance_date, p.start_time;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_performance_by_id` (IN `in_performance_id` INT)   BEGIN
    SELECT p.*, t.name AS theater_name
    FROM performances p
    JOIN theaters t ON p.theater_id = t.theater_id
    WHERE p.performance_id = in_performance_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_performance_detailed_by_id` (IN `in_performance_id` INT)   BEGIN
    SELECT p.*, s.title, t.name AS theater_name
    FROM performances p
    JOIN shows s ON p.show_id = s.show_id
    JOIN theaters t ON p.theater_id = t.theater_id
    WHERE p.performance_id = in_performance_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_reviews_by_show` (IN `in_show_id` INT)   BEGIN
  
    SELECT r.*, u.account_name AS account_name
    FROM reviews r
    JOIN users u ON r.user_id = u.user_id
    WHERE r.show_id = in_show_id
    ORDER BY r.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_seats_for_theater` (IN `in_theater_id` INT)   BEGIN
  
    SELECT
        s.seat_id,
        s.theater_id,
        s.category_id,
        s.row_char,
        s.seat_number,
        s.real_seat_number,
        s.created_at,
        c.category_name,
        c.base_price,
        c.color_class
    FROM seats s
    LEFT JOIN seat_categories c ON s.category_id = c.category_id
    WHERE s.theater_id = in_theater_id
    ORDER BY s.row_char, s.seat_number;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_seat_categories` ()   BEGIN
    SELECT category_id, category_name, base_price, color_class
    FROM seat_categories
    ORDER BY category_id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_seat_category_by_id` (IN `in_category_id` INT)   BEGIN
    SELECT * FROM seat_categories WHERE category_id = in_category_id LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_seat_category_by_price` (IN `in_base_price` DECIMAL(10,3))   BEGIN
    SELECT * FROM seat_categories WHERE base_price = in_base_price LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_show_by_id` (IN `in_show_id` INT)   BEGIN
    SELECT s.*, GROUP_CONCAT(g.genre_name SEPARATOR ', ') AS genres
    FROM shows s
    LEFT JOIN show_genres sg ON s.show_id = sg.show_id
    LEFT JOIN genres g ON sg.genre_id = g.genre_id
    WHERE s.show_id = in_show_id
    GROUP BY s.show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_staff_users` ()   BEGIN
    SELECT * FROM users WHERE user_type = 'Nhân viên' ORDER BY user_id ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_user_bookings_detailed` (IN `in_user_id` INT)   BEGIN
  
    SELECT b.*, GROUP_CONCAT(CONCAT(s.row_char, s.real_seat_number) ORDER BY s.row_char, s.seat_number SEPARATOR ', ') AS seats
    FROM bookings b
    LEFT JOIN tickets t ON b.booking_id = t.booking_id
    LEFT JOIN seats s ON t.seat_id = s.seat_id
    WHERE b.user_id = in_user_id
    GROUP BY b.booking_id
    ORDER BY b.created_at DESC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_user_by_account_name` (IN `in_account_name` VARCHAR(100))   BEGIN
    SELECT * FROM users WHERE account_name = in_account_name LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_user_by_email` (IN `in_email` VARCHAR(255))   BEGIN
    SELECT * FROM users WHERE email = in_email LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_user_by_id` (IN `in_user_id` INT)   BEGIN
    SELECT * FROM users WHERE user_id = in_user_id LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_get_user_detail_by_id` (IN `in_user_id` INT)   BEGIN
    SELECT * FROM user_detail WHERE user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_insert_actor` (IN `in_full_name` VARCHAR(255), IN `in_nick_name` VARCHAR(255), IN `in_avatar_url` VARCHAR(255), IN `in_status` VARCHAR(50))   BEGIN
    INSERT INTO actors (full_name, nick_name, avatar_url, status, created_at)
    VALUES (in_full_name, in_nick_name, in_avatar_url, in_status, NOW());
    SELECT LAST_INSERT_ID() AS actor_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_modify_theater_size` (IN `in_theater_id` INT, IN `in_add_rows` INT, IN `in_add_cols` INT)   BEGIN
    DECLARE maxRowChar CHAR(1);
    DECLARE oldRows INT;
    DECLARE oldCols INT;
    DECLARE r INT;
    DECLARE c INT;
    DECLARE addc INT;
 
    SELECT MAX(row_char) INTO maxRowChar FROM seats WHERE theater_id = in_theater_id;
    IF maxRowChar IS NULL THEN
        SET oldRows = 0;
    ELSE
        SET oldRows = ASCII(maxRowChar) - 64;
    END IF;
    SELECT MAX(seat_number) INTO oldCols FROM seats WHERE theater_id = in_theater_id;
    IF oldCols IS NULL THEN
        SET oldCols = 0;
    END IF;
  
    IF in_add_rows > 0 THEN
        SET r = oldRows + 1;
        WHILE r <= oldRows + in_add_rows DO
            SET c = 1;
            WHILE c <= oldCols DO
                INSERT INTO seats (theater_id, row_char, seat_number, real_seat_number, category_id)
                VALUES (in_theater_id, CHAR(64 + r), c, c, NULL);
                SET c = c + 1;
            END WHILE;
            SET r = r + 1;
        END WHILE;
    END IF;
 
    IF in_add_rows < 0 THEN
        DELETE FROM seats
        WHERE theater_id = in_theater_id
          AND (ASCII(row_char) - 64) > oldRows + in_add_rows;
    END IF;
  
    IF in_add_cols > 0 THEN
        SET addc = 1;
        WHILE addc <= in_add_cols DO
            INSERT INTO seats (theater_id, row_char, seat_number, real_seat_number, category_id)
            SELECT in_theater_id, row_char, oldCols + addc, oldCols + addc, NULL
            FROM (SELECT DISTINCT row_char FROM seats WHERE theater_id = in_theater_id) AS row_list;
            SET addc = addc + 1;
        END WHILE;
    END IF;

    IF in_add_cols < 0 THEN
        DELETE FROM seats
        WHERE theater_id = in_theater_id
          AND seat_number > oldCols + in_add_cols;
    END IF;

    CALL proc_update_theater_seat_counts();
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_performances_by_show` (IN `in_show_id` INT)   BEGIN
    -- Cập nhật trạng thái suất diễn và vở diễn trước khi lấy dữ liệu
    CALL proc_update_statuses();

    -- Trả về các suất chiếu thuộc vở diễn đang mở bán
    SELECT performance_id,
           performance_date,
           start_time,
           end_time,
           price
    FROM performances
    WHERE show_id = in_show_id
      AND status = 'Đang mở bán';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_rating_distribution` ()   BEGIN
    SELECT rating as star, COUNT(*) as rating_count
    FROM reviews
    GROUP BY rating
    ORDER BY rating;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_revenue_monthly` ()   BEGIN
    SELECT 
        DATE_FORMAT(b.created_at, '%m/%Y') as month, 
        COALESCE(SUM(b.total_amount), 0) as total_revenue
    FROM bookings b
    JOIN payments p ON b.booking_id = p.booking_id
    WHERE p.status = 'Thành công'
    GROUP BY YEAR(b.created_at), MONTH(b.created_at)
    ORDER BY b.created_at ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_seats_with_status` (IN `in_performance_id` INT)   BEGIN
    /*
      Trả về danh sách ghế và trạng thái bán cho một suất diễn.
      GHI CHÚ: Bổ sung trường color_class để phía ứng dụng có thể tự tạo màu ghế.
      Thứ tự và alias của các cột phải khớp với lớp SeatStatus trong mã nguồn.
    */
    SELECT s.seat_id                    AS seat_id,
           s.row_char                   AS row_char,
           s.seat_number                AS seat_number,
           IFNULL(sc.category_name, '') AS category_name,
           IFNULL(sc.base_price, 0)     AS base_price,
           (sp.status <> 'trống')       AS is_sold,
           sc.color_class               AS color_class
    FROM seats s
    JOIN seat_performance sp ON sp.seat_id = s.seat_id
    LEFT JOIN seat_categories sc ON sc.category_id = s.category_id
    WHERE sp.performance_id = in_performance_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_set_user_otp` (IN `in_user_id` INT, IN `in_otp_code` VARCHAR(10), IN `in_expires` DATETIME)   BEGIN
    UPDATE users
    SET otp_code = in_otp_code,
        otp_expires_at = in_expires
    WHERE user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_sold_tickets_daily` ()   BEGIN
    /*
      Trả về danh sách số lượng vé đã bán theo từng ngày.
      Vé được coi là đã bán khi status nằm trong ('Hợp lệ','Đã sử dụng').
    */
    SELECT DATE_FORMAT(t.created_at, '%Y-%m-%d') AS period,
           COUNT(*) AS sold_tickets
    FROM tickets t
    WHERE t.status IN ('Hợp lệ','Đã sử dụng')
    GROUP BY DATE_FORMAT(t.created_at, '%Y-%m-%d')
    ORDER BY DATE_FORMAT(t.created_at, '%Y-%m-%d');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_sold_tickets_monthly` ()   BEGIN
    /*
      Trả về số lượng vé bán cho mỗi tháng (yyyy-mm).
    */
    SELECT DATE_FORMAT(t.created_at, '%Y-%m') AS period,
           COUNT(*) AS sold_tickets
    FROM tickets t
    WHERE t.status IN ('Hợp lệ','Đã sử dụng')
    GROUP BY DATE_FORMAT(t.created_at, '%Y-%m')
    ORDER BY DATE_FORMAT(t.created_at, '%Y-%m');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_sold_tickets_weekly` ()   BEGIN
    /*
      Trả về số lượng vé bán cho mỗi tuần ISO (năm và số tuần).
      period trả về dạng YEARWEEK ISO.
    */
    SELECT CONVERT(YEARWEEK(t.created_at, 3), CHAR) AS period,
           COUNT(*) AS sold_tickets
    FROM tickets t
    WHERE t.status IN ('Hợp lệ','Đã sử dụng')
    GROUP BY YEARWEEK(t.created_at, 3)
    ORDER BY YEARWEEK(t.created_at, 3);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_sold_tickets_yearly` ()   BEGIN
    SELECT 
        CONVERT(YEAR(t.created_at), CHAR) AS period,
        COUNT(*) AS sold_tickets,
        0 as unsold_tickets -- <--- Thêm cột giả
    FROM tickets t
    WHERE t.status IN ('Hợp lệ','Đã sử dụng')
    GROUP BY YEAR(t.created_at)
    ORDER BY YEAR(t.created_at);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_top3_nearest_performances` ()   BEGIN
    -- Cập nhật trạng thái suất diễn và vở diễn để đảm bảo dữ liệu chính xác
    CALL proc_update_statuses();
    -- Lấy các suất đang mở bán hoặc đang diễn, sắp xếp tăng dần theo ngày giờ bắt đầu, giới hạn 3 suất
    SELECT performance_id,
           performance_date,
           start_time,
           end_time,
           price
    FROM performances
    WHERE status IN ('Đang mở bán','Đang diễn')
    ORDER BY CONCAT(performance_date, ' ', start_time) ASC
    LIMIT 3;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_top3_nearest_performances_extended` ()   BEGIN
    -- Cập nhật trạng thái trước khi lấy dữ liệu
    CALL proc_update_statuses();
    -- Lấy top 3 suất diễn sớm nhất đang mở bán hoặc đang diễn, kèm thông tin vở diễn và số vé đã bán
    SELECT p.performance_id,
           s.title AS show_title,
           p.performance_date,
           p.start_time,
           p.end_time,
           p.price,
           SUM(sp.status <> 'trống') AS sold_count,
           COUNT(sp.seat_id)         AS total_count
    FROM performances p
    JOIN shows s ON s.show_id = p.show_id
    JOIN seat_performance sp ON sp.performance_id = p.performance_id
    WHERE p.status IN ('Đang mở bán','Đang diễn')
    GROUP BY p.performance_id
    ORDER BY CONCAT(p.performance_date, ' ', p.start_time) ASC
    LIMIT 3;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_top5_shows_by_date_range` (IN `p_start_date` DATETIME, IN `p_end_date` DATETIME)   BEGIN
    SELECT 
        s.title as show_name, 
        COUNT(t.ticket_id) as sold_tickets
    FROM shows s
    JOIN performances p ON s.show_id = p.show_id
    JOIN bookings b ON p.performance_id = b.performance_id
    JOIN tickets t ON b.booking_id = t.booking_id
    JOIN payments pay ON b.booking_id = pay.booking_id
    WHERE pay.status = 'Thành công'
      -- Nếu tham số NULL thì lấy hết, ngược lại lọc theo ngày tạo đơn
      AND (p_start_date IS NULL OR b.created_at >= p_start_date)
      AND (p_end_date IS NULL OR b.created_at <= p_end_date)
    GROUP BY s.show_id
    ORDER BY sold_tickets DESC
    LIMIT 5;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_top5_shows_by_tickets` ()   BEGIN
    SELECT 
        s.title as show_name, 
        COUNT(t.ticket_id) as sold_tickets
    FROM shows s
    JOIN performances p ON s.show_id = p.show_id
    JOIN bookings b ON p.performance_id = b.performance_id
    JOIN tickets t ON b.booking_id = t.booking_id
    JOIN payments pay ON b.booking_id = pay.booking_id
    WHERE pay.status = 'Thành công'
    GROUP BY s.show_id
    ORDER BY sold_tickets DESC
    LIMIT 5;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_actor` (IN `in_actor_id` INT, IN `in_full_name` VARCHAR(255), IN `in_nick_name` VARCHAR(255), IN `in_avatar_url` VARCHAR(255), IN `in_status` VARCHAR(50))   BEGIN
    UPDATE actors
    SET full_name = in_full_name,
        nick_name = in_nick_name,
        avatar_url = in_avatar_url,
        status = in_status
    WHERE actor_id = in_actor_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_booking_status` (IN `in_booking_id` INT, IN `in_booking_status` VARCHAR(20))   BEGIN
    UPDATE bookings
    SET booking_status = in_booking_status
    WHERE booking_id = in_booking_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_genre` (IN `in_id` INT, IN `in_name` VARCHAR(100))   BEGIN
    UPDATE genres
    SET genre_name = in_name
    WHERE genre_id = in_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_payment_status` (IN `in_txn_ref` VARCHAR(255), IN `in_status` VARCHAR(20), IN `in_bank_code` VARCHAR(255), IN `in_pay_date` VARCHAR(255))   BEGIN

    UPDATE payments
    SET status = in_status,
        vnp_bank_code = in_bank_code,
        vnp_pay_date = in_pay_date,
        updated_at = NOW()
    WHERE vnp_txn_ref = in_txn_ref;

    IF in_status = 'Thất bại' THEN
      
        UPDATE bookings b
        JOIN payments p ON p.booking_id = b.booking_id
        SET b.booking_status = 'Đã hủy'
        WHERE p.vnp_txn_ref = in_txn_ref;

        UPDATE tickets t
        JOIN payments p2 ON p2.booking_id = t.booking_id
        SET t.status = 'Đã hủy'
        WHERE p2.vnp_txn_ref = in_txn_ref
          AND t.status IN ('Đang chờ','Hợp lệ');

        UPDATE seat_performance sp
        JOIN tickets t2 ON sp.seat_id = t2.seat_id
        JOIN payments p3 ON p3.booking_id = t2.booking_id
        JOIN bookings b2 ON b2.booking_id = p3.booking_id
        SET sp.status = 'trống'
        WHERE p3.vnp_txn_ref = in_txn_ref
          AND sp.performance_id = b2.performance_id;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_performance_statuses` ()   BEGIN
    UPDATE performances
    SET status = 'Đã kết thúc'
    WHERE status NOT IN ('Đã kết thúc','Đã hủy')
      AND (
        performance_date < CURDATE()
        OR (performance_date = CURDATE() AND end_time IS NOT NULL AND end_time < CURTIME())
      );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_performance_status_single` (IN `in_performance_id` INT, IN `in_status` VARCHAR(20))   BEGIN
    UPDATE performances
    SET status = in_status
    WHERE performance_id = in_performance_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_seat_category` (IN `in_category_id` INT, IN `in_name` VARCHAR(100), IN `in_base_price` DECIMAL(10,3), IN `in_color_class` VARCHAR(50))   BEGIN
    UPDATE seat_categories
    SET category_name = in_name,
        base_price    = in_base_price,
        color_class   = in_color_class
    WHERE category_id = in_category_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_seat_category_range` (IN `in_theater_id` INT, IN `in_row_char` CHAR(1), IN `in_start_seat` INT, IN `in_end_seat` INT, IN `in_category_id` INT)   BEGIN
 
    UPDATE seats
    SET category_id = IF(in_category_id = 0, NULL, in_category_id)
    WHERE theater_id = in_theater_id
      AND row_char = in_row_char
      AND seat_number BETWEEN in_start_seat AND in_end_seat;

    SET @rn := 0;
    UPDATE seats s
    JOIN (
        SELECT seat_id, (@rn := @rn + 1) AS new_num
        FROM seats
        WHERE theater_id = in_theater_id
          AND row_char = in_row_char
          AND category_id IS NOT NULL
        ORDER BY seat_number
    ) AS ordered ON s.seat_id = ordered.seat_id
    SET s.real_seat_number = ordered.new_num;

    UPDATE seats
    SET real_seat_number = 0
    WHERE theater_id = in_theater_id
      AND row_char = in_row_char
      AND category_id IS NULL;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_show_details` (IN `in_show_id` INT, IN `in_title` VARCHAR(255), IN `in_description` TEXT, IN `in_duration` INT, IN `in_director` VARCHAR(255), IN `in_poster` VARCHAR(255))   BEGIN
    UPDATE shows
    SET title            = in_title,
        description      = in_description,
        duration_minutes = in_duration,
        director         = in_director,
        poster_image_url = in_poster
    WHERE show_id = in_show_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_show_statuses` ()   BEGIN

    UPDATE shows s
    SET s.status = (
        CASE
            WHEN (SELECT COUNT(*) FROM performances p WHERE p.show_id = s.show_id) = 0 THEN 'Sắp chiếu'
            WHEN (SELECT COUNT(*) FROM performances p WHERE p.show_id = s.show_id AND p.status <> 'Đã kết thúc') = 0 THEN 'Đã kết thúc'
            ELSE 'Đang chiếu'
        END
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_staff_user` (IN `in_user_id` INT, IN `in_account_name` VARCHAR(100), IN `in_email` VARCHAR(255), IN `in_status` VARCHAR(50))   BEGIN
    UPDATE users
    SET account_name = in_account_name,
        email        = in_email,
        status       = in_status
    WHERE user_id = in_user_id AND user_type = 'Nhân viên';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_statuses` ()   BEGIN
    -- Cập nhật trạng thái cho bảng performances
    UPDATE performances
    SET status =
        CASE
            -- Nếu thời gian kết thúc < thời gian hiện tại thì đã kết thúc
            WHEN (
                CONCAT(performance_date, ' ', COALESCE(end_time, start_time)) < NOW()
            ) THEN 'Đã kết thúc'
            -- Nếu đã bắt đầu nhưng chưa kết thúc => đang diễn
            WHEN (
                CONCAT(performance_date, ' ', start_time) <= NOW() AND
                (
                    end_time IS NULL OR CONCAT(performance_date, ' ', end_time) >= NOW()
                )
            ) THEN 'Đang diễn'
            -- Còn lại là đang mở bán
            ELSE 'Đang mở bán'
        END;

    -- Cập nhật trạng thái cho bảng shows
    UPDATE shows s
    SET s.status = (
        CASE
            -- Nếu có ít nhất một suất đang mở bán hoặc đang diễn => Đang chiếu
            WHEN EXISTS (
                SELECT 1 FROM performances p
                WHERE p.show_id = s.show_id
                  AND p.status IN ('Đang mở bán', 'Đang diễn')
            ) THEN 'Đang chiếu'
            -- Nếu tất cả các suất đều đã kết thúc => Đã kết thúc
            WHEN NOT EXISTS (
                SELECT 1 FROM performances p
                WHERE p.show_id = s.show_id AND p.status <> 'Đã kết thúc'
            ) THEN 'Đã kết thúc'
            ELSE s.status
        END
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_theater` (IN `in_theater_id` INT, IN `in_name` VARCHAR(255))   BEGIN
    UPDATE theaters
    SET name = in_name
    WHERE theater_id = in_theater_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_theater_seat_counts` ()   BEGIN
    UPDATE theaters t
    LEFT JOIN (
        SELECT theater_id, COUNT(seat_id) AS total_seats
        FROM seats
        GROUP BY theater_id
    ) AS seat_count
    ON t.theater_id = seat_count.theater_id
    SET t.total_seats = COALESCE(seat_count.total_seats, 0);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_unverified_user_password_email` (IN `in_user_id` INT, IN `in_password` VARCHAR(255), IN `in_email` VARCHAR(255))   BEGIN
    UPDATE users
    SET password = in_password,
        email = in_email
    WHERE user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_unverified_user_password_name` (IN `in_user_id` INT, IN `in_password` VARCHAR(255), IN `in_account_name` VARCHAR(100))   BEGIN
    UPDATE users
    SET password = in_password,
        account_name = in_account_name
    WHERE user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_update_user_password` (IN `in_user_id` INT, IN `in_password` VARCHAR(255))   BEGIN
    UPDATE users
    SET password = in_password,
        otp_code = NULL,
        otp_expires_at = NULL
    WHERE user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_upsert_user_detail` (IN `in_user_id` INT, IN `in_full_name` VARCHAR(255), IN `in_date_of_birth` DATE, IN `in_address` VARCHAR(255), IN `in_phone` VARCHAR(20))   BEGIN
    INSERT INTO user_detail (user_id, full_name, date_of_birth, address, phone)
    VALUES (in_user_id, in_full_name, in_date_of_birth, in_address, in_phone)
    ON DUPLICATE KEY UPDATE
        full_name     = VALUES(full_name),
        date_of_birth = VALUES(date_of_birth),
        address       = VALUES(address),
        phone         = VALUES(phone);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_verify_user_otp` (IN `in_user_id` INT, IN `in_otp_code` VARCHAR(10))   BEGIN
    DECLARE v INT DEFAULT 0;
    SELECT CASE
            WHEN otp_code = in_otp_code AND otp_expires_at >= NOW() THEN 1
            ELSE 0
        END AS verified
    INTO v
    FROM users
    WHERE user_id = in_user_id;
    IF v = 1 THEN
        UPDATE users
        SET is_verified = 1,
            otp_code = NULL,
            otp_expires_at = NULL
        WHERE user_id = in_user_id;
    END IF;
    SELECT v AS verified;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `actors`
--

CREATE TABLE `actors` (
  `actor_id` int(11) NOT NULL,
  `full_name` varchar(255) NOT NULL,
  `nick_name` varchar(255) DEFAULT NULL,
  `avatar_url` varchar(500) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `status` enum('Hoạt động','Ngừng hoạt động') NOT NULL DEFAULT 'Hoạt động',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `actors`
--

INSERT INTO `actors` (`actor_id`, `full_name`, `nick_name`, `avatar_url`, `email`, `phone`, `status`, `created_at`) VALUES
(1, 'Thành Lộc', 'Phù thủy sân khấu', NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(2, 'Hữu Châu', NULL, NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(3, 'Hồng Vân', 'NSND Hồng Vân', NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(4, 'Hoài Linh', 'Sáu Bảnh', NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(5, 'Trấn Thành', 'A Xìn', NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(6, 'Thu Trang', 'Hoa hậu hài', NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(7, 'Tiến Luật', NULL, NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(8, 'Diệu Nhi', NULL, NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(9, 'Minh Dự', 'Thánh chửi', NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58'),
(10, 'Hải Triều', 'Lụa', NULL, NULL, NULL, 'Hoạt động', '2025-11-22 14:30:58');

-- --------------------------------------------------------

--
-- Table structure for table `bookings`
--

CREATE TABLE `bookings` (
  `booking_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `performance_id` int(11) NOT NULL,
  `total_amount` decimal(10,3) NOT NULL,
  `booking_status` enum('Đang xử lý','Đã hoàn thành','Đã hủy') NOT NULL DEFAULT 'Đang xử lý',
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  `created_by` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `bookings`
--

INSERT INTO `bookings` (`booking_id`, `user_id`, `performance_id`, `total_amount`, `booking_status`, `created_at`, `created_by`) VALUES
(1, NULL, 32, 6000000.000, 'Đã hoàn thành', '2025-01-01 09:59:00', 22),
(2, NULL, 31, 5100000.000, 'Đã hoàn thành', '2025-01-01 17:57:00', 27),
(3, NULL, 17, 5800000.000, 'Đã hoàn thành', '2025-01-02 01:12:00', 28),
(4, NULL, 42, 3200000.000, 'Đã hoàn thành', '2025-01-02 08:11:00', 28),
(5, NULL, 50, 5900000.000, 'Đã hoàn thành', '2025-01-02 16:00:00', 27),
(6, NULL, 20, 4800000.000, 'Đã hoàn thành', '2025-01-03 00:17:00', 6),
(7, NULL, 19, 4000000.000, 'Đã hoàn thành', '2025-01-03 07:13:00', 28),
(8, NULL, 18, 2500000.000, 'Đã hoàn thành', '2025-01-03 14:22:00', 22),
(9, NULL, 32, 3300000.000, 'Đã hoàn thành', '2025-01-03 22:46:00', 28),
(10, NULL, 34, 3700000.000, 'Đã hoàn thành', '2025-01-04 07:52:00', 22),
(11, NULL, 42, 3000000.000, 'Đã hoàn thành', '2025-01-04 15:22:00', 27),
(12, NULL, 50, 5500000.000, 'Đã hoàn thành', '2025-01-04 22:47:00', 27),
(13, NULL, 19, 5100000.000, 'Đã hoàn thành', '2025-01-05 06:03:00', 27),
(14, NULL, 19, 3800000.000, 'Đã hoàn thành', '2025-01-05 12:45:00', 28),
(15, NULL, 50, 2600000.000, 'Đã hoàn thành', '2025-01-05 21:24:00', 6),
(16, NULL, 15, 4700000.000, 'Đã hoàn thành', '2025-01-06 06:06:00', 28),
(17, NULL, 42, 3800000.000, 'Đã hoàn thành', '2025-01-06 14:26:00', 6),
(18, NULL, 51, 5400000.000, 'Đã hoàn thành', '2025-01-06 23:04:00', 27),
(19, NULL, 18, 6000000.000, 'Đã hoàn thành', '2025-01-07 06:13:00', 6),
(20, NULL, 17, 2900000.000, 'Đã hoàn thành', '2025-01-07 13:31:00', 27),
(21, NULL, 32, 3100000.000, 'Đã hoàn thành', '2025-01-07 20:28:00', 28),
(22, NULL, 16, 6000000.000, 'Đã hoàn thành', '2025-01-08 03:56:00', 27),
(23, NULL, 51, 4100000.000, 'Đã hoàn thành', '2025-01-08 11:47:00', 27),
(24, NULL, 51, 4100000.000, 'Đã hoàn thành', '2025-01-08 20:50:00', 6),
(25, NULL, 15, 2800000.000, 'Đã hoàn thành', '2025-01-09 04:08:00', 6),
(26, NULL, 19, 4000000.000, 'Đã hoàn thành', '2025-01-09 12:32:00', 6),
(27, NULL, 18, 2500000.000, 'Đã hoàn thành', '2025-01-09 21:36:00', 28),
(28, NULL, 16, 4400000.000, 'Đã hoàn thành', '2025-01-10 05:32:00', 28),
(29, NULL, 52, 2100000.000, 'Đã hoàn thành', '2025-01-10 12:27:00', 27),
(30, NULL, 16, 3500000.000, 'Đã hoàn thành', '2025-01-10 20:26:00', 27),
(31, NULL, 50, 4800000.000, 'Đã hoàn thành', '2025-01-11 05:07:00', 27),
(32, NULL, 16, 4700000.000, 'Đã hoàn thành', '2025-01-11 12:28:00', 6),
(33, NULL, 41, 4400000.000, 'Đã hoàn thành', '2025-01-11 19:42:00', 28),
(34, NULL, 42, 3200000.000, 'Đã hoàn thành', '2025-01-12 02:28:00', 27),
(35, NULL, 50, 2600000.000, 'Đã hoàn thành', '2025-01-12 11:15:00', 6),
(36, NULL, 32, 4200000.000, 'Đã hoàn thành', '2025-01-12 20:12:00', 6),
(37, NULL, 31, 5700000.000, 'Đã hoàn thành', '2025-01-13 05:18:00', 27),
(38, NULL, 42, 2100000.000, 'Đã hoàn thành', '2025-01-13 12:15:00', 6),
(39, NULL, 34, 2700000.000, 'Đã hoàn thành', '2025-01-13 20:41:00', 28),
(40, NULL, 32, 5900000.000, 'Đã hoàn thành', '2025-01-14 03:23:00', 22),
(41, NULL, 52, 4000000.000, 'Đã hoàn thành', '2025-01-14 11:13:00', 28),
(42, NULL, 32, 4500000.000, 'Đã hoàn thành', '2025-01-14 19:27:00', 27),
(43, NULL, 52, 5500000.000, 'Đã hoàn thành', '2025-01-15 03:50:00', 6),
(44, NULL, 51, 2400000.000, 'Đã hoàn thành', '2025-01-15 12:53:00', 27),
(45, NULL, 41, 4100000.000, 'Đã hoàn thành', '2025-01-15 21:03:00', 28),
(46, NULL, 31, 4000000.000, 'Đã hoàn thành', '2025-01-16 05:20:00', 28),
(47, NULL, 42, 5600000.000, 'Đã hoàn thành', '2025-01-16 13:24:00', 27),
(48, NULL, 19, 2900000.000, 'Đã hoàn thành', '2025-01-16 22:00:00', 27),
(49, NULL, 15, 5900000.000, 'Đã hoàn thành', '2025-01-17 05:56:00', 28),
(50, NULL, 41, 2100000.000, 'Đã hoàn thành', '2025-01-17 13:22:00', 6),
(51, NULL, 17, 3100000.000, 'Đã hoàn thành', '2025-01-17 20:47:00', 28),
(52, NULL, 52, 4800000.000, 'Đã hoàn thành', '2025-01-18 05:48:00', 6),
(53, NULL, 19, 5000000.000, 'Đã hoàn thành', '2025-01-18 14:52:00', 28),
(54, NULL, 41, 4400000.000, 'Đã hoàn thành', '2025-01-18 23:01:00', 6),
(55, NULL, 51, 3200000.000, 'Đã hoàn thành', '2025-01-19 05:57:00', 22),
(56, NULL, 19, 5900000.000, 'Đã hoàn thành', '2025-01-19 13:04:00', 6),
(57, NULL, 34, 5400000.000, 'Đã hoàn thành', '2025-01-19 21:55:00', 28),
(58, NULL, 51, 4900000.000, 'Đã hoàn thành', '2025-01-20 06:14:00', 28),
(59, NULL, 19, 2600000.000, 'Đã hoàn thành', '2025-01-20 13:53:00', 28),
(60, NULL, 52, 5500000.000, 'Đã hoàn thành', '2025-01-20 21:27:00', 27),
(61, NULL, 51, 3800000.000, 'Đã hoàn thành', '2025-01-21 04:19:00', 22),
(62, NULL, 51, 2100000.000, 'Đã hoàn thành', '2025-01-21 11:24:00', 27),
(63, NULL, 20, 4100000.000, 'Đã hoàn thành', '2025-01-21 19:07:00', 27),
(64, NULL, 32, 3700000.000, 'Đã hoàn thành', '2025-01-22 02:10:00', 28),
(65, NULL, 19, 2100000.000, 'Đã hoàn thành', '2025-01-22 09:54:00', 22),
(66, NULL, 18, 4200000.000, 'Đã hoàn thành', '2025-01-22 17:28:00', 22),
(67, NULL, 34, 2100000.000, 'Đã hoàn thành', '2025-01-23 02:12:00', 6),
(68, NULL, 50, 5500000.000, 'Đã hoàn thành', '2025-01-23 08:54:00', 6),
(69, NULL, 42, 4100000.000, 'Đã hoàn thành', '2025-01-23 15:50:00', 27),
(70, NULL, 32, 4300000.000, 'Đã hoàn thành', '2025-01-24 00:01:00', 28),
(71, NULL, 51, 4400000.000, 'Đã hoàn thành', '2025-01-24 09:09:00', 28),
(72, NULL, 50, 5400000.000, 'Đã hoàn thành', '2025-01-24 16:54:00', 22),
(73, NULL, 32, 4400000.000, 'Đã hoàn thành', '2025-01-25 00:53:00', 6),
(74, NULL, 42, 5700000.000, 'Đã hoàn thành', '2025-01-25 08:39:00', 27),
(75, NULL, 17, 2800000.000, 'Đã hoàn thành', '2025-01-25 16:01:00', 22),
(76, NULL, 32, 4000000.000, 'Đã hoàn thành', '2025-01-25 23:53:00', 22),
(77, NULL, 17, 4000000.000, 'Đã hoàn thành', '2025-01-26 08:06:00', 22),
(78, NULL, 31, 3700000.000, 'Đã hoàn thành', '2025-01-26 15:48:00', 28),
(79, NULL, 52, 5900000.000, 'Đã hoàn thành', '2025-01-27 00:48:00', 6),
(80, NULL, 50, 4900000.000, 'Đã hoàn thành', '2025-01-27 07:30:00', 27),
(81, NULL, 50, 2400000.000, 'Đã hoàn thành', '2025-01-27 15:55:00', 6),
(82, NULL, 50, 3900000.000, 'Đã hoàn thành', '2025-01-28 00:26:00', 22),
(83, NULL, 42, 4700000.000, 'Đã hoàn thành', '2025-01-28 08:45:00', 6),
(84, NULL, 17, 2900000.000, 'Đã hoàn thành', '2025-01-28 15:27:00', 6),
(85, NULL, 18, 5800000.000, 'Đã hoàn thành', '2025-01-28 22:27:00', 28),
(86, NULL, 51, 2900000.000, 'Đã hoàn thành', '2025-01-29 05:49:00', 6),
(87, NULL, 34, 2400000.000, 'Đã hoàn thành', '2025-01-29 14:36:00', 22),
(88, NULL, 18, 3600000.000, 'Đã hoàn thành', '2025-01-29 22:04:00', 28),
(89, NULL, 51, 6000000.000, 'Đã hoàn thành', '2025-01-30 05:20:00', 6),
(90, NULL, 42, 2000000.000, 'Đã hoàn thành', '2025-01-30 12:41:00', 6),
(91, NULL, 16, 2000000.000, 'Đã hoàn thành', '2025-01-30 21:41:00', 27),
(92, NULL, 50, 4200000.000, 'Đã hoàn thành', '2025-01-31 06:05:00', 27),
(93, NULL, 50, 2100000.000, 'Đã hoàn thành', '2025-01-31 13:03:00', 6),
(94, NULL, 17, 5000000.000, 'Đã hoàn thành', '2025-01-31 21:34:00', 6),
(95, NULL, 52, 2000000.000, 'Đã hoàn thành', '2025-02-01 06:03:00', 6),
(96, NULL, 32, 4800000.000, 'Đã hoàn thành', '2025-02-01 14:48:00', 28),
(97, NULL, 50, 2700000.000, 'Đã hoàn thành', '2025-02-01 23:40:00', 6),
(98, NULL, 32, 6000000.000, 'Đã hoàn thành', '2025-02-02 07:54:00', 28),
(99, NULL, 18, 2800000.000, 'Đã hoàn thành', '2025-02-02 15:36:00', 6),
(100, NULL, 51, 2000000.000, 'Đã hoàn thành', '2025-02-02 23:53:00', 28),
(101, NULL, 31, 3400000.000, 'Đã hoàn thành', '2025-02-03 06:42:00', 28),
(102, NULL, 16, 3500000.000, 'Đã hoàn thành', '2025-02-03 13:32:00', 22),
(103, NULL, 50, 2700000.000, 'Đã hoàn thành', '2025-02-03 21:41:00', 6),
(104, NULL, 51, 3800000.000, 'Đã hoàn thành', '2025-02-04 04:23:00', 27),
(105, NULL, 32, 5700000.000, 'Đã hoàn thành', '2025-02-04 12:42:00', 22),
(106, NULL, 42, 3800000.000, 'Đã hoàn thành', '2025-02-04 19:53:00', 27),
(107, NULL, 20, 4400000.000, 'Đã hoàn thành', '2025-02-05 03:46:00', 28),
(108, NULL, 50, 4000000.000, 'Đã hoàn thành', '2025-02-05 10:55:00', 22),
(109, NULL, 41, 2000000.000, 'Đã hoàn thành', '2025-02-05 19:50:00', 27),
(110, NULL, 50, 5900000.000, 'Đã hoàn thành', '2025-02-06 03:47:00', 22),
(111, NULL, 20, 4100000.000, 'Đã hoàn thành', '2025-02-06 11:15:00', 6),
(112, NULL, 52, 2500000.000, 'Đã hoàn thành', '2025-02-06 19:58:00', 27),
(113, NULL, 42, 4400000.000, 'Đã hoàn thành', '2025-02-07 03:33:00', 6),
(114, NULL, 41, 4700000.000, 'Đã hoàn thành', '2025-02-07 10:17:00', 6),
(115, NULL, 52, 5500000.000, 'Đã hoàn thành', '2025-02-07 16:57:00', 22),
(116, NULL, 20, 5300000.000, 'Đã hoàn thành', '2025-02-08 00:38:00', 28),
(117, NULL, 17, 2300000.000, 'Đã hoàn thành', '2025-02-08 07:51:00', 28),
(118, NULL, 15, 5400000.000, 'Đã hoàn thành', '2025-02-08 15:39:00', 22),
(119, NULL, 50, 5400000.000, 'Đã hoàn thành', '2025-02-09 00:48:00', 28),
(120, NULL, 18, 2500000.000, 'Đã hoàn thành', '2025-02-09 09:16:00', 22),
(121, NULL, 51, 6000000.000, 'Đã hoàn thành', '2025-02-09 17:17:00', 22),
(122, NULL, 34, 6000000.000, 'Đã hoàn thành', '2025-02-10 02:23:00', 27),
(123, NULL, 19, 4900000.000, 'Đã hoàn thành', '2025-02-10 09:47:00', 27),
(124, NULL, 32, 5000000.000, 'Đã hoàn thành', '2025-02-10 17:18:00', 22),
(125, NULL, 16, 3600000.000, 'Đã hoàn thành', '2025-02-11 00:55:00', 6),
(126, NULL, 50, 5300000.000, 'Đã hoàn thành', '2025-02-11 08:31:00', 22),
(127, NULL, 34, 5100000.000, 'Đã hoàn thành', '2025-02-11 15:35:00', 22),
(128, NULL, 15, 2000000.000, 'Đã hoàn thành', '2025-02-11 23:58:00', 6),
(129, NULL, 15, 5300000.000, 'Đã hoàn thành', '2025-02-12 07:25:00', 6),
(130, NULL, 52, 3000000.000, 'Đã hoàn thành', '2025-02-12 14:15:00', 27),
(131, NULL, 16, 2200000.000, 'Đã hoàn thành', '2025-02-12 21:16:00', 27),
(132, NULL, 20, 2300000.000, 'Đã hoàn thành', '2025-02-13 05:59:00', 6),
(133, NULL, 52, 4900000.000, 'Đã hoàn thành', '2025-02-13 15:02:00', 6),
(134, NULL, 52, 2100000.000, 'Đã hoàn thành', '2025-02-13 23:36:00', 27),
(135, NULL, 51, 5700000.000, 'Đã hoàn thành', '2025-02-14 07:27:00', 22),
(136, NULL, 31, 2300000.000, 'Đã hoàn thành', '2025-02-14 16:23:00', 6),
(137, NULL, 17, 3600000.000, 'Đã hoàn thành', '2025-02-15 00:34:00', 27),
(138, NULL, 15, 5000000.000, 'Đã hoàn thành', '2025-02-15 09:37:00', 22),
(139, NULL, 20, 5100000.000, 'Đã hoàn thành', '2025-02-15 18:47:00', 27),
(140, NULL, 15, 6000000.000, 'Đã hoàn thành', '2025-02-16 02:10:00', 28),
(141, NULL, 32, 5500000.000, 'Đã hoàn thành', '2025-02-16 10:48:00', 6),
(142, NULL, 50, 5100000.000, 'Đã hoàn thành', '2025-02-16 18:31:00', 6),
(143, NULL, 41, 3900000.000, 'Đã hoàn thành', '2025-02-17 02:17:00', 28),
(144, NULL, 15, 4500000.000, 'Đã hoàn thành', '2025-02-17 09:49:00', 28),
(145, NULL, 19, 4100000.000, 'Đã hoàn thành', '2025-02-17 17:12:00', 6),
(146, NULL, 20, 5900000.000, 'Đã hoàn thành', '2025-02-18 02:12:00', 6),
(147, NULL, 31, 5000000.000, 'Đã hoàn thành', '2025-02-18 09:39:00', 28),
(148, NULL, 18, 5700000.000, 'Đã hoàn thành', '2025-02-18 16:28:00', 6),
(149, NULL, 42, 4000000.000, 'Đã hoàn thành', '2025-02-19 01:21:00', 28),
(150, NULL, 19, 3800000.000, 'Đã hoàn thành', '2025-02-19 08:07:00', 27),
(151, NULL, 20, 3300000.000, 'Đã hoàn thành', '2025-02-19 14:52:00', 28),
(152, NULL, 32, 5800000.000, 'Đã hoàn thành', '2025-02-19 21:44:00', 28),
(153, NULL, 32, 2300000.000, 'Đã hoàn thành', '2025-02-20 04:51:00', 6),
(154, NULL, 41, 3900000.000, 'Đã hoàn thành', '2025-02-20 13:45:00', 22),
(155, NULL, 52, 4800000.000, 'Đã hoàn thành', '2025-02-20 22:05:00', 28),
(156, NULL, 50, 4300000.000, 'Đã hoàn thành', '2025-02-21 05:03:00', 22),
(157, NULL, 19, 3900000.000, 'Đã hoàn thành', '2025-02-21 13:41:00', 27),
(158, NULL, 19, 5700000.000, 'Đã hoàn thành', '2025-02-21 21:28:00', 22),
(159, NULL, 32, 5700000.000, 'Đã hoàn thành', '2025-02-22 05:33:00', 27),
(160, NULL, 20, 4300000.000, 'Đã hoàn thành', '2025-02-22 12:57:00', 28),
(161, NULL, 31, 5000000.000, 'Đã hoàn thành', '2025-02-22 20:51:00', 27),
(162, NULL, 50, 4300000.000, 'Đã hoàn thành', '2025-02-23 03:40:00', 27),
(163, NULL, 20, 2600000.000, 'Đã hoàn thành', '2025-02-23 11:50:00', 6),
(164, NULL, 52, 5500000.000, 'Đã hoàn thành', '2025-02-23 19:38:00', 22),
(165, NULL, 50, 5100000.000, 'Đã hoàn thành', '2025-02-24 04:24:00', 28),
(166, NULL, 16, 5800000.000, 'Đã hoàn thành', '2025-02-24 11:12:00', 28),
(167, NULL, 19, 3900000.000, 'Đã hoàn thành', '2025-02-24 18:59:00', 28),
(168, NULL, 17, 5600000.000, 'Đã hoàn thành', '2025-02-25 03:33:00', 28),
(169, NULL, 42, 5900000.000, 'Đã hoàn thành', '2025-02-25 10:37:00', 22),
(170, NULL, 41, 3000000.000, 'Đã hoàn thành', '2025-02-25 17:20:00', 28),
(171, NULL, 50, 5000000.000, 'Đã hoàn thành', '2025-02-26 00:31:00', 6),
(172, NULL, 31, 4900000.000, 'Đã hoàn thành', '2025-02-26 07:26:00', 6),
(173, NULL, 51, 4200000.000, 'Đã hoàn thành', '2025-02-26 16:02:00', 22),
(174, NULL, 15, 3100000.000, 'Đã hoàn thành', '2025-02-27 00:47:00', 27),
(175, NULL, 51, 2200000.000, 'Đã hoàn thành', '2025-02-27 09:05:00', 27),
(176, NULL, 20, 5300000.000, 'Đã hoàn thành', '2025-02-27 16:13:00', 27),
(177, NULL, 34, 4900000.000, 'Đã hoàn thành', '2025-02-28 00:21:00', 28),
(178, NULL, 19, 5100000.000, 'Đã hoàn thành', '2025-02-28 07:05:00', 28),
(179, NULL, 42, 2800000.000, 'Đã hoàn thành', '2025-02-28 13:57:00', 28),
(180, NULL, 15, 1400000.000, 'Đã hoàn thành', '2025-02-28 20:56:00', 6),
(181, NULL, 17, 1700000.000, 'Đã hoàn thành', '2025-03-01 05:32:00', 28),
(182, NULL, 50, 2000000.000, 'Đã hoàn thành', '2025-03-01 14:40:00', 28),
(183, NULL, 34, 1800000.000, 'Đã hoàn thành', '2025-03-01 22:09:00', 22),
(184, NULL, 16, 800000.000, 'Đã hoàn thành', '2025-03-02 07:14:00', 6),
(185, NULL, 42, 500000.000, 'Đã hoàn thành', '2025-03-02 14:02:00', 28),
(186, NULL, 42, 1300000.000, 'Đã hoàn thành', '2025-03-02 21:53:00', 28),
(187, NULL, 31, 500000.000, 'Đã hoàn thành', '2025-03-03 06:05:00', 28),
(188, NULL, 34, 800000.000, 'Đã hoàn thành', '2025-03-03 14:57:00', 22),
(189, NULL, 19, 500000.000, 'Đã hoàn thành', '2025-03-03 22:31:00', 28),
(190, NULL, 32, 1000000.000, 'Đã hoàn thành', '2025-03-04 05:18:00', 28),
(191, NULL, 31, 800000.000, 'Đã hoàn thành', '2025-03-04 13:19:00', 6),
(192, NULL, 32, 1700000.000, 'Đã hoàn thành', '2025-03-04 21:58:00', 22),
(193, NULL, 18, 1400000.000, 'Đã hoàn thành', '2025-03-05 04:42:00', 27),
(194, NULL, 16, 1900000.000, 'Đã hoàn thành', '2025-03-05 11:37:00', 27),
(195, NULL, 52, 1200000.000, 'Đã hoàn thành', '2025-03-05 18:57:00', 22),
(196, NULL, 16, 900000.000, 'Đã hoàn thành', '2025-03-06 03:53:00', 28),
(197, NULL, 52, 1700000.000, 'Đã hoàn thành', '2025-03-06 11:53:00', 28),
(198, NULL, 34, 1400000.000, 'Đã hoàn thành', '2025-03-06 18:47:00', 22),
(199, NULL, 51, 1000000.000, 'Đã hoàn thành', '2025-03-07 01:35:00', 27),
(200, NULL, 51, 900000.000, 'Đã hoàn thành', '2025-03-07 10:18:00', 6),
(201, NULL, 41, 1900000.000, 'Đã hoàn thành', '2025-03-07 18:43:00', 6),
(202, NULL, 15, 1700000.000, 'Đã hoàn thành', '2025-03-08 03:45:00', 28),
(203, NULL, 17, 800000.000, 'Đã hoàn thành', '2025-03-08 12:34:00', 6),
(204, NULL, 32, 2000000.000, 'Đã hoàn thành', '2025-03-08 20:35:00', 6),
(205, NULL, 51, 1000000.000, 'Đã hoàn thành', '2025-03-09 05:36:00', 6),
(206, NULL, 19, 500000.000, 'Đã hoàn thành', '2025-03-09 14:18:00', 28),
(207, NULL, 32, 600000.000, 'Đã hoàn thành', '2025-03-09 23:18:00', 28),
(208, NULL, 34, 500000.000, 'Đã hoàn thành', '2025-03-10 06:59:00', 6),
(209, NULL, 51, 700000.000, 'Đã hoàn thành', '2025-03-10 14:33:00', 28),
(210, NULL, 31, 700000.000, 'Đã hoàn thành', '2025-03-10 22:32:00', 28),
(211, NULL, 20, 600000.000, 'Đã hoàn thành', '2025-03-11 07:20:00', 27),
(212, NULL, 41, 1400000.000, 'Đã hoàn thành', '2025-03-11 14:49:00', 6),
(213, NULL, 41, 1800000.000, 'Đã hoàn thành', '2025-03-11 23:41:00', 6),
(214, NULL, 16, 800000.000, 'Đã hoàn thành', '2025-03-12 06:33:00', 27),
(215, NULL, 50, 800000.000, 'Đã hoàn thành', '2025-03-12 14:27:00', 6),
(216, NULL, 31, 500000.000, 'Đã hoàn thành', '2025-03-12 23:36:00', 6),
(217, NULL, 41, 800000.000, 'Đã hoàn thành', '2025-03-13 07:07:00', 27),
(218, NULL, 50, 1400000.000, 'Đã hoàn thành', '2025-03-13 15:25:00', 6),
(219, NULL, 18, 1300000.000, 'Đã hoàn thành', '2025-03-13 22:34:00', 22),
(220, NULL, 20, 1400000.000, 'Đã hoàn thành', '2025-03-14 07:21:00', 6),
(221, NULL, 52, 900000.000, 'Đã hoàn thành', '2025-03-14 16:12:00', 22),
(222, NULL, 19, 1100000.000, 'Đã hoàn thành', '2025-03-15 01:02:00', 6),
(223, NULL, 31, 700000.000, 'Đã hoàn thành', '2025-03-15 07:56:00', 27),
(224, NULL, 50, 600000.000, 'Đã hoàn thành', '2025-03-15 16:46:00', 6),
(225, NULL, 20, 2000000.000, 'Đã hoàn thành', '2025-03-15 23:41:00', 6),
(226, NULL, 16, 1400000.000, 'Đã hoàn thành', '2025-03-16 07:37:00', 22),
(227, NULL, 41, 1900000.000, 'Đã hoàn thành', '2025-03-16 16:28:00', 28),
(228, NULL, 50, 700000.000, 'Đã hoàn thành', '2025-03-17 01:30:00', 28),
(229, NULL, 51, 2000000.000, 'Đã hoàn thành', '2025-03-17 08:33:00', 22),
(230, NULL, 18, 1200000.000, 'Đã hoàn thành', '2025-03-17 16:40:00', 27),
(231, NULL, 18, 800000.000, 'Đã hoàn thành', '2025-03-18 01:26:00', 6),
(232, NULL, 16, 800000.000, 'Đã hoàn thành', '2025-03-18 09:54:00', 22),
(233, NULL, 17, 1000000.000, 'Đã hoàn thành', '2025-03-18 16:56:00', 22),
(234, NULL, 31, 1700000.000, 'Đã hoàn thành', '2025-03-19 01:29:00', 6),
(235, NULL, 19, 1500000.000, 'Đã hoàn thành', '2025-03-19 09:37:00', 6),
(236, NULL, 52, 2000000.000, 'Đã hoàn thành', '2025-03-19 16:43:00', 6),
(237, NULL, 32, 1300000.000, 'Đã hoàn thành', '2025-03-20 00:49:00', 6),
(238, NULL, 15, 1100000.000, 'Đã hoàn thành', '2025-03-20 07:36:00', 22),
(239, NULL, 15, 900000.000, 'Đã hoàn thành', '2025-03-20 16:30:00', 22),
(240, NULL, 50, 700000.000, 'Đã hoàn thành', '2025-03-21 01:14:00', 27),
(241, NULL, 41, 1400000.000, 'Đã hoàn thành', '2025-03-21 10:04:00', 6),
(242, NULL, 15, 1000000.000, 'Đã hoàn thành', '2025-03-21 19:05:00', 28),
(243, NULL, 42, 800000.000, 'Đã hoàn thành', '2025-03-22 01:58:00', 28),
(244, NULL, 41, 1300000.000, 'Đã hoàn thành', '2025-03-22 09:05:00', 6),
(245, NULL, 20, 900000.000, 'Đã hoàn thành', '2025-03-22 15:56:00', 22),
(246, NULL, 42, 1800000.000, 'Đã hoàn thành', '2025-03-22 23:26:00', 28),
(247, NULL, 42, 1200000.000, 'Đã hoàn thành', '2025-03-23 06:24:00', 27),
(248, NULL, 42, 1500000.000, 'Đã hoàn thành', '2025-03-23 14:07:00', 28),
(249, NULL, 16, 1700000.000, 'Đã hoàn thành', '2025-03-23 20:52:00', 6),
(250, NULL, 19, 1300000.000, 'Đã hoàn thành', '2025-03-24 05:04:00', 28),
(251, NULL, 50, 900000.000, 'Đã hoàn thành', '2025-03-24 12:44:00', 22),
(252, NULL, 15, 700000.000, 'Đã hoàn thành', '2025-03-24 20:35:00', 28),
(253, NULL, 51, 1900000.000, 'Đã hoàn thành', '2025-03-25 03:43:00', 6),
(254, NULL, 32, 2000000.000, 'Đã hoàn thành', '2025-03-25 10:57:00', 6),
(255, NULL, 16, 2000000.000, 'Đã hoàn thành', '2025-03-25 19:26:00', 27),
(256, NULL, 50, 1700000.000, 'Đã hoàn thành', '2025-03-26 02:38:00', 27),
(257, NULL, 41, 1700000.000, 'Đã hoàn thành', '2025-03-26 09:54:00', 27),
(258, NULL, 31, 1200000.000, 'Đã hoàn thành', '2025-03-26 17:58:00', 27),
(259, NULL, 18, 1700000.000, 'Đã hoàn thành', '2025-03-27 03:01:00', 22),
(260, NULL, 50, 1900000.000, 'Đã hoàn thành', '2025-03-27 11:44:00', 28),
(261, NULL, 20, 700000.000, 'Đã hoàn thành', '2025-03-27 20:01:00', 22),
(262, NULL, 20, 800000.000, 'Đã hoàn thành', '2025-03-28 04:04:00', 6),
(263, NULL, 17, 1000000.000, 'Đã hoàn thành', '2025-03-28 11:29:00', 6),
(264, NULL, 52, 1100000.000, 'Đã hoàn thành', '2025-03-28 20:31:00', 22),
(265, NULL, 32, 500000.000, 'Đã hoàn thành', '2025-03-29 04:59:00', 22),
(266, NULL, 32, 1800000.000, 'Đã hoàn thành', '2025-03-29 12:08:00', 28),
(267, NULL, 16, 900000.000, 'Đã hoàn thành', '2025-03-29 21:07:00', 28),
(268, NULL, 15, 2000000.000, 'Đã hoàn thành', '2025-03-30 04:10:00', 22),
(269, NULL, 16, 1700000.000, 'Đã hoàn thành', '2025-03-30 12:52:00', 28),
(270, NULL, 16, 2000000.000, 'Đã hoàn thành', '2025-03-30 20:27:00', 6),
(271, NULL, 51, 1100000.000, 'Đã hoàn thành', '2025-03-31 03:45:00', 22),
(272, NULL, 18, 1200000.000, 'Đã hoàn thành', '2025-03-31 10:48:00', 6),
(273, NULL, 32, 1600000.000, 'Đã hoàn thành', '2025-03-31 19:15:00', 28),
(274, NULL, 20, 1300000.000, 'Đã hoàn thành', '2025-04-01 02:33:00', 27),
(275, NULL, 32, 1800000.000, 'Đã hoàn thành', '2025-04-01 09:43:00', 28),
(276, NULL, 51, 1700000.000, 'Đã hoàn thành', '2025-04-01 18:30:00', 28),
(277, NULL, 32, 600000.000, 'Đã hoàn thành', '2025-04-02 01:42:00', 6),
(278, NULL, 42, 800000.000, 'Đã hoàn thành', '2025-04-02 10:07:00', 28),
(279, NULL, 42, 700000.000, 'Đã hoàn thành', '2025-04-02 17:25:00', 28),
(280, NULL, 41, 1100000.000, 'Đã hoàn thành', '2025-04-03 00:34:00', 28),
(281, NULL, 19, 1400000.000, 'Đã hoàn thành', '2025-04-03 09:36:00', 27),
(282, NULL, 18, 1400000.000, 'Đã hoàn thành', '2025-04-03 18:06:00', 28),
(283, NULL, 34, 600000.000, 'Đã hoàn thành', '2025-04-04 02:36:00', 22),
(284, NULL, 50, 1300000.000, 'Đã hoàn thành', '2025-04-04 09:53:00', 28),
(285, NULL, 16, 2000000.000, 'Đã hoàn thành', '2025-04-04 18:05:00', 27),
(286, NULL, 50, 700000.000, 'Đã hoàn thành', '2025-04-05 02:13:00', 28),
(287, NULL, 41, 700000.000, 'Đã hoàn thành', '2025-04-05 10:07:00', 28),
(288, NULL, 20, 1800000.000, 'Đã hoàn thành', '2025-04-05 18:24:00', 6),
(289, NULL, 52, 800000.000, 'Đã hoàn thành', '2025-04-06 03:01:00', 6),
(290, NULL, 19, 1800000.000, 'Đã hoàn thành', '2025-04-06 10:37:00', 27),
(291, NULL, 18, 1600000.000, 'Đã hoàn thành', '2025-04-06 19:26:00', 28),
(292, NULL, 34, 1100000.000, 'Đã hoàn thành', '2025-04-07 03:07:00', 28),
(293, NULL, 34, 900000.000, 'Đã hoàn thành', '2025-04-07 11:12:00', 22),
(294, NULL, 19, 1900000.000, 'Đã hoàn thành', '2025-04-07 18:47:00', 22),
(295, NULL, 34, 800000.000, 'Đã hoàn thành', '2025-04-08 02:28:00', 22),
(296, NULL, 18, 600000.000, 'Đã hoàn thành', '2025-04-08 10:52:00', 28),
(297, NULL, 52, 1100000.000, 'Đã hoàn thành', '2025-04-08 18:44:00', 27),
(298, NULL, 16, 1500000.000, 'Đã hoàn thành', '2025-04-09 01:43:00', 22),
(299, NULL, 31, 1900000.000, 'Đã hoàn thành', '2025-04-09 09:34:00', 27),
(300, NULL, 51, 1200000.000, 'Đã hoàn thành', '2025-04-09 17:25:00', 22),
(301, NULL, 51, 1200000.000, 'Đã hoàn thành', '2025-04-10 02:29:00', 28),
(302, NULL, 18, 500000.000, 'Đã hoàn thành', '2025-04-10 10:39:00', 28),
(303, NULL, 50, 600000.000, 'Đã hoàn thành', '2025-04-10 19:14:00', 28),
(304, NULL, 52, 1000000.000, 'Đã hoàn thành', '2025-04-11 03:01:00', 6),
(305, NULL, 31, 1600000.000, 'Đã hoàn thành', '2025-04-11 10:17:00', 22),
(306, NULL, 41, 500000.000, 'Đã hoàn thành', '2025-04-11 18:56:00', 6),
(307, NULL, 15, 2000000.000, 'Đã hoàn thành', '2025-04-12 02:50:00', 27),
(308, NULL, 18, 600000.000, 'Đã hoàn thành', '2025-04-12 11:05:00', 28),
(309, NULL, 42, 2000000.000, 'Đã hoàn thành', '2025-04-12 19:16:00', 6),
(310, NULL, 42, 1800000.000, 'Đã hoàn thành', '2025-04-13 03:39:00', 6),
(311, NULL, 16, 1700000.000, 'Đã hoàn thành', '2025-04-13 12:03:00', 27),
(312, NULL, 51, 2000000.000, 'Đã hoàn thành', '2025-04-13 19:53:00', 27),
(313, NULL, 42, 1500000.000, 'Đã hoàn thành', '2025-04-14 04:20:00', 22),
(314, NULL, 19, 900000.000, 'Đã hoàn thành', '2025-04-14 13:07:00', 6),
(315, NULL, 20, 1500000.000, 'Đã hoàn thành', '2025-04-14 20:09:00', 6),
(316, NULL, 52, 1600000.000, 'Đã hoàn thành', '2025-04-15 05:01:00', 28),
(317, NULL, 42, 800000.000, 'Đã hoàn thành', '2025-04-15 12:37:00', 27),
(318, NULL, 17, 1200000.000, 'Đã hoàn thành', '2025-04-15 19:33:00', 28),
(319, NULL, 31, 1000000.000, 'Đã hoàn thành', '2025-04-16 04:19:00', 27),
(320, NULL, 15, 600000.000, 'Đã hoàn thành', '2025-04-16 12:29:00', 6),
(321, NULL, 41, 1700000.000, 'Đã hoàn thành', '2025-04-16 20:52:00', 28),
(322, NULL, 34, 1800000.000, 'Đã hoàn thành', '2025-04-17 05:07:00', 6),
(323, NULL, 19, 1900000.000, 'Đã hoàn thành', '2025-04-17 12:13:00', 22),
(324, NULL, 52, 500000.000, 'Đã hoàn thành', '2025-04-17 20:16:00', 28),
(325, NULL, 50, 1500000.000, 'Đã hoàn thành', '2025-04-18 03:57:00', 22),
(326, NULL, 51, 1800000.000, 'Đã hoàn thành', '2025-04-18 11:26:00', 28),
(327, NULL, 50, 1800000.000, 'Đã hoàn thành', '2025-04-18 18:38:00', 22),
(328, NULL, 50, 600000.000, 'Đã hoàn thành', '2025-04-19 03:37:00', 28),
(329, NULL, 31, 500000.000, 'Đã hoàn thành', '2025-04-19 12:30:00', 22),
(330, NULL, 19, 900000.000, 'Đã hoàn thành', '2025-04-19 21:08:00', 27),
(331, NULL, 15, 700000.000, 'Đã hoàn thành', '2025-04-20 05:09:00', 22),
(332, NULL, 20, 600000.000, 'Đã hoàn thành', '2025-04-20 13:26:00', 27),
(333, NULL, 34, 500000.000, 'Đã hoàn thành', '2025-04-20 21:32:00', 22),
(334, NULL, 16, 500000.000, 'Đã hoàn thành', '2025-04-21 04:58:00', 27),
(335, NULL, 20, 1600000.000, 'Đã hoàn thành', '2025-04-21 12:05:00', 27),
(336, NULL, 32, 1800000.000, 'Đã hoàn thành', '2025-04-21 20:37:00', 28),
(337, NULL, 52, 2000000.000, 'Đã hoàn thành', '2025-04-22 03:35:00', 27),
(338, NULL, 15, 1400000.000, 'Đã hoàn thành', '2025-04-22 12:43:00', 27),
(339, NULL, 17, 1700000.000, 'Đã hoàn thành', '2025-04-22 21:15:00', 6),
(340, NULL, 17, 1700000.000, 'Đã hoàn thành', '2025-04-23 05:27:00', 27),
(341, NULL, 41, 500000.000, 'Đã hoàn thành', '2025-04-23 12:13:00', 6),
(342, NULL, 16, 1800000.000, 'Đã hoàn thành', '2025-04-23 20:52:00', 6),
(343, NULL, 15, 2000000.000, 'Đã hoàn thành', '2025-04-24 04:38:00', 6),
(344, NULL, 31, 500000.000, 'Đã hoàn thành', '2025-04-24 12:36:00', 28),
(345, NULL, 41, 1700000.000, 'Đã hoàn thành', '2025-04-24 20:09:00', 27),
(346, NULL, 34, 1200000.000, 'Đã hoàn thành', '2025-04-25 04:14:00', 6),
(347, NULL, 18, 1800000.000, 'Đã hoàn thành', '2025-04-25 12:01:00', 27),
(348, NULL, 42, 1100000.000, 'Đã hoàn thành', '2025-04-25 20:45:00', 28),
(349, NULL, 17, 2000000.000, 'Đã hoàn thành', '2025-04-26 03:53:00', 22),
(350, NULL, 31, 1700000.000, 'Đã hoàn thành', '2025-04-26 11:46:00', 27),
(351, NULL, 18, 1400000.000, 'Đã hoàn thành', '2025-04-26 19:03:00', 28),
(352, NULL, 50, 1900000.000, 'Đã hoàn thành', '2025-04-27 02:17:00', 28),
(353, NULL, 42, 800000.000, 'Đã hoàn thành', '2025-04-27 11:25:00', 28),
(354, NULL, 31, 2000000.000, 'Đã hoàn thành', '2025-04-27 18:16:00', 28),
(355, NULL, 32, 600000.000, 'Đã hoàn thành', '2025-04-28 00:56:00', 27),
(356, NULL, 51, 600000.000, 'Đã hoàn thành', '2025-04-28 08:34:00', 6),
(357, NULL, 34, 1500000.000, 'Đã hoàn thành', '2025-04-28 16:15:00', 22),
(358, NULL, 34, 1200000.000, 'Đã hoàn thành', '2025-04-29 00:01:00', 27),
(359, NULL, 41, 1000000.000, 'Đã hoàn thành', '2025-04-29 08:44:00', 28),
(360, NULL, 32, 2000000.000, 'Đã hoàn thành', '2025-04-29 17:34:00', 6),
(361, NULL, 51, 900000.000, 'Đã hoàn thành', '2025-04-30 01:15:00', 22),
(362, NULL, 50, 1500000.000, 'Đã hoàn thành', '2025-04-30 08:13:00', 27),
(363, NULL, 17, 1400000.000, 'Đã hoàn thành', '2025-04-30 16:30:00', 27),
(364, NULL, 15, 700000.000, 'Đã hoàn thành', '2025-05-01 00:21:00', 22),
(365, NULL, 41, 600000.000, 'Đã hoàn thành', '2025-05-01 07:40:00', 22),
(366, NULL, 32, 1300000.000, 'Đã hoàn thành', '2025-05-01 15:25:00', 6),
(367, NULL, 15, 2000000.000, 'Đã hoàn thành', '2025-05-01 23:38:00', 22),
(368, NULL, 19, 1300000.000, 'Đã hoàn thành', '2025-05-02 08:18:00', 28),
(369, NULL, 52, 700000.000, 'Đã hoàn thành', '2025-05-02 16:56:00', 27),
(370, NULL, 52, 1600000.000, 'Đã hoàn thành', '2025-05-03 01:20:00', 22),
(371, NULL, 15, 1700000.000, 'Đã hoàn thành', '2025-05-03 08:37:00', 6),
(372, NULL, 41, 2000000.000, 'Đã hoàn thành', '2025-05-03 17:20:00', 27),
(373, NULL, 20, 1300000.000, 'Đã hoàn thành', '2025-05-04 00:42:00', 6),
(374, NULL, 16, 600000.000, 'Đã hoàn thành', '2025-05-04 08:36:00', 6),
(375, NULL, 15, 1700000.000, 'Đã hoàn thành', '2025-05-04 17:21:00', 22),
(376, NULL, 31, 1800000.000, 'Đã hoàn thành', '2025-05-05 02:31:00', 22),
(377, NULL, 42, 1200000.000, 'Đã hoàn thành', '2025-05-05 09:58:00', 6),
(378, NULL, 41, 600000.000, 'Đã hoàn thành', '2025-05-05 18:10:00', 27),
(379, NULL, 42, 1600000.000, 'Đã hoàn thành', '2025-05-06 03:10:00', 22),
(380, NULL, 41, 1100000.000, 'Đã hoàn thành', '2025-05-06 11:17:00', 28),
(381, NULL, 50, 1700000.000, 'Đã hoàn thành', '2025-05-06 20:05:00', 22),
(382, NULL, 52, 1300000.000, 'Đã hoàn thành', '2025-05-07 05:09:00', 28),
(383, NULL, 32, 2000000.000, 'Đã hoàn thành', '2025-05-07 12:52:00', 6),
(384, NULL, 52, 1900000.000, 'Đã hoàn thành', '2025-05-07 21:56:00', 22),
(385, NULL, 20, 1600000.000, 'Đã hoàn thành', '2025-05-08 06:01:00', 28),
(386, NULL, 17, 1700000.000, 'Đã hoàn thành', '2025-05-08 14:16:00', 27),
(387, NULL, 31, 1300000.000, 'Đã hoàn thành', '2025-05-08 21:44:00', 27),
(388, NULL, 31, 900000.000, 'Đã hoàn thành', '2025-05-09 06:52:00', 22),
(389, NULL, 34, 1900000.000, 'Đã hoàn thành', '2025-05-09 14:54:00', 27),
(390, NULL, 42, 900000.000, 'Đã hoàn thành', '2025-05-09 22:28:00', 22),
(391, NULL, 18, 1500000.000, 'Đã hoàn thành', '2025-05-10 07:01:00', 28),
(392, NULL, 50, 900000.000, 'Đã hoàn thành', '2025-05-10 15:33:00', 22),
(393, NULL, 42, 600000.000, 'Đã hoàn thành', '2025-05-11 00:16:00', 22),
(394, NULL, 32, 2000000.000, 'Đã hoàn thành', '2025-05-11 06:57:00', 27),
(395, NULL, 34, 1400000.000, 'Đã hoàn thành', '2025-05-11 15:00:00', 28),
(396, NULL, 20, 1200000.000, 'Đã hoàn thành', '2025-05-12 00:00:00', 27),
(397, NULL, 50, 1300000.000, 'Đã hoàn thành', '2025-05-12 07:40:00', 27),
(398, NULL, 41, 700000.000, 'Đã hoàn thành', '2025-05-12 14:21:00', 28),
(399, NULL, 17, 1800000.000, 'Đã hoàn thành', '2025-05-12 21:03:00', 22),
(400, NULL, 17, 1500000.000, 'Đã hoàn thành', '2025-05-13 05:32:00', 27),
(401, NULL, 20, 700000.000, 'Đã hoàn thành', '2025-05-13 14:34:00', 28),
(402, NULL, 20, 1100000.000, 'Đã hoàn thành', '2025-05-13 23:27:00', 6),
(403, NULL, 18, 600000.000, 'Đã hoàn thành', '2025-05-14 08:36:00', 6),
(404, NULL, 52, 800000.000, 'Đã hoàn thành', '2025-05-14 15:45:00', 28),
(405, NULL, 42, 1700000.000, 'Đã hoàn thành', '2025-05-14 23:21:00', 27),
(406, NULL, 18, 800000.000, 'Đã hoàn thành', '2025-05-15 06:01:00', 28),
(407, NULL, 18, 900000.000, 'Đã hoàn thành', '2025-05-15 14:58:00', 27),
(408, NULL, 19, 1300000.000, 'Đã hoàn thành', '2025-05-15 23:08:00', 28),
(409, NULL, 34, 2000000.000, 'Đã hoàn thành', '2025-05-16 05:59:00', 22),
(410, NULL, 52, 800000.000, 'Đã hoàn thành', '2025-05-16 15:03:00', 28),
(411, NULL, 50, 1800000.000, 'Đã hoàn thành', '2025-05-16 23:29:00', 28),
(412, NULL, 20, 1900000.000, 'Đã hoàn thành', '2025-05-17 06:35:00', 28),
(413, NULL, 16, 1600000.000, 'Đã hoàn thành', '2025-05-17 13:34:00', 27),
(414, NULL, 41, 1800000.000, 'Đã hoàn thành', '2025-05-17 22:42:00', 6),
(415, NULL, 19, 2000000.000, 'Đã hoàn thành', '2025-05-18 06:03:00', 27),
(416, NULL, 50, 500000.000, 'Đã hoàn thành', '2025-05-18 15:04:00', 6),
(417, NULL, 15, 1400000.000, 'Đã hoàn thành', '2025-05-18 23:03:00', 28),
(418, NULL, 31, 900000.000, 'Đã hoàn thành', '2025-05-19 07:35:00', 28),
(419, NULL, 18, 800000.000, 'Đã hoàn thành', '2025-05-19 16:31:00', 6),
(420, NULL, 15, 1900000.000, 'Đã hoàn thành', '2025-05-20 00:00:00', 6),
(421, NULL, 16, 800000.000, 'Đã hoàn thành', '2025-05-20 08:31:00', 28),
(422, NULL, 17, 1800000.000, 'Đã hoàn thành', '2025-05-20 15:31:00', 27),
(423, NULL, 16, 1100000.000, 'Đã hoàn thành', '2025-05-20 22:41:00', 27),
(424, NULL, 52, 800000.000, 'Đã hoàn thành', '2025-05-21 07:04:00', 6),
(425, NULL, 52, 600000.000, 'Đã hoàn thành', '2025-05-21 14:44:00', 28),
(426, NULL, 32, 1500000.000, 'Đã hoàn thành', '2025-05-21 23:06:00', 6),
(427, NULL, 34, 1400000.000, 'Đã hoàn thành', '2025-05-22 06:27:00', 27),
(428, NULL, 31, 2000000.000, 'Đã hoàn thành', '2025-05-22 14:29:00', 22),
(429, NULL, 41, 500000.000, 'Đã hoàn thành', '2025-05-22 22:58:00', 22),
(430, NULL, 42, 1300000.000, 'Đã hoàn thành', '2025-05-23 07:28:00', 22),
(431, NULL, 19, 2000000.000, 'Đã hoàn thành', '2025-05-23 16:26:00', 6),
(432, NULL, 51, 1500000.000, 'Đã hoàn thành', '2025-05-23 23:31:00', 27),
(433, NULL, 51, 1700000.000, 'Đã hoàn thành', '2025-05-24 08:34:00', 27),
(434, NULL, 42, 500000.000, 'Đã hoàn thành', '2025-05-24 17:01:00', 6),
(435, NULL, 51, 1900000.000, 'Đã hoàn thành', '2025-05-25 00:55:00', 6),
(436, NULL, 16, 1800000.000, 'Đã hoàn thành', '2025-05-25 08:04:00', 6),
(437, NULL, 41, 1300000.000, 'Đã hoàn thành', '2025-05-25 15:55:00', 27),
(438, NULL, 17, 1300000.000, 'Đã hoàn thành', '2025-05-26 00:15:00', 6),
(439, NULL, 18, 1700000.000, 'Đã hoàn thành', '2025-05-26 07:07:00', 28),
(440, NULL, 18, 1400000.000, 'Đã hoàn thành', '2025-05-26 13:51:00', 28),
(441, NULL, 32, 1900000.000, 'Đã hoàn thành', '2025-05-26 22:16:00', 28),
(442, NULL, 32, 1400000.000, 'Đã hoàn thành', '2025-05-27 05:51:00', 27),
(443, NULL, 52, 600000.000, 'Đã hoàn thành', '2025-05-27 13:12:00', 22),
(444, NULL, 17, 1200000.000, 'Đã hoàn thành', '2025-05-27 21:02:00', 28),
(445, NULL, 41, 1400000.000, 'Đã hoàn thành', '2025-05-28 04:22:00', 28),
(446, NULL, 32, 600000.000, 'Đã hoàn thành', '2025-05-28 13:29:00', 22),
(447, NULL, 32, 800000.000, 'Đã hoàn thành', '2025-05-28 20:57:00', 28),
(448, NULL, 31, 1400000.000, 'Đã hoàn thành', '2025-05-29 05:54:00', 27),
(449, NULL, 17, 700000.000, 'Đã hoàn thành', '2025-05-29 12:43:00', 27),
(450, NULL, 31, 1800000.000, 'Đã hoàn thành', '2025-05-29 21:10:00', 22),
(451, NULL, 42, 1000000.000, 'Đã hoàn thành', '2025-05-30 05:37:00', 28),
(452, NULL, 31, 1200000.000, 'Đã hoàn thành', '2025-05-30 14:29:00', 22),
(453, NULL, 50, 900000.000, 'Đã hoàn thành', '2025-05-30 22:51:00', 28),
(454, NULL, 19, 1900000.000, 'Đã hoàn thành', '2025-05-31 06:55:00', 28),
(455, NULL, 20, 1900000.000, 'Đã hoàn thành', '2025-05-31 13:38:00', 28),
(456, NULL, 16, 5400000.000, 'Đã hoàn thành', '2025-05-31 22:24:00', 28),
(457, NULL, 52, 4800000.000, 'Đã hoàn thành', '2025-06-01 05:36:00', 28),
(458, NULL, 31, 2200000.000, 'Đã hoàn thành', '2025-06-01 12:33:00', 27),
(459, NULL, 20, 2400000.000, 'Đã hoàn thành', '2025-06-01 20:25:00', 6),
(460, NULL, 51, 2400000.000, 'Đã hoàn thành', '2025-06-02 04:26:00', 28),
(461, NULL, 34, 4600000.000, 'Đã hoàn thành', '2025-06-02 11:34:00', 27),
(462, NULL, 51, 4700000.000, 'Đã hoàn thành', '2025-06-02 18:50:00', 22),
(463, NULL, 32, 2400000.000, 'Đã hoàn thành', '2025-06-03 01:35:00', 28),
(464, NULL, 41, 5600000.000, 'Đã hoàn thành', '2025-06-03 10:45:00', 28),
(465, NULL, 18, 2600000.000, 'Đã hoàn thành', '2025-06-03 18:16:00', 27),
(466, NULL, 34, 3300000.000, 'Đã hoàn thành', '2025-06-04 01:40:00', 27),
(467, NULL, 19, 4300000.000, 'Đã hoàn thành', '2025-06-04 09:00:00', 6),
(468, NULL, 20, 4900000.000, 'Đã hoàn thành', '2025-06-04 16:54:00', 22),
(469, NULL, 15, 2600000.000, 'Đã hoàn thành', '2025-06-05 01:32:00', 27),
(470, NULL, 50, 3700000.000, 'Đã hoàn thành', '2025-06-05 09:49:00', 27),
(471, NULL, 15, 3200000.000, 'Đã hoàn thành', '2025-06-05 16:58:00', 6),
(472, NULL, 16, 4500000.000, 'Đã hoàn thành', '2025-06-06 01:35:00', 6),
(473, NULL, 16, 4900000.000, 'Đã hoàn thành', '2025-06-06 09:41:00', 27),
(474, NULL, 16, 4600000.000, 'Đã hoàn thành', '2025-06-06 16:55:00', 6),
(475, NULL, 16, 2200000.000, 'Đã hoàn thành', '2025-06-06 23:38:00', 22),
(476, NULL, 34, 5000000.000, 'Đã hoàn thành', '2025-06-07 07:18:00', 28),
(477, NULL, 20, 2000000.000, 'Đã hoàn thành', '2025-06-07 14:05:00', 6),
(478, NULL, 16, 4800000.000, 'Đã hoàn thành', '2025-06-07 23:03:00', 6),
(479, NULL, 19, 5000000.000, 'Đã hoàn thành', '2025-06-08 07:11:00', 22),
(480, NULL, 50, 3600000.000, 'Đã hoàn thành', '2025-06-08 14:51:00', 27),
(481, NULL, 31, 5300000.000, 'Đã hoàn thành', '2025-06-08 23:56:00', 6),
(482, NULL, 34, 5900000.000, 'Đã hoàn thành', '2025-06-09 08:31:00', 27),
(483, NULL, 52, 2200000.000, 'Đã hoàn thành', '2025-06-09 16:06:00', 6),
(484, NULL, 51, 3900000.000, 'Đã hoàn thành', '2025-06-09 23:03:00', 28),
(485, NULL, 15, 4200000.000, 'Đã hoàn thành', '2025-06-10 06:05:00', 22),
(486, NULL, 42, 2600000.000, 'Đã hoàn thành', '2025-06-10 14:35:00', 22),
(487, NULL, 20, 4200000.000, 'Đã hoàn thành', '2025-06-10 23:11:00', 22),
(488, NULL, 15, 5400000.000, 'Đã hoàn thành', '2025-06-11 06:07:00', 6),
(489, NULL, 20, 5100000.000, 'Đã hoàn thành', '2025-06-11 14:32:00', 28),
(490, NULL, 20, 4700000.000, 'Đã hoàn thành', '2025-06-11 22:02:00', 6),
(491, NULL, 34, 5400000.000, 'Đã hoàn thành', '2025-06-12 04:47:00', 22),
(492, NULL, 16, 3400000.000, 'Đã hoàn thành', '2025-06-12 12:01:00', 27),
(493, NULL, 51, 4400000.000, 'Đã hoàn thành', '2025-06-12 19:41:00', 22),
(494, NULL, 20, 3000000.000, 'Đã hoàn thành', '2025-06-13 03:43:00', 27),
(495, NULL, 50, 2800000.000, 'Đã hoàn thành', '2025-06-13 11:10:00', 22),
(496, NULL, 52, 2300000.000, 'Đã hoàn thành', '2025-06-13 19:43:00', 6),
(497, NULL, 16, 2000000.000, 'Đã hoàn thành', '2025-06-14 03:15:00', 27),
(498, NULL, 31, 3700000.000, 'Đã hoàn thành', '2025-06-14 10:13:00', 27),
(499, NULL, 18, 3800000.000, 'Đã hoàn thành', '2025-06-14 18:56:00', 6),
(500, NULL, 50, 5500000.000, 'Đã hoàn thành', '2025-06-15 02:11:00', 28),
(501, NULL, 19, 5500000.000, 'Đã hoàn thành', '2025-06-15 10:51:00', 22),
(502, NULL, 16, 3700000.000, 'Đã hoàn thành', '2025-06-15 18:19:00', 6),
(503, NULL, 15, 2800000.000, 'Đã hoàn thành', '2025-06-16 02:55:00', 27),
(504, NULL, 15, 2800000.000, 'Đã hoàn thành', '2025-06-16 11:55:00', 22),
(505, NULL, 20, 4900000.000, 'Đã hoàn thành', '2025-06-16 20:01:00', 27),
(506, NULL, 51, 5400000.000, 'Đã hoàn thành', '2025-06-17 04:21:00', 22),
(507, NULL, 34, 3500000.000, 'Đã hoàn thành', '2025-06-17 13:08:00', 28),
(508, NULL, 19, 5900000.000, 'Đã hoàn thành', '2025-06-17 20:38:00', 22),
(509, NULL, 18, 4900000.000, 'Đã hoàn thành', '2025-06-18 04:50:00', 28),
(510, NULL, 20, 3700000.000, 'Đã hoàn thành', '2025-06-18 12:43:00', 6),
(511, NULL, 18, 4600000.000, 'Đã hoàn thành', '2025-06-18 21:38:00', 6),
(512, NULL, 16, 3100000.000, 'Đã hoàn thành', '2025-06-19 05:33:00', 22),
(513, NULL, 15, 2500000.000, 'Đã hoàn thành', '2025-06-19 14:41:00', 22),
(514, NULL, 34, 2700000.000, 'Đã hoàn thành', '2025-06-19 23:51:00', 22),
(515, NULL, 50, 4300000.000, 'Đã hoàn thành', '2025-06-20 07:05:00', 27),
(516, NULL, 50, 5200000.000, 'Đã hoàn thành', '2025-06-20 15:40:00', 27),
(517, NULL, 32, 4800000.000, 'Đã hoàn thành', '2025-06-21 00:14:00', 22),
(518, NULL, 42, 3600000.000, 'Đã hoàn thành', '2025-06-21 07:48:00', 27),
(519, NULL, 42, 3900000.000, 'Đã hoàn thành', '2025-06-21 15:23:00', 27),
(520, NULL, 18, 3000000.000, 'Đã hoàn thành', '2025-06-21 23:59:00', 28),
(521, NULL, 34, 4900000.000, 'Đã hoàn thành', '2025-06-22 07:54:00', 27),
(522, NULL, 32, 5200000.000, 'Đã hoàn thành', '2025-06-22 15:29:00', 22),
(523, NULL, 51, 3000000.000, 'Đã hoàn thành', '2025-06-23 00:38:00', 22),
(524, NULL, 20, 2600000.000, 'Đã hoàn thành', '2025-06-23 08:19:00', 27),
(525, NULL, 18, 3500000.000, 'Đã hoàn thành', '2025-06-23 17:20:00', 27),
(526, NULL, 18, 2100000.000, 'Đã hoàn thành', '2025-06-24 01:28:00', 6),
(527, NULL, 41, 2900000.000, 'Đã hoàn thành', '2025-06-24 09:28:00', 27),
(528, NULL, 42, 4400000.000, 'Đã hoàn thành', '2025-06-24 16:32:00', 22),
(529, NULL, 16, 2300000.000, 'Đã hoàn thành', '2025-06-25 01:31:00', 28),
(530, NULL, 41, 2900000.000, 'Đã hoàn thành', '2025-06-25 09:37:00', 27),
(531, NULL, 31, 3000000.000, 'Đã hoàn thành', '2025-06-25 16:33:00', 27),
(532, NULL, 32, 4500000.000, 'Đã hoàn thành', '2025-06-25 23:23:00', 27),
(533, NULL, 15, 4200000.000, 'Đã hoàn thành', '2025-06-26 06:31:00', 28),
(534, NULL, 50, 5300000.000, 'Đã hoàn thành', '2025-06-26 14:35:00', 6),
(535, NULL, 18, 5700000.000, 'Đã hoàn thành', '2025-06-26 21:53:00', 27),
(536, NULL, 51, 2500000.000, 'Đã hoàn thành', '2025-06-27 04:41:00', 28),
(537, NULL, 19, 5600000.000, 'Đã hoàn thành', '2025-06-27 13:18:00', 22),
(538, NULL, 32, 3700000.000, 'Đã hoàn thành', '2025-06-27 21:41:00', 28),
(539, NULL, 31, 5400000.000, 'Đã hoàn thành', '2025-06-28 06:43:00', 27),
(540, NULL, 51, 5500000.000, 'Đã hoàn thành', '2025-06-28 14:52:00', 22),
(541, NULL, 17, 2500000.000, 'Đã hoàn thành', '2025-06-28 23:41:00', 22),
(542, NULL, 52, 3000000.000, 'Đã hoàn thành', '2025-06-29 07:57:00', 28),
(543, NULL, 18, 5600000.000, 'Đã hoàn thành', '2025-06-29 15:12:00', 22),
(544, NULL, 41, 4700000.000, 'Đã hoàn thành', '2025-06-29 23:02:00', 27),
(545, NULL, 18, 4800000.000, 'Đã hoàn thành', '2025-06-30 05:55:00', 6),
(546, NULL, 17, 4600000.000, 'Đã hoàn thành', '2025-06-30 12:39:00', 28),
(547, NULL, 41, 5300000.000, 'Đã hoàn thành', '2025-06-30 21:26:00', 28),
(548, NULL, 17, 5300000.000, 'Đã hoàn thành', '2025-07-01 05:00:00', 28),
(549, NULL, 50, 3100000.000, 'Đã hoàn thành', '2025-07-01 12:56:00', 6),
(550, NULL, 16, 2700000.000, 'Đã hoàn thành', '2025-07-01 20:31:00', 22),
(551, NULL, 16, 4600000.000, 'Đã hoàn thành', '2025-07-02 05:29:00', 6),
(552, NULL, 42, 5500000.000, 'Đã hoàn thành', '2025-07-02 12:15:00', 22),
(553, NULL, 19, 3400000.000, 'Đã hoàn thành', '2025-07-02 19:17:00', 28),
(554, NULL, 16, 3600000.000, 'Đã hoàn thành', '2025-07-03 04:02:00', 22),
(555, NULL, 51, 5500000.000, 'Đã hoàn thành', '2025-07-03 13:04:00', 28),
(556, NULL, 50, 2600000.000, 'Đã hoàn thành', '2025-07-03 21:31:00', 27),
(557, NULL, 17, 4800000.000, 'Đã hoàn thành', '2025-07-04 06:30:00', 27),
(558, NULL, 18, 4400000.000, 'Đã hoàn thành', '2025-07-04 15:30:00', 22),
(559, NULL, 31, 3500000.000, 'Đã hoàn thành', '2025-07-04 22:30:00', 28),
(560, NULL, 52, 4700000.000, 'Đã hoàn thành', '2025-07-05 06:23:00', 6),
(561, NULL, 34, 3800000.000, 'Đã hoàn thành', '2025-07-05 14:27:00', 22),
(562, NULL, 19, 4400000.000, 'Đã hoàn thành', '2025-07-05 22:48:00', 6),
(563, NULL, 17, 4200000.000, 'Đã hoàn thành', '2025-07-06 06:38:00', 27),
(564, NULL, 34, 5100000.000, 'Đã hoàn thành', '2025-07-06 14:38:00', 22),
(565, NULL, 16, 3700000.000, 'Đã hoàn thành', '2025-07-06 22:44:00', 28),
(566, NULL, 15, 4300000.000, 'Đã hoàn thành', '2025-07-07 06:11:00', 22),
(567, NULL, 16, 3800000.000, 'Đã hoàn thành', '2025-07-07 13:43:00', 28),
(568, NULL, 17, 2200000.000, 'Đã hoàn thành', '2025-07-07 22:42:00', 27),
(569, NULL, 51, 2400000.000, 'Đã hoàn thành', '2025-07-08 05:30:00', 6),
(570, NULL, 42, 5600000.000, 'Đã hoàn thành', '2025-07-08 12:28:00', 27),
(571, NULL, 31, 3200000.000, 'Đã hoàn thành', '2025-07-08 19:09:00', 28),
(572, NULL, 34, 5600000.000, 'Đã hoàn thành', '2025-07-09 03:27:00', 22),
(573, NULL, 52, 4800000.000, 'Đã hoàn thành', '2025-07-09 11:49:00', 6),
(574, NULL, 19, 4300000.000, 'Đã hoàn thành', '2025-07-09 19:41:00', 22),
(575, NULL, 32, 3300000.000, 'Đã hoàn thành', '2025-07-10 03:51:00', 28),
(576, NULL, 42, 5400000.000, 'Đã hoàn thành', '2025-07-10 12:53:00', 28),
(577, NULL, 32, 4000000.000, 'Đã hoàn thành', '2025-07-10 19:33:00', 27),
(578, NULL, 50, 2700000.000, 'Đã hoàn thành', '2025-07-11 02:54:00', 28),
(579, NULL, 50, 4800000.000, 'Đã hoàn thành', '2025-07-11 11:06:00', 22),
(580, NULL, 20, 4900000.000, 'Đã hoàn thành', '2025-07-11 20:07:00', 6),
(581, NULL, 16, 4700000.000, 'Đã hoàn thành', '2025-07-12 05:16:00', 6),
(582, NULL, 41, 4500000.000, 'Đã hoàn thành', '2025-07-12 13:07:00', 27),
(583, NULL, 34, 3900000.000, 'Đã hoàn thành', '2025-07-12 21:16:00', 22),
(584, NULL, 20, 4700000.000, 'Đã hoàn thành', '2025-07-13 04:05:00', 27),
(585, NULL, 15, 3400000.000, 'Đã hoàn thành', '2025-07-13 12:18:00', 22),
(586, NULL, 50, 4300000.000, 'Đã hoàn thành', '2025-07-13 20:03:00', 28),
(587, NULL, 15, 2200000.000, 'Đã hoàn thành', '2025-07-14 04:55:00', 27),
(588, NULL, 18, 6000000.000, 'Đã hoàn thành', '2025-07-14 13:07:00', 22),
(589, NULL, 15, 2000000.000, 'Đã hoàn thành', '2025-07-14 20:22:00', 28),
(590, NULL, 18, 2600000.000, 'Đã hoàn thành', '2025-07-15 05:21:00', 28),
(591, NULL, 51, 4100000.000, 'Đã hoàn thành', '2025-07-15 13:53:00', 6),
(592, NULL, 18, 5100000.000, 'Đã hoàn thành', '2025-07-15 22:49:00', 22),
(593, NULL, 51, 4900000.000, 'Đã hoàn thành', '2025-07-16 07:40:00', 22),
(594, NULL, 31, 2700000.000, 'Đã hoàn thành', '2025-07-16 14:30:00', 27),
(595, NULL, 16, 4600000.000, 'Đã hoàn thành', '2025-07-16 21:43:00', 6),
(596, NULL, 41, 3500000.000, 'Đã hoàn thành', '2025-07-17 06:23:00', 28),
(597, NULL, 16, 4900000.000, 'Đã hoàn thành', '2025-07-17 15:01:00', 6),
(598, NULL, 50, 2400000.000, 'Đã hoàn thành', '2025-07-18 00:04:00', 22),
(599, NULL, 32, 3600000.000, 'Đã hoàn thành', '2025-07-18 06:51:00', 27),
(600, NULL, 20, 3300000.000, 'Đã hoàn thành', '2025-07-18 15:16:00', 28),
(601, NULL, 20, 5000000.000, 'Đã hoàn thành', '2025-07-18 22:29:00', 22),
(602, NULL, 34, 2600000.000, 'Đã hoàn thành', '2025-07-19 06:40:00', 28),
(603, NULL, 51, 4000000.000, 'Đã hoàn thành', '2025-07-19 15:01:00', 27),
(604, NULL, 32, 3000000.000, 'Đã hoàn thành', '2025-07-19 23:42:00', 28),
(605, NULL, 50, 4700000.000, 'Đã hoàn thành', '2025-07-20 07:17:00', 28),
(606, NULL, 19, 2600000.000, 'Đã hoàn thành', '2025-07-20 16:14:00', 27),
(607, NULL, 16, 5700000.000, 'Đã hoàn thành', '2025-07-21 00:54:00', 27),
(608, NULL, 32, 3700000.000, 'Đã hoàn thành', '2025-07-21 08:49:00', 27),
(609, NULL, 51, 2800000.000, 'Đã hoàn thành', '2025-07-21 16:00:00', 27),
(610, NULL, 41, 5600000.000, 'Đã hoàn thành', '2025-07-22 00:23:00', 27),
(611, NULL, 17, 5000000.000, 'Đã hoàn thành', '2025-07-22 08:53:00', 27),
(612, NULL, 20, 2600000.000, 'Đã hoàn thành', '2025-07-22 15:40:00', 22),
(613, NULL, 17, 5900000.000, 'Đã hoàn thành', '2025-07-22 23:40:00', 28),
(614, NULL, 15, 3600000.000, 'Đã hoàn thành', '2025-07-23 07:50:00', 22),
(615, NULL, 51, 3800000.000, 'Đã hoàn thành', '2025-07-23 15:09:00', 6),
(616, NULL, 15, 2600000.000, 'Đã hoàn thành', '2025-07-23 22:32:00', 22),
(617, NULL, 31, 4400000.000, 'Đã hoàn thành', '2025-07-24 06:52:00', 6),
(618, NULL, 51, 2400000.000, 'Đã hoàn thành', '2025-07-24 15:44:00', 22),
(619, NULL, 41, 4000000.000, 'Đã hoàn thành', '2025-07-24 23:09:00', 28),
(620, NULL, 16, 6000000.000, 'Đã hoàn thành', '2025-07-25 07:37:00', 6),
(621, NULL, 52, 5600000.000, 'Đã hoàn thành', '2025-07-25 15:40:00', 28),
(622, NULL, 50, 4400000.000, 'Đã hoàn thành', '2025-07-25 22:26:00', 6),
(623, NULL, 31, 4300000.000, 'Đã hoàn thành', '2025-07-26 05:06:00', 27),
(624, NULL, 18, 2400000.000, 'Đã hoàn thành', '2025-07-26 13:14:00', 6),
(625, NULL, 16, 2600000.000, 'Đã hoàn thành', '2025-07-26 20:57:00', 27),
(626, NULL, 34, 4300000.000, 'Đã hoàn thành', '2025-07-27 05:53:00', 27),
(627, NULL, 31, 5500000.000, 'Đã hoàn thành', '2025-07-27 12:49:00', 22),
(628, NULL, 31, 3500000.000, 'Đã hoàn thành', '2025-07-27 21:38:00', 6),
(629, NULL, 15, 2700000.000, 'Đã hoàn thành', '2025-07-28 05:31:00', 27),
(630, NULL, 15, 2700000.000, 'Đã hoàn thành', '2025-07-28 14:32:00', 6),
(631, NULL, 42, 3000000.000, 'Đã hoàn thành', '2025-07-28 21:34:00', 6),
(632, NULL, 50, 4900000.000, 'Đã hoàn thành', '2025-07-29 05:53:00', 28),
(633, NULL, 20, 4200000.000, 'Đã hoàn thành', '2025-07-29 14:43:00', 6),
(634, NULL, 34, 2700000.000, 'Đã hoàn thành', '2025-07-29 23:45:00', 27),
(635, NULL, 16, 3200000.000, 'Đã hoàn thành', '2025-07-30 06:54:00', 22),
(636, NULL, 34, 4900000.000, 'Đã hoàn thành', '2025-07-30 14:14:00', 28),
(637, NULL, 17, 3500000.000, 'Đã hoàn thành', '2025-07-30 22:34:00', 27),
(638, NULL, 41, 2900000.000, 'Đã hoàn thành', '2025-07-31 07:31:00', 27),
(639, NULL, 17, 5100000.000, 'Đã hoàn thành', '2025-07-31 16:03:00', 6),
(640, NULL, 15, 700000.000, 'Đã hoàn thành', '2025-08-01 00:15:00', 28),
(641, NULL, 42, 1000000.000, 'Đã hoàn thành', '2025-08-01 08:14:00', 27),
(642, NULL, 17, 500000.000, 'Đã hoàn thành', '2025-08-01 15:47:00', 6),
(643, NULL, 50, 1400000.000, 'Đã hoàn thành', '2025-08-02 00:26:00', 27),
(644, NULL, 31, 1400000.000, 'Đã hoàn thành', '2025-08-02 07:44:00', 22),
(645, NULL, 34, 1400000.000, 'Đã hoàn thành', '2025-08-02 16:25:00', 22),
(646, NULL, 19, 900000.000, 'Đã hoàn thành', '2025-08-03 00:21:00', 28),
(647, NULL, 51, 500000.000, 'Đã hoàn thành', '2025-08-03 07:56:00', 28),
(648, NULL, 34, 1400000.000, 'Đã hoàn thành', '2025-08-03 15:11:00', 28),
(649, NULL, 50, 1900000.000, 'Đã hoàn thành', '2025-08-03 23:54:00', 6),
(650, NULL, 32, 1200000.000, 'Đã hoàn thành', '2025-08-04 07:58:00', 27),
(651, NULL, 42, 700000.000, 'Đã hoàn thành', '2025-08-04 16:35:00', 22),
(652, NULL, 41, 500000.000, 'Đã hoàn thành', '2025-08-05 00:52:00', 28),
(653, NULL, 32, 1200000.000, 'Đã hoàn thành', '2025-08-05 08:49:00', 27),
(654, NULL, 50, 1600000.000, 'Đã hoàn thành', '2025-08-05 16:44:00', 28),
(655, NULL, 17, 500000.000, 'Đã hoàn thành', '2025-08-05 23:51:00', 28),
(656, NULL, 19, 2000000.000, 'Đã hoàn thành', '2025-08-06 07:41:00', 28),
(657, NULL, 50, 600000.000, 'Đã hoàn thành', '2025-08-06 16:07:00', 27),
(658, NULL, 51, 800000.000, 'Đã hoàn thành', '2025-08-07 00:14:00', 27),
(659, NULL, 42, 1200000.000, 'Đã hoàn thành', '2025-08-07 07:22:00', 27),
(660, NULL, 19, 1600000.000, 'Đã hoàn thành', '2025-08-07 14:59:00', 28),
(661, NULL, 20, 1500000.000, 'Đã hoàn thành', '2025-08-07 22:06:00', 22),
(662, NULL, 52, 2000000.000, 'Đã hoàn thành', '2025-08-08 06:25:00', 6),
(663, NULL, 19, 1000000.000, 'Đã hoàn thành', '2025-08-08 13:08:00', 27),
(664, NULL, 20, 1300000.000, 'Đã hoàn thành', '2025-08-08 21:24:00', 22),
(665, NULL, 32, 500000.000, 'Đã hoàn thành', '2025-08-09 05:35:00', 6),
(666, NULL, 51, 1000000.000, 'Đã hoàn thành', '2025-08-09 12:34:00', 6),
(667, NULL, 51, 2000000.000, 'Đã hoàn thành', '2025-08-09 20:19:00', 27),
(668, NULL, 17, 1000000.000, 'Đã hoàn thành', '2025-08-10 05:24:00', 28),
(669, NULL, 31, 1100000.000, 'Đã hoàn thành', '2025-08-10 13:11:00', 27),
(670, NULL, 52, 800000.000, 'Đã hoàn thành', '2025-08-10 21:16:00', 27),
(671, NULL, 18, 1300000.000, 'Đã hoàn thành', '2025-08-11 05:17:00', 22),
(672, NULL, 31, 1500000.000, 'Đã hoàn thành', '2025-08-11 14:11:00', 6),
(673, NULL, 34, 500000.000, 'Đã hoàn thành', '2025-08-11 22:59:00', 22),
(674, NULL, 20, 1000000.000, 'Đã hoàn thành', '2025-08-12 07:25:00', 22),
(675, NULL, 15, 1200000.000, 'Đã hoàn thành', '2025-08-12 16:00:00', 27),
(676, NULL, 41, 1500000.000, 'Đã hoàn thành', '2025-08-13 01:07:00', 28),
(677, NULL, 42, 1700000.000, 'Đã hoàn thành', '2025-08-13 09:19:00', 27),
(678, NULL, 15, 600000.000, 'Đã hoàn thành', '2025-08-13 16:58:00', 28),
(679, NULL, 34, 1600000.000, 'Đã hoàn thành', '2025-08-14 01:18:00', 27),
(680, NULL, 19, 1900000.000, 'Đã hoàn thành', '2025-08-14 08:38:00', 28),
(681, NULL, 15, 1800000.000, 'Đã hoàn thành', '2025-08-14 15:42:00', 22),
(682, NULL, 52, 500000.000, 'Đã hoàn thành', '2025-08-14 23:30:00', 27),
(683, NULL, 51, 1400000.000, 'Đã hoàn thành', '2025-08-15 06:32:00', 22),
(684, NULL, 18, 1900000.000, 'Đã hoàn thành', '2025-08-15 14:53:00', 27),
(685, NULL, 41, 600000.000, 'Đã hoàn thành', '2025-08-15 23:05:00', 28),
(686, NULL, 52, 1500000.000, 'Đã hoàn thành', '2025-08-16 06:20:00', 22),
(687, NULL, 52, 1100000.000, 'Đã hoàn thành', '2025-08-16 14:59:00', 27),
(688, NULL, 51, 700000.000, 'Đã hoàn thành', '2025-08-16 23:01:00', 27),
(689, NULL, 34, 500000.000, 'Đã hoàn thành', '2025-08-17 07:02:00', 28),
(690, NULL, 16, 1100000.000, 'Đã hoàn thành', '2025-08-17 16:11:00', 22),
(691, NULL, 42, 500000.000, 'Đã hoàn thành', '2025-08-17 23:47:00', 22),
(692, NULL, 15, 700000.000, 'Đã hoàn thành', '2025-08-18 08:51:00', 27),
(693, NULL, 18, 1900000.000, 'Đã hoàn thành', '2025-08-18 16:19:00', 6),
(694, NULL, 50, 1300000.000, 'Đã hoàn thành', '2025-08-19 01:25:00', 22),
(695, NULL, 20, 1200000.000, 'Đã hoàn thành', '2025-08-19 08:34:00', 28),
(696, NULL, 42, 2000000.000, 'Đã hoàn thành', '2025-08-19 15:21:00', 22),
(697, NULL, 51, 1400000.000, 'Đã hoàn thành', '2025-08-20 00:25:00', 28);
INSERT INTO `bookings` (`booking_id`, `user_id`, `performance_id`, `total_amount`, `booking_status`, `created_at`, `created_by`) VALUES
(698, NULL, 52, 900000.000, 'Đã hoàn thành', '2025-08-20 07:42:00', 27),
(699, NULL, 31, 2000000.000, 'Đã hoàn thành', '2025-08-20 14:44:00', 28),
(700, NULL, 52, 500000.000, 'Đã hoàn thành', '2025-08-20 21:57:00', 27),
(701, NULL, 20, 1100000.000, 'Đã hoàn thành', '2025-08-21 06:38:00', 27),
(702, NULL, 52, 1200000.000, 'Đã hoàn thành', '2025-08-21 15:27:00', 22),
(703, NULL, 18, 900000.000, 'Đã hoàn thành', '2025-08-21 22:38:00', 6),
(704, NULL, 15, 1500000.000, 'Đã hoàn thành', '2025-08-22 07:03:00', 6),
(705, NULL, 31, 900000.000, 'Đã hoàn thành', '2025-08-22 14:38:00', 6),
(706, NULL, 20, 1400000.000, 'Đã hoàn thành', '2025-08-22 21:55:00', 27),
(707, NULL, 42, 1900000.000, 'Đã hoàn thành', '2025-08-23 06:18:00', 6),
(708, NULL, 51, 1200000.000, 'Đã hoàn thành', '2025-08-23 14:47:00', 28),
(709, NULL, 31, 1600000.000, 'Đã hoàn thành', '2025-08-23 22:29:00', 6),
(710, NULL, 18, 1700000.000, 'Đã hoàn thành', '2025-08-24 07:18:00', 27),
(711, NULL, 16, 1300000.000, 'Đã hoàn thành', '2025-08-24 15:38:00', 27),
(712, NULL, 16, 800000.000, 'Đã hoàn thành', '2025-08-25 00:07:00', 27),
(713, NULL, 42, 700000.000, 'Đã hoàn thành', '2025-08-25 08:11:00', 27),
(714, NULL, 34, 800000.000, 'Đã hoàn thành', '2025-08-25 17:06:00', 28),
(715, NULL, 17, 1600000.000, 'Đã hoàn thành', '2025-08-26 01:21:00', 6),
(716, NULL, 18, 900000.000, 'Đã hoàn thành', '2025-08-26 08:12:00', 27),
(717, NULL, 16, 1100000.000, 'Đã hoàn thành', '2025-08-26 16:46:00', 27),
(718, NULL, 52, 1400000.000, 'Đã hoàn thành', '2025-08-26 23:54:00', 22),
(719, NULL, 16, 1100000.000, 'Đã hoàn thành', '2025-08-27 07:53:00', 28),
(720, NULL, 15, 1600000.000, 'Đã hoàn thành', '2025-08-27 14:40:00', 6),
(721, NULL, 15, 1600000.000, 'Đã hoàn thành', '2025-08-27 22:42:00', 22),
(722, NULL, 50, 900000.000, 'Đã hoàn thành', '2025-08-28 06:35:00', 22),
(723, NULL, 18, 1800000.000, 'Đã hoàn thành', '2025-08-28 15:24:00', 6),
(724, NULL, 15, 1800000.000, 'Đã hoàn thành', '2025-08-29 00:19:00', 6),
(725, NULL, 42, 1700000.000, 'Đã hoàn thành', '2025-08-29 07:14:00', 28),
(726, NULL, 34, 1700000.000, 'Đã hoàn thành', '2025-08-29 14:59:00', 22),
(727, NULL, 20, 2000000.000, 'Đã hoàn thành', '2025-08-29 22:52:00', 28),
(728, NULL, 32, 1700000.000, 'Đã hoàn thành', '2025-08-30 07:15:00', 27),
(729, NULL, 42, 1200000.000, 'Đã hoàn thành', '2025-08-30 14:06:00', 27),
(730, NULL, 42, 1800000.000, 'Đã hoàn thành', '2025-08-30 21:25:00', 6),
(731, NULL, 17, 900000.000, 'Đã hoàn thành', '2025-08-31 05:59:00', 28),
(732, NULL, 31, 1900000.000, 'Đã hoàn thành', '2025-08-31 12:40:00', 28),
(733, NULL, 50, 900000.000, 'Đã hoàn thành', '2025-08-31 20:16:00', 28),
(734, NULL, 15, 1400000.000, 'Đã hoàn thành', '2025-09-01 04:36:00', 6),
(735, NULL, 52, 1700000.000, 'Đã hoàn thành', '2025-09-01 13:32:00', 6),
(736, NULL, 31, 900000.000, 'Đã hoàn thành', '2025-09-01 20:46:00', 6),
(737, NULL, 17, 1400000.000, 'Đã hoàn thành', '2025-09-02 05:01:00', 22),
(738, NULL, 52, 1900000.000, 'Đã hoàn thành', '2025-09-02 11:49:00', 22),
(739, NULL, 32, 600000.000, 'Đã hoàn thành', '2025-09-02 20:05:00', 28),
(740, NULL, 31, 1100000.000, 'Đã hoàn thành', '2025-09-03 03:14:00', 6),
(741, NULL, 15, 1100000.000, 'Đã hoàn thành', '2025-09-03 11:26:00', 6),
(742, NULL, 15, 900000.000, 'Đã hoàn thành', '2025-09-03 19:30:00', 27),
(743, NULL, 42, 1700000.000, 'Đã hoàn thành', '2025-09-04 03:39:00', 27),
(744, NULL, 18, 1600000.000, 'Đã hoàn thành', '2025-09-04 12:33:00', 28),
(745, NULL, 32, 1000000.000, 'Đã hoàn thành', '2025-09-04 19:45:00', 22),
(746, NULL, 42, 900000.000, 'Đã hoàn thành', '2025-09-05 04:06:00', 28),
(747, NULL, 32, 2000000.000, 'Đã hoàn thành', '2025-09-05 10:46:00', 6),
(748, NULL, 52, 1900000.000, 'Đã hoàn thành', '2025-09-05 17:37:00', 22),
(749, NULL, 51, 1200000.000, 'Đã hoàn thành', '2025-09-06 01:26:00', 27),
(750, NULL, 17, 600000.000, 'Đã hoàn thành', '2025-09-06 09:25:00', 22),
(751, NULL, 20, 1500000.000, 'Đã hoàn thành', '2025-09-06 18:04:00', 28),
(752, NULL, 15, 1800000.000, 'Đã hoàn thành', '2025-09-07 01:23:00', 27),
(753, NULL, 31, 1400000.000, 'Đã hoàn thành', '2025-09-07 08:32:00', 28),
(754, NULL, 41, 500000.000, 'Đã hoàn thành', '2025-09-07 15:34:00', 27),
(755, NULL, 52, 1600000.000, 'Đã hoàn thành', '2025-09-07 22:36:00', 27),
(756, NULL, 41, 1000000.000, 'Đã hoàn thành', '2025-09-08 06:19:00', 6),
(757, NULL, 19, 1700000.000, 'Đã hoàn thành', '2025-09-08 15:23:00', 22),
(758, NULL, 15, 1100000.000, 'Đã hoàn thành', '2025-09-08 22:48:00', 22),
(759, NULL, 20, 500000.000, 'Đã hoàn thành', '2025-09-09 07:19:00', 28),
(760, NULL, 17, 1400000.000, 'Đã hoàn thành', '2025-09-09 14:40:00', 6),
(761, NULL, 20, 800000.000, 'Đã hoàn thành', '2025-09-09 23:14:00', 27),
(762, NULL, 42, 1500000.000, 'Đã hoàn thành', '2025-09-10 06:56:00', 28),
(763, NULL, 19, 1300000.000, 'Đã hoàn thành', '2025-09-10 15:54:00', 22),
(764, NULL, 52, 1800000.000, 'Đã hoàn thành', '2025-09-10 23:39:00', 22),
(765, NULL, 17, 1100000.000, 'Đã hoàn thành', '2025-09-11 07:44:00', 27),
(766, NULL, 50, 1800000.000, 'Đã hoàn thành', '2025-09-11 15:56:00', 27),
(767, NULL, 51, 2000000.000, 'Đã hoàn thành', '2025-09-11 22:41:00', 6),
(768, NULL, 34, 1700000.000, 'Đã hoàn thành', '2025-09-12 06:31:00', 28),
(769, NULL, 32, 1000000.000, 'Đã hoàn thành', '2025-09-12 13:51:00', 6),
(770, NULL, 18, 1700000.000, 'Đã hoàn thành', '2025-09-12 20:56:00', 6),
(771, NULL, 20, 600000.000, 'Đã hoàn thành', '2025-09-13 03:38:00', 27),
(772, NULL, 20, 1400000.000, 'Đã hoàn thành', '2025-09-13 11:44:00', 22),
(773, NULL, 42, 700000.000, 'Đã hoàn thành', '2025-09-13 18:33:00', 27),
(774, NULL, 31, 700000.000, 'Đã hoàn thành', '2025-09-14 01:44:00', 27),
(775, NULL, 32, 700000.000, 'Đã hoàn thành', '2025-09-14 09:39:00', 27),
(776, NULL, 18, 800000.000, 'Đã hoàn thành', '2025-09-14 18:05:00', 6),
(777, NULL, 31, 1900000.000, 'Đã hoàn thành', '2025-09-15 02:25:00', 27),
(778, NULL, 20, 500000.000, 'Đã hoàn thành', '2025-09-15 11:03:00', 27),
(779, NULL, 16, 1900000.000, 'Đã hoàn thành', '2025-09-15 19:49:00', 28),
(780, NULL, 31, 500000.000, 'Đã hoàn thành', '2025-09-16 04:32:00', 28),
(781, NULL, 42, 2000000.000, 'Đã hoàn thành', '2025-09-16 12:42:00', 6),
(782, NULL, 16, 1800000.000, 'Đã hoàn thành', '2025-09-16 19:36:00', 22),
(783, NULL, 42, 2000000.000, 'Đã hoàn thành', '2025-09-17 03:37:00', 6),
(784, NULL, 17, 600000.000, 'Đã hoàn thành', '2025-09-17 11:28:00', 6),
(785, NULL, 31, 1700000.000, 'Đã hoàn thành', '2025-09-17 18:52:00', 6),
(786, NULL, 52, 600000.000, 'Đã hoàn thành', '2025-09-18 03:07:00', 6),
(787, NULL, 34, 2000000.000, 'Đã hoàn thành', '2025-09-18 10:06:00', 28),
(788, NULL, 19, 1800000.000, 'Đã hoàn thành', '2025-09-18 17:00:00', 28),
(789, NULL, 17, 1300000.000, 'Đã hoàn thành', '2025-09-19 02:08:00', 27),
(790, NULL, 41, 600000.000, 'Đã hoàn thành', '2025-09-19 09:47:00', 27),
(791, NULL, 50, 800000.000, 'Đã hoàn thành', '2025-09-19 16:45:00', 28),
(792, NULL, 17, 1900000.000, 'Đã hoàn thành', '2025-09-20 01:44:00', 6),
(793, NULL, 19, 1400000.000, 'Đã hoàn thành', '2025-09-20 08:36:00', 28),
(794, NULL, 19, 1400000.000, 'Đã hoàn thành', '2025-09-20 15:25:00', 28),
(795, NULL, 15, 1300000.000, 'Đã hoàn thành', '2025-09-21 00:03:00', 28),
(796, NULL, 16, 1800000.000, 'Đã hoàn thành', '2025-09-21 07:34:00', 27),
(797, NULL, 34, 600000.000, 'Đã hoàn thành', '2025-09-21 15:08:00', 28),
(798, NULL, 32, 1100000.000, 'Đã hoàn thành', '2025-09-21 21:55:00', 22),
(799, NULL, 50, 1700000.000, 'Đã hoàn thành', '2025-09-22 04:44:00', 6),
(800, NULL, 41, 1800000.000, 'Đã hoàn thành', '2025-09-22 12:41:00', 22),
(801, NULL, 31, 1500000.000, 'Đã hoàn thành', '2025-09-22 20:29:00', 22),
(802, NULL, 34, 700000.000, 'Đã hoàn thành', '2025-09-23 04:32:00', 6),
(803, NULL, 52, 500000.000, 'Đã hoàn thành', '2025-09-23 12:42:00', 28),
(804, NULL, 51, 600000.000, 'Đã hoàn thành', '2025-09-23 19:41:00', 22),
(805, NULL, 17, 900000.000, 'Đã hoàn thành', '2025-09-24 03:38:00', 28),
(806, NULL, 51, 1600000.000, 'Đã hoàn thành', '2025-09-24 12:08:00', 28),
(807, NULL, 17, 900000.000, 'Đã hoàn thành', '2025-09-24 20:26:00', 22),
(808, NULL, 41, 600000.000, 'Đã hoàn thành', '2025-09-25 05:00:00', 27),
(809, NULL, 19, 1300000.000, 'Đã hoàn thành', '2025-09-25 12:37:00', 28),
(810, NULL, 19, 600000.000, 'Đã hoàn thành', '2025-09-25 21:26:00', 28),
(811, NULL, 52, 1300000.000, 'Đã hoàn thành', '2025-09-26 05:38:00', 28),
(812, NULL, 52, 1500000.000, 'Đã hoàn thành', '2025-09-26 12:54:00', 22),
(813, NULL, 50, 1000000.000, 'Đã hoàn thành', '2025-09-26 21:53:00', 27),
(814, NULL, 31, 2000000.000, 'Đã hoàn thành', '2025-09-27 06:01:00', 27),
(815, NULL, 16, 1400000.000, 'Đã hoàn thành', '2025-09-27 12:45:00', 27),
(816, NULL, 18, 1800000.000, 'Đã hoàn thành', '2025-09-27 19:58:00', 28),
(817, NULL, 42, 800000.000, 'Đã hoàn thành', '2025-09-28 04:24:00', 6),
(818, NULL, 31, 1200000.000, 'Đã hoàn thành', '2025-09-28 12:32:00', 27),
(819, NULL, 51, 700000.000, 'Đã hoàn thành', '2025-09-28 20:23:00', 22),
(820, NULL, 34, 1100000.000, 'Đã hoàn thành', '2025-09-29 04:21:00', 22),
(821, NULL, 31, 2000000.000, 'Đã hoàn thành', '2025-09-29 12:30:00', 6),
(822, NULL, 19, 800000.000, 'Đã hoàn thành', '2025-09-29 20:59:00', 6),
(823, NULL, 19, 1600000.000, 'Đã hoàn thành', '2025-09-30 05:20:00', 6),
(824, NULL, 52, 1400000.000, 'Đã hoàn thành', '2025-09-30 12:10:00', 22),
(825, NULL, 31, 1100000.000, 'Đã hoàn thành', '2025-09-30 21:20:00', 28),
(826, NULL, 34, 1800000.000, 'Đã hoàn thành', '2025-10-01 04:37:00', 28),
(827, NULL, 16, 1200000.000, 'Đã hoàn thành', '2025-10-01 12:36:00', 6),
(828, NULL, 51, 1100000.000, 'Đã hoàn thành', '2025-10-01 21:21:00', 28),
(829, NULL, 32, 700000.000, 'Đã hoàn thành', '2025-10-02 06:09:00', 28),
(830, NULL, 19, 800000.000, 'Đã hoàn thành', '2025-10-02 13:35:00', 28),
(831, NULL, 34, 1000000.000, 'Đã hoàn thành', '2025-10-02 22:19:00', 27),
(832, NULL, 34, 1500000.000, 'Đã hoàn thành', '2025-10-03 06:47:00', 27),
(833, NULL, 19, 500000.000, 'Đã hoàn thành', '2025-10-03 14:03:00', 22),
(834, NULL, 31, 600000.000, 'Đã hoàn thành', '2025-10-03 22:49:00', 28),
(835, NULL, 42, 1200000.000, 'Đã hoàn thành', '2025-10-04 06:16:00', 27),
(836, NULL, 15, 2000000.000, 'Đã hoàn thành', '2025-10-04 13:00:00', 22),
(837, NULL, 20, 900000.000, 'Đã hoàn thành', '2025-10-04 20:18:00', 27),
(838, NULL, 34, 1600000.000, 'Đã hoàn thành', '2025-10-05 03:03:00', 28),
(839, NULL, 31, 700000.000, 'Đã hoàn thành', '2025-10-05 10:46:00', 28),
(840, NULL, 18, 700000.000, 'Đã hoàn thành', '2025-10-05 18:59:00', 27),
(841, NULL, 42, 1900000.000, 'Đã hoàn thành', '2025-10-06 03:58:00', 22),
(842, NULL, 50, 1500000.000, 'Đã hoàn thành', '2025-10-06 11:21:00', 27),
(843, NULL, 19, 1600000.000, 'Đã hoàn thành', '2025-10-06 18:22:00', 22),
(844, NULL, 32, 1400000.000, 'Đã hoàn thành', '2025-10-07 02:15:00', 6),
(845, NULL, 50, 500000.000, 'Đã hoàn thành', '2025-10-07 09:46:00', 27),
(846, NULL, 20, 900000.000, 'Đã hoàn thành', '2025-10-07 17:59:00', 6),
(847, NULL, 19, 1600000.000, 'Đã hoàn thành', '2025-10-08 03:03:00', 27),
(848, NULL, 41, 600000.000, 'Đã hoàn thành', '2025-10-08 10:58:00', 28),
(849, NULL, 34, 800000.000, 'Đã hoàn thành', '2025-10-08 18:18:00', 6),
(850, NULL, 19, 1700000.000, 'Đã hoàn thành', '2025-10-09 01:17:00', 22),
(851, NULL, 20, 700000.000, 'Đã hoàn thành', '2025-10-09 09:34:00', 22),
(852, NULL, 52, 1300000.000, 'Đã hoàn thành', '2025-10-09 17:28:00', 27),
(853, NULL, 50, 1900000.000, 'Đã hoàn thành', '2025-10-10 02:24:00', 6),
(854, NULL, 16, 1000000.000, 'Đã hoàn thành', '2025-10-10 10:57:00', 27),
(855, NULL, 52, 800000.000, 'Đã hoàn thành', '2025-10-10 18:18:00', 6),
(856, NULL, 51, 1100000.000, 'Đã hoàn thành', '2025-10-11 01:41:00', 22),
(857, NULL, 34, 1400000.000, 'Đã hoàn thành', '2025-10-11 10:39:00', 22),
(858, NULL, 34, 1800000.000, 'Đã hoàn thành', '2025-10-11 17:26:00', 27),
(859, NULL, 42, 1100000.000, 'Đã hoàn thành', '2025-10-12 01:25:00', 6),
(860, NULL, 32, 1500000.000, 'Đã hoàn thành', '2025-10-12 09:23:00', 28),
(861, NULL, 41, 2000000.000, 'Đã hoàn thành', '2025-10-12 17:23:00', 27),
(862, NULL, 15, 1900000.000, 'Đã hoàn thành', '2025-10-13 01:23:00', 6),
(863, NULL, 41, 600000.000, 'Đã hoàn thành', '2025-10-13 09:59:00', 28),
(864, NULL, 17, 1900000.000, 'Đã hoàn thành', '2025-10-13 17:25:00', 28),
(865, NULL, 18, 2000000.000, 'Đã hoàn thành', '2025-10-14 02:04:00', 6),
(866, NULL, 15, 1700000.000, 'Đã hoàn thành', '2025-10-14 10:05:00', 28),
(867, NULL, 19, 700000.000, 'Đã hoàn thành', '2025-10-14 18:06:00', 27),
(868, NULL, 32, 600000.000, 'Đã hoàn thành', '2025-10-15 01:06:00', 22),
(869, NULL, 52, 1900000.000, 'Đã hoàn thành', '2025-10-15 10:03:00', 22),
(870, NULL, 20, 700000.000, 'Đã hoàn thành', '2025-10-15 18:36:00', 28),
(871, NULL, 31, 1500000.000, 'Đã hoàn thành', '2025-10-16 02:04:00', 22),
(872, NULL, 41, 1900000.000, 'Đã hoàn thành', '2025-10-16 10:20:00', 28),
(873, NULL, 41, 1100000.000, 'Đã hoàn thành', '2025-10-16 18:14:00', 6),
(874, NULL, 51, 1500000.000, 'Đã hoàn thành', '2025-10-17 02:54:00', 6),
(875, NULL, 19, 1900000.000, 'Đã hoàn thành', '2025-10-17 10:36:00', 27),
(876, NULL, 16, 1900000.000, 'Đã hoàn thành', '2025-10-17 19:25:00', 28),
(877, NULL, 50, 1400000.000, 'Đã hoàn thành', '2025-10-18 03:45:00', 6),
(878, NULL, 42, 2000000.000, 'Đã hoàn thành', '2025-10-18 12:46:00', 27),
(879, NULL, 41, 1900000.000, 'Đã hoàn thành', '2025-10-18 20:31:00', 27),
(880, NULL, 32, 1800000.000, 'Đã hoàn thành', '2025-10-19 03:16:00', 28),
(881, NULL, 15, 600000.000, 'Đã hoàn thành', '2025-10-19 10:36:00', 6),
(882, NULL, 52, 1200000.000, 'Đã hoàn thành', '2025-10-19 17:22:00', 22),
(883, NULL, 52, 2000000.000, 'Đã hoàn thành', '2025-10-20 02:10:00', 27),
(884, NULL, 51, 2000000.000, 'Đã hoàn thành', '2025-10-20 10:32:00', 6),
(885, NULL, 52, 1900000.000, 'Đã hoàn thành', '2025-10-20 18:47:00', 6),
(886, NULL, 31, 2000000.000, 'Đã hoàn thành', '2025-10-21 02:16:00', 22),
(887, NULL, 41, 800000.000, 'Đã hoàn thành', '2025-10-21 09:02:00', 22),
(888, NULL, 19, 1200000.000, 'Đã hoàn thành', '2025-10-21 17:14:00', 28),
(889, NULL, 34, 1800000.000, 'Đã hoàn thành', '2025-10-22 01:56:00', 28),
(890, NULL, 19, 900000.000, 'Đã hoàn thành', '2025-10-22 11:05:00', 28),
(891, NULL, 41, 1600000.000, 'Đã hoàn thành', '2025-10-22 18:06:00', 6),
(892, NULL, 15, 500000.000, 'Đã hoàn thành', '2025-10-23 00:59:00', 28),
(893, NULL, 42, 1400000.000, 'Đã hoàn thành', '2025-10-23 09:43:00', 22),
(894, NULL, 15, 1200000.000, 'Đã hoàn thành', '2025-10-23 18:22:00', 22),
(895, NULL, 18, 1400000.000, 'Đã hoàn thành', '2025-10-24 03:13:00', 22),
(896, NULL, 50, 700000.000, 'Đã hoàn thành', '2025-10-24 12:04:00', 27),
(897, NULL, 52, 1900000.000, 'Đã hoàn thành', '2025-10-24 19:46:00', 27),
(898, NULL, 42, 1600000.000, 'Đã hoàn thành', '2025-10-25 04:38:00', 28),
(899, NULL, 52, 1600000.000, 'Đã hoàn thành', '2025-10-25 11:46:00', 28),
(900, NULL, 42, 600000.000, 'Đã hoàn thành', '2025-10-25 18:38:00', 6),
(901, NULL, 32, 1700000.000, 'Đã hoàn thành', '2025-10-26 03:03:00', 6),
(902, NULL, 16, 1700000.000, 'Đã hoàn thành', '2025-10-26 11:16:00', 28),
(903, NULL, 17, 900000.000, 'Đã hoàn thành', '2025-10-26 18:58:00', 6),
(904, NULL, 16, 600000.000, 'Đã hoàn thành', '2025-10-27 04:06:00', 28),
(905, NULL, 51, 1100000.000, 'Đã hoàn thành', '2025-10-27 12:34:00', 28),
(906, NULL, 19, 1500000.000, 'Đã hoàn thành', '2025-10-27 19:29:00', 27),
(907, NULL, 32, 2000000.000, 'Đã hoàn thành', '2025-10-28 03:34:00', 27),
(908, NULL, 32, 1300000.000, 'Đã hoàn thành', '2025-10-28 12:05:00', 22),
(909, NULL, 17, 600000.000, 'Đã hoàn thành', '2025-10-28 20:49:00', 28),
(910, NULL, 17, 700000.000, 'Đã hoàn thành', '2025-10-29 04:17:00', 28),
(911, NULL, 42, 1400000.000, 'Đã hoàn thành', '2025-10-29 11:43:00', 22),
(912, NULL, 16, 1800000.000, 'Đã hoàn thành', '2025-10-29 19:44:00', 28),
(913, NULL, 41, 1500000.000, 'Đã hoàn thành', '2025-10-30 03:36:00', 22),
(914, NULL, 17, 1300000.000, 'Đã hoàn thành', '2025-10-30 11:01:00', 22),
(915, NULL, 17, 2000000.000, 'Đã hoàn thành', '2025-10-30 20:03:00', 22),
(916, NULL, 50, 1800000.000, 'Đã hoàn thành', '2025-10-31 04:34:00', 22),
(917, NULL, 50, 1300000.000, 'Đã hoàn thành', '2025-10-31 12:39:00', 22),
(918, NULL, 32, 700000.000, 'Đã hoàn thành', '2025-10-31 21:38:00', 27),
(919, NULL, 15, 700000.000, 'Đã hoàn thành', '2025-11-01 05:01:00', 27),
(920, NULL, 41, 800000.000, 'Đã hoàn thành', '2025-11-01 12:44:00', 22),
(921, NULL, 17, 2000000.000, 'Đã hoàn thành', '2025-11-01 21:50:00', 27),
(922, NULL, 34, 1200000.000, 'Đã hoàn thành', '2025-11-02 05:04:00', 27),
(923, NULL, 34, 1800000.000, 'Đã hoàn thành', '2025-11-02 13:24:00', 28),
(924, NULL, 52, 500000.000, 'Đã hoàn thành', '2025-11-02 21:26:00', 22),
(925, NULL, 51, 700000.000, 'Đã hoàn thành', '2025-11-03 05:50:00', 27),
(926, NULL, 18, 600000.000, 'Đã hoàn thành', '2025-11-03 14:40:00', 27),
(927, NULL, 15, 1200000.000, 'Đã hoàn thành', '2025-11-03 23:18:00', 27),
(928, NULL, 41, 1700000.000, 'Đã hoàn thành', '2025-11-04 06:38:00', 27),
(929, NULL, 32, 1700000.000, 'Đã hoàn thành', '2025-11-04 13:47:00', 6),
(930, NULL, 50, 1900000.000, 'Đã hoàn thành', '2025-11-04 21:06:00', 22),
(931, NULL, 17, 500000.000, 'Đã hoàn thành', '2025-11-05 03:53:00', 27),
(932, NULL, 32, 1300000.000, 'Đã hoàn thành', '2025-11-05 11:50:00', 28),
(933, NULL, 52, 1800000.000, 'Đã hoàn thành', '2025-11-05 19:34:00', 27),
(934, NULL, 34, 1500000.000, 'Đã hoàn thành', '2025-11-06 02:52:00', 28),
(935, NULL, 42, 1100000.000, 'Đã hoàn thành', '2025-11-06 10:13:00', 22),
(936, NULL, 32, 500000.000, 'Đã hoàn thành', '2025-11-06 19:05:00', 22),
(937, NULL, 51, 700000.000, 'Đã hoàn thành', '2025-11-07 02:54:00', 27),
(938, NULL, 50, 600000.000, 'Đã hoàn thành', '2025-11-07 09:58:00', 27),
(939, NULL, 31, 1500000.000, 'Đã hoàn thành', '2025-11-07 16:42:00', 6),
(940, NULL, 17, 1100000.000, 'Đã hoàn thành', '2025-11-08 00:01:00', 27),
(941, NULL, 15, 500000.000, 'Đã hoàn thành', '2025-11-08 07:47:00', 6),
(942, NULL, 34, 1100000.000, 'Đã hoàn thành', '2025-11-08 16:13:00', 27),
(943, NULL, 31, 1200000.000, 'Đã hoàn thành', '2025-11-08 23:25:00', 22),
(944, NULL, 41, 2000000.000, 'Đã hoàn thành', '2025-11-09 06:49:00', 28),
(945, NULL, 50, 1800000.000, 'Đã hoàn thành', '2025-11-09 15:57:00', 22),
(946, NULL, 31, 1100000.000, 'Đã hoàn thành', '2025-11-09 23:15:00', 22),
(947, NULL, 51, 1600000.000, 'Đã hoàn thành', '2025-11-10 07:32:00', 6),
(948, NULL, 31, 1800000.000, 'Đã hoàn thành', '2025-11-10 15:49:00', 28),
(949, NULL, 15, 1800000.000, 'Đã hoàn thành', '2025-11-10 23:23:00', 22),
(950, NULL, 15, 1800000.000, 'Đã hoàn thành', '2025-11-11 08:11:00', 22),
(951, NULL, 34, 500000.000, 'Đã hoàn thành', '2025-11-11 15:43:00', 27),
(952, NULL, 15, 1700000.000, 'Đã hoàn thành', '2025-11-11 23:13:00', 28),
(953, NULL, 50, 1900000.000, 'Đã hoàn thành', '2025-11-12 06:30:00', 27),
(954, NULL, 32, 1800000.000, 'Đã hoàn thành', '2025-11-12 15:16:00', 6),
(955, NULL, 19, 1500000.000, 'Đã hoàn thành', '2025-11-12 23:34:00', 22),
(956, NULL, 34, 2000000.000, 'Đã hoàn thành', '2025-11-13 08:31:00', 6),
(957, NULL, 52, 1400000.000, 'Đã hoàn thành', '2025-11-13 15:54:00', 28),
(958, NULL, 31, 1800000.000, 'Đã hoàn thành', '2025-11-13 23:06:00', 28),
(959, NULL, 20, 800000.000, 'Đã hoàn thành', '2025-11-14 06:00:00', 6),
(960, NULL, 15, 1300000.000, 'Đã hoàn thành', '2025-11-14 14:30:00', 28),
(961, NULL, 18, 900000.000, 'Đã hoàn thành', '2025-11-14 21:24:00', 28),
(962, NULL, 51, 1800000.000, 'Đã hoàn thành', '2025-11-15 06:09:00', 28),
(963, NULL, 32, 1500000.000, 'Đã hoàn thành', '2025-11-15 14:53:00', 27),
(964, NULL, 50, 1800000.000, 'Đã hoàn thành', '2025-11-15 22:40:00', 22),
(965, NULL, 42, 1800000.000, 'Đã hoàn thành', '2025-11-16 06:16:00', 27),
(966, NULL, 41, 1300000.000, 'Đã hoàn thành', '2025-11-16 12:56:00', 27),
(967, NULL, 51, 1100000.000, 'Đã hoàn thành', '2025-11-16 20:56:00', 28),
(968, NULL, 32, 1700000.000, 'Đã hoàn thành', '2025-11-17 05:44:00', 6),
(969, NULL, 42, 900000.000, 'Đã hoàn thành', '2025-11-17 13:11:00', 6),
(970, NULL, 42, 2000000.000, 'Đã hoàn thành', '2025-11-17 20:14:00', 6),
(971, NULL, 50, 800000.000, 'Đã hoàn thành', '2025-11-18 05:21:00', 28),
(972, NULL, 34, 1500000.000, 'Đã hoàn thành', '2025-11-18 13:04:00', 27),
(973, NULL, 50, 2000000.000, 'Đã hoàn thành', '2025-11-18 20:58:00', 27),
(974, NULL, 34, 1700000.000, 'Đã hoàn thành', '2025-11-19 05:40:00', 27),
(975, NULL, 20, 700000.000, 'Đã hoàn thành', '2025-11-19 14:39:00', 27),
(976, NULL, 31, 1800000.000, 'Đã hoàn thành', '2025-11-19 21:25:00', 6),
(977, NULL, 34, 1400000.000, 'Đã hoàn thành', '2025-11-20 04:39:00', 27),
(978, NULL, 42, 1800000.000, 'Đã hoàn thành', '2025-11-20 12:36:00', 6),
(979, NULL, 52, 1100000.000, 'Đã hoàn thành', '2025-11-20 20:32:00', 28),
(980, NULL, 31, 1400000.000, 'Đã hoàn thành', '2025-11-21 04:48:00', 27),
(981, NULL, 50, 1000000.000, 'Đã hoàn thành', '2025-11-21 13:22:00', 22),
(982, NULL, 51, 1400000.000, 'Đã hoàn thành', '2025-11-21 22:29:00', 28),
(983, NULL, 15, 1000000.000, 'Đã hoàn thành', '2025-11-22 06:47:00', 27),
(984, NULL, 17, 800000.000, 'Đã hoàn thành', '2025-11-22 14:53:00', 27),
(985, NULL, 19, 600000.000, 'Đã hoàn thành', '2025-11-22 22:22:00', 6),
(986, NULL, 34, 500000.000, 'Đã hoàn thành', '2025-11-23 06:28:00', 27),
(987, NULL, 31, 2000000.000, 'Đã hoàn thành', '2025-11-23 14:46:00', 28),
(988, NULL, 17, 600000.000, 'Đã hoàn thành', '2025-11-23 23:06:00', 22),
(989, NULL, 41, 800000.000, 'Đã hoàn thành', '2025-11-24 06:40:00', 22),
(990, NULL, 31, 1500000.000, 'Đã hoàn thành', '2025-11-24 13:36:00', 28),
(991, NULL, 52, 1000000.000, 'Đã hoàn thành', '2025-11-24 20:37:00', 28),
(992, NULL, 32, 800000.000, 'Đã hoàn thành', '2025-11-25 04:04:00', 6),
(993, NULL, 51, 1000000.000, 'Đã hoàn thành', '2025-11-25 11:33:00', 27),
(994, NULL, 18, 1300000.000, 'Đã hoàn thành', '2025-11-25 19:17:00', 28),
(995, NULL, 18, 600000.000, 'Đã hoàn thành', '2025-11-26 02:25:00', 28),
(996, NULL, 51, 1200000.000, 'Đã hoàn thành', '2025-11-26 10:38:00', 28),
(997, NULL, 18, 600000.000, 'Đã hoàn thành', '2025-11-26 17:34:00', 28),
(998, NULL, 51, 2000000.000, 'Đã hoàn thành', '2025-11-27 01:09:00', 27),
(999, NULL, 17, 1200000.000, 'Đã hoàn thành', '2025-11-27 09:25:00', 22),
(1000, NULL, 42, 800000.000, 'Đã hoàn thành', '2025-11-27 16:44:00', 6),
(1001, NULL, 51, 1425000.000, 'Đã hoàn thành', '2025-11-26 09:35:31', 6),
(1002, NULL, 18, 660000.000, 'Đã hoàn thành', '2025-11-27 18:41:50', 6),
(1003, NULL, 18, 990000.000, 'Đã hoàn thành', '2025-11-27 20:23:57', 6),
(1004, NULL, 18, 510000.000, 'Đã hoàn thành', '2025-11-27 20:25:54', 6),
(1005, NULL, 18, 330000.000, 'Đã hoàn thành', '2025-11-27 20:39:01', 6),
(1006, NULL, 18, 585000.000, 'Đã hoàn thành', '2025-11-27 21:12:36', 6),
(1007, NULL, 18, 510000.000, 'Đã hoàn thành', '2025-11-27 21:12:51', 6),
(1008, NULL, 18, 360000.000, 'Đã hoàn thành', '2025-11-27 21:15:56', 6),
(1009, NULL, 18, 180000.000, 'Đã hoàn thành', '2025-11-27 21:16:04', 6),
(1010, NULL, 18, 360000.000, 'Đã hoàn thành', '2025-11-27 21:46:11', 6),
(1011, NULL, 51, 1500000.000, 'Đã hoàn thành', '2025-11-27 21:46:39', 6),
(1012, NULL, 18, 360000.000, 'Đã hoàn thành', '2025-11-28 06:59:50', 6),
(1013, NULL, 52, 860000.000, 'Đã hoàn thành', '2025-11-28 07:00:04', 6);

-- --------------------------------------------------------

--
-- Table structure for table `genres`
--

CREATE TABLE `genres` (
  `genre_id` int(11) NOT NULL,
  `genre_name` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `genres`
--

INSERT INTO `genres` (`genre_id`, `genre_name`, `created_at`) VALUES
(6, 'Bi kịch', '2025-10-03 16:00:14'),
(7, 'Hài kịch', '2025-10-03 16:00:24'),
(8, 'Tâm lý - Xã hội', '2025-10-03 16:00:33'),
(9, 'Hiện thực', '2025-10-03 16:00:41'),
(10, 'Dân gian', '2025-10-03 16:00:49'),
(11, 'Lãng mạn', '2025-10-03 16:01:04'),
(12, 'Giả tưởng - huyền ảo', '2025-10-03 16:01:15'),
(13, 'Huyền bí', '2025-10-03 16:01:22'),
(14, 'Chuyển thể cổ tích', '2025-10-03 16:01:35'),
(15, 'Kinh điển', '2025-10-03 16:01:42'),
(16, 'Gia đình - tình cảm', '2025-11-04 12:32:59'),
(17, 'Lịch sử', '2025-11-04 12:34:03'),
(18, 'Chính luận - Xã hội', '2025-11-04 12:34:20'),
(19, 'Châm biếm - Trào phúng', '2025-11-04 12:34:51');

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

CREATE TABLE `payments` (
  `payment_id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `amount` decimal(10,3) NOT NULL,
  `status` enum('Đang chờ','Thành công','Thất bại') NOT NULL DEFAULT 'Đang chờ',
  `payment_method` varchar(50) DEFAULT NULL,
  `vnp_txn_ref` varchar(64) DEFAULT NULL,
  `vnp_bank_code` varchar(20) DEFAULT NULL,
  `vnp_pay_date` varchar(14) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `payments`
--

INSERT INTO `payments` (`payment_id`, `booking_id`, `amount`, `status`, `payment_method`, `vnp_txn_ref`, `vnp_bank_code`, `vnp_pay_date`, `created_at`, `updated_at`) VALUES
(1, 1, 6000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-01 09:59:00', '2025-01-01 09:59:00'),
(2, 2, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-01 17:57:00', '2025-01-01 17:57:00'),
(3, 3, 5800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-02 01:12:00', '2025-01-02 01:12:00'),
(4, 4, 3200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-02 08:11:00', '2025-01-02 08:11:00'),
(5, 5, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-02 16:00:00', '2025-01-02 16:00:00'),
(6, 6, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-03 00:17:00', '2025-01-03 00:17:00'),
(7, 7, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-03 07:13:00', '2025-01-03 07:13:00'),
(8, 8, 2500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-03 14:22:00', '2025-01-03 14:22:00'),
(9, 9, 3300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-03 22:46:00', '2025-01-03 22:46:00'),
(10, 10, 3700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-04 07:52:00', '2025-01-04 07:52:00'),
(11, 11, 3000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-04 15:22:00', '2025-01-04 15:22:00'),
(12, 12, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-04 22:47:00', '2025-01-04 22:47:00'),
(13, 13, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-05 06:03:00', '2025-01-05 06:03:00'),
(14, 14, 3800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-05 12:45:00', '2025-01-05 12:45:00'),
(15, 15, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-05 21:24:00', '2025-01-05 21:24:00'),
(16, 16, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-06 06:06:00', '2025-01-06 06:06:00'),
(17, 17, 3800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-06 14:26:00', '2025-01-06 14:26:00'),
(18, 18, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-06 23:04:00', '2025-01-06 23:04:00'),
(19, 19, 6000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-07 06:13:00', '2025-01-07 06:13:00'),
(20, 20, 2900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-07 13:31:00', '2025-01-07 13:31:00'),
(21, 21, 3100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-07 20:28:00', '2025-01-07 20:28:00'),
(22, 22, 6000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-08 03:56:00', '2025-01-08 03:56:00'),
(23, 23, 4100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-08 11:47:00', '2025-01-08 11:47:00'),
(24, 24, 4100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-08 20:50:00', '2025-01-08 20:50:00'),
(25, 25, 2800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-09 04:08:00', '2025-01-09 04:08:00'),
(26, 26, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-09 12:32:00', '2025-01-09 12:32:00'),
(27, 27, 2500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-09 21:36:00', '2025-01-09 21:36:00'),
(28, 28, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-10 05:32:00', '2025-01-10 05:32:00'),
(29, 29, 2100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-10 12:27:00', '2025-01-10 12:27:00'),
(30, 30, 3500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-10 20:26:00', '2025-01-10 20:26:00'),
(31, 31, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-11 05:07:00', '2025-01-11 05:07:00'),
(32, 32, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-11 12:28:00', '2025-01-11 12:28:00'),
(33, 33, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-11 19:42:00', '2025-01-11 19:42:00'),
(34, 34, 3200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-12 02:28:00', '2025-01-12 02:28:00'),
(35, 35, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-12 11:15:00', '2025-01-12 11:15:00'),
(36, 36, 4200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-12 20:12:00', '2025-01-12 20:12:00'),
(37, 37, 5700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-13 05:18:00', '2025-01-13 05:18:00'),
(38, 38, 2100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-13 12:15:00', '2025-01-13 12:15:00'),
(39, 39, 2700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-13 20:41:00', '2025-01-13 20:41:00'),
(40, 40, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-14 03:23:00', '2025-01-14 03:23:00'),
(41, 41, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-14 11:13:00', '2025-01-14 11:13:00'),
(42, 42, 4500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-14 19:27:00', '2025-01-14 19:27:00'),
(43, 43, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-15 03:50:00', '2025-01-15 03:50:00'),
(44, 44, 2400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-15 12:53:00', '2025-01-15 12:53:00'),
(45, 45, 4100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-15 21:03:00', '2025-01-15 21:03:00'),
(46, 46, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-16 05:20:00', '2025-01-16 05:20:00'),
(47, 47, 5600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-16 13:24:00', '2025-01-16 13:24:00'),
(48, 48, 2900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-16 22:00:00', '2025-01-16 22:00:00'),
(49, 49, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-17 05:56:00', '2025-01-17 05:56:00'),
(50, 50, 2100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-17 13:22:00', '2025-01-17 13:22:00'),
(51, 51, 3100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-17 20:47:00', '2025-01-17 20:47:00'),
(52, 52, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-18 05:48:00', '2025-01-18 05:48:00'),
(53, 53, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-18 14:52:00', '2025-01-18 14:52:00'),
(54, 54, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-18 23:01:00', '2025-01-18 23:01:00'),
(55, 55, 3200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-19 05:57:00', '2025-01-19 05:57:00'),
(56, 56, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-19 13:04:00', '2025-01-19 13:04:00'),
(57, 57, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-19 21:55:00', '2025-01-19 21:55:00'),
(58, 58, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-20 06:14:00', '2025-01-20 06:14:00'),
(59, 59, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-20 13:53:00', '2025-01-20 13:53:00'),
(60, 60, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-20 21:27:00', '2025-01-20 21:27:00'),
(61, 61, 3800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-21 04:19:00', '2025-01-21 04:19:00'),
(62, 62, 2100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-21 11:24:00', '2025-01-21 11:24:00'),
(63, 63, 4100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-21 19:07:00', '2025-01-21 19:07:00'),
(64, 64, 3700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-22 02:10:00', '2025-01-22 02:10:00'),
(65, 65, 2100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-22 09:54:00', '2025-01-22 09:54:00'),
(66, 66, 4200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-22 17:28:00', '2025-01-22 17:28:00'),
(67, 67, 2100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-23 02:12:00', '2025-01-23 02:12:00'),
(68, 68, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-23 08:54:00', '2025-01-23 08:54:00'),
(69, 69, 4100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-23 15:50:00', '2025-01-23 15:50:00'),
(70, 70, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-24 00:01:00', '2025-01-24 00:01:00'),
(71, 71, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-24 09:09:00', '2025-01-24 09:09:00'),
(72, 72, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-24 16:54:00', '2025-01-24 16:54:00'),
(73, 73, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-25 00:53:00', '2025-01-25 00:53:00'),
(74, 74, 5700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-25 08:39:00', '2025-01-25 08:39:00'),
(75, 75, 2800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-25 16:01:00', '2025-01-25 16:01:00'),
(76, 76, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-25 23:53:00', '2025-01-25 23:53:00'),
(77, 77, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-26 08:06:00', '2025-01-26 08:06:00'),
(78, 78, 3700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-26 15:48:00', '2025-01-26 15:48:00'),
(79, 79, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-27 00:48:00', '2025-01-27 00:48:00'),
(80, 80, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-27 07:30:00', '2025-01-27 07:30:00'),
(81, 81, 2400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-27 15:55:00', '2025-01-27 15:55:00'),
(82, 82, 3900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-28 00:26:00', '2025-01-28 00:26:00'),
(83, 83, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-28 08:45:00', '2025-01-28 08:45:00'),
(84, 84, 2900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-28 15:27:00', '2025-01-28 15:27:00'),
(85, 85, 5800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-28 22:27:00', '2025-01-28 22:27:00'),
(86, 86, 2900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-29 05:49:00', '2025-01-29 05:49:00'),
(87, 87, 2400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-29 14:36:00', '2025-01-29 14:36:00'),
(88, 88, 3600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-29 22:04:00', '2025-01-29 22:04:00'),
(89, 89, 6000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-30 05:20:00', '2025-01-30 05:20:00'),
(90, 90, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-30 12:41:00', '2025-01-30 12:41:00'),
(91, 91, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-30 21:41:00', '2025-01-30 21:41:00'),
(92, 92, 4200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-31 06:05:00', '2025-01-31 06:05:00'),
(93, 93, 2100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-31 13:03:00', '2025-01-31 13:03:00'),
(94, 94, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-01-31 21:34:00', '2025-01-31 21:34:00'),
(95, 95, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-01 06:03:00', '2025-02-01 06:03:00'),
(96, 96, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-01 14:48:00', '2025-02-01 14:48:00'),
(97, 97, 2700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-01 23:40:00', '2025-02-01 23:40:00'),
(98, 98, 6000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-02 07:54:00', '2025-02-02 07:54:00'),
(99, 99, 2800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-02 15:36:00', '2025-02-02 15:36:00'),
(100, 100, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-02 23:53:00', '2025-02-02 23:53:00'),
(101, 101, 3400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-03 06:42:00', '2025-02-03 06:42:00'),
(102, 102, 3500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-03 13:32:00', '2025-02-03 13:32:00'),
(103, 103, 2700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-03 21:41:00', '2025-02-03 21:41:00'),
(104, 104, 3800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-04 04:23:00', '2025-02-04 04:23:00'),
(105, 105, 5700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-04 12:42:00', '2025-02-04 12:42:00'),
(106, 106, 3800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-04 19:53:00', '2025-02-04 19:53:00'),
(107, 107, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-05 03:46:00', '2025-02-05 03:46:00'),
(108, 108, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-05 10:55:00', '2025-02-05 10:55:00'),
(109, 109, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-05 19:50:00', '2025-02-05 19:50:00'),
(110, 110, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-06 03:47:00', '2025-02-06 03:47:00'),
(111, 111, 4100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-06 11:15:00', '2025-02-06 11:15:00'),
(112, 112, 2500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-06 19:58:00', '2025-02-06 19:58:00'),
(113, 113, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-07 03:33:00', '2025-02-07 03:33:00'),
(114, 114, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-07 10:17:00', '2025-02-07 10:17:00'),
(115, 115, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-07 16:57:00', '2025-02-07 16:57:00'),
(116, 116, 5300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-08 00:38:00', '2025-02-08 00:38:00'),
(117, 117, 2300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-08 07:51:00', '2025-02-08 07:51:00'),
(118, 118, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-08 15:39:00', '2025-02-08 15:39:00'),
(119, 119, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-09 00:48:00', '2025-02-09 00:48:00'),
(120, 120, 2500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-09 09:16:00', '2025-02-09 09:16:00'),
(121, 121, 6000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-09 17:17:00', '2025-02-09 17:17:00'),
(122, 122, 6000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-10 02:23:00', '2025-02-10 02:23:00'),
(123, 123, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-10 09:47:00', '2025-02-10 09:47:00'),
(124, 124, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-10 17:18:00', '2025-02-10 17:18:00'),
(125, 125, 3600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-11 00:55:00', '2025-02-11 00:55:00'),
(126, 126, 5300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-11 08:31:00', '2025-02-11 08:31:00'),
(127, 127, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-11 15:35:00', '2025-02-11 15:35:00'),
(128, 128, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-11 23:58:00', '2025-02-11 23:58:00'),
(129, 129, 5300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-12 07:25:00', '2025-02-12 07:25:00'),
(130, 130, 3000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-12 14:15:00', '2025-02-12 14:15:00'),
(131, 131, 2200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-12 21:16:00', '2025-02-12 21:16:00'),
(132, 132, 2300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-13 05:59:00', '2025-02-13 05:59:00'),
(133, 133, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-13 15:02:00', '2025-02-13 15:02:00'),
(134, 134, 2100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-13 23:36:00', '2025-02-13 23:36:00'),
(135, 135, 5700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-14 07:27:00', '2025-02-14 07:27:00'),
(136, 136, 2300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-14 16:23:00', '2025-02-14 16:23:00'),
(137, 137, 3600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-15 00:34:00', '2025-02-15 00:34:00'),
(138, 138, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-15 09:37:00', '2025-02-15 09:37:00'),
(139, 139, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-15 18:47:00', '2025-02-15 18:47:00'),
(140, 140, 6000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-16 02:10:00', '2025-02-16 02:10:00'),
(141, 141, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-16 10:48:00', '2025-02-16 10:48:00'),
(142, 142, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-16 18:31:00', '2025-02-16 18:31:00'),
(143, 143, 3900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-17 02:17:00', '2025-02-17 02:17:00'),
(144, 144, 4500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-17 09:49:00', '2025-02-17 09:49:00'),
(145, 145, 4100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-17 17:12:00', '2025-02-17 17:12:00'),
(146, 146, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-18 02:12:00', '2025-02-18 02:12:00'),
(147, 147, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-18 09:39:00', '2025-02-18 09:39:00'),
(148, 148, 5700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-18 16:28:00', '2025-02-18 16:28:00'),
(149, 149, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-19 01:21:00', '2025-02-19 01:21:00'),
(150, 150, 3800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-19 08:07:00', '2025-02-19 08:07:00'),
(151, 151, 3300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-19 14:52:00', '2025-02-19 14:52:00'),
(152, 152, 5800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-19 21:44:00', '2025-02-19 21:44:00'),
(153, 153, 2300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-20 04:51:00', '2025-02-20 04:51:00'),
(154, 154, 3900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-20 13:45:00', '2025-02-20 13:45:00'),
(155, 155, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-20 22:05:00', '2025-02-20 22:05:00'),
(156, 156, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-21 05:03:00', '2025-02-21 05:03:00'),
(157, 157, 3900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-21 13:41:00', '2025-02-21 13:41:00'),
(158, 158, 5700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-21 21:28:00', '2025-02-21 21:28:00'),
(159, 159, 5700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-22 05:33:00', '2025-02-22 05:33:00'),
(160, 160, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-22 12:57:00', '2025-02-22 12:57:00'),
(161, 161, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-22 20:51:00', '2025-02-22 20:51:00'),
(162, 162, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-23 03:40:00', '2025-02-23 03:40:00'),
(163, 163, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-23 11:50:00', '2025-02-23 11:50:00'),
(164, 164, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-23 19:38:00', '2025-02-23 19:38:00'),
(165, 165, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-24 04:24:00', '2025-02-24 04:24:00'),
(166, 166, 5800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-24 11:12:00', '2025-02-24 11:12:00'),
(167, 167, 3900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-24 18:59:00', '2025-02-24 18:59:00'),
(168, 168, 5600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-25 03:33:00', '2025-02-25 03:33:00'),
(169, 169, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-25 10:37:00', '2025-02-25 10:37:00'),
(170, 170, 3000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-25 17:20:00', '2025-02-25 17:20:00'),
(171, 171, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-26 00:31:00', '2025-02-26 00:31:00'),
(172, 172, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-26 07:26:00', '2025-02-26 07:26:00'),
(173, 173, 4200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-26 16:02:00', '2025-02-26 16:02:00'),
(174, 174, 3100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-27 00:47:00', '2025-02-27 00:47:00'),
(175, 175, 2200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-27 09:05:00', '2025-02-27 09:05:00'),
(176, 176, 5300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-27 16:13:00', '2025-02-27 16:13:00'),
(177, 177, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-28 00:21:00', '2025-02-28 00:21:00'),
(178, 178, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-28 07:05:00', '2025-02-28 07:05:00'),
(179, 179, 2800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-28 13:57:00', '2025-02-28 13:57:00'),
(180, 180, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-02-28 20:56:00', '2025-02-28 20:56:00'),
(181, 181, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-01 05:32:00', '2025-03-01 05:32:00'),
(182, 182, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-01 14:40:00', '2025-03-01 14:40:00'),
(183, 183, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-01 22:09:00', '2025-03-01 22:09:00'),
(184, 184, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-02 07:14:00', '2025-03-02 07:14:00'),
(185, 185, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-02 14:02:00', '2025-03-02 14:02:00'),
(186, 186, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-02 21:53:00', '2025-03-02 21:53:00'),
(187, 187, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-03 06:05:00', '2025-03-03 06:05:00'),
(188, 188, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-03 14:57:00', '2025-03-03 14:57:00'),
(189, 189, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-03 22:31:00', '2025-03-03 22:31:00'),
(190, 190, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-04 05:18:00', '2025-03-04 05:18:00'),
(191, 191, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-04 13:19:00', '2025-03-04 13:19:00'),
(192, 192, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-04 21:58:00', '2025-03-04 21:58:00'),
(193, 193, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-05 04:42:00', '2025-03-05 04:42:00'),
(194, 194, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-05 11:37:00', '2025-03-05 11:37:00'),
(195, 195, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-05 18:57:00', '2025-03-05 18:57:00'),
(196, 196, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-06 03:53:00', '2025-03-06 03:53:00'),
(197, 197, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-06 11:53:00', '2025-03-06 11:53:00'),
(198, 198, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-06 18:47:00', '2025-03-06 18:47:00'),
(199, 199, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-07 01:35:00', '2025-03-07 01:35:00'),
(200, 200, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-07 10:18:00', '2025-03-07 10:18:00'),
(201, 201, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-07 18:43:00', '2025-03-07 18:43:00'),
(202, 202, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-08 03:45:00', '2025-03-08 03:45:00'),
(203, 203, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-08 12:34:00', '2025-03-08 12:34:00'),
(204, 204, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-08 20:35:00', '2025-03-08 20:35:00'),
(205, 205, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-09 05:36:00', '2025-03-09 05:36:00'),
(206, 206, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-09 14:18:00', '2025-03-09 14:18:00'),
(207, 207, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-09 23:18:00', '2025-03-09 23:18:00'),
(208, 208, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-10 06:59:00', '2025-03-10 06:59:00'),
(209, 209, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-10 14:33:00', '2025-03-10 14:33:00'),
(210, 210, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-10 22:32:00', '2025-03-10 22:32:00'),
(211, 211, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-11 07:20:00', '2025-03-11 07:20:00'),
(212, 212, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-11 14:49:00', '2025-03-11 14:49:00'),
(213, 213, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-11 23:41:00', '2025-03-11 23:41:00'),
(214, 214, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-12 06:33:00', '2025-03-12 06:33:00'),
(215, 215, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-12 14:27:00', '2025-03-12 14:27:00'),
(216, 216, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-12 23:36:00', '2025-03-12 23:36:00'),
(217, 217, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-13 07:07:00', '2025-03-13 07:07:00'),
(218, 218, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-13 15:25:00', '2025-03-13 15:25:00'),
(219, 219, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-13 22:34:00', '2025-03-13 22:34:00'),
(220, 220, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-14 07:21:00', '2025-03-14 07:21:00'),
(221, 221, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-14 16:12:00', '2025-03-14 16:12:00'),
(222, 222, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-15 01:02:00', '2025-03-15 01:02:00'),
(223, 223, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-15 07:56:00', '2025-03-15 07:56:00'),
(224, 224, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-15 16:46:00', '2025-03-15 16:46:00'),
(225, 225, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-15 23:41:00', '2025-03-15 23:41:00'),
(226, 226, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-16 07:37:00', '2025-03-16 07:37:00'),
(227, 227, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-16 16:28:00', '2025-03-16 16:28:00'),
(228, 228, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-17 01:30:00', '2025-03-17 01:30:00'),
(229, 229, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-17 08:33:00', '2025-03-17 08:33:00'),
(230, 230, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-17 16:40:00', '2025-03-17 16:40:00'),
(231, 231, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-18 01:26:00', '2025-03-18 01:26:00'),
(232, 232, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-18 09:54:00', '2025-03-18 09:54:00'),
(233, 233, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-18 16:56:00', '2025-03-18 16:56:00'),
(234, 234, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-19 01:29:00', '2025-03-19 01:29:00'),
(235, 235, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-19 09:37:00', '2025-03-19 09:37:00'),
(236, 236, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-19 16:43:00', '2025-03-19 16:43:00'),
(237, 237, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-20 00:49:00', '2025-03-20 00:49:00'),
(238, 238, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-20 07:36:00', '2025-03-20 07:36:00'),
(239, 239, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-20 16:30:00', '2025-03-20 16:30:00'),
(240, 240, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-21 01:14:00', '2025-03-21 01:14:00'),
(241, 241, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-21 10:04:00', '2025-03-21 10:04:00'),
(242, 242, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-21 19:05:00', '2025-03-21 19:05:00'),
(243, 243, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-22 01:58:00', '2025-03-22 01:58:00'),
(244, 244, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-22 09:05:00', '2025-03-22 09:05:00'),
(245, 245, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-22 15:56:00', '2025-03-22 15:56:00'),
(246, 246, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-22 23:26:00', '2025-03-22 23:26:00'),
(247, 247, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-23 06:24:00', '2025-03-23 06:24:00'),
(248, 248, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-23 14:07:00', '2025-03-23 14:07:00'),
(249, 249, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-23 20:52:00', '2025-03-23 20:52:00'),
(250, 250, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-24 05:04:00', '2025-03-24 05:04:00'),
(251, 251, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-24 12:44:00', '2025-03-24 12:44:00'),
(252, 252, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-24 20:35:00', '2025-03-24 20:35:00'),
(253, 253, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-25 03:43:00', '2025-03-25 03:43:00'),
(254, 254, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-25 10:57:00', '2025-03-25 10:57:00'),
(255, 255, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-25 19:26:00', '2025-03-25 19:26:00'),
(256, 256, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-26 02:38:00', '2025-03-26 02:38:00'),
(257, 257, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-26 09:54:00', '2025-03-26 09:54:00'),
(258, 258, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-26 17:58:00', '2025-03-26 17:58:00'),
(259, 259, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-27 03:01:00', '2025-03-27 03:01:00'),
(260, 260, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-27 11:44:00', '2025-03-27 11:44:00'),
(261, 261, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-27 20:01:00', '2025-03-27 20:01:00'),
(262, 262, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-28 04:04:00', '2025-03-28 04:04:00'),
(263, 263, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-28 11:29:00', '2025-03-28 11:29:00'),
(264, 264, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-28 20:31:00', '2025-03-28 20:31:00'),
(265, 265, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-29 04:59:00', '2025-03-29 04:59:00'),
(266, 266, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-29 12:08:00', '2025-03-29 12:08:00'),
(267, 267, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-29 21:07:00', '2025-03-29 21:07:00'),
(268, 268, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-30 04:10:00', '2025-03-30 04:10:00'),
(269, 269, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-30 12:52:00', '2025-03-30 12:52:00'),
(270, 270, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-30 20:27:00', '2025-03-30 20:27:00'),
(271, 271, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-31 03:45:00', '2025-03-31 03:45:00'),
(272, 272, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-31 10:48:00', '2025-03-31 10:48:00'),
(273, 273, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-03-31 19:15:00', '2025-03-31 19:15:00'),
(274, 274, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-01 02:33:00', '2025-04-01 02:33:00'),
(275, 275, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-01 09:43:00', '2025-04-01 09:43:00'),
(276, 276, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-01 18:30:00', '2025-04-01 18:30:00'),
(277, 277, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-02 01:42:00', '2025-04-02 01:42:00'),
(278, 278, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-02 10:07:00', '2025-04-02 10:07:00'),
(279, 279, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-02 17:25:00', '2025-04-02 17:25:00'),
(280, 280, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-03 00:34:00', '2025-04-03 00:34:00'),
(281, 281, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-03 09:36:00', '2025-04-03 09:36:00'),
(282, 282, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-03 18:06:00', '2025-04-03 18:06:00'),
(283, 283, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-04 02:36:00', '2025-04-04 02:36:00'),
(284, 284, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-04 09:53:00', '2025-04-04 09:53:00'),
(285, 285, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-04 18:05:00', '2025-04-04 18:05:00'),
(286, 286, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-05 02:13:00', '2025-04-05 02:13:00'),
(287, 287, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-05 10:07:00', '2025-04-05 10:07:00'),
(288, 288, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-05 18:24:00', '2025-04-05 18:24:00'),
(289, 289, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-06 03:01:00', '2025-04-06 03:01:00'),
(290, 290, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-06 10:37:00', '2025-04-06 10:37:00'),
(291, 291, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-06 19:26:00', '2025-04-06 19:26:00'),
(292, 292, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-07 03:07:00', '2025-04-07 03:07:00'),
(293, 293, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-07 11:12:00', '2025-04-07 11:12:00'),
(294, 294, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-07 18:47:00', '2025-04-07 18:47:00'),
(295, 295, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-08 02:28:00', '2025-04-08 02:28:00'),
(296, 296, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-08 10:52:00', '2025-04-08 10:52:00'),
(297, 297, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-08 18:44:00', '2025-04-08 18:44:00'),
(298, 298, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-09 01:43:00', '2025-04-09 01:43:00'),
(299, 299, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-09 09:34:00', '2025-04-09 09:34:00'),
(300, 300, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-09 17:25:00', '2025-04-09 17:25:00'),
(301, 301, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-10 02:29:00', '2025-04-10 02:29:00'),
(302, 302, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-10 10:39:00', '2025-04-10 10:39:00'),
(303, 303, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-10 19:14:00', '2025-04-10 19:14:00'),
(304, 304, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-11 03:01:00', '2025-04-11 03:01:00'),
(305, 305, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-11 10:17:00', '2025-04-11 10:17:00'),
(306, 306, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-11 18:56:00', '2025-04-11 18:56:00'),
(307, 307, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-12 02:50:00', '2025-04-12 02:50:00'),
(308, 308, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-12 11:05:00', '2025-04-12 11:05:00'),
(309, 309, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-12 19:16:00', '2025-04-12 19:16:00'),
(310, 310, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-13 03:39:00', '2025-04-13 03:39:00'),
(311, 311, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-13 12:03:00', '2025-04-13 12:03:00'),
(312, 312, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-13 19:53:00', '2025-04-13 19:53:00'),
(313, 313, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-14 04:20:00', '2025-04-14 04:20:00'),
(314, 314, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-14 13:07:00', '2025-04-14 13:07:00'),
(315, 315, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-14 20:09:00', '2025-04-14 20:09:00'),
(316, 316, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-15 05:01:00', '2025-04-15 05:01:00'),
(317, 317, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-15 12:37:00', '2025-04-15 12:37:00'),
(318, 318, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-15 19:33:00', '2025-04-15 19:33:00'),
(319, 319, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-16 04:19:00', '2025-04-16 04:19:00'),
(320, 320, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-16 12:29:00', '2025-04-16 12:29:00'),
(321, 321, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-16 20:52:00', '2025-04-16 20:52:00'),
(322, 322, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-17 05:07:00', '2025-04-17 05:07:00'),
(323, 323, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-17 12:13:00', '2025-04-17 12:13:00'),
(324, 324, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-17 20:16:00', '2025-04-17 20:16:00'),
(325, 325, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-18 03:57:00', '2025-04-18 03:57:00'),
(326, 326, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-18 11:26:00', '2025-04-18 11:26:00'),
(327, 327, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-18 18:38:00', '2025-04-18 18:38:00'),
(328, 328, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-19 03:37:00', '2025-04-19 03:37:00'),
(329, 329, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-19 12:30:00', '2025-04-19 12:30:00'),
(330, 330, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-19 21:08:00', '2025-04-19 21:08:00'),
(331, 331, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-20 05:09:00', '2025-04-20 05:09:00'),
(332, 332, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-20 13:26:00', '2025-04-20 13:26:00'),
(333, 333, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-20 21:32:00', '2025-04-20 21:32:00'),
(334, 334, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-21 04:58:00', '2025-04-21 04:58:00'),
(335, 335, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-21 12:05:00', '2025-04-21 12:05:00'),
(336, 336, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-21 20:37:00', '2025-04-21 20:37:00'),
(337, 337, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-22 03:35:00', '2025-04-22 03:35:00'),
(338, 338, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-22 12:43:00', '2025-04-22 12:43:00'),
(339, 339, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-22 21:15:00', '2025-04-22 21:15:00'),
(340, 340, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-23 05:27:00', '2025-04-23 05:27:00'),
(341, 341, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-23 12:13:00', '2025-04-23 12:13:00'),
(342, 342, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-23 20:52:00', '2025-04-23 20:52:00'),
(343, 343, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-24 04:38:00', '2025-04-24 04:38:00'),
(344, 344, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-24 12:36:00', '2025-04-24 12:36:00'),
(345, 345, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-24 20:09:00', '2025-04-24 20:09:00'),
(346, 346, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-25 04:14:00', '2025-04-25 04:14:00'),
(347, 347, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-25 12:01:00', '2025-04-25 12:01:00'),
(348, 348, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-25 20:45:00', '2025-04-25 20:45:00'),
(349, 349, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-26 03:53:00', '2025-04-26 03:53:00'),
(350, 350, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-26 11:46:00', '2025-04-26 11:46:00'),
(351, 351, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-26 19:03:00', '2025-04-26 19:03:00'),
(352, 352, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-27 02:17:00', '2025-04-27 02:17:00'),
(353, 353, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-27 11:25:00', '2025-04-27 11:25:00'),
(354, 354, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-27 18:16:00', '2025-04-27 18:16:00'),
(355, 355, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-28 00:56:00', '2025-04-28 00:56:00'),
(356, 356, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-28 08:34:00', '2025-04-28 08:34:00'),
(357, 357, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-28 16:15:00', '2025-04-28 16:15:00'),
(358, 358, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-29 00:01:00', '2025-04-29 00:01:00'),
(359, 359, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-29 08:44:00', '2025-04-29 08:44:00'),
(360, 360, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-29 17:34:00', '2025-04-29 17:34:00'),
(361, 361, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-30 01:15:00', '2025-04-30 01:15:00'),
(362, 362, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-30 08:13:00', '2025-04-30 08:13:00'),
(363, 363, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-04-30 16:30:00', '2025-04-30 16:30:00'),
(364, 364, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-01 00:21:00', '2025-05-01 00:21:00'),
(365, 365, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-01 07:40:00', '2025-05-01 07:40:00'),
(366, 366, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-01 15:25:00', '2025-05-01 15:25:00'),
(367, 367, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-01 23:38:00', '2025-05-01 23:38:00'),
(368, 368, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-02 08:18:00', '2025-05-02 08:18:00'),
(369, 369, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-02 16:56:00', '2025-05-02 16:56:00'),
(370, 370, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-03 01:20:00', '2025-05-03 01:20:00'),
(371, 371, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-03 08:37:00', '2025-05-03 08:37:00'),
(372, 372, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-03 17:20:00', '2025-05-03 17:20:00'),
(373, 373, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-04 00:42:00', '2025-05-04 00:42:00'),
(374, 374, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-04 08:36:00', '2025-05-04 08:36:00'),
(375, 375, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-04 17:21:00', '2025-05-04 17:21:00'),
(376, 376, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-05 02:31:00', '2025-05-05 02:31:00'),
(377, 377, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-05 09:58:00', '2025-05-05 09:58:00'),
(378, 378, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-05 18:10:00', '2025-05-05 18:10:00'),
(379, 379, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-06 03:10:00', '2025-05-06 03:10:00'),
(380, 380, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-06 11:17:00', '2025-05-06 11:17:00'),
(381, 381, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-06 20:05:00', '2025-05-06 20:05:00'),
(382, 382, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-07 05:09:00', '2025-05-07 05:09:00'),
(383, 383, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-07 12:52:00', '2025-05-07 12:52:00'),
(384, 384, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-07 21:56:00', '2025-05-07 21:56:00'),
(385, 385, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-08 06:01:00', '2025-05-08 06:01:00'),
(386, 386, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-08 14:16:00', '2025-05-08 14:16:00'),
(387, 387, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-08 21:44:00', '2025-05-08 21:44:00'),
(388, 388, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-09 06:52:00', '2025-05-09 06:52:00'),
(389, 389, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-09 14:54:00', '2025-05-09 14:54:00'),
(390, 390, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-09 22:28:00', '2025-05-09 22:28:00'),
(391, 391, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-10 07:01:00', '2025-05-10 07:01:00'),
(392, 392, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-10 15:33:00', '2025-05-10 15:33:00'),
(393, 393, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-11 00:16:00', '2025-05-11 00:16:00'),
(394, 394, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-11 06:57:00', '2025-05-11 06:57:00'),
(395, 395, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-11 15:00:00', '2025-05-11 15:00:00'),
(396, 396, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-12 00:00:00', '2025-05-12 00:00:00'),
(397, 397, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-12 07:40:00', '2025-05-12 07:40:00'),
(398, 398, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-12 14:21:00', '2025-05-12 14:21:00'),
(399, 399, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-12 21:03:00', '2025-05-12 21:03:00'),
(400, 400, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-13 05:32:00', '2025-05-13 05:32:00'),
(401, 401, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-13 14:34:00', '2025-05-13 14:34:00'),
(402, 402, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-13 23:27:00', '2025-05-13 23:27:00'),
(403, 403, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-14 08:36:00', '2025-05-14 08:36:00'),
(404, 404, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-14 15:45:00', '2025-05-14 15:45:00'),
(405, 405, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-14 23:21:00', '2025-05-14 23:21:00'),
(406, 406, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-15 06:01:00', '2025-05-15 06:01:00'),
(407, 407, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-15 14:58:00', '2025-05-15 14:58:00'),
(408, 408, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-15 23:08:00', '2025-05-15 23:08:00'),
(409, 409, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-16 05:59:00', '2025-05-16 05:59:00'),
(410, 410, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-16 15:03:00', '2025-05-16 15:03:00'),
(411, 411, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-16 23:29:00', '2025-05-16 23:29:00'),
(412, 412, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-17 06:35:00', '2025-05-17 06:35:00'),
(413, 413, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-17 13:34:00', '2025-05-17 13:34:00'),
(414, 414, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-17 22:42:00', '2025-05-17 22:42:00'),
(415, 415, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-18 06:03:00', '2025-05-18 06:03:00'),
(416, 416, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-18 15:04:00', '2025-05-18 15:04:00'),
(417, 417, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-18 23:03:00', '2025-05-18 23:03:00'),
(418, 418, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-19 07:35:00', '2025-05-19 07:35:00'),
(419, 419, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-19 16:31:00', '2025-05-19 16:31:00'),
(420, 420, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-20 00:00:00', '2025-05-20 00:00:00'),
(421, 421, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-20 08:31:00', '2025-05-20 08:31:00'),
(422, 422, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-20 15:31:00', '2025-05-20 15:31:00'),
(423, 423, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-20 22:41:00', '2025-05-20 22:41:00'),
(424, 424, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-21 07:04:00', '2025-05-21 07:04:00'),
(425, 425, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-21 14:44:00', '2025-05-21 14:44:00'),
(426, 426, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-21 23:06:00', '2025-05-21 23:06:00'),
(427, 427, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-22 06:27:00', '2025-05-22 06:27:00'),
(428, 428, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-22 14:29:00', '2025-05-22 14:29:00'),
(429, 429, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-22 22:58:00', '2025-05-22 22:58:00'),
(430, 430, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-23 07:28:00', '2025-05-23 07:28:00'),
(431, 431, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-23 16:26:00', '2025-05-23 16:26:00'),
(432, 432, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-23 23:31:00', '2025-05-23 23:31:00'),
(433, 433, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-24 08:34:00', '2025-05-24 08:34:00'),
(434, 434, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-24 17:01:00', '2025-05-24 17:01:00'),
(435, 435, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-25 00:55:00', '2025-05-25 00:55:00'),
(436, 436, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-25 08:04:00', '2025-05-25 08:04:00'),
(437, 437, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-25 15:55:00', '2025-05-25 15:55:00'),
(438, 438, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-26 00:15:00', '2025-05-26 00:15:00'),
(439, 439, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-26 07:07:00', '2025-05-26 07:07:00'),
(440, 440, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-26 13:51:00', '2025-05-26 13:51:00'),
(441, 441, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-26 22:16:00', '2025-05-26 22:16:00'),
(442, 442, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-27 05:51:00', '2025-05-27 05:51:00'),
(443, 443, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-27 13:12:00', '2025-05-27 13:12:00');
INSERT INTO `payments` (`payment_id`, `booking_id`, `amount`, `status`, `payment_method`, `vnp_txn_ref`, `vnp_bank_code`, `vnp_pay_date`, `created_at`, `updated_at`) VALUES
(444, 444, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-27 21:02:00', '2025-05-27 21:02:00'),
(445, 445, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-28 04:22:00', '2025-05-28 04:22:00'),
(446, 446, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-28 13:29:00', '2025-05-28 13:29:00'),
(447, 447, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-28 20:57:00', '2025-05-28 20:57:00'),
(448, 448, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-29 05:54:00', '2025-05-29 05:54:00'),
(449, 449, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-29 12:43:00', '2025-05-29 12:43:00'),
(450, 450, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-29 21:10:00', '2025-05-29 21:10:00'),
(451, 451, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-30 05:37:00', '2025-05-30 05:37:00'),
(452, 452, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-30 14:29:00', '2025-05-30 14:29:00'),
(453, 453, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-30 22:51:00', '2025-05-30 22:51:00'),
(454, 454, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-31 06:55:00', '2025-05-31 06:55:00'),
(455, 455, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-31 13:38:00', '2025-05-31 13:38:00'),
(456, 456, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-05-31 22:24:00', '2025-05-31 22:24:00'),
(457, 457, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-01 05:36:00', '2025-06-01 05:36:00'),
(458, 458, 2200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-01 12:33:00', '2025-06-01 12:33:00'),
(459, 459, 2400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-01 20:25:00', '2025-06-01 20:25:00'),
(460, 460, 2400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-02 04:26:00', '2025-06-02 04:26:00'),
(461, 461, 4600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-02 11:34:00', '2025-06-02 11:34:00'),
(462, 462, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-02 18:50:00', '2025-06-02 18:50:00'),
(463, 463, 2400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-03 01:35:00', '2025-06-03 01:35:00'),
(464, 464, 5600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-03 10:45:00', '2025-06-03 10:45:00'),
(465, 465, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-03 18:16:00', '2025-06-03 18:16:00'),
(466, 466, 3300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-04 01:40:00', '2025-06-04 01:40:00'),
(467, 467, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-04 09:00:00', '2025-06-04 09:00:00'),
(468, 468, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-04 16:54:00', '2025-06-04 16:54:00'),
(469, 469, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-05 01:32:00', '2025-06-05 01:32:00'),
(470, 470, 3700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-05 09:49:00', '2025-06-05 09:49:00'),
(471, 471, 3200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-05 16:58:00', '2025-06-05 16:58:00'),
(472, 472, 4500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-06 01:35:00', '2025-06-06 01:35:00'),
(473, 473, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-06 09:41:00', '2025-06-06 09:41:00'),
(474, 474, 4600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-06 16:55:00', '2025-06-06 16:55:00'),
(475, 475, 2200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-06 23:38:00', '2025-06-06 23:38:00'),
(476, 476, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-07 07:18:00', '2025-06-07 07:18:00'),
(477, 477, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-07 14:05:00', '2025-06-07 14:05:00'),
(478, 478, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-07 23:03:00', '2025-06-07 23:03:00'),
(479, 479, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-08 07:11:00', '2025-06-08 07:11:00'),
(480, 480, 3600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-08 14:51:00', '2025-06-08 14:51:00'),
(481, 481, 5300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-08 23:56:00', '2025-06-08 23:56:00'),
(482, 482, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-09 08:31:00', '2025-06-09 08:31:00'),
(483, 483, 2200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-09 16:06:00', '2025-06-09 16:06:00'),
(484, 484, 3900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-09 23:03:00', '2025-06-09 23:03:00'),
(485, 485, 4200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-10 06:05:00', '2025-06-10 06:05:00'),
(486, 486, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-10 14:35:00', '2025-06-10 14:35:00'),
(487, 487, 4200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-10 23:11:00', '2025-06-10 23:11:00'),
(488, 488, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-11 06:07:00', '2025-06-11 06:07:00'),
(489, 489, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-11 14:32:00', '2025-06-11 14:32:00'),
(490, 490, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-11 22:02:00', '2025-06-11 22:02:00'),
(491, 491, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-12 04:47:00', '2025-06-12 04:47:00'),
(492, 492, 3400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-12 12:01:00', '2025-06-12 12:01:00'),
(493, 493, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-12 19:41:00', '2025-06-12 19:41:00'),
(494, 494, 3000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-13 03:43:00', '2025-06-13 03:43:00'),
(495, 495, 2800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-13 11:10:00', '2025-06-13 11:10:00'),
(496, 496, 2300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-13 19:43:00', '2025-06-13 19:43:00'),
(497, 497, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-14 03:15:00', '2025-06-14 03:15:00'),
(498, 498, 3700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-14 10:13:00', '2025-06-14 10:13:00'),
(499, 499, 3800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-14 18:56:00', '2025-06-14 18:56:00'),
(500, 500, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-15 02:11:00', '2025-06-15 02:11:00'),
(501, 501, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-15 10:51:00', '2025-06-15 10:51:00'),
(502, 502, 3700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-15 18:19:00', '2025-06-15 18:19:00'),
(503, 503, 2800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-16 02:55:00', '2025-06-16 02:55:00'),
(504, 504, 2800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-16 11:55:00', '2025-06-16 11:55:00'),
(505, 505, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-16 20:01:00', '2025-06-16 20:01:00'),
(506, 506, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-17 04:21:00', '2025-06-17 04:21:00'),
(507, 507, 3500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-17 13:08:00', '2025-06-17 13:08:00'),
(508, 508, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-17 20:38:00', '2025-06-17 20:38:00'),
(509, 509, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-18 04:50:00', '2025-06-18 04:50:00'),
(510, 510, 3700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-18 12:43:00', '2025-06-18 12:43:00'),
(511, 511, 4600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-18 21:38:00', '2025-06-18 21:38:00'),
(512, 512, 3100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-19 05:33:00', '2025-06-19 05:33:00'),
(513, 513, 2500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-19 14:41:00', '2025-06-19 14:41:00'),
(514, 514, 2700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-19 23:51:00', '2025-06-19 23:51:00'),
(515, 515, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-20 07:05:00', '2025-06-20 07:05:00'),
(516, 516, 5200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-20 15:40:00', '2025-06-20 15:40:00'),
(517, 517, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-21 00:14:00', '2025-06-21 00:14:00'),
(518, 518, 3600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-21 07:48:00', '2025-06-21 07:48:00'),
(519, 519, 3900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-21 15:23:00', '2025-06-21 15:23:00'),
(520, 520, 3000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-21 23:59:00', '2025-06-21 23:59:00'),
(521, 521, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-22 07:54:00', '2025-06-22 07:54:00'),
(522, 522, 5200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-22 15:29:00', '2025-06-22 15:29:00'),
(523, 523, 3000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-23 00:38:00', '2025-06-23 00:38:00'),
(524, 524, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-23 08:19:00', '2025-06-23 08:19:00'),
(525, 525, 3500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-23 17:20:00', '2025-06-23 17:20:00'),
(526, 526, 2100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-24 01:28:00', '2025-06-24 01:28:00'),
(527, 527, 2900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-24 09:28:00', '2025-06-24 09:28:00'),
(528, 528, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-24 16:32:00', '2025-06-24 16:32:00'),
(529, 529, 2300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-25 01:31:00', '2025-06-25 01:31:00'),
(530, 530, 2900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-25 09:37:00', '2025-06-25 09:37:00'),
(531, 531, 3000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-25 16:33:00', '2025-06-25 16:33:00'),
(532, 532, 4500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-25 23:23:00', '2025-06-25 23:23:00'),
(533, 533, 4200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-26 06:31:00', '2025-06-26 06:31:00'),
(534, 534, 5300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-26 14:35:00', '2025-06-26 14:35:00'),
(535, 535, 5700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-26 21:53:00', '2025-06-26 21:53:00'),
(536, 536, 2500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-27 04:41:00', '2025-06-27 04:41:00'),
(537, 537, 5600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-27 13:18:00', '2025-06-27 13:18:00'),
(538, 538, 3700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-27 21:41:00', '2025-06-27 21:41:00'),
(539, 539, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-28 06:43:00', '2025-06-28 06:43:00'),
(540, 540, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-28 14:52:00', '2025-06-28 14:52:00'),
(541, 541, 2500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-28 23:41:00', '2025-06-28 23:41:00'),
(542, 542, 3000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-29 07:57:00', '2025-06-29 07:57:00'),
(543, 543, 5600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-29 15:12:00', '2025-06-29 15:12:00'),
(544, 544, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-29 23:02:00', '2025-06-29 23:02:00'),
(545, 545, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-30 05:55:00', '2025-06-30 05:55:00'),
(546, 546, 4600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-30 12:39:00', '2025-06-30 12:39:00'),
(547, 547, 5300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-06-30 21:26:00', '2025-06-30 21:26:00'),
(548, 548, 5300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-01 05:00:00', '2025-07-01 05:00:00'),
(549, 549, 3100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-01 12:56:00', '2025-07-01 12:56:00'),
(550, 550, 2700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-01 20:31:00', '2025-07-01 20:31:00'),
(551, 551, 4600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-02 05:29:00', '2025-07-02 05:29:00'),
(552, 552, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-02 12:15:00', '2025-07-02 12:15:00'),
(553, 553, 3400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-02 19:17:00', '2025-07-02 19:17:00'),
(554, 554, 3600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-03 04:02:00', '2025-07-03 04:02:00'),
(555, 555, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-03 13:04:00', '2025-07-03 13:04:00'),
(556, 556, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-03 21:31:00', '2025-07-03 21:31:00'),
(557, 557, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-04 06:30:00', '2025-07-04 06:30:00'),
(558, 558, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-04 15:30:00', '2025-07-04 15:30:00'),
(559, 559, 3500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-04 22:30:00', '2025-07-04 22:30:00'),
(560, 560, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-05 06:23:00', '2025-07-05 06:23:00'),
(561, 561, 3800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-05 14:27:00', '2025-07-05 14:27:00'),
(562, 562, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-05 22:48:00', '2025-07-05 22:48:00'),
(563, 563, 4200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-06 06:38:00', '2025-07-06 06:38:00'),
(564, 564, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-06 14:38:00', '2025-07-06 14:38:00'),
(565, 565, 3700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-06 22:44:00', '2025-07-06 22:44:00'),
(566, 566, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-07 06:11:00', '2025-07-07 06:11:00'),
(567, 567, 3800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-07 13:43:00', '2025-07-07 13:43:00'),
(568, 568, 2200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-07 22:42:00', '2025-07-07 22:42:00'),
(569, 569, 2400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-08 05:30:00', '2025-07-08 05:30:00'),
(570, 570, 5600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-08 12:28:00', '2025-07-08 12:28:00'),
(571, 571, 3200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-08 19:09:00', '2025-07-08 19:09:00'),
(572, 572, 5600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-09 03:27:00', '2025-07-09 03:27:00'),
(573, 573, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-09 11:49:00', '2025-07-09 11:49:00'),
(574, 574, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-09 19:41:00', '2025-07-09 19:41:00'),
(575, 575, 3300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-10 03:51:00', '2025-07-10 03:51:00'),
(576, 576, 5400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-10 12:53:00', '2025-07-10 12:53:00'),
(577, 577, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-10 19:33:00', '2025-07-10 19:33:00'),
(578, 578, 2700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-11 02:54:00', '2025-07-11 02:54:00'),
(579, 579, 4800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-11 11:06:00', '2025-07-11 11:06:00'),
(580, 580, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-11 20:07:00', '2025-07-11 20:07:00'),
(581, 581, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-12 05:16:00', '2025-07-12 05:16:00'),
(582, 582, 4500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-12 13:07:00', '2025-07-12 13:07:00'),
(583, 583, 3900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-12 21:16:00', '2025-07-12 21:16:00'),
(584, 584, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-13 04:05:00', '2025-07-13 04:05:00'),
(585, 585, 3400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-13 12:18:00', '2025-07-13 12:18:00'),
(586, 586, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-13 20:03:00', '2025-07-13 20:03:00'),
(587, 587, 2200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-14 04:55:00', '2025-07-14 04:55:00'),
(588, 588, 6000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-14 13:07:00', '2025-07-14 13:07:00'),
(589, 589, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-14 20:22:00', '2025-07-14 20:22:00'),
(590, 590, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-15 05:21:00', '2025-07-15 05:21:00'),
(591, 591, 4100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-15 13:53:00', '2025-07-15 13:53:00'),
(592, 592, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-15 22:49:00', '2025-07-15 22:49:00'),
(593, 593, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-16 07:40:00', '2025-07-16 07:40:00'),
(594, 594, 2700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-16 14:30:00', '2025-07-16 14:30:00'),
(595, 595, 4600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-16 21:43:00', '2025-07-16 21:43:00'),
(596, 596, 3500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-17 06:23:00', '2025-07-17 06:23:00'),
(597, 597, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-17 15:01:00', '2025-07-17 15:01:00'),
(598, 598, 2400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-18 00:04:00', '2025-07-18 00:04:00'),
(599, 599, 3600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-18 06:51:00', '2025-07-18 06:51:00'),
(600, 600, 3300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-18 15:16:00', '2025-07-18 15:16:00'),
(601, 601, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-18 22:29:00', '2025-07-18 22:29:00'),
(602, 602, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-19 06:40:00', '2025-07-19 06:40:00'),
(603, 603, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-19 15:01:00', '2025-07-19 15:01:00'),
(604, 604, 3000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-19 23:42:00', '2025-07-19 23:42:00'),
(605, 605, 4700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-20 07:17:00', '2025-07-20 07:17:00'),
(606, 606, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-20 16:14:00', '2025-07-20 16:14:00'),
(607, 607, 5700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-21 00:54:00', '2025-07-21 00:54:00'),
(608, 608, 3700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-21 08:49:00', '2025-07-21 08:49:00'),
(609, 609, 2800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-21 16:00:00', '2025-07-21 16:00:00'),
(610, 610, 5600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-22 00:23:00', '2025-07-22 00:23:00'),
(611, 611, 5000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-22 08:53:00', '2025-07-22 08:53:00'),
(612, 612, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-22 15:40:00', '2025-07-22 15:40:00'),
(613, 613, 5900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-22 23:40:00', '2025-07-22 23:40:00'),
(614, 614, 3600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-23 07:50:00', '2025-07-23 07:50:00'),
(615, 615, 3800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-23 15:09:00', '2025-07-23 15:09:00'),
(616, 616, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-23 22:32:00', '2025-07-23 22:32:00'),
(617, 617, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-24 06:52:00', '2025-07-24 06:52:00'),
(618, 618, 2400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-24 15:44:00', '2025-07-24 15:44:00'),
(619, 619, 4000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-24 23:09:00', '2025-07-24 23:09:00'),
(620, 620, 6000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-25 07:37:00', '2025-07-25 07:37:00'),
(621, 621, 5600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-25 15:40:00', '2025-07-25 15:40:00'),
(622, 622, 4400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-25 22:26:00', '2025-07-25 22:26:00'),
(623, 623, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-26 05:06:00', '2025-07-26 05:06:00'),
(624, 624, 2400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-26 13:14:00', '2025-07-26 13:14:00'),
(625, 625, 2600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-26 20:57:00', '2025-07-26 20:57:00'),
(626, 626, 4300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-27 05:53:00', '2025-07-27 05:53:00'),
(627, 627, 5500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-27 12:49:00', '2025-07-27 12:49:00'),
(628, 628, 3500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-27 21:38:00', '2025-07-27 21:38:00'),
(629, 629, 2700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-28 05:31:00', '2025-07-28 05:31:00'),
(630, 630, 2700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-28 14:32:00', '2025-07-28 14:32:00'),
(631, 631, 3000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-28 21:34:00', '2025-07-28 21:34:00'),
(632, 632, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-29 05:53:00', '2025-07-29 05:53:00'),
(633, 633, 4200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-29 14:43:00', '2025-07-29 14:43:00'),
(634, 634, 2700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-29 23:45:00', '2025-07-29 23:45:00'),
(635, 635, 3200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-30 06:54:00', '2025-07-30 06:54:00'),
(636, 636, 4900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-30 14:14:00', '2025-07-30 14:14:00'),
(637, 637, 3500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-30 22:34:00', '2025-07-30 22:34:00'),
(638, 638, 2900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-31 07:31:00', '2025-07-31 07:31:00'),
(639, 639, 5100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-07-31 16:03:00', '2025-07-31 16:03:00'),
(640, 640, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-01 00:15:00', '2025-08-01 00:15:00'),
(641, 641, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-01 08:14:00', '2025-08-01 08:14:00'),
(642, 642, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-01 15:47:00', '2025-08-01 15:47:00'),
(643, 643, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-02 00:26:00', '2025-08-02 00:26:00'),
(644, 644, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-02 07:44:00', '2025-08-02 07:44:00'),
(645, 645, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-02 16:25:00', '2025-08-02 16:25:00'),
(646, 646, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-03 00:21:00', '2025-08-03 00:21:00'),
(647, 647, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-03 07:56:00', '2025-08-03 07:56:00'),
(648, 648, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-03 15:11:00', '2025-08-03 15:11:00'),
(649, 649, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-03 23:54:00', '2025-08-03 23:54:00'),
(650, 650, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-04 07:58:00', '2025-08-04 07:58:00'),
(651, 651, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-04 16:35:00', '2025-08-04 16:35:00'),
(652, 652, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-05 00:52:00', '2025-08-05 00:52:00'),
(653, 653, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-05 08:49:00', '2025-08-05 08:49:00'),
(654, 654, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-05 16:44:00', '2025-08-05 16:44:00'),
(655, 655, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-05 23:51:00', '2025-08-05 23:51:00'),
(656, 656, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-06 07:41:00', '2025-08-06 07:41:00'),
(657, 657, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-06 16:07:00', '2025-08-06 16:07:00'),
(658, 658, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-07 00:14:00', '2025-08-07 00:14:00'),
(659, 659, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-07 07:22:00', '2025-08-07 07:22:00'),
(660, 660, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-07 14:59:00', '2025-08-07 14:59:00'),
(661, 661, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-07 22:06:00', '2025-08-07 22:06:00'),
(662, 662, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-08 06:25:00', '2025-08-08 06:25:00'),
(663, 663, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-08 13:08:00', '2025-08-08 13:08:00'),
(664, 664, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-08 21:24:00', '2025-08-08 21:24:00'),
(665, 665, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-09 05:35:00', '2025-08-09 05:35:00'),
(666, 666, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-09 12:34:00', '2025-08-09 12:34:00'),
(667, 667, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-09 20:19:00', '2025-08-09 20:19:00'),
(668, 668, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-10 05:24:00', '2025-08-10 05:24:00'),
(669, 669, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-10 13:11:00', '2025-08-10 13:11:00'),
(670, 670, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-10 21:16:00', '2025-08-10 21:16:00'),
(671, 671, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-11 05:17:00', '2025-08-11 05:17:00'),
(672, 672, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-11 14:11:00', '2025-08-11 14:11:00'),
(673, 673, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-11 22:59:00', '2025-08-11 22:59:00'),
(674, 674, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-12 07:25:00', '2025-08-12 07:25:00'),
(675, 675, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-12 16:00:00', '2025-08-12 16:00:00'),
(676, 676, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-13 01:07:00', '2025-08-13 01:07:00'),
(677, 677, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-13 09:19:00', '2025-08-13 09:19:00'),
(678, 678, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-13 16:58:00', '2025-08-13 16:58:00'),
(679, 679, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-14 01:18:00', '2025-08-14 01:18:00'),
(680, 680, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-14 08:38:00', '2025-08-14 08:38:00'),
(681, 681, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-14 15:42:00', '2025-08-14 15:42:00'),
(682, 682, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-14 23:30:00', '2025-08-14 23:30:00'),
(683, 683, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-15 06:32:00', '2025-08-15 06:32:00'),
(684, 684, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-15 14:53:00', '2025-08-15 14:53:00'),
(685, 685, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-15 23:05:00', '2025-08-15 23:05:00'),
(686, 686, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-16 06:20:00', '2025-08-16 06:20:00'),
(687, 687, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-16 14:59:00', '2025-08-16 14:59:00'),
(688, 688, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-16 23:01:00', '2025-08-16 23:01:00'),
(689, 689, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-17 07:02:00', '2025-08-17 07:02:00'),
(690, 690, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-17 16:11:00', '2025-08-17 16:11:00'),
(691, 691, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-17 23:47:00', '2025-08-17 23:47:00'),
(692, 692, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-18 08:51:00', '2025-08-18 08:51:00'),
(693, 693, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-18 16:19:00', '2025-08-18 16:19:00'),
(694, 694, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-19 01:25:00', '2025-08-19 01:25:00'),
(695, 695, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-19 08:34:00', '2025-08-19 08:34:00'),
(696, 696, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-19 15:21:00', '2025-08-19 15:21:00'),
(697, 697, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-20 00:25:00', '2025-08-20 00:25:00'),
(698, 698, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-20 07:42:00', '2025-08-20 07:42:00'),
(699, 699, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-20 14:44:00', '2025-08-20 14:44:00'),
(700, 700, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-20 21:57:00', '2025-08-20 21:57:00'),
(701, 701, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-21 06:38:00', '2025-08-21 06:38:00'),
(702, 702, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-21 15:27:00', '2025-08-21 15:27:00'),
(703, 703, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-21 22:38:00', '2025-08-21 22:38:00'),
(704, 704, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-22 07:03:00', '2025-08-22 07:03:00'),
(705, 705, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-22 14:38:00', '2025-08-22 14:38:00'),
(706, 706, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-22 21:55:00', '2025-08-22 21:55:00'),
(707, 707, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-23 06:18:00', '2025-08-23 06:18:00'),
(708, 708, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-23 14:47:00', '2025-08-23 14:47:00'),
(709, 709, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-23 22:29:00', '2025-08-23 22:29:00'),
(710, 710, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-24 07:18:00', '2025-08-24 07:18:00'),
(711, 711, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-24 15:38:00', '2025-08-24 15:38:00'),
(712, 712, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-25 00:07:00', '2025-08-25 00:07:00'),
(713, 713, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-25 08:11:00', '2025-08-25 08:11:00'),
(714, 714, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-25 17:06:00', '2025-08-25 17:06:00'),
(715, 715, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-26 01:21:00', '2025-08-26 01:21:00'),
(716, 716, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-26 08:12:00', '2025-08-26 08:12:00'),
(717, 717, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-26 16:46:00', '2025-08-26 16:46:00'),
(718, 718, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-26 23:54:00', '2025-08-26 23:54:00'),
(719, 719, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-27 07:53:00', '2025-08-27 07:53:00'),
(720, 720, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-27 14:40:00', '2025-08-27 14:40:00'),
(721, 721, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-27 22:42:00', '2025-08-27 22:42:00'),
(722, 722, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-28 06:35:00', '2025-08-28 06:35:00'),
(723, 723, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-28 15:24:00', '2025-08-28 15:24:00'),
(724, 724, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-29 00:19:00', '2025-08-29 00:19:00'),
(725, 725, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-29 07:14:00', '2025-08-29 07:14:00'),
(726, 726, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-29 14:59:00', '2025-08-29 14:59:00'),
(727, 727, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-29 22:52:00', '2025-08-29 22:52:00'),
(728, 728, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-30 07:15:00', '2025-08-30 07:15:00'),
(729, 729, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-30 14:06:00', '2025-08-30 14:06:00'),
(730, 730, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-30 21:25:00', '2025-08-30 21:25:00'),
(731, 731, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-31 05:59:00', '2025-08-31 05:59:00'),
(732, 732, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-31 12:40:00', '2025-08-31 12:40:00'),
(733, 733, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-08-31 20:16:00', '2025-08-31 20:16:00'),
(734, 734, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-01 04:36:00', '2025-09-01 04:36:00'),
(735, 735, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-01 13:32:00', '2025-09-01 13:32:00'),
(736, 736, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-01 20:46:00', '2025-09-01 20:46:00'),
(737, 737, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-02 05:01:00', '2025-09-02 05:01:00'),
(738, 738, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-02 11:49:00', '2025-09-02 11:49:00'),
(739, 739, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-02 20:05:00', '2025-09-02 20:05:00'),
(740, 740, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-03 03:14:00', '2025-09-03 03:14:00'),
(741, 741, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-03 11:26:00', '2025-09-03 11:26:00'),
(742, 742, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-03 19:30:00', '2025-09-03 19:30:00'),
(743, 743, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-04 03:39:00', '2025-09-04 03:39:00'),
(744, 744, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-04 12:33:00', '2025-09-04 12:33:00'),
(745, 745, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-04 19:45:00', '2025-09-04 19:45:00'),
(746, 746, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-05 04:06:00', '2025-09-05 04:06:00'),
(747, 747, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-05 10:46:00', '2025-09-05 10:46:00'),
(748, 748, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-05 17:37:00', '2025-09-05 17:37:00'),
(749, 749, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-06 01:26:00', '2025-09-06 01:26:00'),
(750, 750, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-06 09:25:00', '2025-09-06 09:25:00'),
(751, 751, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-06 18:04:00', '2025-09-06 18:04:00'),
(752, 752, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-07 01:23:00', '2025-09-07 01:23:00'),
(753, 753, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-07 08:32:00', '2025-09-07 08:32:00'),
(754, 754, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-07 15:34:00', '2025-09-07 15:34:00'),
(755, 755, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-07 22:36:00', '2025-09-07 22:36:00'),
(756, 756, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-08 06:19:00', '2025-09-08 06:19:00'),
(757, 757, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-08 15:23:00', '2025-09-08 15:23:00'),
(758, 758, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-08 22:48:00', '2025-09-08 22:48:00'),
(759, 759, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-09 07:19:00', '2025-09-09 07:19:00'),
(760, 760, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-09 14:40:00', '2025-09-09 14:40:00'),
(761, 761, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-09 23:14:00', '2025-09-09 23:14:00'),
(762, 762, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-10 06:56:00', '2025-09-10 06:56:00'),
(763, 763, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-10 15:54:00', '2025-09-10 15:54:00'),
(764, 764, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-10 23:39:00', '2025-09-10 23:39:00'),
(765, 765, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-11 07:44:00', '2025-09-11 07:44:00'),
(766, 766, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-11 15:56:00', '2025-09-11 15:56:00'),
(767, 767, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-11 22:41:00', '2025-09-11 22:41:00'),
(768, 768, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-12 06:31:00', '2025-09-12 06:31:00'),
(769, 769, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-12 13:51:00', '2025-09-12 13:51:00'),
(770, 770, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-12 20:56:00', '2025-09-12 20:56:00'),
(771, 771, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-13 03:38:00', '2025-09-13 03:38:00'),
(772, 772, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-13 11:44:00', '2025-09-13 11:44:00'),
(773, 773, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-13 18:33:00', '2025-09-13 18:33:00'),
(774, 774, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-14 01:44:00', '2025-09-14 01:44:00'),
(775, 775, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-14 09:39:00', '2025-09-14 09:39:00'),
(776, 776, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-14 18:05:00', '2025-09-14 18:05:00'),
(777, 777, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-15 02:25:00', '2025-09-15 02:25:00'),
(778, 778, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-15 11:03:00', '2025-09-15 11:03:00'),
(779, 779, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-15 19:49:00', '2025-09-15 19:49:00'),
(780, 780, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-16 04:32:00', '2025-09-16 04:32:00'),
(781, 781, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-16 12:42:00', '2025-09-16 12:42:00'),
(782, 782, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-16 19:36:00', '2025-09-16 19:36:00'),
(783, 783, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-17 03:37:00', '2025-09-17 03:37:00'),
(784, 784, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-17 11:28:00', '2025-09-17 11:28:00'),
(785, 785, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-17 18:52:00', '2025-09-17 18:52:00'),
(786, 786, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-18 03:07:00', '2025-09-18 03:07:00'),
(787, 787, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-18 10:06:00', '2025-09-18 10:06:00'),
(788, 788, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-18 17:00:00', '2025-09-18 17:00:00'),
(789, 789, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-19 02:08:00', '2025-09-19 02:08:00'),
(790, 790, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-19 09:47:00', '2025-09-19 09:47:00'),
(791, 791, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-19 16:45:00', '2025-09-19 16:45:00'),
(792, 792, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-20 01:44:00', '2025-09-20 01:44:00'),
(793, 793, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-20 08:36:00', '2025-09-20 08:36:00'),
(794, 794, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-20 15:25:00', '2025-09-20 15:25:00'),
(795, 795, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-21 00:03:00', '2025-09-21 00:03:00'),
(796, 796, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-21 07:34:00', '2025-09-21 07:34:00'),
(797, 797, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-21 15:08:00', '2025-09-21 15:08:00'),
(798, 798, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-21 21:55:00', '2025-09-21 21:55:00'),
(799, 799, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-22 04:44:00', '2025-09-22 04:44:00'),
(800, 800, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-22 12:41:00', '2025-09-22 12:41:00'),
(801, 801, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-22 20:29:00', '2025-09-22 20:29:00'),
(802, 802, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-23 04:32:00', '2025-09-23 04:32:00'),
(803, 803, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-23 12:42:00', '2025-09-23 12:42:00'),
(804, 804, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-23 19:41:00', '2025-09-23 19:41:00'),
(805, 805, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-24 03:38:00', '2025-09-24 03:38:00'),
(806, 806, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-24 12:08:00', '2025-09-24 12:08:00'),
(807, 807, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-24 20:26:00', '2025-09-24 20:26:00'),
(808, 808, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-25 05:00:00', '2025-09-25 05:00:00'),
(809, 809, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-25 12:37:00', '2025-09-25 12:37:00'),
(810, 810, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-25 21:26:00', '2025-09-25 21:26:00'),
(811, 811, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-26 05:38:00', '2025-09-26 05:38:00'),
(812, 812, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-26 12:54:00', '2025-09-26 12:54:00'),
(813, 813, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-26 21:53:00', '2025-09-26 21:53:00'),
(814, 814, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-27 06:01:00', '2025-09-27 06:01:00'),
(815, 815, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-27 12:45:00', '2025-09-27 12:45:00'),
(816, 816, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-27 19:58:00', '2025-09-27 19:58:00'),
(817, 817, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-28 04:24:00', '2025-09-28 04:24:00'),
(818, 818, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-28 12:32:00', '2025-09-28 12:32:00'),
(819, 819, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-28 20:23:00', '2025-09-28 20:23:00'),
(820, 820, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-29 04:21:00', '2025-09-29 04:21:00'),
(821, 821, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-29 12:30:00', '2025-09-29 12:30:00'),
(822, 822, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-29 20:59:00', '2025-09-29 20:59:00'),
(823, 823, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-30 05:20:00', '2025-09-30 05:20:00'),
(824, 824, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-30 12:10:00', '2025-09-30 12:10:00'),
(825, 825, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-09-30 21:20:00', '2025-09-30 21:20:00'),
(826, 826, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-01 04:37:00', '2025-10-01 04:37:00'),
(827, 827, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-01 12:36:00', '2025-10-01 12:36:00'),
(828, 828, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-01 21:21:00', '2025-10-01 21:21:00'),
(829, 829, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-02 06:09:00', '2025-10-02 06:09:00'),
(830, 830, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-02 13:35:00', '2025-10-02 13:35:00'),
(831, 831, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-02 22:19:00', '2025-10-02 22:19:00'),
(832, 832, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-03 06:47:00', '2025-10-03 06:47:00'),
(833, 833, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-03 14:03:00', '2025-10-03 14:03:00'),
(834, 834, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-03 22:49:00', '2025-10-03 22:49:00'),
(835, 835, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-04 06:16:00', '2025-10-04 06:16:00'),
(836, 836, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-04 13:00:00', '2025-10-04 13:00:00'),
(837, 837, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-04 20:18:00', '2025-10-04 20:18:00'),
(838, 838, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-05 03:03:00', '2025-10-05 03:03:00'),
(839, 839, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-05 10:46:00', '2025-10-05 10:46:00'),
(840, 840, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-05 18:59:00', '2025-10-05 18:59:00'),
(841, 841, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-06 03:58:00', '2025-10-06 03:58:00'),
(842, 842, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-06 11:21:00', '2025-10-06 11:21:00'),
(843, 843, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-06 18:22:00', '2025-10-06 18:22:00'),
(844, 844, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-07 02:15:00', '2025-10-07 02:15:00'),
(845, 845, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-07 09:46:00', '2025-10-07 09:46:00'),
(846, 846, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-07 17:59:00', '2025-10-07 17:59:00'),
(847, 847, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-08 03:03:00', '2025-10-08 03:03:00'),
(848, 848, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-08 10:58:00', '2025-10-08 10:58:00'),
(849, 849, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-08 18:18:00', '2025-10-08 18:18:00'),
(850, 850, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-09 01:17:00', '2025-10-09 01:17:00'),
(851, 851, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-09 09:34:00', '2025-10-09 09:34:00'),
(852, 852, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-09 17:28:00', '2025-10-09 17:28:00'),
(853, 853, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-10 02:24:00', '2025-10-10 02:24:00'),
(854, 854, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-10 10:57:00', '2025-10-10 10:57:00'),
(855, 855, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-10 18:18:00', '2025-10-10 18:18:00'),
(856, 856, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-11 01:41:00', '2025-10-11 01:41:00'),
(857, 857, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-11 10:39:00', '2025-10-11 10:39:00'),
(858, 858, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-11 17:26:00', '2025-10-11 17:26:00'),
(859, 859, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-12 01:25:00', '2025-10-12 01:25:00'),
(860, 860, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-12 09:23:00', '2025-10-12 09:23:00'),
(861, 861, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-12 17:23:00', '2025-10-12 17:23:00'),
(862, 862, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-13 01:23:00', '2025-10-13 01:23:00'),
(863, 863, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-13 09:59:00', '2025-10-13 09:59:00'),
(864, 864, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-13 17:25:00', '2025-10-13 17:25:00'),
(865, 865, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-14 02:04:00', '2025-10-14 02:04:00'),
(866, 866, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-14 10:05:00', '2025-10-14 10:05:00'),
(867, 867, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-14 18:06:00', '2025-10-14 18:06:00'),
(868, 868, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-15 01:06:00', '2025-10-15 01:06:00'),
(869, 869, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-15 10:03:00', '2025-10-15 10:03:00'),
(870, 870, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-15 18:36:00', '2025-10-15 18:36:00'),
(871, 871, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-16 02:04:00', '2025-10-16 02:04:00'),
(872, 872, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-16 10:20:00', '2025-10-16 10:20:00'),
(873, 873, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-16 18:14:00', '2025-10-16 18:14:00'),
(874, 874, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-17 02:54:00', '2025-10-17 02:54:00'),
(875, 875, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-17 10:36:00', '2025-10-17 10:36:00'),
(876, 876, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-17 19:25:00', '2025-10-17 19:25:00'),
(877, 877, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-18 03:45:00', '2025-10-18 03:45:00'),
(878, 878, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-18 12:46:00', '2025-10-18 12:46:00'),
(879, 879, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-18 20:31:00', '2025-10-18 20:31:00'),
(880, 880, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-19 03:16:00', '2025-10-19 03:16:00'),
(881, 881, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-19 10:36:00', '2025-10-19 10:36:00'),
(882, 882, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-19 17:22:00', '2025-10-19 17:22:00'),
(883, 883, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-20 02:10:00', '2025-10-20 02:10:00'),
(884, 884, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-20 10:32:00', '2025-10-20 10:32:00');
INSERT INTO `payments` (`payment_id`, `booking_id`, `amount`, `status`, `payment_method`, `vnp_txn_ref`, `vnp_bank_code`, `vnp_pay_date`, `created_at`, `updated_at`) VALUES
(885, 885, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-20 18:47:00', '2025-10-20 18:47:00'),
(886, 886, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-21 02:16:00', '2025-10-21 02:16:00'),
(887, 887, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-21 09:02:00', '2025-10-21 09:02:00'),
(888, 888, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-21 17:14:00', '2025-10-21 17:14:00'),
(889, 889, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-22 01:56:00', '2025-10-22 01:56:00'),
(890, 890, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-22 11:05:00', '2025-10-22 11:05:00'),
(891, 891, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-22 18:06:00', '2025-10-22 18:06:00'),
(892, 892, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-23 00:59:00', '2025-10-23 00:59:00'),
(893, 893, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-23 09:43:00', '2025-10-23 09:43:00'),
(894, 894, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-23 18:22:00', '2025-10-23 18:22:00'),
(895, 895, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-24 03:13:00', '2025-10-24 03:13:00'),
(896, 896, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-24 12:04:00', '2025-10-24 12:04:00'),
(897, 897, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-24 19:46:00', '2025-10-24 19:46:00'),
(898, 898, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-25 04:38:00', '2025-10-25 04:38:00'),
(899, 899, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-25 11:46:00', '2025-10-25 11:46:00'),
(900, 900, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-25 18:38:00', '2025-10-25 18:38:00'),
(901, 901, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-26 03:03:00', '2025-10-26 03:03:00'),
(902, 902, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-26 11:16:00', '2025-10-26 11:16:00'),
(903, 903, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-26 18:58:00', '2025-10-26 18:58:00'),
(904, 904, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-27 04:06:00', '2025-10-27 04:06:00'),
(905, 905, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-27 12:34:00', '2025-10-27 12:34:00'),
(906, 906, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-27 19:29:00', '2025-10-27 19:29:00'),
(907, 907, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-28 03:34:00', '2025-10-28 03:34:00'),
(908, 908, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-28 12:05:00', '2025-10-28 12:05:00'),
(909, 909, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-28 20:49:00', '2025-10-28 20:49:00'),
(910, 910, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-29 04:17:00', '2025-10-29 04:17:00'),
(911, 911, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-29 11:43:00', '2025-10-29 11:43:00'),
(912, 912, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-29 19:44:00', '2025-10-29 19:44:00'),
(913, 913, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-30 03:36:00', '2025-10-30 03:36:00'),
(914, 914, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-30 11:01:00', '2025-10-30 11:01:00'),
(915, 915, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-30 20:03:00', '2025-10-30 20:03:00'),
(916, 916, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-31 04:34:00', '2025-10-31 04:34:00'),
(917, 917, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-31 12:39:00', '2025-10-31 12:39:00'),
(918, 918, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-10-31 21:38:00', '2025-10-31 21:38:00'),
(919, 919, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-01 05:01:00', '2025-11-01 05:01:00'),
(920, 920, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-01 12:44:00', '2025-11-01 12:44:00'),
(921, 921, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-01 21:50:00', '2025-11-01 21:50:00'),
(922, 922, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-02 05:04:00', '2025-11-02 05:04:00'),
(923, 923, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-02 13:24:00', '2025-11-02 13:24:00'),
(924, 924, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-02 21:26:00', '2025-11-02 21:26:00'),
(925, 925, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-03 05:50:00', '2025-11-03 05:50:00'),
(926, 926, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-03 14:40:00', '2025-11-03 14:40:00'),
(927, 927, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-03 23:18:00', '2025-11-03 23:18:00'),
(928, 928, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-04 06:38:00', '2025-11-04 06:38:00'),
(929, 929, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-04 13:47:00', '2025-11-04 13:47:00'),
(930, 930, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-04 21:06:00', '2025-11-04 21:06:00'),
(931, 931, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-05 03:53:00', '2025-11-05 03:53:00'),
(932, 932, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-05 11:50:00', '2025-11-05 11:50:00'),
(933, 933, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-05 19:34:00', '2025-11-05 19:34:00'),
(934, 934, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-06 02:52:00', '2025-11-06 02:52:00'),
(935, 935, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-06 10:13:00', '2025-11-06 10:13:00'),
(936, 936, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-06 19:05:00', '2025-11-06 19:05:00'),
(937, 937, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-07 02:54:00', '2025-11-07 02:54:00'),
(938, 938, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-07 09:58:00', '2025-11-07 09:58:00'),
(939, 939, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-07 16:42:00', '2025-11-07 16:42:00'),
(940, 940, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-08 00:01:00', '2025-11-08 00:01:00'),
(941, 941, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-08 07:47:00', '2025-11-08 07:47:00'),
(942, 942, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-08 16:13:00', '2025-11-08 16:13:00'),
(943, 943, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-08 23:25:00', '2025-11-08 23:25:00'),
(944, 944, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-09 06:49:00', '2025-11-09 06:49:00'),
(945, 945, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-09 15:57:00', '2025-11-09 15:57:00'),
(946, 946, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-09 23:15:00', '2025-11-09 23:15:00'),
(947, 947, 1600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-10 07:32:00', '2025-11-10 07:32:00'),
(948, 948, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-10 15:49:00', '2025-11-10 15:49:00'),
(949, 949, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-10 23:23:00', '2025-11-10 23:23:00'),
(950, 950, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-11 08:11:00', '2025-11-11 08:11:00'),
(951, 951, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-11 15:43:00', '2025-11-11 15:43:00'),
(952, 952, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-11 23:13:00', '2025-11-11 23:13:00'),
(953, 953, 1900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-12 06:30:00', '2025-11-12 06:30:00'),
(954, 954, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-12 15:16:00', '2025-11-12 15:16:00'),
(955, 955, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-12 23:34:00', '2025-11-12 23:34:00'),
(956, 956, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-13 08:31:00', '2025-11-13 08:31:00'),
(957, 957, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-13 15:54:00', '2025-11-13 15:54:00'),
(958, 958, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-13 23:06:00', '2025-11-13 23:06:00'),
(959, 959, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-14 06:00:00', '2025-11-14 06:00:00'),
(960, 960, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-14 14:30:00', '2025-11-14 14:30:00'),
(961, 961, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-14 21:24:00', '2025-11-14 21:24:00'),
(962, 962, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-15 06:09:00', '2025-11-15 06:09:00'),
(963, 963, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-15 14:53:00', '2025-11-15 14:53:00'),
(964, 964, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-15 22:40:00', '2025-11-15 22:40:00'),
(965, 965, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-16 06:16:00', '2025-11-16 06:16:00'),
(966, 966, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-16 12:56:00', '2025-11-16 12:56:00'),
(967, 967, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-16 20:56:00', '2025-11-16 20:56:00'),
(968, 968, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-17 05:44:00', '2025-11-17 05:44:00'),
(969, 969, 900000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-17 13:11:00', '2025-11-17 13:11:00'),
(970, 970, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-17 20:14:00', '2025-11-17 20:14:00'),
(971, 971, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-18 05:21:00', '2025-11-18 05:21:00'),
(972, 972, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-18 13:04:00', '2025-11-18 13:04:00'),
(973, 973, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-18 20:58:00', '2025-11-18 20:58:00'),
(974, 974, 1700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-19 05:40:00', '2025-11-19 05:40:00'),
(975, 975, 700000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-19 14:39:00', '2025-11-19 14:39:00'),
(976, 976, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-19 21:25:00', '2025-11-19 21:25:00'),
(977, 977, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-20 04:39:00', '2025-11-20 04:39:00'),
(978, 978, 1800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-20 12:36:00', '2025-11-20 12:36:00'),
(979, 979, 1100000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-20 20:32:00', '2025-11-20 20:32:00'),
(980, 980, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-21 04:48:00', '2025-11-21 04:48:00'),
(981, 981, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-21 13:22:00', '2025-11-21 13:22:00'),
(982, 982, 1400000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-21 22:29:00', '2025-11-21 22:29:00'),
(983, 983, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-22 06:47:00', '2025-11-22 06:47:00'),
(984, 984, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-22 14:53:00', '2025-11-22 14:53:00'),
(985, 985, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-22 22:22:00', '2025-11-22 22:22:00'),
(986, 986, 500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-23 06:28:00', '2025-11-23 06:28:00'),
(987, 987, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-23 14:46:00', '2025-11-23 14:46:00'),
(988, 988, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-23 23:06:00', '2025-11-23 23:06:00'),
(989, 989, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-24 06:40:00', '2025-11-24 06:40:00'),
(990, 990, 1500000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-24 13:36:00', '2025-11-24 13:36:00'),
(991, 991, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-24 20:37:00', '2025-11-24 20:37:00'),
(992, 992, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-25 04:04:00', '2025-11-25 04:04:00'),
(993, 993, 1000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-25 11:33:00', '2025-11-25 11:33:00'),
(994, 994, 1300000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-25 19:17:00', '2025-11-25 19:17:00'),
(995, 995, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-26 02:25:00', '2025-11-26 02:25:00'),
(996, 996, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-26 10:38:00', '2025-11-26 10:38:00'),
(997, 997, 600000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-26 17:34:00', '2025-11-26 17:34:00'),
(998, 998, 2000000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-27 01:09:00', '2025-11-27 01:09:00'),
(999, 999, 1200000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-27 09:25:00', '2025-11-27 09:25:00'),
(1000, 1000, 800000.000, 'Thành công', 'Tiền mặt', NULL, NULL, NULL, '2025-11-27 16:44:00', '2025-11-27 16:44:00'),
(1024, 1001, 1425000.000, 'Thành công', 'Chuyển khoản', '', NULL, NULL, '2025-11-26 09:35:31', '2025-11-26 09:35:31'),
(1025, 1002, 660000.000, 'Thành công', 'Tiền mặt', '', NULL, NULL, '2025-11-27 18:41:50', '2025-11-27 18:41:50'),
(1026, 1003, 990000.000, 'Thành công', 'Chuyển khoản', '', NULL, NULL, '2025-11-27 20:23:57', '2025-11-27 20:23:57'),
(1027, 1004, 510000.000, 'Thành công', 'Chuyển khoản', '', NULL, NULL, '2025-11-27 20:25:54', '2025-11-27 20:25:54'),
(1028, 1005, 330000.000, 'Thành công', 'Tiền mặt', '', NULL, NULL, '2025-11-27 20:39:02', '2025-11-27 20:39:02'),
(1029, 1006, 585000.000, 'Thành công', 'Tiền mặt', '', NULL, NULL, '2025-11-27 21:12:36', '2025-11-27 21:12:36'),
(1030, 1007, 510000.000, 'Thành công', 'Chuyển khoản', '', NULL, NULL, '2025-11-27 21:12:51', '2025-11-27 21:12:51'),
(1031, 1008, 360000.000, 'Thành công', 'Tiền mặt', '', NULL, NULL, '2025-11-27 21:15:56', '2025-11-27 21:15:56'),
(1032, 1009, 180000.000, 'Thành công', 'Chuyển khoản', '', NULL, NULL, '2025-11-27 21:16:04', '2025-11-27 21:16:04'),
(1033, 1010, 360000.000, 'Thành công', 'Tiền mặt', '', NULL, NULL, '2025-11-27 21:46:11', '2025-11-27 21:46:11'),
(1034, 1011, 1500000.000, 'Thành công', 'Chuyển khoản', '', NULL, NULL, '2025-11-27 21:46:39', '2025-11-27 21:46:39'),
(1035, 1012, 360000.000, 'Thành công', 'Tiền mặt', '', NULL, NULL, '2025-11-28 06:59:50', '2025-11-28 06:59:50'),
(1036, 1013, 860000.000, 'Thành công', 'Chuyển khoản', '', NULL, NULL, '2025-11-28 07:00:04', '2025-11-28 07:00:04');

-- --------------------------------------------------------

--
-- Table structure for table `performances`
--

CREATE TABLE `performances` (
  `performance_id` int(11) NOT NULL,
  `show_id` int(11) DEFAULT NULL,
  `theater_id` int(11) DEFAULT NULL,
  `performance_date` date NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time DEFAULT NULL,
  `status` enum('Đang mở bán','Đã hủy','Đã kết thúc') DEFAULT 'Đang mở bán',
  `price` decimal(10,0) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `performances`
--

INSERT INTO `performances` (`performance_id`, `show_id`, `theater_id`, `performance_date`, `start_time`, `end_time`, `status`, `price`, `created_at`, `updated_at`) VALUES
(15, 8, 1, '2025-10-23', '19:30:00', NULL, 'Đã kết thúc', 180000, '2025-08-01 00:00:00', '2025-08-01 00:00:00'),
(16, 8, 2, '2025-10-26', '20:00:00', NULL, 'Đã kết thúc', 180000, '2025-08-01 00:00:00', '2025-08-01 00:00:00'),
(17, 8, 1, '2025-11-27', '19:30:00', NULL, 'Đã kết thúc', 200000, '2025-08-01 00:00:00', '2025-11-27 12:46:30'),
(18, 8, 3, '2025-11-30', '18:00:00', '20:00:00', 'Đang mở bán', 180000, '2025-08-01 00:00:00', '2025-11-28 07:59:56'),
(19, 9, 2, '2025-11-11', '19:00:00', NULL, 'Đã kết thúc', 150000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(20, 9, 3, '2025-11-13', '20:00:00', NULL, 'Đã kết thúc', 160000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(21, 9, 1, '2025-11-18', '19:00:00', NULL, 'Đã kết thúc', 150000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(22, 9, 2, '2025-11-21', '18:30:00', NULL, 'Đã kết thúc', 160000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(23, 10, 3, '2025-11-14', '19:00:00', NULL, 'Đã kết thúc', 170000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(24, 10, 1, '2025-11-15', '20:00:00', NULL, 'Đã kết thúc', 170000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(25, 10, 2, '2025-11-19', '19:00:00', NULL, 'Đã kết thúc', 180000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(26, 10, 1, '2025-11-20', '20:00:00', NULL, 'Đã kết thúc', 170000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(27, 10, 3, '2025-11-22', '18:30:00', NULL, 'Đã kết thúc', 170000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(28, 11, 1, '2025-11-16', '19:30:00', NULL, 'Đã kết thúc', 200000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(29, 11, 2, '2025-11-20', '20:00:00', NULL, 'Đã kết thúc', 220000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(30, 11, 1, '2025-11-23', '19:00:00', NULL, 'Đã kết thúc', 200000, '2025-08-01 00:00:00', '2025-11-23 13:35:03'),
(31, 10, 3, '2025-11-25', '18:30:00', NULL, 'Đã kết thúc', 220000, '2025-08-01 00:00:00', '2025-11-26 04:15:26'),
(32, 12, 2, '2025-11-17', '19:00:00', NULL, 'Đã kết thúc', 160000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(33, 12, 1, '2025-11-19', '20:00:00', NULL, 'Đã kết thúc', 160000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(34, 12, 3, '2025-11-24', '20:00:00', NULL, 'Đã kết thúc', 170000, '2025-08-01 00:00:00', '2025-11-24 15:36:25'),
(35, 12, 2, '2025-11-26', '19:00:00', '20:44:00', 'Đã kết thúc', 160000, '2025-08-01 00:00:00', '2025-11-26 14:12:14'),
(41, 18, 1, '2025-11-12', '19:30:00', '21:10:00', 'Đã kết thúc', 250000, '2025-11-04 13:08:55', '2025-11-22 11:47:10'),
(42, 18, 2, '2025-11-14', '20:00:00', '21:40:00', 'Đã kết thúc', 200000, '2025-11-04 13:09:41', '2025-11-22 11:47:10'),
(43, 18, 3, '2025-11-15', '20:00:00', '21:40:00', 'Đã kết thúc', 200000, '2025-11-04 13:10:13', '2025-11-22 11:47:10'),
(44, 18, 1, '2025-11-17', '20:30:00', '22:10:00', 'Đã kết thúc', 180000, '2025-11-04 13:10:59', '2025-11-22 11:47:10'),
(45, 19, 2, '2025-11-16', '19:30:00', '21:15:00', 'Đã kết thúc', 300000, '2025-11-04 13:11:48', '2025-11-22 11:47:10'),
(46, 19, 1, '2025-11-17', '18:00:00', '19:45:00', 'Đã kết thúc', 280000, '2025-11-04 13:12:33', '2025-11-22 11:47:10'),
(47, 19, 3, '2025-11-19', '20:00:00', '21:45:00', 'Đã kết thúc', 300000, '2025-11-04 13:13:11', '2025-11-22 11:47:10'),
(48, 19, 1, '2025-11-21', '19:30:00', '21:15:00', 'Đã kết thúc', 250000, '2025-11-04 13:13:48', '2025-11-22 11:47:10'),
(49, 13, 1, '2025-11-23', '19:30:00', '21:05:00', 'Đã kết thúc', 350000, '2025-11-04 13:41:51', '2025-11-23 15:05:42'),
(50, 13, 2, '2025-11-24', '20:00:00', '21:35:00', 'Đã kết thúc', 300000, '2025-11-04 13:42:37', '2025-11-24 15:36:25'),
(51, 17, 2, '2025-11-28', '19:30:00', '21:25:00', 'Đang mở bán', 350000, '2025-11-04 13:43:57', '2025-11-27 18:55:19'),
(52, 17, 2, '2025-11-29', '20:00:00', '21:55:00', 'Đang mở bán', 280000, '2025-11-04 13:44:19', '2025-11-04 13:44:19');

-- --------------------------------------------------------

--
-- Table structure for table `reviews`
--

CREATE TABLE `reviews` (
  `review_id` int(11) NOT NULL,
  `show_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `rating` int(11) DEFAULT NULL CHECK (`rating` >= 1 and `rating` <= 5),
  `content` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `seats`
--

CREATE TABLE `seats` (
  `seat_id` int(11) NOT NULL,
  `theater_id` int(11) DEFAULT NULL,
  `category_id` int(11) DEFAULT NULL,
  `row_char` varchar(5) NOT NULL,
  `seat_number` int(11) NOT NULL,
  `real_seat_number` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `seats`
--

INSERT INTO `seats` (`seat_id`, `theater_id`, `category_id`, `row_char`, `seat_number`, `real_seat_number`, `created_at`) VALUES
(1, 1, 1, 'A', 1, 1, '2025-09-24 16:19:02'),
(2, 1, 1, 'A', 2, 2, '2025-09-24 16:19:02'),
(3, 1, 1, 'A', 3, 3, '2025-09-24 16:19:02'),
(4, 1, 1, 'A', 4, 4, '2025-09-24 16:19:02'),
(5, 1, 1, 'A', 5, 5, '2025-09-24 16:19:02'),
(6, 1, 1, 'A', 6, 6, '2025-09-24 16:19:02'),
(7, 1, 1, 'A', 7, 7, '2025-09-24 16:19:02'),
(8, 1, 1, 'A', 8, 8, '2025-09-24 16:19:02'),
(9, 1, 1, 'A', 9, 9, '2025-09-24 16:19:02'),
(10, 1, 1, 'A', 10, 10, '2025-09-24 16:19:02'),
(11, 1, 1, 'B', 1, 1, '2025-09-24 16:19:02'),
(12, 1, 1, 'B', 2, 2, '2025-09-24 16:19:02'),
(13, 1, 1, 'B', 3, 3, '2025-09-24 16:19:02'),
(14, 1, 1, 'B', 4, 4, '2025-09-24 16:19:02'),
(15, 1, 1, 'B', 5, 5, '2025-09-24 16:19:02'),
(16, 1, 1, 'B', 6, 6, '2025-09-24 16:19:02'),
(17, 1, 1, 'B', 7, 7, '2025-09-24 16:19:02'),
(18, 1, 1, 'B', 8, 8, '2025-09-24 16:19:02'),
(19, 1, 1, 'B', 9, 9, '2025-09-24 16:19:02'),
(20, 1, 1, 'B', 10, 10, '2025-09-24 16:19:02'),
(21, 1, 2, 'C', 1, 1, '2025-09-24 16:19:02'),
(22, 1, 2, 'C', 2, 2, '2025-09-24 16:19:02'),
(23, 1, 2, 'C', 3, 3, '2025-09-24 16:19:02'),
(24, 1, 2, 'C', 4, 4, '2025-09-24 16:19:02'),
(25, 1, 2, 'C', 5, 5, '2025-09-24 16:19:02'),
(26, 1, 2, 'C', 6, 6, '2025-09-24 16:19:02'),
(27, 1, 2, 'C', 7, 7, '2025-09-24 16:19:02'),
(28, 1, 2, 'C', 8, 8, '2025-09-24 16:19:02'),
(29, 1, 2, 'C', 9, 9, '2025-09-24 16:19:02'),
(30, 1, 2, 'C', 10, 10, '2025-09-24 16:19:02'),
(31, 1, 3, 'D', 1, 1, '2025-09-24 16:19:02'),
(32, 1, 3, 'D', 2, 2, '2025-09-24 16:19:02'),
(33, 1, 3, 'D', 3, 3, '2025-09-24 16:19:02'),
(34, 1, 3, 'D', 4, 4, '2025-09-24 16:19:02'),
(35, 1, 3, 'D', 5, 5, '2025-09-24 16:19:02'),
(36, 1, 3, 'D', 6, 6, '2025-09-24 16:19:02'),
(37, 1, 3, 'E', 1, 1, '2025-09-24 16:19:02'),
(38, 1, 3, 'E', 2, 2, '2025-09-24 16:19:02'),
(39, 1, 3, 'E', 3, 3, '2025-09-24 16:19:02'),
(40, 1, 3, 'E', 4, 4, '2025-09-24 16:19:02'),
(41, 1, 3, 'E', 5, 5, '2025-09-24 16:19:02'),
(42, 1, 3, 'E', 6, 6, '2025-09-24 16:19:02'),
(43, 1, 3, 'F', 1, 1, '2025-09-24 16:19:02'),
(44, 1, 3, 'F', 2, 2, '2025-09-24 16:19:02'),
(45, 1, 3, 'F', 3, 3, '2025-09-24 16:19:02'),
(46, 1, 3, 'F', 4, 4, '2025-09-24 16:19:02'),
(47, 1, 3, 'F', 5, 5, '2025-09-24 16:19:02'),
(48, 1, 3, 'F', 6, 6, '2025-09-24 16:19:02'),
(49, 1, 3, 'F', 7, 7, '2025-09-24 16:19:02'),
(50, 1, 3, 'F', 8, 8, '2025-09-24 16:19:02'),
(51, 1, 3, 'F', 9, 9, '2025-09-24 16:19:02'),
(52, 1, 3, 'F', 10, 10, '2025-09-24 16:19:02'),
(53, 2, 1, 'A', 1, 1, '2025-09-24 16:19:02'),
(54, 2, 1, 'A', 2, 2, '2025-09-24 16:19:02'),
(55, 2, 1, 'A', 3, 3, '2025-09-24 16:19:02'),
(56, 2, 1, 'A', 4, 4, '2025-09-24 16:19:02'),
(57, 2, 1, 'A', 5, 5, '2025-09-24 16:19:02'),
(58, 2, 1, 'A', 6, 6, '2025-09-24 16:19:02'),
(59, 2, 1, 'B', 1, 1, '2025-09-24 16:19:02'),
(60, 2, 1, 'B', 2, 2, '2025-09-24 16:19:02'),
(61, 2, 1, 'B', 3, 3, '2025-09-24 16:19:02'),
(62, 2, 1, 'B', 4, 4, '2025-09-24 16:19:02'),
(63, 2, 1, 'B', 5, 5, '2025-09-24 16:19:02'),
(64, 2, 1, 'B', 6, 6, '2025-09-24 16:19:02'),
(65, 2, 2, 'C', 1, 1, '2025-09-24 16:19:02'),
(66, 2, 2, 'C', 2, 2, '2025-09-24 16:19:02'),
(67, 2, 2, 'C', 3, 3, '2025-09-24 16:19:02'),
(68, 2, 2, 'C', 4, 4, '2025-09-24 16:19:02'),
(69, 2, 2, 'C', 5, 5, '2025-09-24 16:19:02'),
(70, 2, 2, 'C', 6, 6, '2025-09-24 16:19:02'),
(71, 2, 1, 'D', 1, 1, '2025-09-24 16:19:02'),
(72, 2, 1, 'D', 2, 2, '2025-09-24 16:19:02'),
(73, 2, 1, 'D', 3, 3, '2025-09-24 16:19:02'),
(74, 2, 1, 'D', 4, 4, '2025-09-24 16:19:02'),
(75, 2, 1, 'D', 5, 5, '2025-09-24 16:19:02'),
(76, 2, 1, 'D', 6, 6, '2025-09-24 16:19:02'),
(77, 3, 1, 'A', 1, 1, '2025-09-24 16:19:02'),
(78, 3, 1, 'A', 2, 2, '2025-09-24 16:19:02'),
(79, 3, 1, 'A', 3, 3, '2025-09-24 16:19:02'),
(80, 3, 1, 'A', 4, 4, '2025-09-24 16:19:02'),
(81, 3, 1, 'A', 5, 5, '2025-09-24 16:19:02'),
(82, 3, 1, 'A', 6, 6, '2025-09-24 16:19:02'),
(83, 3, 1, 'B', 1, 1, '2025-09-24 16:19:02'),
(84, 3, 1, 'B', 2, 2, '2025-09-24 16:19:02'),
(85, 3, 1, 'B', 3, 3, '2025-09-24 16:19:02'),
(86, 3, 1, 'B', 4, 4, '2025-09-24 16:19:02'),
(87, 3, 1, 'B', 5, 5, '2025-09-24 16:19:02'),
(88, 3, 1, 'B', 6, 6, '2025-09-24 16:19:02'),
(89, 3, 2, 'C', 1, 1, '2025-09-24 16:19:02'),
(90, 3, 2, 'C', 2, 2, '2025-09-24 16:19:02'),
(91, 3, 2, 'C', 3, 3, '2025-09-24 16:19:02'),
(92, 3, 2, 'C', 4, 4, '2025-09-24 16:19:02'),
(93, 3, 2, 'C', 5, 5, '2025-09-24 16:19:02'),
(94, 3, 2, 'C', 6, 6, '2025-09-24 16:19:02'),
(95, 3, 3, 'D', 1, 1, '2025-09-24 16:19:02'),
(96, 3, 3, 'D', 2, 2, '2025-09-24 16:19:02'),
(97, 3, 3, 'D', 3, 3, '2025-09-24 16:19:02'),
(98, 3, 3, 'D', 4, 4, '2025-09-24 16:19:02'),
(99, 3, 3, 'D', 5, 5, '2025-09-24 16:19:02'),
(100, 3, 3, 'D', 6, 6, '2025-09-24 16:19:02'),
(101, 3, 3, 'E', 1, 1, '2025-09-24 16:19:02'),
(102, 3, 3, 'E', 2, 2, '2025-09-24 16:19:02'),
(103, 3, 3, 'E', 3, 3, '2025-09-24 16:19:02'),
(104, 3, 3, 'E', 4, 4, '2025-09-24 16:19:02'),
(105, 3, 3, 'E', 5, 5, '2025-09-24 16:19:02'),
(106, 3, 3, 'E', 6, 6, '2025-09-24 16:19:02'),
(207, 2, 1, 'A', 7, 7, '2025-11-17 18:55:09'),
(208, 2, 1, 'B', 7, 7, '2025-11-17 18:55:09'),
(209, 2, 2, 'C', 7, 7, '2025-11-17 18:55:09'),
(210, 2, 1, 'D', 7, 7, '2025-11-17 18:55:09'),
(214, 2, 1, 'A', 8, 8, '2025-11-17 18:58:14'),
(215, 2, 1, 'B', 8, 8, '2025-11-17 18:58:14'),
(216, 2, 2, 'C', 8, 8, '2025-11-17 18:58:14'),
(217, 2, 1, 'D', 8, 8, '2025-11-17 18:58:14');

-- --------------------------------------------------------

--
-- Table structure for table `seat_categories`
--

CREATE TABLE `seat_categories` (
  `category_id` int(11) NOT NULL,
  `category_name` varchar(100) NOT NULL,
  `base_price` decimal(10,0) NOT NULL,
  `color_class` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `seat_categories`
--

INSERT INTO `seat_categories` (`category_id`, `category_name`, `base_price`, `color_class`) VALUES
(1, 'A', 150000, '0d6efd'),
(2, 'B', 75000, '198754'),
(3, 'C', 0, '6f42c1'),
(6, 'D', 50000, '27ae60'),
(7, 'E', 45000, '2980B9');

-- --------------------------------------------------------

--
-- Table structure for table `seat_performance`
--

CREATE TABLE `seat_performance` (
  `seat_id` int(11) NOT NULL,
  `performance_id` int(11) NOT NULL,
  `status` enum('trống','đã đặt') NOT NULL DEFAULT 'trống'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `seat_performance`
--

INSERT INTO `seat_performance` (`seat_id`, `performance_id`, `status`) VALUES
(1, 15, 'đã đặt'),
(1, 17, 'trống'),
(1, 21, 'trống'),
(1, 24, 'trống'),
(1, 26, 'trống'),
(1, 28, 'trống'),
(1, 30, 'đã đặt'),
(1, 33, 'trống'),
(1, 41, 'trống'),
(1, 44, 'trống'),
(1, 46, 'trống'),
(1, 48, 'trống'),
(1, 49, 'trống'),
(2, 15, 'trống'),
(2, 17, 'đã đặt'),
(2, 21, 'đã đặt'),
(2, 24, 'trống'),
(2, 26, 'trống'),
(2, 28, 'trống'),
(2, 30, 'trống'),
(2, 33, 'trống'),
(2, 41, 'trống'),
(2, 44, 'trống'),
(2, 46, 'trống'),
(2, 48, 'trống'),
(2, 49, 'trống'),
(3, 15, 'trống'),
(3, 17, 'đã đặt'),
(3, 21, 'trống'),
(3, 24, 'trống'),
(3, 26, 'trống'),
(3, 28, 'trống'),
(3, 30, 'đã đặt'),
(3, 33, 'trống'),
(3, 41, 'trống'),
(3, 44, 'trống'),
(3, 46, 'trống'),
(3, 48, 'trống'),
(3, 49, 'trống'),
(4, 15, 'đã đặt'),
(4, 17, 'đã đặt'),
(4, 21, 'trống'),
(4, 24, 'trống'),
(4, 26, 'trống'),
(4, 28, 'trống'),
(4, 30, 'đã đặt'),
(4, 33, 'trống'),
(4, 41, 'trống'),
(4, 44, 'trống'),
(4, 46, 'trống'),
(4, 48, 'trống'),
(4, 49, 'trống'),
(5, 15, 'trống'),
(5, 17, 'trống'),
(5, 21, 'trống'),
(5, 24, 'trống'),
(5, 26, 'trống'),
(5, 28, 'trống'),
(5, 30, 'trống'),
(5, 33, 'trống'),
(5, 41, 'trống'),
(5, 44, 'trống'),
(5, 46, 'trống'),
(5, 48, 'trống'),
(5, 49, 'trống'),
(6, 15, 'trống'),
(6, 17, 'đã đặt'),
(6, 21, 'đã đặt'),
(6, 24, 'trống'),
(6, 26, 'trống'),
(6, 28, 'đã đặt'),
(6, 30, 'trống'),
(6, 33, 'đã đặt'),
(6, 41, 'trống'),
(6, 44, 'trống'),
(6, 46, 'trống'),
(6, 48, 'trống'),
(6, 49, 'trống'),
(7, 15, 'trống'),
(7, 17, 'trống'),
(7, 21, 'đã đặt'),
(7, 24, 'trống'),
(7, 26, 'trống'),
(7, 28, 'trống'),
(7, 30, 'trống'),
(7, 33, 'trống'),
(7, 41, 'trống'),
(7, 44, 'trống'),
(7, 46, 'trống'),
(7, 48, 'trống'),
(7, 49, 'trống'),
(8, 15, 'trống'),
(8, 17, 'trống'),
(8, 21, 'trống'),
(8, 24, 'trống'),
(8, 26, 'trống'),
(8, 28, 'trống'),
(8, 30, 'trống'),
(8, 33, 'trống'),
(8, 41, 'trống'),
(8, 44, 'trống'),
(8, 46, 'trống'),
(8, 48, 'trống'),
(8, 49, 'trống'),
(9, 15, 'trống'),
(9, 17, 'trống'),
(9, 21, 'trống'),
(9, 24, 'trống'),
(9, 26, 'trống'),
(9, 28, 'trống'),
(9, 30, 'trống'),
(9, 33, 'đã đặt'),
(9, 41, 'trống'),
(9, 44, 'trống'),
(9, 46, 'trống'),
(9, 48, 'trống'),
(9, 49, 'trống'),
(10, 15, 'trống'),
(10, 17, 'đã đặt'),
(10, 21, 'trống'),
(10, 24, 'đã đặt'),
(10, 26, 'đã đặt'),
(10, 28, 'trống'),
(10, 30, 'đã đặt'),
(10, 33, 'trống'),
(10, 41, 'trống'),
(10, 44, 'trống'),
(10, 46, 'trống'),
(10, 48, 'trống'),
(10, 49, 'trống'),
(11, 15, 'đã đặt'),
(11, 17, 'trống'),
(11, 21, 'trống'),
(11, 24, 'trống'),
(11, 26, 'trống'),
(11, 28, 'trống'),
(11, 30, 'đã đặt'),
(11, 33, 'trống'),
(11, 41, 'trống'),
(11, 44, 'trống'),
(11, 46, 'trống'),
(11, 48, 'trống'),
(11, 49, 'trống'),
(12, 15, 'trống'),
(12, 17, 'trống'),
(12, 21, 'trống'),
(12, 24, 'trống'),
(12, 26, 'trống'),
(12, 28, 'trống'),
(12, 30, 'trống'),
(12, 33, 'trống'),
(12, 41, 'trống'),
(12, 44, 'trống'),
(12, 46, 'trống'),
(12, 48, 'trống'),
(12, 49, 'trống'),
(13, 15, 'trống'),
(13, 17, 'đã đặt'),
(13, 21, 'trống'),
(13, 24, 'đã đặt'),
(13, 26, 'trống'),
(13, 28, 'trống'),
(13, 30, 'đã đặt'),
(13, 33, 'trống'),
(13, 41, 'trống'),
(13, 44, 'trống'),
(13, 46, 'trống'),
(13, 48, 'trống'),
(13, 49, 'trống'),
(14, 15, 'trống'),
(14, 17, 'trống'),
(14, 21, 'trống'),
(14, 24, 'trống'),
(14, 26, 'trống'),
(14, 28, 'trống'),
(14, 30, 'đã đặt'),
(14, 33, 'trống'),
(14, 41, 'trống'),
(14, 44, 'trống'),
(14, 46, 'trống'),
(14, 48, 'trống'),
(14, 49, 'trống'),
(15, 15, 'trống'),
(15, 17, 'trống'),
(15, 21, 'đã đặt'),
(15, 24, 'trống'),
(15, 26, 'đã đặt'),
(15, 28, 'trống'),
(15, 30, 'trống'),
(15, 33, 'trống'),
(15, 41, 'trống'),
(15, 44, 'trống'),
(15, 46, 'trống'),
(15, 48, 'trống'),
(15, 49, 'trống'),
(16, 15, 'trống'),
(16, 17, 'trống'),
(16, 21, 'trống'),
(16, 24, 'trống'),
(16, 26, 'trống'),
(16, 28, 'trống'),
(16, 30, 'đã đặt'),
(16, 33, 'trống'),
(16, 41, 'trống'),
(16, 44, 'trống'),
(16, 46, 'trống'),
(16, 48, 'trống'),
(16, 49, 'trống'),
(17, 15, 'trống'),
(17, 17, 'trống'),
(17, 21, 'trống'),
(17, 24, 'trống'),
(17, 26, 'trống'),
(17, 28, 'trống'),
(17, 30, 'trống'),
(17, 33, 'trống'),
(17, 41, 'trống'),
(17, 44, 'trống'),
(17, 46, 'trống'),
(17, 48, 'trống'),
(17, 49, 'trống'),
(18, 15, 'đã đặt'),
(18, 17, 'trống'),
(18, 21, 'đã đặt'),
(18, 24, 'trống'),
(18, 26, 'trống'),
(18, 28, 'trống'),
(18, 30, 'đã đặt'),
(18, 33, 'đã đặt'),
(18, 41, 'trống'),
(18, 44, 'trống'),
(18, 46, 'trống'),
(18, 48, 'trống'),
(18, 49, 'trống'),
(19, 15, 'đã đặt'),
(19, 17, 'trống'),
(19, 21, 'trống'),
(19, 24, 'trống'),
(19, 26, 'trống'),
(19, 28, 'trống'),
(19, 30, 'trống'),
(19, 33, 'trống'),
(19, 41, 'trống'),
(19, 44, 'trống'),
(19, 46, 'trống'),
(19, 48, 'trống'),
(19, 49, 'trống'),
(20, 15, 'trống'),
(20, 17, 'trống'),
(20, 21, 'trống'),
(20, 24, 'trống'),
(20, 26, 'trống'),
(20, 28, 'trống'),
(20, 30, 'trống'),
(20, 33, 'trống'),
(20, 41, 'trống'),
(20, 44, 'trống'),
(20, 46, 'trống'),
(20, 48, 'trống'),
(20, 49, 'trống'),
(21, 15, 'đã đặt'),
(21, 17, 'đã đặt'),
(21, 21, 'trống'),
(21, 24, 'đã đặt'),
(21, 26, 'trống'),
(21, 28, 'trống'),
(21, 30, 'trống'),
(21, 33, 'đã đặt'),
(21, 41, 'trống'),
(21, 44, 'trống'),
(21, 46, 'trống'),
(21, 48, 'trống'),
(21, 49, 'trống'),
(22, 15, 'trống'),
(22, 17, 'trống'),
(22, 21, 'trống'),
(22, 24, 'trống'),
(22, 26, 'trống'),
(22, 28, 'trống'),
(22, 30, 'trống'),
(22, 33, 'đã đặt'),
(22, 41, 'trống'),
(22, 44, 'trống'),
(22, 46, 'trống'),
(22, 48, 'trống'),
(22, 49, 'trống'),
(23, 15, 'trống'),
(23, 17, 'trống'),
(23, 21, 'trống'),
(23, 24, 'trống'),
(23, 26, 'trống'),
(23, 28, 'trống'),
(23, 30, 'trống'),
(23, 33, 'đã đặt'),
(23, 41, 'trống'),
(23, 44, 'trống'),
(23, 46, 'trống'),
(23, 48, 'trống'),
(23, 49, 'trống'),
(24, 15, 'trống'),
(24, 17, 'đã đặt'),
(24, 21, 'trống'),
(24, 24, 'trống'),
(24, 26, 'trống'),
(24, 28, 'trống'),
(24, 30, 'trống'),
(24, 33, 'trống'),
(24, 41, 'trống'),
(24, 44, 'trống'),
(24, 46, 'trống'),
(24, 48, 'trống'),
(24, 49, 'trống'),
(25, 15, 'trống'),
(25, 17, 'trống'),
(25, 21, 'trống'),
(25, 24, 'trống'),
(25, 26, 'trống'),
(25, 28, 'đã đặt'),
(25, 30, 'đã đặt'),
(25, 33, 'đã đặt'),
(25, 41, 'trống'),
(25, 44, 'trống'),
(25, 46, 'trống'),
(25, 48, 'trống'),
(25, 49, 'trống'),
(26, 15, 'trống'),
(26, 17, 'đã đặt'),
(26, 21, 'đã đặt'),
(26, 24, 'trống'),
(26, 26, 'đã đặt'),
(26, 28, 'trống'),
(26, 30, 'trống'),
(26, 33, 'trống'),
(26, 41, 'trống'),
(26, 44, 'trống'),
(26, 46, 'trống'),
(26, 48, 'trống'),
(26, 49, 'trống'),
(27, 15, 'trống'),
(27, 17, 'trống'),
(27, 21, 'trống'),
(27, 24, 'trống'),
(27, 26, 'trống'),
(27, 28, 'đã đặt'),
(27, 30, 'trống'),
(27, 33, 'trống'),
(27, 41, 'trống'),
(27, 44, 'trống'),
(27, 46, 'trống'),
(27, 48, 'trống'),
(27, 49, 'trống'),
(28, 15, 'trống'),
(28, 17, 'đã đặt'),
(28, 21, 'trống'),
(28, 24, 'trống'),
(28, 26, 'trống'),
(28, 28, 'trống'),
(28, 30, 'trống'),
(28, 33, 'đã đặt'),
(28, 41, 'trống'),
(28, 44, 'trống'),
(28, 46, 'trống'),
(28, 48, 'trống'),
(28, 49, 'trống'),
(29, 15, 'đã đặt'),
(29, 17, 'trống'),
(29, 21, 'trống'),
(29, 24, 'trống'),
(29, 26, 'trống'),
(29, 28, 'trống'),
(29, 30, 'trống'),
(29, 33, 'đã đặt'),
(29, 41, 'trống'),
(29, 44, 'trống'),
(29, 46, 'trống'),
(29, 48, 'trống'),
(29, 49, 'trống'),
(30, 15, 'trống'),
(30, 17, 'trống'),
(30, 21, 'trống'),
(30, 24, 'trống'),
(30, 26, 'trống'),
(30, 28, 'trống'),
(30, 30, 'trống'),
(30, 33, 'đã đặt'),
(30, 41, 'trống'),
(30, 44, 'trống'),
(30, 46, 'trống'),
(30, 48, 'trống'),
(30, 49, 'trống'),
(31, 15, 'đã đặt'),
(31, 17, 'trống'),
(31, 21, 'trống'),
(31, 24, 'trống'),
(31, 26, 'trống'),
(31, 28, 'trống'),
(31, 30, 'trống'),
(31, 33, 'trống'),
(31, 41, 'trống'),
(31, 44, 'trống'),
(31, 46, 'trống'),
(31, 48, 'trống'),
(31, 49, 'trống'),
(32, 15, 'trống'),
(32, 17, 'trống'),
(32, 21, 'trống'),
(32, 24, 'đã đặt'),
(32, 26, 'đã đặt'),
(32, 28, 'trống'),
(32, 30, 'trống'),
(32, 33, 'trống'),
(32, 41, 'trống'),
(32, 44, 'trống'),
(32, 46, 'trống'),
(32, 48, 'trống'),
(32, 49, 'trống'),
(33, 15, 'trống'),
(33, 17, 'trống'),
(33, 21, 'đã đặt'),
(33, 24, 'trống'),
(33, 26, 'trống'),
(33, 28, 'trống'),
(33, 30, 'trống'),
(33, 33, 'trống'),
(33, 41, 'trống'),
(33, 44, 'trống'),
(33, 46, 'trống'),
(33, 48, 'trống'),
(33, 49, 'trống'),
(34, 15, 'trống'),
(34, 17, 'trống'),
(34, 21, 'trống'),
(34, 24, 'trống'),
(34, 26, 'trống'),
(34, 28, 'đã đặt'),
(34, 30, 'trống'),
(34, 33, 'trống'),
(34, 41, 'trống'),
(34, 44, 'trống'),
(34, 46, 'trống'),
(34, 48, 'trống'),
(34, 49, 'trống'),
(35, 15, 'trống'),
(35, 17, 'trống'),
(35, 21, 'trống'),
(35, 24, 'trống'),
(35, 26, 'trống'),
(35, 28, 'trống'),
(35, 30, 'trống'),
(35, 33, 'trống'),
(35, 41, 'trống'),
(35, 44, 'trống'),
(35, 46, 'trống'),
(35, 48, 'trống'),
(35, 49, 'trống'),
(36, 15, 'trống'),
(36, 17, 'trống'),
(36, 21, 'đã đặt'),
(36, 24, 'trống'),
(36, 26, 'trống'),
(36, 28, 'đã đặt'),
(36, 30, 'trống'),
(36, 33, 'trống'),
(36, 41, 'trống'),
(36, 44, 'trống'),
(36, 46, 'trống'),
(36, 48, 'trống'),
(36, 49, 'trống'),
(37, 15, 'đã đặt'),
(37, 17, 'trống'),
(37, 21, 'trống'),
(37, 24, 'trống'),
(37, 26, 'trống'),
(37, 28, 'trống'),
(37, 30, 'trống'),
(37, 33, 'trống'),
(37, 41, 'trống'),
(37, 44, 'trống'),
(37, 46, 'trống'),
(37, 48, 'trống'),
(37, 49, 'trống'),
(38, 15, 'trống'),
(38, 17, 'trống'),
(38, 21, 'đã đặt'),
(38, 24, 'trống'),
(38, 26, 'trống'),
(38, 28, 'trống'),
(38, 30, 'trống'),
(38, 33, 'trống'),
(38, 41, 'trống'),
(38, 44, 'trống'),
(38, 46, 'trống'),
(38, 48, 'trống'),
(38, 49, 'trống'),
(39, 15, 'trống'),
(39, 17, 'trống'),
(39, 21, 'trống'),
(39, 24, 'trống'),
(39, 26, 'trống'),
(39, 28, 'trống'),
(39, 30, 'trống'),
(39, 33, 'trống'),
(39, 41, 'trống'),
(39, 44, 'trống'),
(39, 46, 'trống'),
(39, 48, 'trống'),
(39, 49, 'trống'),
(40, 15, 'trống'),
(40, 17, 'trống'),
(40, 21, 'trống'),
(40, 24, 'trống'),
(40, 26, 'đã đặt'),
(40, 28, 'trống'),
(40, 30, 'trống'),
(40, 33, 'trống'),
(40, 41, 'trống'),
(40, 44, 'trống'),
(40, 46, 'trống'),
(40, 48, 'trống'),
(40, 49, 'trống'),
(41, 15, 'trống'),
(41, 17, 'trống'),
(41, 21, 'trống'),
(41, 24, 'trống'),
(41, 26, 'trống'),
(41, 28, 'trống'),
(41, 30, 'trống'),
(41, 33, 'trống'),
(41, 41, 'trống'),
(41, 44, 'trống'),
(41, 46, 'trống'),
(41, 48, 'trống'),
(41, 49, 'trống'),
(42, 15, 'trống'),
(42, 17, 'trống'),
(42, 21, 'đã đặt'),
(42, 24, 'trống'),
(42, 26, 'trống'),
(42, 28, 'trống'),
(42, 30, 'trống'),
(42, 33, 'trống'),
(42, 41, 'trống'),
(42, 44, 'trống'),
(42, 46, 'trống'),
(42, 48, 'trống'),
(42, 49, 'trống'),
(43, 15, 'trống'),
(43, 17, 'đã đặt'),
(43, 21, 'trống'),
(43, 24, 'đã đặt'),
(43, 26, 'trống'),
(43, 28, 'trống'),
(43, 30, 'trống'),
(43, 33, 'trống'),
(43, 41, 'trống'),
(43, 44, 'trống'),
(43, 46, 'trống'),
(43, 48, 'trống'),
(43, 49, 'trống'),
(44, 15, 'trống'),
(44, 17, 'trống'),
(44, 21, 'trống'),
(44, 24, 'trống'),
(44, 26, 'đã đặt'),
(44, 28, 'trống'),
(44, 30, 'đã đặt'),
(44, 33, 'trống'),
(44, 41, 'trống'),
(44, 44, 'trống'),
(44, 46, 'trống'),
(44, 48, 'trống'),
(44, 49, 'trống'),
(45, 15, 'trống'),
(45, 17, 'trống'),
(45, 21, 'trống'),
(45, 24, 'trống'),
(45, 26, 'trống'),
(45, 28, 'trống'),
(45, 30, 'trống'),
(45, 33, 'trống'),
(45, 41, 'trống'),
(45, 44, 'trống'),
(45, 46, 'trống'),
(45, 48, 'trống'),
(45, 49, 'trống'),
(46, 15, 'trống'),
(46, 17, 'trống'),
(46, 21, 'trống'),
(46, 24, 'trống'),
(46, 26, 'trống'),
(46, 28, 'trống'),
(46, 30, 'trống'),
(46, 33, 'trống'),
(46, 41, 'trống'),
(46, 44, 'trống'),
(46, 46, 'trống'),
(46, 48, 'trống'),
(46, 49, 'trống'),
(47, 15, 'đã đặt'),
(47, 17, 'trống'),
(47, 21, 'trống'),
(47, 24, 'trống'),
(47, 26, 'trống'),
(47, 28, 'trống'),
(47, 30, 'trống'),
(47, 33, 'đã đặt'),
(47, 41, 'trống'),
(47, 44, 'trống'),
(47, 46, 'trống'),
(47, 48, 'trống'),
(47, 49, 'trống'),
(48, 15, 'trống'),
(48, 17, 'trống'),
(48, 21, 'trống'),
(48, 24, 'trống'),
(48, 26, 'trống'),
(48, 28, 'trống'),
(48, 30, 'trống'),
(48, 33, 'trống'),
(48, 41, 'trống'),
(48, 44, 'trống'),
(48, 46, 'trống'),
(48, 48, 'trống'),
(48, 49, 'trống'),
(49, 15, 'trống'),
(49, 17, 'trống'),
(49, 21, 'trống'),
(49, 24, 'đã đặt'),
(49, 26, 'trống'),
(49, 28, 'trống'),
(49, 30, 'trống'),
(49, 33, 'trống'),
(49, 41, 'trống'),
(49, 44, 'trống'),
(49, 46, 'trống'),
(49, 48, 'trống'),
(49, 49, 'trống'),
(50, 15, 'trống'),
(50, 17, 'trống'),
(50, 21, 'trống'),
(50, 24, 'trống'),
(50, 26, 'trống'),
(50, 28, 'đã đặt'),
(50, 30, 'đã đặt'),
(50, 33, 'trống'),
(50, 41, 'trống'),
(50, 44, 'trống'),
(50, 46, 'trống'),
(50, 48, 'trống'),
(50, 49, 'trống'),
(51, 15, 'trống'),
(51, 17, 'trống'),
(51, 21, 'trống'),
(51, 24, 'trống'),
(51, 26, 'trống'),
(51, 28, 'trống'),
(51, 30, 'trống'),
(51, 33, 'trống'),
(51, 41, 'trống'),
(51, 44, 'trống'),
(51, 46, 'trống'),
(51, 48, 'trống'),
(51, 49, 'trống'),
(52, 15, 'trống'),
(52, 17, 'trống'),
(52, 21, 'trống'),
(52, 24, 'trống'),
(52, 26, 'trống'),
(52, 28, 'trống'),
(52, 30, 'trống'),
(52, 33, 'đã đặt'),
(52, 41, 'trống'),
(52, 44, 'trống'),
(52, 46, 'trống'),
(52, 48, 'trống'),
(52, 49, 'trống'),
(53, 16, 'trống'),
(53, 19, 'trống'),
(53, 22, 'trống'),
(53, 25, 'trống'),
(53, 29, 'đã đặt'),
(53, 32, 'trống'),
(53, 35, 'đã đặt'),
(53, 42, 'trống'),
(53, 45, 'trống'),
(53, 50, 'đã đặt'),
(53, 52, 'trống'),
(54, 16, 'trống'),
(54, 19, 'trống'),
(54, 22, 'đã đặt'),
(54, 25, 'trống'),
(54, 29, 'đã đặt'),
(54, 32, 'trống'),
(54, 35, 'trống'),
(54, 42, 'trống'),
(54, 45, 'trống'),
(54, 50, 'đã đặt'),
(54, 52, 'trống'),
(55, 16, 'đã đặt'),
(55, 19, 'trống'),
(55, 22, 'trống'),
(55, 25, 'đã đặt'),
(55, 29, 'đã đặt'),
(55, 32, 'đã đặt'),
(55, 35, 'trống'),
(55, 42, 'trống'),
(55, 45, 'trống'),
(55, 50, 'đã đặt'),
(55, 52, 'đã đặt'),
(56, 16, 'đã đặt'),
(56, 19, 'trống'),
(56, 22, 'trống'),
(56, 25, 'đã đặt'),
(56, 29, 'đã đặt'),
(56, 32, 'đã đặt'),
(56, 35, 'trống'),
(56, 42, 'trống'),
(56, 45, 'trống'),
(56, 50, 'đã đặt'),
(56, 52, 'đã đặt'),
(57, 16, 'trống'),
(57, 19, 'trống'),
(57, 22, 'trống'),
(57, 25, 'trống'),
(57, 29, 'trống'),
(57, 32, 'trống'),
(57, 35, 'đã đặt'),
(57, 42, 'trống'),
(57, 45, 'trống'),
(57, 50, 'đã đặt'),
(57, 52, 'trống'),
(58, 16, 'đã đặt'),
(58, 19, 'trống'),
(58, 22, 'trống'),
(58, 25, 'trống'),
(58, 29, 'đã đặt'),
(58, 32, 'đã đặt'),
(58, 35, 'đã đặt'),
(58, 42, 'trống'),
(58, 45, 'trống'),
(58, 50, 'đã đặt'),
(58, 52, 'trống'),
(59, 16, 'đã đặt'),
(59, 19, 'trống'),
(59, 22, 'trống'),
(59, 25, 'trống'),
(59, 29, 'đã đặt'),
(59, 32, 'đã đặt'),
(59, 35, 'đã đặt'),
(59, 42, 'trống'),
(59, 45, 'trống'),
(59, 50, 'đã đặt'),
(59, 52, 'trống'),
(60, 16, 'đã đặt'),
(60, 19, 'trống'),
(60, 22, 'trống'),
(60, 25, 'đã đặt'),
(60, 29, 'trống'),
(60, 32, 'đã đặt'),
(60, 35, 'trống'),
(60, 42, 'trống'),
(60, 45, 'trống'),
(60, 50, 'trống'),
(60, 52, 'trống'),
(61, 16, 'đã đặt'),
(61, 19, 'trống'),
(61, 22, 'trống'),
(61, 25, 'trống'),
(61, 29, 'trống'),
(61, 32, 'trống'),
(61, 35, 'trống'),
(61, 42, 'trống'),
(61, 45, 'trống'),
(61, 50, 'trống'),
(61, 52, 'trống'),
(62, 16, 'đã đặt'),
(62, 19, 'trống'),
(62, 22, 'trống'),
(62, 25, 'đã đặt'),
(62, 29, 'trống'),
(62, 32, 'trống'),
(62, 35, 'trống'),
(62, 42, 'trống'),
(62, 45, 'trống'),
(62, 50, 'đã đặt'),
(62, 52, 'trống'),
(63, 16, 'đã đặt'),
(63, 19, 'trống'),
(63, 22, 'trống'),
(63, 25, 'trống'),
(63, 29, 'đã đặt'),
(63, 32, 'đã đặt'),
(63, 35, 'trống'),
(63, 42, 'trống'),
(63, 45, 'trống'),
(63, 50, 'đã đặt'),
(63, 52, 'trống'),
(64, 16, 'trống'),
(64, 19, 'đã đặt'),
(64, 22, 'trống'),
(64, 25, 'trống'),
(64, 29, 'đã đặt'),
(64, 32, 'đã đặt'),
(64, 35, 'trống'),
(64, 42, 'trống'),
(64, 45, 'trống'),
(64, 50, 'đã đặt'),
(64, 52, 'trống'),
(65, 16, 'trống'),
(65, 19, 'trống'),
(65, 22, 'trống'),
(65, 25, 'đã đặt'),
(65, 29, 'đã đặt'),
(65, 32, 'đã đặt'),
(65, 35, 'trống'),
(65, 42, 'trống'),
(65, 45, 'trống'),
(65, 50, 'trống'),
(65, 52, 'trống'),
(66, 16, 'trống'),
(66, 19, 'trống'),
(66, 22, 'trống'),
(66, 25, 'đã đặt'),
(66, 29, 'trống'),
(66, 32, 'đã đặt'),
(66, 35, 'đã đặt'),
(66, 42, 'trống'),
(66, 45, 'trống'),
(66, 50, 'trống'),
(66, 52, 'trống'),
(67, 16, 'trống'),
(67, 19, 'trống'),
(67, 22, 'đã đặt'),
(67, 25, 'trống'),
(67, 29, 'trống'),
(67, 32, 'trống'),
(67, 35, 'trống'),
(67, 42, 'trống'),
(67, 45, 'trống'),
(67, 50, 'đã đặt'),
(67, 52, 'trống'),
(68, 16, 'đã đặt'),
(68, 19, 'trống'),
(68, 22, 'đã đặt'),
(68, 25, 'trống'),
(68, 29, 'đã đặt'),
(68, 32, 'trống'),
(68, 35, 'trống'),
(68, 42, 'trống'),
(68, 45, 'trống'),
(68, 50, 'đã đặt'),
(68, 52, 'trống'),
(69, 16, 'trống'),
(69, 19, 'đã đặt'),
(69, 22, 'trống'),
(69, 25, 'trống'),
(69, 29, 'đã đặt'),
(69, 32, 'đã đặt'),
(69, 35, 'đã đặt'),
(69, 42, 'trống'),
(69, 45, 'trống'),
(69, 50, 'trống'),
(69, 52, 'trống'),
(70, 16, 'trống'),
(70, 19, 'trống'),
(70, 22, 'đã đặt'),
(70, 25, 'đã đặt'),
(70, 29, 'đã đặt'),
(70, 32, 'đã đặt'),
(70, 35, 'đã đặt'),
(70, 42, 'trống'),
(70, 45, 'trống'),
(70, 50, 'trống'),
(70, 52, 'trống'),
(71, 16, 'trống'),
(71, 19, 'đã đặt'),
(71, 22, 'trống'),
(71, 25, 'đã đặt'),
(71, 29, 'đã đặt'),
(71, 32, 'đã đặt'),
(71, 35, 'trống'),
(71, 42, 'trống'),
(71, 45, 'trống'),
(71, 50, 'đã đặt'),
(71, 52, 'trống'),
(72, 16, 'trống'),
(72, 19, 'trống'),
(72, 22, 'đã đặt'),
(72, 25, 'đã đặt'),
(72, 29, 'đã đặt'),
(72, 32, 'trống'),
(72, 35, 'trống'),
(72, 42, 'trống'),
(72, 45, 'trống'),
(72, 50, 'đã đặt'),
(72, 52, 'trống'),
(73, 16, 'đã đặt'),
(73, 19, 'trống'),
(73, 22, 'trống'),
(73, 25, 'trống'),
(73, 29, 'đã đặt'),
(73, 32, 'trống'),
(73, 35, 'đã đặt'),
(73, 42, 'trống'),
(73, 45, 'trống'),
(73, 50, 'đã đặt'),
(73, 52, 'trống'),
(74, 16, 'trống'),
(74, 19, 'đã đặt'),
(74, 22, 'trống'),
(74, 25, 'trống'),
(74, 29, 'đã đặt'),
(74, 32, 'trống'),
(74, 35, 'đã đặt'),
(74, 42, 'trống'),
(74, 45, 'trống'),
(74, 50, 'đã đặt'),
(74, 52, 'trống'),
(75, 16, 'đã đặt'),
(75, 19, 'trống'),
(75, 22, 'trống'),
(75, 25, 'đã đặt'),
(75, 29, 'trống'),
(75, 32, 'đã đặt'),
(75, 35, 'trống'),
(75, 42, 'trống'),
(75, 45, 'trống'),
(75, 50, 'đã đặt'),
(75, 52, 'trống'),
(76, 16, 'đã đặt'),
(76, 19, 'trống'),
(76, 22, 'đã đặt'),
(76, 25, 'trống'),
(76, 29, 'trống'),
(76, 32, 'đã đặt'),
(76, 35, 'đã đặt'),
(76, 42, 'trống'),
(76, 45, 'trống'),
(76, 50, 'trống'),
(76, 52, 'trống'),
(77, 18, 'đã đặt'),
(77, 20, 'trống'),
(77, 23, 'trống'),
(77, 27, 'đã đặt'),
(77, 31, 'trống'),
(77, 34, 'đã đặt'),
(77, 43, 'trống'),
(77, 47, 'trống'),
(77, 51, 'trống'),
(78, 18, 'đã đặt'),
(78, 20, 'trống'),
(78, 23, 'trống'),
(78, 27, 'đã đặt'),
(78, 31, 'trống'),
(78, 34, 'đã đặt'),
(78, 43, 'trống'),
(78, 47, 'trống'),
(78, 51, 'trống'),
(79, 18, 'đã đặt'),
(79, 20, 'trống'),
(79, 23, 'trống'),
(79, 27, 'đã đặt'),
(79, 31, 'đã đặt'),
(79, 34, 'đã đặt'),
(79, 43, 'trống'),
(79, 47, 'trống'),
(79, 51, 'đã đặt'),
(80, 18, 'đã đặt'),
(80, 20, 'trống'),
(80, 23, 'trống'),
(80, 27, 'đã đặt'),
(80, 31, 'đã đặt'),
(80, 34, 'đã đặt'),
(80, 43, 'trống'),
(80, 47, 'trống'),
(80, 51, 'đã đặt'),
(81, 18, 'đã đặt'),
(81, 20, 'trống'),
(81, 23, 'trống'),
(81, 27, 'đã đặt'),
(81, 31, 'đã đặt'),
(81, 34, 'đã đặt'),
(81, 43, 'trống'),
(81, 47, 'trống'),
(81, 51, 'trống'),
(82, 18, 'đã đặt'),
(82, 20, 'trống'),
(82, 23, 'trống'),
(82, 27, 'đã đặt'),
(82, 31, 'trống'),
(82, 34, 'đã đặt'),
(82, 43, 'trống'),
(82, 47, 'trống'),
(82, 51, 'đã đặt'),
(83, 18, 'đã đặt'),
(83, 20, 'trống'),
(83, 23, 'trống'),
(83, 27, 'trống'),
(83, 31, 'trống'),
(83, 34, 'trống'),
(83, 43, 'trống'),
(83, 47, 'trống'),
(83, 51, 'trống'),
(84, 18, 'đã đặt'),
(84, 20, 'trống'),
(84, 23, 'đã đặt'),
(84, 27, 'đã đặt'),
(84, 31, 'đã đặt'),
(84, 34, 'trống'),
(84, 43, 'trống'),
(84, 47, 'trống'),
(84, 51, 'đã đặt'),
(85, 18, 'đã đặt'),
(85, 20, 'trống'),
(85, 23, 'trống'),
(85, 27, 'trống'),
(85, 31, 'đã đặt'),
(85, 34, 'đã đặt'),
(85, 43, 'trống'),
(85, 47, 'trống'),
(85, 51, 'đã đặt'),
(86, 18, 'đã đặt'),
(86, 20, 'trống'),
(86, 23, 'trống'),
(86, 27, 'trống'),
(86, 31, 'đã đặt'),
(86, 34, 'đã đặt'),
(86, 43, 'trống'),
(86, 47, 'trống'),
(86, 51, 'đã đặt'),
(87, 18, 'đã đặt'),
(87, 20, 'trống'),
(87, 23, 'trống'),
(87, 27, 'đã đặt'),
(87, 31, 'đã đặt'),
(87, 34, 'đã đặt'),
(87, 43, 'trống'),
(87, 47, 'trống'),
(87, 51, 'trống'),
(88, 18, 'đã đặt'),
(88, 20, 'đã đặt'),
(88, 23, 'trống'),
(88, 27, 'đã đặt'),
(88, 31, 'đã đặt'),
(88, 34, 'đã đặt'),
(88, 43, 'trống'),
(88, 47, 'trống'),
(88, 51, 'đã đặt'),
(89, 18, 'đã đặt'),
(89, 20, 'đã đặt'),
(89, 23, 'trống'),
(89, 27, 'đã đặt'),
(89, 31, 'đã đặt'),
(89, 34, 'trống'),
(89, 43, 'trống'),
(89, 47, 'trống'),
(89, 51, 'trống'),
(90, 18, 'đã đặt'),
(90, 20, 'trống'),
(90, 23, 'đã đặt'),
(90, 27, 'đã đặt'),
(90, 31, 'trống'),
(90, 34, 'trống'),
(90, 43, 'trống'),
(90, 47, 'trống'),
(90, 51, 'trống'),
(91, 18, 'đã đặt'),
(91, 20, 'đã đặt'),
(91, 23, 'trống'),
(91, 27, 'trống'),
(91, 31, 'đã đặt'),
(91, 34, 'đã đặt'),
(91, 43, 'trống'),
(91, 47, 'trống'),
(91, 51, 'trống'),
(92, 18, 'đã đặt'),
(92, 20, 'trống'),
(92, 23, 'trống'),
(92, 27, 'đã đặt'),
(92, 31, 'đã đặt'),
(92, 34, 'đã đặt'),
(92, 43, 'trống'),
(92, 47, 'trống'),
(92, 51, 'trống'),
(93, 18, 'đã đặt'),
(93, 20, 'trống'),
(93, 23, 'trống'),
(93, 27, 'đã đặt'),
(93, 31, 'trống'),
(93, 34, 'đã đặt'),
(93, 43, 'trống'),
(93, 47, 'trống'),
(93, 51, 'trống'),
(94, 18, 'đã đặt'),
(94, 20, 'trống'),
(94, 23, 'trống'),
(94, 27, 'trống'),
(94, 31, 'đã đặt'),
(94, 34, 'trống'),
(94, 43, 'trống'),
(94, 47, 'trống'),
(94, 51, 'đã đặt'),
(95, 18, 'đã đặt'),
(95, 20, 'đã đặt'),
(95, 23, 'trống'),
(95, 27, 'đã đặt'),
(95, 31, 'đã đặt'),
(95, 34, 'trống'),
(95, 43, 'trống'),
(95, 47, 'trống'),
(95, 51, 'trống'),
(96, 18, 'đã đặt'),
(96, 20, 'trống'),
(96, 23, 'đã đặt'),
(96, 27, 'trống'),
(96, 31, 'đã đặt'),
(96, 34, 'đã đặt'),
(96, 43, 'trống'),
(96, 47, 'trống'),
(96, 51, 'trống'),
(97, 18, 'đã đặt'),
(97, 20, 'trống'),
(97, 23, 'đã đặt'),
(97, 27, 'trống'),
(97, 31, 'đã đặt'),
(97, 34, 'đã đặt'),
(97, 43, 'trống'),
(97, 47, 'trống'),
(97, 51, 'trống'),
(98, 18, 'đã đặt'),
(98, 20, 'trống'),
(98, 23, 'trống'),
(98, 27, 'trống'),
(98, 31, 'trống'),
(98, 34, 'đã đặt'),
(98, 43, 'trống'),
(98, 47, 'trống'),
(98, 51, 'trống'),
(99, 18, 'đã đặt'),
(99, 20, 'trống'),
(99, 23, 'trống'),
(99, 27, 'đã đặt'),
(99, 31, 'trống'),
(99, 34, 'đã đặt'),
(99, 43, 'trống'),
(99, 47, 'trống'),
(99, 51, 'trống'),
(100, 18, 'đã đặt'),
(100, 20, 'trống'),
(100, 23, 'trống'),
(100, 27, 'trống'),
(100, 31, 'trống'),
(100, 34, 'đã đặt'),
(100, 43, 'trống'),
(100, 47, 'trống'),
(100, 51, 'trống'),
(101, 18, 'đã đặt'),
(101, 20, 'trống'),
(101, 23, 'trống'),
(101, 27, 'đã đặt'),
(101, 31, 'trống'),
(101, 34, 'đã đặt'),
(101, 43, 'trống'),
(101, 47, 'trống'),
(101, 51, 'trống'),
(102, 18, 'trống'),
(102, 20, 'đã đặt'),
(102, 23, 'trống'),
(102, 27, 'trống'),
(102, 31, 'đã đặt'),
(102, 34, 'đã đặt'),
(102, 43, 'trống'),
(102, 47, 'trống'),
(102, 51, 'đã đặt'),
(103, 18, 'đã đặt'),
(103, 20, 'trống'),
(103, 23, 'trống'),
(103, 27, 'trống'),
(103, 31, 'đã đặt'),
(103, 34, 'đã đặt'),
(103, 43, 'trống'),
(103, 47, 'trống'),
(103, 51, 'đã đặt'),
(104, 18, 'đã đặt'),
(104, 20, 'trống'),
(104, 23, 'trống'),
(104, 27, 'trống'),
(104, 31, 'đã đặt'),
(104, 34, 'đã đặt'),
(104, 43, 'trống'),
(104, 47, 'trống'),
(104, 51, 'đã đặt'),
(105, 18, 'đã đặt'),
(105, 20, 'trống'),
(105, 23, 'trống'),
(105, 27, 'đã đặt'),
(105, 31, 'đã đặt'),
(105, 34, 'đã đặt'),
(105, 43, 'trống'),
(105, 47, 'trống'),
(105, 51, 'trống'),
(106, 18, 'đã đặt'),
(106, 20, 'đã đặt'),
(106, 23, 'trống'),
(106, 27, 'đã đặt'),
(106, 31, 'đã đặt'),
(106, 34, 'đã đặt'),
(106, 43, 'trống'),
(106, 47, 'trống'),
(106, 51, 'trống');

-- --------------------------------------------------------

--
-- Table structure for table `shows`
--

CREATE TABLE `shows` (
  `show_id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `duration_minutes` int(11) DEFAULT NULL,
  `director` varchar(255) DEFAULT NULL,
  `poster_image_url` varchar(255) DEFAULT NULL,
  `status` enum('Sắp chiếu','Đang chiếu','Đã kết thúc') NOT NULL DEFAULT 'Sắp chiếu',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `shows`
--

INSERT INTO `shows` (`show_id`, `title`, `description`, `duration_minutes`, `director`, `poster_image_url`, `status`, `created_at`, `updated_at`) VALUES
(8, 'Đứt dây tơ chùng', 'Câu chuyện xoay quanh những giằng xé trong tình yêu, danh vọng và số phận. Sợi dây tình cảm tưởng chừng bền chặt nhưng lại mong manh trước thử thách của lòng người.', 120, 'Nguyễn Văn Khánh', 'assets/images/dut-day-to-chung-poster.jpg', 'Đang chiếu', '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(9, 'Gánh Cỏ Sông Hàn', 'Lấy bối cảnh miền Trung những năm sau chiến tranh, vở kịch khắc họa số phận những con người mưu sinh bên bến sông Hàn, với tình người chan chứa giữa cuộc đời đầy nhọc nhằn.', 110, 'Trần Thị Mai', 'assets/images/ganh-co-poster.jpg', 'Đã kết thúc', '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(10, 'Làng Song Sinh', 'Một ngôi làng kỳ bí nơi những cặp song sinh liên tục chào đời. Bí mật phía sau sự trùng hợp ấy dần hé lộ, để rồi đẩy người xem vào những tình huống ly kỳ và ám ảnh.', 100, 'Lê Hoàng Nam', 'assets/images/lang-song-sinh-poster.jpg', 'Đã kết thúc', '2025-08-01 00:00:00', '2025-11-26 04:15:26'),
(11, 'Lôi Vũ', 'Một trong những vở kịch nổi tiếng nhất thế kỷ XX, “Lôi Vũ” phơi bày những mâu thuẫn giai cấp, đạo đức và gia đình trong xã hội cũ. Vở diễn mang đến sự lay động mạnh mẽ và dư âm lâu dài.', 140, 'Phạm Quang Dũng', 'assets/images/loi-vu.jpg', 'Đã kết thúc', '2025-08-01 00:00:00', '2025-11-23 13:35:03'),
(12, 'Ngôi Nhà Trong Mây', 'Một câu chuyện thơ mộng về tình yêu và khát vọng sống, nơi con người tìm đến “ngôi nhà trong mây” để trốn chạy thực tại. Nhưng rồi họ nhận ra: hạnh phúc thật sự chỉ đến khi dám đối diện với chính mình.', 104, 'Vũ Thảo My', 'assets/images/ngoi-nha-trong-may-poster.jpg', 'Đã kết thúc', '2025-08-01 00:00:00', '2025-11-26 14:12:14'),
(13, 'Tấm Cám Đại Chiến', 'Phiên bản hiện đại, vui nhộn và đầy sáng tạo của truyện cổ tích “Tấm Cám”. Với yếu tố gây cười, châm biếm và bất ngờ, vở diễn mang đến những phút giây giải trí thú vị cho cả gia đình.', 95, 'Hoàng Anh Tú', 'assets/images/tam-cam-poster.jpg', 'Đã kết thúc', '2025-08-01 00:00:00', '2025-11-24 15:36:25'),
(14, 'Má ơi út dìa', 'Câu chuyện cảm động về tình mẫu tử và nỗi day dứt của người con xa quê. Những ký ức, những tiếng gọi “Má ơi” trở thành sợi dây kết nối quá khứ và hiện tại.', 110, 'Nguyễn Thị Thanh Hương', 'assets/images/ma-oi-ut-dia-poster.png', 'Đã kết thúc', '2025-11-04 12:37:19', '2025-11-24 07:07:01'),
(15, 'Tía ơi má dìa', 'Một vở kịch hài – tình cảm về những hiểu lầm, giận hờn và yêu thương trong một gia đình miền Tây. Tiếng cười và nước mắt đan xen tạo nên cảm xúc sâu lắng.', 100, 'Trần Hoài Phong', 'assets/images/tia-oi-ma-dia-poster.jpg', 'Đã kết thúc', '2025-11-04 12:40:24', '2025-11-24 07:07:01'),
(16, 'Đức Thượng Công Tả Quân Lê Văn Duyệt', 'Tái hiện hình tượng vị danh tướng Lê Văn Duyệt – người để lại dấu ấn sâu đậm trong lịch sử và lòng dân Nam Bộ. Một vở diễn lịch sử trang trọng, đầy khí phách.', 130, 'Phạm Hữu Tấn', 'assets/images/duc-thuong-cong-ta-quan-le-van-duyet-poster.jpg', 'Đã kết thúc', '2025-11-04 12:42:26', '2025-11-24 07:07:01'),
(17, 'Chuyến Đò Định Mệnh', 'Một câu chuyện đầy kịch tính xoay quanh chuyến đò cuối cùng của đời người lái đò, nơi tình yêu, tội lỗi và sự tha thứ gặp nhau trong một đêm giông bão.', 115, 'Vũ Ngọc Dũng', 'assets/images/chuyen-do-dinh-menh-poster.jpg', 'Đang chiếu', '2025-11-04 12:43:35', '2025-11-04 13:43:57'),
(18, 'Một Ngày Làm Vua', 'Vở hài kịch xã hội châm biếm về một người bình thường bỗng được trao quyền lực. Từ đó, những tình huống oái oăm, dở khóc dở cười liên tục xảy ra.', 100, 'Nguyễn Hoàng Anh', 'assets/images/mot-ngay-lam-vua-poster.jpg', 'Đã kết thúc', '2025-11-04 12:44:58', '2025-11-22 11:47:10'),
(19, 'Xóm Vịt Trời', 'Một góc nhìn nhân văn và hài hước về cuộc sống mưu sinh của những người lao động nghèo trong một xóm nhỏ ven sông. Dù khốn khó, họ vẫn giữ niềm tin và tình người.', 105, 'Lê Thị Phương Loan', 'assets/images/xom-vit-troi-poster.jpg', 'Đã kết thúc', '2025-11-04 12:46:05', '2025-11-22 11:47:10'),
(20, 'Những con ma nhà hát', '“Những Con Ma Nhà Hát” là một câu chuyện rùng rợn nhưng cũng đầy tính châm biếm, xoay quanh những hiện tượng kỳ bí xảy ra tại một nhà hát cũ sắp bị phá bỏ. Khi đoàn kịch mới đến tập luyện, những bóng ma của các diễn viên quá cố bắt đầu xuất hiện, đưa người xem vào hành trình giằng co giữa nghệ thuật, danh vọng và quá khứ bị lãng quên.', 115, 'Nguyễn Khánh Trung', 'assets/images/nhung-con-ma-poster.jpg', 'Đã kết thúc', '2025-11-04 13:19:55', '2025-11-24 07:07:01');

-- --------------------------------------------------------

--
-- Table structure for table `show_actors`
--

CREATE TABLE `show_actors` (
  `show_id` int(11) NOT NULL,
  `actor_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `show_actors`
--

INSERT INTO `show_actors` (`show_id`, `actor_id`) VALUES
(8, 2),
(8, 4),
(8, 6),
(8, 9),
(8, 10),
(9, 2),
(9, 3),
(9, 5),
(10, 3),
(10, 8),
(10, 10),
(11, 1),
(11, 5),
(11, 6),
(12, 5),
(12, 6),
(12, 9),
(13, 5),
(13, 6),
(13, 7),
(14, 3),
(14, 5),
(14, 7),
(15, 2),
(15, 3),
(15, 4),
(16, 3),
(16, 4),
(16, 10),
(17, 1),
(17, 6),
(17, 8),
(17, 10),
(18, 2),
(18, 5),
(18, 7),
(19, 2),
(19, 3),
(19, 4),
(20, 4),
(20, 8),
(20, 10);

-- --------------------------------------------------------

--
-- Table structure for table `show_genres`
--

CREATE TABLE `show_genres` (
  `show_id` int(11) NOT NULL,
  `genre_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `show_genres`
--

INSERT INTO `show_genres` (`show_id`, `genre_id`) VALUES
(8, 6),
(8, 8),
(9, 8),
(9, 9),
(9, 10),
(10, 8),
(10, 13),
(11, 6),
(11, 8),
(11, 15),
(12, 11),
(12, 12),
(13, 7),
(13, 14),
(14, 6),
(14, 10),
(14, 16),
(15, 7),
(15, 10),
(15, 16),
(16, 15),
(16, 17),
(16, 18),
(17, 6),
(17, 8),
(17, 13),
(18, 7),
(18, 18),
(18, 19),
(19, 8),
(19, 9),
(19, 10),
(20, 8),
(20, 12),
(20, 13);

-- --------------------------------------------------------

--
-- Table structure for table `theaters`
--

CREATE TABLE `theaters` (
  `theater_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `total_seats` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` enum('Chờ xử lý','Đã hoạt động') NOT NULL DEFAULT 'Chờ xử lý'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `theaters`
--

INSERT INTO `theaters` (`theater_id`, `name`, `total_seats`, `created_at`, `status`) VALUES
(1, 'Main Hall', 52, '2025-10-03 16:14:11', 'Đã hoạt động'),
(2, 'Black Box', 32, '2025-10-03 16:14:22', 'Đã hoạt động'),
(3, 'Studio', 30, '2025-10-03 16:14:32', 'Đã hoạt động');

-- --------------------------------------------------------

--
-- Table structure for table `tickets`
--

CREATE TABLE `tickets` (
  `ticket_id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `seat_id` int(11) NOT NULL,
  `ticket_code` bigint(20) NOT NULL,
  `status` enum('Đang chờ','Hợp lệ','Đã sử dụng','Đã hủy') NOT NULL DEFAULT 'Đang chờ',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `tickets`
--

INSERT INTO `tickets` (`ticket_id`, `booking_id`, `seat_id`, `ticket_code`, `status`, `created_at`) VALUES
(1, 1001, 82, 2407093170477, 'Đang chờ', '2025-11-26 09:35:31'),
(2, 1001, 88, 8911093521779, 'Đang chờ', '2025-11-26 09:35:31'),
(3, 1001, 94, 9334188374069, 'Đang chờ', '2025-11-26 09:35:31'),
(4, 1002, 80, 9937661581613, 'Đang chờ', '2025-11-27 18:41:50'),
(5, 1002, 81, 2685743062464, 'Đang chờ', '2025-11-27 18:41:50'),
(6, 1003, 86, 9615730844079, 'Đang chờ', '2025-11-27 20:23:57'),
(7, 1003, 87, 3021425309610, 'Đang chờ', '2025-11-27 20:23:57'),
(8, 1003, 88, 3259934292416, 'Đang chờ', '2025-11-27 20:23:57'),
(9, 1004, 93, 6235395809854, 'Đang chờ', '2025-11-27 20:25:54'),
(10, 1004, 94, 2397176448625, 'Đang chờ', '2025-11-27 20:25:54'),
(11, 1005, 78, 1279695090166, 'Đang chờ', '2025-11-27 20:39:02'),
(12, 1006, 85, 7206946381559, 'Đang chờ', '2025-11-27 21:12:36'),
(13, 1006, 91, 4195646913904, 'Đang chờ', '2025-11-27 21:12:36'),
(14, 1007, 89, 7357395701442, 'Đang chờ', '2025-11-27 21:12:51'),
(15, 1007, 90, 5200038042105, 'Đang chờ', '2025-11-27 21:12:51'),
(16, 1008, 97, 2928003382801, 'Đang chờ', '2025-11-27 21:15:56'),
(17, 1008, 98, 7039903064294, 'Đang chờ', '2025-11-27 21:15:56'),
(18, 1009, 100, 7415505449673, 'Đang chờ', '2025-11-27 21:16:04'),
(19, 1010, 95, 5957818332088, 'Đang chờ', '2025-11-27 21:46:11'),
(20, 1010, 101, 6542575588023, 'Đang chờ', '2025-11-27 21:46:11'),
(21, 1011, 84, 4839423220454, 'Đang chờ', '2025-11-27 21:46:39'),
(22, 1011, 85, 3569389614806, 'Đang chờ', '2025-11-27 21:46:39'),
(23, 1011, 86, 2328678689271, 'Đang chờ', '2025-11-27 21:46:39'),
(24, 1012, 104, 8935224878540, 'Đang chờ', '2025-11-28 06:59:50'),
(25, 1012, 106, 9690088601493, 'Đang chờ', '2025-11-28 06:59:50'),
(26, 1013, 55, 2644768648449, 'Đang chờ', '2025-11-28 07:00:04'),
(27, 1013, 56, 1153577714370, 'Đang chờ', '2025-11-28 07:00:04');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `account_name` varchar(100) NOT NULL,
  `user_type` enum('Nhân viên','Admin','Khách hàng') NOT NULL,
  `status` enum('hoạt động','khóa') NOT NULL DEFAULT 'hoạt động',
  `is_verified` tinyint(1) NOT NULL DEFAULT 0,
  `otp_code` varchar(10) DEFAULT NULL,
  `otp_expires_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `email`, `password`, `account_name`, `user_type`, `status`, `is_verified`, `otp_code`, `otp_expires_at`) VALUES
(1, 'staff@example.com', '$2a$11$jSoyDGEyNSgflwPKbQyA5.wFUNvhqXLQ5rzeoNSbl.YaZZ8ZrpKwm', 'thanhminh', 'Nhân viên', 'khóa', 1, NULL, NULL),
(2, 'trangltmt1509@gmail.com', '$2y$10$0doy81SVgcSvSwMD/VBK2OGfKf6yIVFEnCmzZYR15PjSq/yGz8p.C', 'trale', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(3, 'hoaithunguyen066@gmail.com', '$2y$10$6pjx5wsk.tW3icop/RZjWu0nMUqs61OhljS8NttNHqOxG2yP/sZdK', 'ht1123', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(4, 'nguyenthithuytrang2020bd@gmail.com', '$2y$10$qEOSBdHhLThH6gneJ2tki.YIdoFCGM7wsBScXYAZ7sgZpDUIuLKSW', 'nguyenna', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(6, 'trangle.31231026559@st.ueh.edu.vn', '$2a$11$eomc40N0cv3Ylmr2AA0tEu5DDSvkAc1BWdYVQLK8181DGbCo.7Hgq', 'trangle', 'Nhân viên', 'hoạt động', 1, NULL, NULL),
(7, 'admin@example.com', '$2a$11$JTJZtd3qxD9zZ3J9qNPdduuSauAEBc/fQubS7t/Ai8jjDfHe69qbe', 'Admin', 'Admin', 'hoạt động', 1, NULL, NULL),
(19, 'minarmy1509@gmail.com', '$2y$10$WmOFFFccY97IjoBtyNQvRufjZLc4MkquHvWOLCSjIn2EIgv.li3my', 'nana', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(20, 'nguyenhoaithu2019pm@gmail.com', '$2y$10$QVaUYDI.e5LWa6G6yqBcHOhHkIr8sez1ze2TMGPWYYMVe29/3caka', 'thele', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(21, 'thuytrang2020bd@gmail.com', '$2y$10$n5UURYh9PjaT9p/zhnD/XuRgILBxbsonGWch13ztBpOP8hjQm7IoG', 'hieunguyen', 'Khách hàng', 'hoạt động', 1, NULL, NULL),
(22, 'trangnguyen.31231026201@st.ueh.edu.vn', '$2a$11$ndW2z6oNM4zTpgdZ8Cri4.GbhGEIwnuT/OJZ/EnMMp1QIHxnc0lOO', 'thuytrang', 'Nhân viên', 'hoạt động', 1, NULL, NULL),
(27, 'thunguyen.31231026200@ueh.edu.vn', '$2a$11$qvmNfvCHabyYkC/DUPE1eOtlJkQhEUf0GfuxF.A0Gk5azhiZkiZ36', 'hoaithu', 'Nhân viên', 'hoạt động', 1, NULL, NULL),
(28, 'ngocduong.31231024139@st.ueh.edu.vn', '$2a$11$5VkZcBouRzHQVgs//GPuFeWf7UaWXdUlEnN2zA8FrNSvSsMddlg/i', 'thanhngoc', 'Nhân viên', 'hoạt động', 1, NULL, NULL),
(34, 'ddd@gmail', '$2a$11$9BbOEUGJ5Jxl8MgSgKbiIe5gOmMmZzUcUN7HiyUWDt4Md8wg0JcE6', 'dd', 'Nhân viên', 'hoạt động', 1, NULL, NULL),
(35, '113@gmail', '$2a$11$h3nekPEs4IqYVnTMLOk3eu65ai.sfA5hNEf0lv.vyhs1qUuLOovG6', 'dddd', 'Admin', 'hoạt động', 1, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `user_detail`
--

CREATE TABLE `user_detail` (
  `user_id` int(11) NOT NULL,
  `full_name` varchar(255) NOT NULL,
  `date_of_birth` date NOT NULL,
  `address` varchar(255) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `user_detail`
--

INSERT INTO `user_detail` (`user_id`, `full_name`, `date_of_birth`, `address`, `phone`) VALUES
(1, 'Dương Hà Thanh', '2005-08-12', NULL, NULL),
(2, 'Lê Minh Anh', '2005-09-10', NULL, NULL),
(3, 'Nguyễn Hà Thi', '2005-08-01', NULL, NULL),
(4, 'Nguyễn Thùy Trinh', '2005-03-12', NULL, NULL),
(6, 'Lê Thị Mỹ Trang', '2025-11-24', 'QN', ''),
(7, 'Le My Phung', '2025-11-22', 'BD', ''),
(19, 'Nguyễn Thị Na', '2003-11-12', NULL, NULL),
(20, 'Lê Thùy Linh', '2001-12-12', NULL, NULL),
(21, 'Nguyễn Văn Hiếu', '2001-12-12', NULL, NULL),
(22, 'Nguyễn Thị Thùy Trang', '2005-03-12', '', ''),
(27, 'Nguyễn Hoài Thu', '2005-08-22', '', ''),
(28, 'Dương Thanh Ngọc', '2005-08-12', '', '');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `actors`
--
ALTER TABLE `actors`
  ADD PRIMARY KEY (`actor_id`);

--
-- Indexes for table `bookings`
--
ALTER TABLE `bookings`
  ADD PRIMARY KEY (`booking_id`),
  ADD KEY `user_idx` (`user_id`),
  ADD KEY `performance_idx` (`performance_id`),
  ADD KEY `fk_booking_user` (`created_by`);

--
-- Indexes for table `genres`
--
ALTER TABLE `genres`
  ADD PRIMARY KEY (`genre_id`);

--
-- Indexes for table `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`payment_id`),
  ADD KEY `payment_booking_idx` (`booking_id`);

--
-- Indexes for table `performances`
--
ALTER TABLE `performances`
  ADD PRIMARY KEY (`performance_id`),
  ADD KEY `show_idx` (`show_id`),
  ADD KEY `theater_idx` (`theater_id`);

--
-- Indexes for table `reviews`
--
ALTER TABLE `reviews`
  ADD PRIMARY KEY (`review_id`),
  ADD KEY `review_show_idx` (`show_id`),
  ADD KEY `review_user_idx` (`user_id`);

--
-- Indexes for table `seats`
--
ALTER TABLE `seats`
  ADD PRIMARY KEY (`seat_id`),
  ADD KEY `theater_idx2` (`theater_id`),
  ADD KEY `category_idx2` (`category_id`);

--
-- Indexes for table `seat_categories`
--
ALTER TABLE `seat_categories`
  ADD PRIMARY KEY (`category_id`);

--
-- Indexes for table `seat_performance`
--
ALTER TABLE `seat_performance`
  ADD PRIMARY KEY (`seat_id`,`performance_id`),
  ADD KEY `sp_performance_idx` (`performance_id`),
  ADD KEY `idx_seat_id` (`seat_id`);

--
-- Indexes for table `shows`
--
ALTER TABLE `shows`
  ADD PRIMARY KEY (`show_id`);

--
-- Indexes for table `show_actors`
--
ALTER TABLE `show_actors`
  ADD PRIMARY KEY (`show_id`,`actor_id`),
  ADD KEY `fk_show_actors_actor` (`actor_id`);

--
-- Indexes for table `show_genres`
--
ALTER TABLE `show_genres`
  ADD PRIMARY KEY (`show_id`,`genre_id`),
  ADD KEY `show_genres_show_idx` (`show_id`),
  ADD KEY `show_genres_genre_idx` (`genre_id`);

--
-- Indexes for table `theaters`
--
ALTER TABLE `theaters`
  ADD PRIMARY KEY (`theater_id`);

--
-- Indexes for table `tickets`
--
ALTER TABLE `tickets`
  ADD PRIMARY KEY (`ticket_id`),
  ADD UNIQUE KEY `unique_ticket_code` (`ticket_code`),
  ADD KEY `ticket_booking_idx` (`booking_id`),
  ADD KEY `ticket_seat_idx` (`seat_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `unique_email` (`email`),
  ADD UNIQUE KEY `unique_account` (`account_name`);

--
-- Indexes for table `user_detail`
--
ALTER TABLE `user_detail`
  ADD PRIMARY KEY (`user_id`),
  ADD KEY `user_id_idx` (`user_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `actors`
--
ALTER TABLE `actors`
  MODIFY `actor_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT for table `bookings`
--
ALTER TABLE `bookings`
  MODIFY `booking_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1014;

--
-- AUTO_INCREMENT for table `genres`
--
ALTER TABLE `genres`
  MODIFY `genre_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `payment_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1037;

--
-- AUTO_INCREMENT for table `performances`
--
ALTER TABLE `performances`
  MODIFY `performance_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=60;

--
-- AUTO_INCREMENT for table `reviews`
--
ALTER TABLE `reviews`
  MODIFY `review_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=39;

--
-- AUTO_INCREMENT for table `seats`
--
ALTER TABLE `seats`
  MODIFY `seat_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=400;

--
-- AUTO_INCREMENT for table `seat_categories`
--
ALTER TABLE `seat_categories`
  MODIFY `category_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `shows`
--
ALTER TABLE `shows`
  MODIFY `show_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=28;

--
-- AUTO_INCREMENT for table `theaters`
--
ALTER TABLE `theaters`
  MODIFY `theater_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- AUTO_INCREMENT for table `tickets`
--
ALTER TABLE `tickets`
  MODIFY `ticket_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=28;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `bookings`
--
ALTER TABLE `bookings`
  ADD CONSTRAINT `fk_booking_user` FOREIGN KEY (`created_by`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `performance_idx` FOREIGN KEY (`performance_id`) REFERENCES `performances` (`performance_id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `user_idx` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `payments`
--
ALTER TABLE `payments`
  ADD CONSTRAINT `payment_booking_idx` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`booking_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `payments_ibfk_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`booking_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `performances`
--
ALTER TABLE `performances`
  ADD CONSTRAINT `show_idx` FOREIGN KEY (`show_id`) REFERENCES `shows` (`show_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `theater_idx` FOREIGN KEY (`theater_id`) REFERENCES `theaters` (`theater_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `reviews`
--
ALTER TABLE `reviews`
  ADD CONSTRAINT `review_show_idx` FOREIGN KEY (`show_id`) REFERENCES `shows` (`show_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `review_user_idx` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `seats`
--
ALTER TABLE `seats`
  ADD CONSTRAINT `category_idx2` FOREIGN KEY (`category_id`) REFERENCES `seat_categories` (`category_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `theater_idx2` FOREIGN KEY (`theater_id`) REFERENCES `theaters` (`theater_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `seat_performance`
--
ALTER TABLE `seat_performance`
  ADD CONSTRAINT `fk_sp_performance` FOREIGN KEY (`performance_id`) REFERENCES `performances` (`performance_id`),
  ADD CONSTRAINT `fk_sp_seat` FOREIGN KEY (`seat_id`) REFERENCES `seats` (`seat_id`),
  ADD CONSTRAINT `idx_seat_id` FOREIGN KEY (`seat_id`) REFERENCES `seats` (`seat_id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `sp_performance_idx` FOREIGN KEY (`performance_id`) REFERENCES `performances` (`performance_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `show_actors`
--
ALTER TABLE `show_actors`
  ADD CONSTRAINT `fk_show_actors_actor` FOREIGN KEY (`actor_id`) REFERENCES `actors` (`actor_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_show_actors_show` FOREIGN KEY (`show_id`) REFERENCES `shows` (`show_id`) ON DELETE CASCADE;

--
-- Constraints for table `show_genres`
--
ALTER TABLE `show_genres`
  ADD CONSTRAINT `show_genres_genre_idx` FOREIGN KEY (`genre_id`) REFERENCES `genres` (`genre_id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `show_genres_show_idx` FOREIGN KEY (`show_id`) REFERENCES `shows` (`show_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `tickets`
--
ALTER TABLE `tickets`
  ADD CONSTRAINT `ticket_booking_idx` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`booking_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `ticket_seat_idx` FOREIGN KEY (`seat_id`) REFERENCES `seats` (`seat_id`) ON UPDATE CASCADE;

--
-- Constraints for table `user_detail`
--
ALTER TABLE `user_detail`
  ADD CONSTRAINT `user_detail_ibfk_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
