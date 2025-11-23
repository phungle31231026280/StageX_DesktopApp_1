-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Nov 23, 2025 at 12:49 PM
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
        DATE_FORMAT(b.created_at, '%m/%Y') as period,
        COUNT(t.ticket_id) as sold_tickets
    FROM bookings b
    JOIN tickets t ON b.booking_id = t.booking_id
    JOIN payments p ON b.booking_id = p.booking_id
    WHERE p.status = 'Thành công'
      AND b.created_at >= DATE_SUB(NOW(), INTERVAL 11 MONTH)
    GROUP BY YEAR(b.created_at), MONTH(b.created_at)
    ORDER BY b.created_at ASC;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_chart_last_4_weeks` ()   BEGIN
    SELECT 
        CONCAT('Tuần ', WEEK(b.created_at, 1)) as period,
        COUNT(t.ticket_id) as sold_tickets
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
        COUNT(t.ticket_id) as sold_tickets
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_booking_pos` (IN `in_user_id` INT, IN `in_performance_id` INT, IN `in_total_amount` DECIMAL(10,2))   BEGIN
    /*
      Gọi thủ tục proc_create_booking để tạo đơn hàng và vé.
      Ứng dụng sẽ truyền danh sách ghế và thực hiện vòng lặp tạo vé ở phía client.
      Sau khi thủ tục proc_create_booking được gọi, bảng bookings sẽ tạo dòng mới với booking_status là 'Đang chờ'.
      Sau đó chúng ta cập nhật booking_status thành 'Đã thanh toán POS' để biểu thị đã thanh toán tại quầy.
    */
    -- Gọi proc_create_booking để tạo đơn hàng với booking_status = 'Đang xử lý'
    CALL proc_create_booking(in_user_id, in_performance_id, in_total_amount);
    -- Sau khi tạo đơn hàng tại quầy, cập nhật trạng thái thành 'Đã hoàn thành'
    UPDATE bookings 
    SET booking_status = 'Đã hoàn thành'
    WHERE booking_id = LAST_INSERT_ID();
    -- Trả về id booking vừa tạo
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

CREATE DEFINER=`root`@`localhost` PROCEDURE `proc_create_ticket` (IN `p_booking_id` INT, IN `p_seat_id` INT, IN `p_ticket_code` VARCHAR(20))   BEGIN
   
    DECLARE v_performance_id INT;

    INSERT INTO tickets (booking_id, seat_id, ticket_code, status, created_at)
    VALUES (p_booking_id, p_seat_id, p_ticket_code, 'Đang chờ', NOW());

    SELECT performance_id INTO v_performance_id
    FROM bookings
    WHERE booking_id = p_booking_id;
    IF v_performance_id IS NOT NULL THEN
        UPDATE seat_performance
        SET status = 'đã đặt'
        WHERE seat_id = p_seat_id
          AND performance_id = v_performance_id;
    END IF;
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
    /*
      Trả về số lượng vé bán cho mỗi năm.
    */
    SELECT CONVERT(YEAR(t.created_at), CHAR) AS period,
           COUNT(*) AS sold_tickets
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
  `user_id` int(11) NOT NULL,
  `performance_id` int(11) NOT NULL,
  `total_amount` decimal(10,3) NOT NULL,
  `booking_status` enum('Đang xử lý','Đã hoàn thành','Đã hủy') NOT NULL DEFAULT 'Đang xử lý',
  `created_at` timestamp NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

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
  `vnp_txn_ref` varchar(64) NOT NULL,
  `vnp_bank_code` varchar(20) DEFAULT NULL,
  `vnp_pay_date` varchar(14) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

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
(17, 8, 1, '2025-11-27', '19:30:00', NULL, 'Đang mở bán', 200000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(18, 8, 3, '2025-11-30', '18:00:00', NULL, 'Đang mở bán', 180000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
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
(30, 11, 1, '2025-11-23', '19:00:00', NULL, 'Đang mở bán', 200000, '2025-08-01 00:00:00', '2025-08-01 00:00:00'),
(31, 10, 3, '2025-11-25', '18:30:00', NULL, 'Đang mở bán', 220000, '2025-08-01 00:00:00', '2025-08-01 00:00:00'),
(32, 12, 2, '2025-11-17', '19:00:00', NULL, 'Đã kết thúc', 160000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(33, 12, 1, '2025-11-19', '20:00:00', NULL, 'Đã kết thúc', 160000, '2025-08-01 00:00:00', '2025-11-22 11:47:10'),
(34, 12, 3, '2025-11-24', '20:00:00', NULL, 'Đang mở bán', 170000, '2025-08-01 00:00:00', '2025-08-01 00:00:00'),
(35, 12, 2, '2025-11-26', '19:00:00', NULL, 'Đang mở bán', 160000, '2025-08-01 00:00:00', '2025-08-01 00:00:00'),
(41, 18, 1, '2025-11-12', '19:30:00', '21:10:00', 'Đã kết thúc', 250000, '2025-11-04 13:08:55', '2025-11-22 11:47:10'),
(42, 18, 2, '2025-11-14', '20:00:00', '21:40:00', 'Đã kết thúc', 200000, '2025-11-04 13:09:41', '2025-11-22 11:47:10'),
(43, 18, 3, '2025-11-15', '20:00:00', '21:40:00', 'Đã kết thúc', 200000, '2025-11-04 13:10:13', '2025-11-22 11:47:10'),
(44, 18, 1, '2025-11-17', '20:30:00', '22:10:00', 'Đã kết thúc', 180000, '2025-11-04 13:10:59', '2025-11-22 11:47:10'),
(45, 19, 2, '2025-11-16', '19:30:00', '21:15:00', 'Đã kết thúc', 300000, '2025-11-04 13:11:48', '2025-11-22 11:47:10'),
(46, 19, 1, '2025-11-17', '18:00:00', '19:45:00', 'Đã kết thúc', 280000, '2025-11-04 13:12:33', '2025-11-22 11:47:10'),
(47, 19, 3, '2025-11-19', '20:00:00', '21:45:00', 'Đã kết thúc', 300000, '2025-11-04 13:13:11', '2025-11-22 11:47:10'),
(48, 19, 1, '2025-11-21', '19:30:00', '21:15:00', 'Đã kết thúc', 250000, '2025-11-04 13:13:48', '2025-11-22 11:47:10'),
(49, 13, 1, '2025-11-23', '19:30:00', '21:05:00', 'Đang mở bán', 350000, '2025-11-04 13:41:51', '2025-11-04 13:41:51'),
(50, 13, 2, '2025-11-24', '20:00:00', '21:35:00', 'Đang mở bán', 300000, '2025-11-04 13:42:37', '2025-11-04 13:42:37'),
(51, 17, 3, '2025-11-28', '19:30:00', '21:25:00', 'Đang mở bán', 350000, '2025-11-04 13:43:57', '2025-11-04 13:43:57'),
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
(6, 'D', 50000, '27ae60');

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
(2, 17, 'trống'),
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
(13, 17, 'trống'),
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
(24, 17, 'trống'),
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
(53, 50, 'trống'),
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
(54, 50, 'trống'),
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
(55, 50, 'trống'),
(55, 52, 'trống'),
(56, 16, 'đã đặt'),
(56, 19, 'trống'),
(56, 22, 'trống'),
(56, 25, 'đã đặt'),
(56, 29, 'đã đặt'),
(56, 32, 'đã đặt'),
(56, 35, 'trống'),
(56, 42, 'trống'),
(56, 45, 'trống'),
(56, 50, 'trống'),
(56, 52, 'trống'),
(57, 16, 'trống'),
(57, 19, 'trống'),
(57, 22, 'trống'),
(57, 25, 'trống'),
(57, 29, 'trống'),
(57, 32, 'trống'),
(57, 35, 'đã đặt'),
(57, 42, 'trống'),
(57, 45, 'trống'),
(57, 50, 'trống'),
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
(58, 50, 'trống'),
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
(59, 50, 'trống'),
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
(62, 50, 'trống'),
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
(63, 50, 'trống'),
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
(64, 50, 'trống'),
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
(67, 50, 'trống'),
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
(68, 50, 'trống'),
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
(71, 50, 'trống'),
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
(72, 50, 'trống'),
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
(73, 50, 'trống'),
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
(74, 50, 'trống'),
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
(75, 50, 'trống'),
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
(78, 18, 'trống'),
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
(79, 31, 'trống'),
(79, 34, 'trống'),
(79, 43, 'trống'),
(79, 47, 'trống'),
(79, 51, 'trống'),
(80, 18, 'trống'),
(80, 20, 'trống'),
(80, 23, 'trống'),
(80, 27, 'đã đặt'),
(80, 31, 'đã đặt'),
(80, 34, 'trống'),
(80, 43, 'trống'),
(80, 47, 'trống'),
(80, 51, 'trống'),
(81, 18, 'trống'),
(81, 20, 'trống'),
(81, 23, 'trống'),
(81, 27, 'đã đặt'),
(81, 31, 'trống'),
(81, 34, 'trống'),
(81, 43, 'trống'),
(81, 47, 'trống'),
(81, 51, 'trống'),
(82, 18, 'đã đặt'),
(82, 20, 'trống'),
(82, 23, 'trống'),
(82, 27, 'đã đặt'),
(82, 31, 'trống'),
(82, 34, 'trống'),
(82, 43, 'trống'),
(82, 47, 'trống'),
(82, 51, 'trống'),
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
(84, 51, 'trống'),
(85, 18, 'trống'),
(85, 20, 'trống'),
(85, 23, 'trống'),
(85, 27, 'trống'),
(85, 31, 'đã đặt'),
(85, 34, 'trống'),
(85, 43, 'trống'),
(85, 47, 'trống'),
(85, 51, 'trống'),
(86, 18, 'trống'),
(86, 20, 'trống'),
(86, 23, 'trống'),
(86, 27, 'trống'),
(86, 31, 'đã đặt'),
(86, 34, 'trống'),
(86, 43, 'trống'),
(86, 47, 'trống'),
(86, 51, 'trống'),
(87, 18, 'trống'),
(87, 20, 'trống'),
(87, 23, 'trống'),
(87, 27, 'đã đặt'),
(87, 31, 'trống'),
(87, 34, 'đã đặt'),
(87, 43, 'trống'),
(87, 47, 'trống'),
(87, 51, 'trống'),
(88, 18, 'trống'),
(88, 20, 'đã đặt'),
(88, 23, 'trống'),
(88, 27, 'đã đặt'),
(88, 31, 'trống'),
(88, 34, 'đã đặt'),
(88, 43, 'trống'),
(88, 47, 'trống'),
(88, 51, 'trống'),
(89, 18, 'trống'),
(89, 20, 'đã đặt'),
(89, 23, 'trống'),
(89, 27, 'đã đặt'),
(89, 31, 'đã đặt'),
(89, 34, 'trống'),
(89, 43, 'trống'),
(89, 47, 'trống'),
(89, 51, 'trống'),
(90, 18, 'trống'),
(90, 20, 'trống'),
(90, 23, 'đã đặt'),
(90, 27, 'đã đặt'),
(90, 31, 'trống'),
(90, 34, 'trống'),
(90, 43, 'trống'),
(90, 47, 'trống'),
(90, 51, 'trống'),
(91, 18, 'trống'),
(91, 20, 'đã đặt'),
(91, 23, 'trống'),
(91, 27, 'trống'),
(91, 31, 'đã đặt'),
(91, 34, 'trống'),
(91, 43, 'trống'),
(91, 47, 'trống'),
(91, 51, 'trống'),
(92, 18, 'đã đặt'),
(92, 20, 'trống'),
(92, 23, 'trống'),
(92, 27, 'đã đặt'),
(92, 31, 'đã đặt'),
(92, 34, 'trống'),
(92, 43, 'trống'),
(92, 47, 'trống'),
(92, 51, 'trống'),
(93, 18, 'trống'),
(93, 20, 'trống'),
(93, 23, 'trống'),
(93, 27, 'đã đặt'),
(93, 31, 'trống'),
(93, 34, 'đã đặt'),
(93, 43, 'trống'),
(93, 47, 'trống'),
(93, 51, 'trống'),
(94, 18, 'trống'),
(94, 20, 'trống'),
(94, 23, 'trống'),
(94, 27, 'trống'),
(94, 31, 'đã đặt'),
(94, 34, 'trống'),
(94, 43, 'trống'),
(94, 47, 'trống'),
(94, 51, 'trống'),
(95, 18, 'trống'),
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
(97, 18, 'trống'),
(97, 20, 'trống'),
(97, 23, 'đã đặt'),
(97, 27, 'trống'),
(97, 31, 'đã đặt'),
(97, 34, 'đã đặt'),
(97, 43, 'trống'),
(97, 47, 'trống'),
(97, 51, 'trống'),
(98, 18, 'trống'),
(98, 20, 'trống'),
(98, 23, 'trống'),
(98, 27, 'trống'),
(98, 31, 'trống'),
(98, 34, 'trống'),
(98, 43, 'trống'),
(98, 47, 'trống'),
(98, 51, 'trống'),
(99, 18, 'đã đặt'),
(99, 20, 'trống'),
(99, 23, 'trống'),
(99, 27, 'đã đặt'),
(99, 31, 'trống'),
(99, 34, 'trống'),
(99, 43, 'trống'),
(99, 47, 'trống'),
(99, 51, 'trống'),
(100, 18, 'trống'),
(100, 20, 'trống'),
(100, 23, 'trống'),
(100, 27, 'trống'),
(100, 31, 'trống'),
(100, 34, 'trống'),
(100, 43, 'trống'),
(100, 47, 'trống'),
(100, 51, 'trống'),
(101, 18, 'trống'),
(101, 20, 'trống'),
(101, 23, 'trống'),
(101, 27, 'đã đặt'),
(101, 31, 'trống'),
(101, 34, 'trống'),
(101, 43, 'trống'),
(101, 47, 'trống'),
(101, 51, 'trống'),
(102, 18, 'trống'),
(102, 20, 'đã đặt'),
(102, 23, 'trống'),
(102, 27, 'trống'),
(102, 31, 'đã đặt'),
(102, 34, 'trống'),
(102, 43, 'trống'),
(102, 47, 'trống'),
(102, 51, 'trống'),
(103, 18, 'đã đặt'),
(103, 20, 'trống'),
(103, 23, 'trống'),
(103, 27, 'trống'),
(103, 31, 'trống'),
(103, 34, 'trống'),
(103, 43, 'trống'),
(103, 47, 'trống'),
(103, 51, 'trống'),
(104, 18, 'trống'),
(104, 20, 'trống'),
(104, 23, 'trống'),
(104, 27, 'trống'),
(104, 31, 'trống'),
(104, 34, 'trống'),
(104, 43, 'trống'),
(104, 47, 'trống'),
(104, 51, 'trống'),
(105, 18, 'đã đặt'),
(105, 20, 'trống'),
(105, 23, 'trống'),
(105, 27, 'đã đặt'),
(105, 31, 'trống'),
(105, 34, 'đã đặt'),
(105, 43, 'trống'),
(105, 47, 'trống'),
(105, 51, 'trống'),
(106, 18, 'trống'),
(106, 20, 'đã đặt'),
(106, 23, 'trống'),
(106, 27, 'đã đặt'),
(106, 31, 'trống'),
(106, 34, 'trống'),
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
(10, 'Làng Song Sinh', 'Một ngôi làng kỳ bí nơi những cặp song sinh liên tục chào đời. Bí mật phía sau sự trùng hợp ấy dần hé lộ, để rồi đẩy người xem vào những tình huống ly kỳ và ám ảnh.', 100, 'Lê Hoàng Nam', 'assets/images/lang-song-sinh-poster.jpg', 'Đang chiếu', '2025-08-01 00:00:00', '2025-08-01 00:00:00'),
(11, 'Lôi Vũ', 'Một trong những vở kịch nổi tiếng nhất thế kỷ XX, “Lôi Vũ” phơi bày những mâu thuẫn giai cấp, đạo đức và gia đình trong xã hội cũ. Vở diễn mang đến sự lay động mạnh mẽ và dư âm lâu dài.', 140, 'Phạm Quang Dũng', 'assets/images/loi-vu.jpg', 'Đang chiếu', '2025-08-01 00:00:00', '2025-08-01 00:00:00'),
(12, 'Ngôi Nhà Trong Mây', 'Một câu chuyện thơ mộng về tình yêu và khát vọng sống, nơi con người tìm đến “ngôi nhà trong mây” để trốn chạy thực tại. Nhưng rồi họ nhận ra: hạnh phúc thật sự chỉ đến khi dám đối diện với chính mình.', 104, 'Vũ Thảo My', 'assets/images/ngoi-nha-trong-may-poster.jpg', 'Đang chiếu', '2025-08-01 00:00:00', '2025-08-01 00:00:00'),
(13, 'Tấm Cám Đại Chiến', 'Phiên bản hiện đại, vui nhộn và đầy sáng tạo của truyện cổ tích “Tấm Cám”. Với yếu tố gây cười, châm biếm và bất ngờ, vở diễn mang đến những phút giây giải trí thú vị cho cả gia đình.', 95, 'Hoàng Anh Tú', 'assets/images/tam-cam-poster.jpg', 'Đang chiếu', '2025-08-01 00:00:00', '2025-11-04 13:41:51'),
(14, 'Má ơi út dìa', 'Câu chuyện cảm động về tình mẫu tử và nỗi day dứt của người con xa quê. Những ký ức, những tiếng gọi “Má ơi” trở thành sợi dây kết nối quá khứ và hiện tại.', 110, 'Nguyễn Thị Thanh Hương', 'assets/images/ma-oi-ut-dia-poster.png', 'Đã kết thúc', '2025-11-04 12:37:19', '2025-11-22 11:47:10'),
(15, 'Tía ơi má dìa', 'Một vở kịch hài – tình cảm về những hiểu lầm, giận hờn và yêu thương trong một gia đình miền Tây. Tiếng cười và nước mắt đan xen tạo nên cảm xúc sâu lắng.', 100, 'Trần Hoài Phong', 'assets/images/tia-oi-ma-dia-poster.jpg', 'Đã kết thúc', '2025-11-04 12:40:24', '2025-11-22 11:47:10'),
(16, 'Đức Thượng Công Tả Quân Lê Văn Duyệt', 'Tái hiện hình tượng vị danh tướng Lê Văn Duyệt – người để lại dấu ấn sâu đậm trong lịch sử và lòng dân Nam Bộ. Một vở diễn lịch sử trang trọng, đầy khí phách.', 130, 'Phạm Hữu Tấn', 'assets/images/duc-thuong-cong-ta-quan-le-van-duyet-poster.jpg', 'Đã kết thúc', '2025-11-04 12:42:26', '2025-11-22 11:47:10'),
(17, 'Chuyến Đò Định Mệnh', 'Một câu chuyện đầy kịch tính xoay quanh chuyến đò cuối cùng của đời người lái đò, nơi tình yêu, tội lỗi và sự tha thứ gặp nhau trong một đêm giông bão.', 115, 'Vũ Ngọc Dũng', 'assets/images/chuyen-do-dinh-menh-poster.jpg', 'Đang chiếu', '2025-11-04 12:43:35', '2025-11-04 13:43:57'),
(18, 'Một Ngày Làm Vua', 'Vở hài kịch xã hội châm biếm về một người bình thường bỗng được trao quyền lực. Từ đó, những tình huống oái oăm, dở khóc dở cười liên tục xảy ra.', 100, 'Nguyễn Hoàng Anh', 'assets/images/mot-ngay-lam-vua-poster.jpg', 'Đã kết thúc', '2025-11-04 12:44:58', '2025-11-22 11:47:10'),
(19, 'Xóm Vịt Trời', 'Một góc nhìn nhân văn và hài hước về cuộc sống mưu sinh của những người lao động nghèo trong một xóm nhỏ ven sông. Dù khốn khó, họ vẫn giữ niềm tin và tình người.', 105, 'Lê Thị Phương Loan', 'assets/images/xom-vit-troi-poster.jpg', 'Đã kết thúc', '2025-11-04 12:46:05', '2025-11-22 11:47:10'),
(20, 'Những con ma nhà hát', '“Những Con Ma Nhà Hát” là một câu chuyện rùng rợn nhưng cũng đầy tính châm biếm, xoay quanh những hiện tượng kỳ bí xảy ra tại một nhà hát cũ sắp bị phá bỏ. Khi đoàn kịch mới đến tập luyện, những bóng ma của các diễn viên quá cố bắt đầu xuất hiện, đưa người xem vào hành trình giằng co giữa nghệ thuật, danh vọng và quá khứ bị lãng quên.', 115, 'Nguyễn Khánh Trung', 'assets/images/nhung-con-ma-poster.jpg', 'Đã kết thúc', '2025-11-04 13:19:55', '2025-11-22 11:47:10');

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
  `ticket_code` varchar(50) NOT NULL,
  `status` enum('Đang chờ','Hợp lệ','Đã sử dụng','Đã hủy') NOT NULL DEFAULT 'Đang chờ',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `account_name` varchar(100) NOT NULL,
  `user_type` enum('Nhân viên','Admin') NOT NULL,
  `status` enum('hoạt động','khóa') NOT NULL DEFAULT 'hoạt động',
  `is_verified` tinyint(1) NOT NULL DEFAULT 0,
  `otp_code` varchar(10) DEFAULT NULL,
  `otp_expires_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `email`, `password`, `account_name`, `user_type`, `status`, `is_verified`, `otp_code`, `otp_expires_at`) VALUES
(1, 'staff@example.com', '$2a$11$jSoyDGEyNSgflwPKbQyA5.wFUNvhqXLQ5rzeoNSbl.YaZZ8ZrpKwm', 'thanhngoc', 'Nhân viên', 'hoạt động', 1, NULL, NULL),
(7, 'admin@example.com', '$2a$11$DdN7GNbBhFyWRYFuKArD7.BfmqgzIpLYXkp7B6SgJBFnLDk5ZCmfG', 'Admin', 'Admin', 'hoạt động', 1, NULL, NULL),
(13, 'mytrangle1509@gmail.com', '$2a$11$fvjwkQmdmtbZ9OtnOh7tGOp.yEHxWnAzu7n9be7OJtterz8v9AbZS', 'trangle', 'Admin', 'hoạt động', 1, NULL, NULL);

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
(1, '', '2005-08-12', '', ''),
(7, 'Le My Phung', '2025-11-22', '', '');

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
  ADD KEY `performance_idx` (`performance_id`);

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
  ADD UNIQUE KEY `unique_txn_ref` (`vnp_txn_ref`),
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
  MODIFY `actor_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `bookings`
--
ALTER TABLE `bookings`
  MODIFY `booking_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=129;

--
-- AUTO_INCREMENT for table `genres`
--
ALTER TABLE `genres`
  MODIFY `genre_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `payment_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=124;

--
-- AUTO_INCREMENT for table `performances`
--
ALTER TABLE `performances`
  MODIFY `performance_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=54;

--
-- AUTO_INCREMENT for table `reviews`
--
ALTER TABLE `reviews`
  MODIFY `review_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=39;

--
-- AUTO_INCREMENT for table `seats`
--
ALTER TABLE `seats`
  MODIFY `seat_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=347;

--
-- AUTO_INCREMENT for table `seat_categories`
--
ALTER TABLE `seat_categories`
  MODIFY `category_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `shows`
--
ALTER TABLE `shows`
  MODIFY `show_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `theaters`
--
ALTER TABLE `theaters`
  MODIFY `theater_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `tickets`
--
ALTER TABLE `tickets`
  MODIFY `ticket_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=245;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `bookings`
--
ALTER TABLE `bookings`
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
