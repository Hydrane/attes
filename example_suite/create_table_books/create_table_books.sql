DROP TABLE IF EXISTS attes_example_books;

--
-- The table 'attes_example_books' records information about books.
--
--     i_id        : The ID of the book, serves as a primary key.
--     s_title     : The title of the book.
--     i_author_id : The ID of the author.
--     s_language  : The language of the original version.
--     i_year      : Year of publication.
--
CREATE TABLE attes_example_books
(
    i_id        INT AUTO_INCREMENT,
    s_title     VARCHAR(256) NOT NULL,
    i_author_id INT,
    s_language  VARCHAR(32),
    i_year      INT,

    PRIMARY KEY(i_id),
    FOREIGN KEY (i_author_id) REFERENCES attes_example_authors(i_id),
    UNIQUE(s_title, i_author_id)
)
ENGINE          = INNODB
DEFAULT CHARSET = utf8
COLLATE         = utf8_bin
;
