Create Database Library_access;
use Library_access;
show tables;
-- Create Books Table
CREATE TABLE Books (
    BookID INT PRIMARY KEY AUTO_INCREMENT,
    Title VARCHAR(255) NOT NULL,
    AuthorID INT,
    Genre VARCHAR(100),
    ISBN VARCHAR(20) UNIQUE,
    FOREIGN KEY (AuthorID) REFERENCES Authors(AuthorID)
);
-- Create Members Table
CREATE TABLE Members (
    MemberID INT PRIMARY KEY AUTO_INCREMENT,
    MemberName VARCHAR(255) NOT NULL,
    Email VARCHAR(255) UNIQUE
);
-- Create Borrowing Table
CREATE TABLE Borrowing (
    BorrowID INT PRIMARY KEY AUTO_INCREMENT,
    BookID INT,
    MemberID INT,
    BorrowDate DATE NOT NULL,
    DueDate DATE NOT NULL,
    ReturnDate DATE NULL, -- NULL if not yet returned
    FineAmount DECIMAL(5, 2) DEFAULT 0.00,
    FOREIGN KEY (BookID) REFERENCES Books(BookID),
    FOREIGN KEY (MemberID) REFERENCES Members(MemberID)
);
-- Insert Sample Authors
INSERT INTO Authors (AuthorName) VALUES
('J.K. Rowling'),
('George Orwell'),
('J.R.R. Tolkien'),
('Jane Austen');

-- Insert Sample Books
INSERT INTO Books (Title, AuthorID, Genre, ISBN) VALUES
('Harry Potter and the Sorcerer Stone', 1, 'Fantasy', '978-0747532699'),
('1984', 2, 'Dystopian', '978-0451524935'),
('The Hobbit', 3, 'Fantasy', '978-0547928227'),
('Animal Farm', 2, 'Satire', '978-0451526342'),
('Pride and Prejudice', 4, 'Romance', '978-0141439518'),
('Harry Potter and the Chamber of Secrets', 1, 'Fantasy', '978-0439064873');

-- Insert Sample Members
INSERT INTO Members (MemberName, Email) VALUES
('Alice Smith', 'alice@example.com'),
('Bob Johnson', 'bob@example.com'),
('Carol White', 'carol@example.com');

-- Insert Sample Borrowing Records
-- Assume current date is around May 15, 2025 for DueDate calculations
INSERT INTO Borrowing (BookID, MemberID, BorrowDate, DueDate) VALUES
(1, 1, '2025-04-01', '2025-04-15'), -- Alice borrowed Harry Potter 1
(2, 2, '2025-04-05', '2025-04-19'), -- Bob borrowed 1984
(3, 1, '2025-04-10', '2025-04-24'), -- Alice borrowed The Hobbit
(5, 3, '2025-05-01', '2025-05-08'); -- Carol borrowed Pride and Prejudice (for fine testing)

-- Show all books borrowed along with the member's name --
SELECT
    bk.Title AS BookTitle,
    m.MemberName,
    br.BorrowDate,
    br.DueDate,
    br.ReturnDate
FROM
    Borrowing br
INNER JOIN
    Books bk ON br.BookID = bk.BookID
INNER JOIN
    Members m ON br.MemberID = m.MemberID;
    
-- Find members who have borrowed Fantasy books --
SELECT DISTINCT
    m.MemberName
FROM
    Members m
INNER JOIN
    Borrowing br ON m.MemberID = br.MemberID
INNER JOIN
    Books bk ON br.BookID = bk.BookID
WHERE
    bk.Genre = 'Fantasy';
-- Indexing for Optimization --
CREATE INDEX idx_books_author_id ON Books (AuthorID);
CREATE INDEX idx_borrowing_book_id ON Borrowing (BookID);
-- You might also consider an index on MemberID for similar reasons:
-- CREATE INDEX idx_borrowing_member_id ON Borrowing (MemberID);

 -- Views --
-- Create a view to display borrowed books and their members --
 CREATE VIEW Vw_BorrowedBooksDetails AS
SELECT
    br.BorrowID,
    bk.Title AS BookTitle,
    bk.Genre AS BookGenre,
    a.AuthorName,
    m.MemberName,
    br.BorrowDate,
    br.DueDate,
    br.ReturnDate,
    br.FineAmount
FROM
    Borrowing br
INNER JOIN
    Books bk ON br.BookID = bk.BookID
INNER JOIN
    Members m ON br.MemberID = m.MemberID
INNER JOIN
    Authors a ON bk.AuthorID = a.AuthorID;
-- Query the view --
-- Select all data from the view
SELECT * FROM Vw_BorrowedBooksDetails;

-- Example: Find details of books borrowed by 'Alice Smith' that are not yet returned
SELECT BookTitle, AuthorName, BorrowDate, DueDate
FROM Vw_BorrowedBooksDetails
WHERE MemberName = 'Alice Smith' AND ReturnDate IS NULL;    

-- Create a stored procedure to list books by category (Genre). Call the procedure--
DELIMITER //

CREATE PROCEDURE Sp_GetBooksByGenre (
    IN p_genre VARCHAR(100)
)
BEGIN
    SELECT
        BookID,
        Title,
        ISBN,
        (SELECT AuthorName FROM Authors WHERE AuthorID = Books.AuthorID) AS AuthorName
    FROM
        Books
    WHERE
        Genre = p_genre;
END //

DELIMITER ;

-- How to call the procedure:
CALL Sp_GetBooksByGenre('Fantasy');

-- User-defined functions (UDFs)--
-- Create a function to calculate late fine (5 per day after 7 days from DueDate)--
DELIMITER //

CREATE FUNCTION CalculateLateFine (
    p_dueDate DATE,
    p_returnDate DATE
)
RETURNS DECIMAL(5, 2)
DETERMINISTIC
BEGIN
    DECLARE days_overdue INT;
    DECLARE calculated_fine DECIMAL(5, 2);
    DECLARE grace_period_days INT DEFAULT 7;
    DECLARE daily_fine_rate DECIMAL(5, 2) DEFAULT 5.00;

    SET calculated_fine = 0.00; 

    IF p_returnDate IS NOT NULL AND p_returnDate > p_dueDate THEN
        SET days_overdue = DATEDIFF(p_returnDate, p_dueDate);
        IF days_overdue > grace_period_days THEN
            SET calculated_fine = (days_overdue - grace_period_days) * daily_fine_rate;
        END IF;
    END IF;
    
    IF calculated_fine < 0.00 THEN
        SET calculated_fine = 0.00;
    END IF;

    RETURN calculated_fine;
END //

DELIMITER ;

-- How to test the function (UDFs are used in SELECT statements):
SELECT CalculateLateFine('2025-05-01', '2025-05-15') AS FineAmount;

-- Triggers--
-- Create a trigger to update FineAmount in the Borrowing table when a book is returned late--
DELIMITER //

CREATE TRIGGER Trg_Before_Borrowing_Update_SetFine
BEFORE UPDATE ON Borrowing
FOR EACH ROW
BEGIN
    IF NEW.ReturnDate IS NOT NULL THEN
        SET NEW.FineAmount = CalculateLateFine(OLD.DueDate, NEW.ReturnDate);
    ELSE
        SET NEW.FineAmount = 0.00; -- Reset fine if ReturnDate is cleared
    END IF;
END //

DELIMITER ;
-- Testing the Trigger --
-- Assume BorrowID = 4 is for Carol White, DueDate = '2025-05-08'
-- Initial state: FineAmount = 0.00
SELECT BorrowID, DueDate, ReturnDate, FineAmount FROM Borrowing WHERE BorrowID = 4;

-- Test: Return late
UPDATE Borrowing
SET ReturnDate = '2025-05-18' -- 10 days after due, 3 days fineable
WHERE BorrowID = 4;

-- Check FineAmount (should be 15.00)
SELECT BorrowID, DueDate, ReturnDate, FineAmount FROM Borrowing WHERE BorrowID = 4;
